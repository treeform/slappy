addToLibrary({
  $slappyMicrophones: {
    nextHandle: 1,
    devices: {},
    workletSource: `
      class SlappyCapture extends AudioWorkletProcessor {
        constructor(options) {
          super();
          this.channels = options.processorOptions.channels;
          this.capacity = options.processorOptions.capacity;
          this.buffer = new Float32Array(this.capacity * this.channels);
          this.readIndex = 0;
          this.writeIndex = 0;
          this.count = 0;
          this.active = false;
          this.closed = false;
          this.generation = 0;
          this.inFlight = 0;
          this.stopRequested = false;
          this.port.onmessage = (event) => {
            const message = event.data;
            if (message.ack) {
              this.inFlight = Math.max(0, this.inFlight - 1);
              this.flush();
            } else {
              if (message.generation !== this.generation) {
                this.readIndex = 0;
                this.writeIndex = 0;
                this.count = 0;
              }
              this.active = message.active;
              this.closed = !!message.closed;
              this.generation = message.generation;
              this.stopRequested = !this.active && !this.closed;
              this.flush();
            }
          };
        }
        flush() {
          while (!this.closed && this.count && this.inFlight < 4) {
            const frames = Math.min(this.count, 2048);
            const samples = new Float32Array(frames * this.channels);
            const first = Math.min(frames, this.capacity - this.readIndex);
            const offset = this.readIndex * this.channels;
            samples.set(this.buffer.subarray(offset,
              offset + first * this.channels));
            if (first < frames) {
              samples.set(this.buffer.subarray(0,
                (frames - first) * this.channels), first * this.channels);
            }
            this.readIndex = (this.readIndex + frames) % this.capacity;
            this.count -= frames;
            this.inFlight++;
            this.port.postMessage({
              samples,
              generation: this.generation
            }, [samples.buffer]);
          }
          if (this.stopRequested && !this.count) {
            this.stopRequested = false;
            this.port.postMessage({stopped: true, generation: this.generation});
          }
        }
        process(inputs) {
          if (this.closed) return false;
          const input = inputs[0];
          if (!this.active || !input.length) return true;
          // Retain audio while rendering blocks the main thread and its ACKs.
          for (let frame = 0; frame < input[0].length; frame++) {
            if (this.count === this.capacity) {
              this.readIndex = (this.readIndex + 1) % this.capacity;
            } else {
              this.count++;
            }
            const offset = this.writeIndex * this.channels;
            for (let channel = 0; channel < this.channels; channel++) {
              const data = input[Math.min(channel, input.length - 1)];
              this.buffer[offset + channel] = data[frame];
            }
            this.writeIndex = (this.writeIndex + 1) % this.capacity;
          }
          this.flush();
          return true;
        }
      }
      registerProcessor('slappy-capture', SlappyCapture);
    `,
    release: function(device) {
      if (device.releasing) return;
      device.releasing = true;
      device.ready = false;
      if (device.source) {
        device.source.disconnect();
        device.source = null;
      }
      if (device.node) {
        device.node.port.onmessage = null;
        device.node.port.postMessage({closed: true});
        device.node.port.close();
        device.node.disconnect();
        device.node = null;
      }
      if (device.stream) {
        for (const track of device.stream.getTracks()) {
          track.onended = null;
          track.stop();
        }
        device.stream = null;
      }
      if (device.context && device.context.state !== 'closed') {
        device.context.close().catch(function(error) {
          if (!device.error) device.error = String(error);
        });
      }
      device.context = null;
      device.buffer = null;
      device.count = 0;
      if (device.moduleUrl) {
        URL.revokeObjectURL(device.moduleUrl);
        device.moduleUrl = null;
      }
    },
    fail: function(device, error) {
      if (device.closed || device.error) return;
      device.error = error && error.name
        ? error.name + ': ' + error.message : String(error);
      device.active = false;
      slappyMicrophones.release(device);
    },
    resume: function(device) {
      if (!device.context || device.error || device.closed) return;
      device.context.resume().catch(function(error) {
        slappyMicrophones.fail(device, error);
      });
    },
    enqueue: function(device, samples) {
      const bytesPerSample = device.bits / 8;
      const frames = samples.length / device.channels;
      for (let frame = 0; frame < frames; frame++) {
        if (device.count === device.capacity) {
          device.readIndex = (device.readIndex + 1) % device.capacity;
        } else {
          device.count++;
        }
        let offset = device.writeIndex * device.channels * bytesPerSample;
        for (let channel = 0; channel < device.channels; channel++) {
          const input = samples[frame * device.channels + channel];
          const sample = Number.isFinite(input)
            ? Math.max(-1, Math.min(1, input)) : 0;
          if (device.bits === 8) {
            device.buffer[offset++] = Math.round((sample + 1) * 127.5);
          } else {
            const pcm = Math.round(sample * (sample < 0 ? 32768 : 32767));
            device.buffer[offset++] = pcm & 255;
            device.buffer[offset++] = (pcm >> 8) & 255;
          }
        }
        device.writeIndex = (device.writeIndex + 1) % device.capacity;
      }
    }
  },
  slappy_microphone_open__deps: ['$slappyMicrophones', '$UTF8ToString'],
  slappy_microphone_open: function(frequency, channels, bits, capacity, name) {
    const handle = slappyMicrophones.nextHandle++;
    const device = {
      frequency, channels, bits, capacity,
      buffer: null,
      readIndex: 0,
      writeIndex: 0,
      count: 0,
      generation: 0,
      active: false,
      stopping: false,
      ready: false,
      closed: false,
      releasing: false,
      error: '',
      context: null,
      stream: null,
      source: null,
      node: null,
      moduleUrl: null
    };
    slappyMicrophones.devices[handle] = device;
    try {
      if (typeof window === 'undefined') {
        throw new Error('Browser microphone capture requires the main thread.');
      }
      if (!globalThis.isSecureContext || !navigator.mediaDevices ||
          !navigator.mediaDevices.getUserMedia) {
        throw new Error('Microphone capture requires HTTPS or localhost.');
      }
      if (frequency <= 0 || capacity <= 0 ||
          (channels !== 1 && channels !== 2) || (bits !== 8 && bits !== 16)) {
        throw new Error('Invalid microphone frequency, capacity, or PCM format.');
      }
      device.buffer = new Uint8Array(capacity * channels * bits / 8);
      device.context = new AudioContext({sampleRate: frequency});
      if (device.context.sampleRate !== frequency) {
        throw new Error('The browser cannot capture at ' + frequency + ' Hz.');
      }
      if (!device.context.audioWorklet ||
          typeof AudioWorkletNode === 'undefined') {
        throw new Error('This browser does not support AudioWorklet capture.');
      }
      // Resume synchronously so a click can satisfy browser autoplay policy.
      slappyMicrophones.resume(device);
      const deviceName = name ? UTF8ToString(name) : '';
      const audio = {channelCount: channels};
      if (deviceName) audio.deviceId = {exact: deviceName};
      navigator.mediaDevices.getUserMedia({audio}).then(async function(stream) {
        if (device.closed || device.error) {
          stream.getTracks().forEach(function(track) { track.stop(); });
          return;
        }
        device.stream = stream;
        for (const track of stream.getTracks()) {
          track.onended = function() {
            slappyMicrophones.fail(device, 'Microphone input ended.');
          };
        }
        const blob = new Blob([slappyMicrophones.workletSource], {
          type: 'application/javascript'
        });
        device.moduleUrl = URL.createObjectURL(blob);
        await device.context.audioWorklet.addModule(device.moduleUrl);
        if (device.closed || device.error) return;
        URL.revokeObjectURL(device.moduleUrl);
        device.moduleUrl = null;
        device.node = new AudioWorkletNode(device.context, 'slappy-capture', {
          numberOfInputs: 1,
          numberOfOutputs: 1,
          outputChannelCount: [1],
          channelCount: channels,
          channelCountMode: 'explicit',
          channelInterpretation: 'speakers',
          processorOptions: {channels, capacity}
        });
        device.node.onprocessorerror = function() {
          slappyMicrophones.fail(device, 'Microphone AudioWorklet failed.');
        };
        device.node.port.onmessage = function(event) {
          if (device.closed || device.error) return;
          if (event.data.stopped) {
            if (event.data.generation === device.generation) {
              device.stopping = false;
            }
            return;
          }
          // Bound the worklet message queue even when the UI thread stalls.
          device.node.port.postMessage({ack: true});
          if (event.data.generation === device.generation) {
            slappyMicrophones.enqueue(device, event.data.samples);
          }
        };
        device.source = device.context.createMediaStreamSource(stream);
        device.source.connect(device.node);
        // The worklet emits silence, keeping it scheduled without feedback.
        device.node.connect(device.context.destination);
        device.node.port.postMessage({
          active: device.active,
          generation: device.generation
        });
        device.ready = true;
      }).catch(function(error) {
        slappyMicrophones.fail(device, error);
      });
    } catch (error) {
      slappyMicrophones.fail(device, error);
    }
    return handle;
  },
  slappy_microphone_start__deps: ['$slappyMicrophones'],
  slappy_microphone_start: function(handle) {
    const device = slappyMicrophones.devices[handle];
    if (!device || device.closed || device.error) return;
    slappyMicrophones.resume(device);
    if (device.active) return;
    device.active = true;
    device.stopping = false;
    device.generation++;
    device.count = 0;
    device.readIndex = 0;
    device.writeIndex = 0;
    if (device.node) device.node.port.postMessage({
      active: true,
      generation: device.generation
    });
  },
  slappy_microphone_stop__deps: ['$slappyMicrophones'],
  slappy_microphone_stop: function(handle) {
    const device = slappyMicrophones.devices[handle];
    if (!device || !device.active) return;
    device.active = false;
    device.stopping = !!device.node;
    if (device.node) device.node.port.postMessage({
      active: false,
      generation: device.generation
    });
  },
  slappy_microphone_stopping__deps: ['$slappyMicrophones'],
  slappy_microphone_stopping: function(handle) {
    const device = slappyMicrophones.devices[handle];
    return !!(device && !device.error && device.stopping);
  },
  slappy_microphone_close__deps: ['$slappyMicrophones'],
  slappy_microphone_close: function(handle) {
    const device = slappyMicrophones.devices[handle];
    if (!device) return;
    device.closed = true;
    device.active = false;
    slappyMicrophones.release(device);
    delete slappyMicrophones.devices[handle];
  },
  slappy_microphone_ready__deps: ['$slappyMicrophones'],
  slappy_microphone_ready: function(handle) {
    const device = slappyMicrophones.devices[handle];
    return !!(device && device.ready && !device.error &&
      device.context.state === 'running');
  },
  slappy_microphone_error_length__deps: [
    '$slappyMicrophones', '$lengthBytesUTF8'
  ],
  slappy_microphone_error_length: function(handle) {
    const device = slappyMicrophones.devices[handle];
    return device ? lengthBytesUTF8(device.error) : 0;
  },
  slappy_microphone_error_into__deps: ['$slappyMicrophones', '$stringToUTF8'],
  slappy_microphone_error_into: function(handle, destination, capacity) {
    const device = slappyMicrophones.devices[handle];
    stringToUTF8(device ? device.error : '', destination, capacity);
  },
  slappy_microphone_available__deps: ['$slappyMicrophones'],
  slappy_microphone_available: function(handle) {
    const device = slappyMicrophones.devices[handle];
    return device && !device.error ? device.count : 0;
  },
  slappy_microphone_read__deps: ['$slappyMicrophones'],
  slappy_microphone_read: function(handle, destination, count) {
    const device = slappyMicrophones.devices[handle];
    if (!device || device.error || count <= 0 || count > device.count) return;
    const stride = device.channels * device.bits / 8;
    const first = Math.min(count, device.capacity - device.readIndex);
    const offset = device.readIndex * stride;
    // Resolve HEAPU8 for each read because WebAssembly memory may grow.
    HEAPU8.set(device.buffer.subarray(offset, offset + first * stride),
      destination);
    if (first < count) {
      HEAPU8.set(device.buffer.subarray(0, (count - first) * stride),
        destination + first * stride);
    }
    device.readIndex = (device.readIndex + count) % device.capacity;
    device.count -= count;
  }
});
