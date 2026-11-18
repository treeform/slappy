# Microphone capture

Slappy uses OpenAL capture on native platforms and Web Audio capture when
compiled with `-d:emscripten`. Both return interleaved PCM through the same
`Microphone` API. No OpenAI connection or API key is needed for capture.

## Browser example

Install Emscripten and Slappy's usual Nim dependencies, then run from the
repository root:

```sh
cd tests
nim c --threads:off -d:emscripten manual_browser_microphone.nim
python3 -m http.server 8000 --directory dist
```

Open <http://localhost:8000/manual_browser_microphone.html>. Click **Record two
seconds**, allow microphone access, then click **Play recording**. **Stop and
close microphone** also cancels a pending permission request. The example keeps
recorded audio in page memory and does not send it to a server.

## Browser capture lifecycle

Create and start the microphone in a click or other user gesture. Browser
permission and audio setup happen asynchronously. Continue yielding to the
browser event loop and poll `ready` from your frame callback:

```nim
import slappy

var
  microphone: Microphone
  finishing: bool

proc beginRecording() =
  ## Called directly by a user gesture.
  microphone = newMicrophone(frequency = 24000, bufferSize = 24000)
  microphone.start()
  finishing = false

proc pollRecording() =
  ## Called by the application's nonblocking frame loop.
  try:
    if microphone == nil:
      return
    if microphone.ready or finishing:
      let pcm = microphone.readAll()
      if pcm.len > 0:
        echo "Captured ", pcm.len, " PCM bytes"
    if finishing and not microphone.stopping:
      microphone.close()
      microphone = nil
      finishing = false
  except SlappyError as error:
    microphone.close()
    microphone = nil
    finishing = false
    echo error.msg

proc finishRecording() =
  ## Requests stop while the frame loop drains the remaining audio.
  if microphone != nil:
    microphone.stop()
    finishing = true

proc cancelRecording() =
  ## Releases the input and cancels any pending permission request.
  if microphone != nil:
    microphone.close()
    microphone = nil
    finishing = false
```

Catch `SlappyError` from `newMicrophone`, `start`, and `stop` in your UI as well.
Permission denial and later setup failures are reported by `ready`, `stopping`,
`samplesAvailable`, or `read`, so they can appear after `newMicrophone` returns.
`ready` returns false while setup is pending and after close. Native devices are
ready immediately after a successful open.

`start` can be called before permission resolves. `stop` requests the end of
capture but keeps the input open and preserves queued frames. Browser capture
runs on an audio thread, so its remaining frames arrive asynchronously. Continue
yielding to the browser event loop and reading PCM while `stopping` is true.
Once `stopping` becomes false, call `readAll` one final time before closing to
retain the end of the recording. Do not busy-wait on `stopping`, because that
prevents the pending audio from arriving. Native stops are synchronous, and
`stopping` returns false for native, closed, or nil microphones.

Call `close` to release the browser microphone indicator and audio resources.
Closing immediately cancels pending capture and discards any remaining audio.
Repeated `close` calls are safe, including after failure or while permission is
pending. A late permission grant after close is immediately released.

`bufferSize`, `samplesAvailable`, and `read(sampleCount)` count sample frames,
not bytes. A stereo frame contains two samples. Supported output formats are
mono or stereo, unsigned 8-bit or signed 16-bit PCM. WebAssembly uses little-endian
16-bit samples. Partial reads preserve unread frames. Reads beyond the available
count raise `SlappyError`, and reading zero frames returns an empty sequence.

Both the browser PCM queue and its audio-thread backlog have a fixed capacity.
The audio thread buffers input during brief rendering stalls, so a busy frame
does not immediately drop captured audio. When a buffer fills, new input
replaces its oldest unread frames. Poll regularly for streaming use and keep
the event loop responsive during longer operations.
Restarting a stopped microphone clears the old capture queue. Calling `start`
again during capture leaves queued frames intact.

## Browser requirements

- Serve the page over HTTPS or localhost. Microphone capture requires a secure
  context and browser permission. Embedded pages may also need their host's
  microphone permissions policy.
- Use a browser with `getUserMedia`, `AudioContext`, and `AudioWorklet` support.
  Call Slappy capture from the browser main thread. Worker and pthread capture
  are not supported.
- Create or start capture from a user gesture so the audio context can run.
  Keep the event loop responsive. Capture does not require Asyncify or shared
  memory.
- Slappy loads its embedded AudioWorklet through a blob URL. A restrictive
  Content Security Policy must permit that module to load.
- Web Audio converts microphone input to the requested capture frequency.
  Available frequencies depend on the browser. An unsupported rate raises
  `SlappyError` instead of silently returning PCM at a different rate.
- Browser `listCaptureDevices()` returns an empty sequence. Use the default
  input by omitting `deviceName`; the browser and operating system choose it.
  A nonempty `deviceName` must be a browser `MediaDeviceInfo.deviceId`, not a
  native OpenAL device name. Obtain browser IDs through your own device picker.

The manual example uses Slappy playback as well as capture. Playback still uses
Emscripten's OpenAL implementation. Native microphone usage and permission rules
remain platform dependent.

## Automated browser tests

The browser tests compile a separate WebAssembly harness and use Chromium's
synthetic microphone. They do not record room audio.

```sh
cd tests/browser
npm ci
npx playwright install chromium
npm test
```

Browser API references: [getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia),
[AudioWorklet](https://developer.mozilla.org/en-US/docs/Web/API/AudioWorklet), and
[AudioContext sample rates](https://developer.mozilla.org/en-US/docs/Web/API/AudioContext/AudioContext).
