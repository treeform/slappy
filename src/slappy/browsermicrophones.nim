import std/os

const BrowserMicrophoneLibrary = currentSourcePath().parentDir /
  "browsermicrophones.js"

{.passL: "--js-library " & quoteShell(BrowserMicrophoneLibrary).}

proc browserMicrophoneOpen*(
  frequency, channels, bits, capacity: cint,
  deviceName: cstring
): cint {.importc: "slappy_microphone_open", cdecl, raises: [].}
  ## Starts an asynchronous browser microphone request on the main thread.

proc browserMicrophoneStart*(
  handle: cint
) {.importc: "slappy_microphone_start", cdecl, raises: [].}
  ## Starts capturing and resumes audio within a browser user gesture.

proc browserMicrophoneStop*(
  handle: cint
) {.importc: "slappy_microphone_stop", cdecl, raises: [].}
  ## Stops capturing while retaining samples already in the ring buffer.

proc browserMicrophoneStopping*(
  handle: cint
): bool {.importc: "slappy_microphone_stopping", cdecl, raises: [].}
  ## Returns whether a stop is still draining frames from the audio thread.

proc browserMicrophoneClose*(
  handle: cint
) {.importc: "slappy_microphone_close", cdecl, raises: [].}
  ## Closes the microphone, including a pending permission request.

proc browserMicrophoneIsReady(
  handle: cint
): cint {.importc: "slappy_microphone_ready", cdecl, raises: [].}
  ## Returns whether the stream, worklet, and audio context are running.

proc browserMicrophoneErrorLength(
  handle: cint
): cint {.importc: "slappy_microphone_error_length", cdecl, raises: [].}
  ## Returns the UTF-8 byte count of the latest asynchronous error.

proc browserMicrophoneErrorInto(
  handle: cint,
  destination: cstring,
  capacity: cint
) {.importc: "slappy_microphone_error_into", cdecl, raises: [].}
  ## Copies the latest asynchronous error into caller-owned memory.

proc browserMicrophoneAvailable*(
  handle: cint
): cint {.importc: "slappy_microphone_available", cdecl, raises: [].}
  ## Returns the number of complete PCM frames waiting in the ring buffer.

proc browserMicrophoneRead*(
  handle: cint,
  destination: pointer,
  count: cint
) {.importc: "slappy_microphone_read", cdecl, raises: [].}
  ## Copies and consumes complete interleaved PCM frames.

proc browserMicrophoneReady*(handle: cint): bool {.raises: [].} =
  ## Returns true after permission and browser audio initialization finish.
  browserMicrophoneIsReady(handle) != 0

proc browserMicrophoneError*(handle: cint): string {.raises: [].} =
  ## Returns the last browser failure, or an empty string while healthy.
  let length = browserMicrophoneErrorLength(handle).int
  if length > 0:
    result = newString(length)
    browserMicrophoneErrorInto(handle, result.cstring, (length + 1).cint)
