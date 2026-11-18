import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

let library;
runInNewContext(readFileSync(new URL('../src/slappy/browsermicrophones.js', import.meta.url), 'utf8'), {
  addToLibrary(value) { library = value; },
});
let Capture;
class AudioWorkletProcessor {
  constructor() {
    this.messages = [];
    this.port = {postMessage: message => this.messages.push(message)};
  }
}
runInNewContext(library.$slappyMicrophones.workletSource, {
  AudioWorkletProcessor,
  Float32Array,
  registerProcessor(name, implementation) {
    assert.equal(name, 'slappy-capture');
    Capture = implementation;
  },
});

function create(capacity, channels = 1) {
  const capture = new Capture({processorOptions: {capacity, channels}});
  capture.port.onmessage({data: {active: true, generation: 1}});
  return capture;
}

function feed(capture, start, frames = 128) {
  const channels = Array.from({length: capture.channels}, (_, channel) =>
    Float32Array.from({length: frames}, (_, i) => (start + i) * (channel === 0 ? 1 : -1)));
  assert.equal(capture.process([channels]), true);
  assert.ok(capture.messages.filter(message => message.samples).length <= 4,
    'Posted audio messages must remain bounded.');
  assert.ok(capture.count <= capture.capacity, 'Worklet backlog must remain bounded.');
}

function drain(capture, generation = 1) {
  const result = [];
  while (capture.messages.length) {
    const message = capture.messages.shift();
    if (message.samples) {
      if (message.generation === generation) result.push(...message.samples);
      capture.port.onmessage({data: {ack: true}});
    }
  }
  return result;
}

// A busy UI cannot ACK worklet messages, but capture must continue buffering.
const stalled = create(4096);
for (let i = 0; i < 20; i++) feed(stalled, i * 128);
assert.deepEqual(drain(stalled), Array.from({length: 2560}, (_, i) => i));
assert.equal(stalled.count, 0);
assert.equal(stalled.inFlight, 0);
console.log('Capture survives a stalled main thread without losing queued frames.');

// Overflow discards the oldest backlog and retains the newest full capacity.
const overflow = create(256);
for (let i = 0; i < 100; i++) feed(overflow, i * 128);
const overflowData = drain(overflow);
assert.deepEqual(overflowData.slice(-256),
  Array.from({length: 256}, (_, i) => 12800 - 256 + i));
assert.equal(overflowData.length, 4 * 128 + 256);
console.log('Worklet overflow and outstanding transfers remain bounded.');

// Restart must not deliver buffered frames from the preceding capture turn.
const restarted = create(1024);
for (let i = 0; i < 6; i++) feed(restarted, i * 128);
restarted.port.onmessage({data: {active: false, generation: 1}});
restarted.port.onmessage({data: {active: true, generation: 2}});
feed(restarted, 10000);
assert.deepEqual(drain(restarted, 2), Array.from({length: 128}, (_, i) => 10000 + i));
restarted.port.onmessage({data: {closed: true}});
assert.equal(restarted.process([[]]), false);
console.log('Restart discards stale worklet frames and close terminates processing.');

// Split transfers and ring wrapping must preserve interleaved channel order.
const stereo = create(1000, 2);
for (let i = 0; i < 10; i++) {
  feed(stereo, i * 128);
  if (i === 3 || i === 9) {
    const start = i === 3 ? 0 : 512;
    const frames = i === 3 ? 512 : 768;
    const expected = [];
    for (let frame = start; frame < start + frames; frame++) {
      expected.push(frame, -frame);
    }
    assert.deepEqual(drain(stereo), expected);
  }
}
console.log('Buffered stereo capture preserves frame and channel order.');

// Stopping after a UI stall must deliver the complete tail before its marker.
const stopped = create(4096);
for (let i = 0; i < 20; i++) feed(stopped, i * 128);
stopped.port.onmessage({data: {active: false, generation: 1}});
const tail = [];
let stopMarkers = 0;
while (stopped.messages.length) {
  const message = stopped.messages.shift();
  if (message.stopped) {
    stopMarkers++;
    assert.equal(tail.length, 2560);
    assert.equal(stopped.messages.length, 0);
  } else {
    tail.push(...message.samples);
    stopped.port.onmessage({data: {ack: true}});
  }
}
assert.equal(stopMarkers, 1);
assert.deepEqual(tail, Array.from({length: 2560}, (_, i) => i));
console.log('Stopping drains stalled capture before reporting completion.');
