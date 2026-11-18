import slappy

when not defined(emscripten):
  {.error: "Build this example with -d:emscripten from the tests directory.".}

{.emit: """
#include <emscripten.h>
EM_JS(void, microphone_status, (const char *message, int canPlay), {
  document.getElementById('status').textContent = UTF8ToString(message);
  document.getElementById('play').disabled = !canPlay;
});
""".}

{.pragma: browserExport, exportc, cdecl, dynlib,
  codegenDecl: "EMSCRIPTEN_KEEPALIVE $# $#$#".}

const
  Frequency = 24000
  RecordingFrames = Frequency * 2

var
  microphone: Microphone
  recording: seq[uint8]
  playback: Source
  capturing: bool

proc microphoneStatus(message: cstring, canPlay: cint) {.importc:
  "microphone_status", nodecl.}
  ## Copies status into the browser controls.

proc emscriptenSetMainLoop(
  callback: proc() {.cdecl.},
  framesPerSecond: cint,
  simulateInfiniteLoop: cint
) {.importc: "emscripten_set_main_loop", header: "<emscripten.h>".}
  ## Registers a nonblocking browser frame callback.

proc status(message: string) =
  ## Updates the visible status without interpreting it as HTML.
  microphoneStatus(message.cstring, cint(recording.len > 0 and not capturing))

proc releaseMicrophone() =
  ## Releases the browser input even while permission is pending.
  capturing = false
  if microphone != nil:
    microphone.close()
    microphone = nil

proc recordMicrophone() {.browserExport.} =
  ## Requests permission and starts a two-second recording from a click.
  try:
    releaseMicrophone()
    if playback != nil:
      playback.close()
      playback = nil
    recording.setLen(0)
    microphone = newMicrophone(
      frequency = Frequency,
      channels = 1,
      bits = 16,
      bufferSize = Frequency
    )
    microphone.start()
    capturing = true
    status("Waiting for microphone permission and audio setup...")
  except SlappyError as error:
    releaseMicrophone()
    status(error.msg)

proc stopMicrophone() {.browserExport.} =
  ## Cancels pending permission or ends capture and releases the input.
  releaseMicrophone()
  status("Microphone closed. Recorded " & $(recording.len div 2) & " frames.")

proc playMicrophone() {.browserExport.} =
  ## Plays the recorded PCM using Slappy's usual OpenAL playback API.
  if recording.len == 0:
    return
  try:
    if playback != nil:
      playback.close()
      playback = nil
    slappyInit()
    playback = newSound(recording, Frequency).play()
    status("Playing the recording.")
  except SlappyError as error:
    status(error.msg)

proc shutdownMicrophone() {.browserExport.} =
  ## Closes audio resources before the browser leaves the page.
  releaseMicrophone()
  if playback != nil:
    playback.close()
    playback = nil
  slappyClose()

proc tick() {.cdecl.} =
  ## Polls capture without blocking browser permission or audio callbacks.
  slappyTick()
  if not capturing:
    return
  try:
    if not microphone.ready:
      return
    let
      remaining = RecordingFrames - recording.len div 2
      available = min(microphone.samplesAvailable, remaining)
    if available > 0:
      recording.add(microphone.read(available))
    status("Recording: " & $(recording.len div 2) & " / " &
      $RecordingFrames & " frames.")
    if recording.len div 2 == RecordingFrames:
      releaseMicrophone()
      status("Recorded two seconds. Microphone closed. Click Play recording.")
  except SlappyError as error:
    releaseMicrophone()
    status(error.msg)

emscriptenSetMainLoop(tick, 0, 0)
