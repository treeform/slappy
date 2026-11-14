import openal

type Failure = enum
  NoFailure, OpenFailure, ContextFailure, CurrentFailure

var
  failure: Failure
  currentContext: ALCcontext
  openedDevices, closedDevices, createdContexts, destroyedContexts: int
  deletedSources: int
  sourcePlaying: bool

proc alcGetString(device: ALCdevice, param: ALCenum): cstring =
  ## Supplies one deterministic mock output device.
  "Mock output"

proc alcOpenDevice(name: cstring): ALCdevice =
  ## Models an output device without opening operating system audio.
  if failure == OpenFailure:
    return nil
  inc openedDevices
  cast[pointer](1)

proc alcCloseDevice(device: ALCdevice): bool =
  ## Requires the context to have been released before its device.
  doAssert device != nil
  doAssert currentContext == nil
  inc closedDevices
  true

proc alcCreateContext(device: ALCdevice, attributes: ptr ALCint): ALCcontext =
  ## Injects a context creation failure when requested.
  if failure == ContextFailure:
    return nil
  inc createdContexts
  cast[pointer](2)

proc alcMakeContextCurrent(context: ALCcontext): bool =
  ## Tracks the current context and models an activation failure.
  if context != nil and failure == CurrentFailure:
    return false
  currentContext = context
  true

proc alcDestroyContext(context: ALCcontext) =
  ## Enforces the same current-context restriction as Emscripten OpenAL.
  doAssert context != nil
  doAssert currentContext != context
  inc destroyedContexts

proc alGenSources(count: ALsizei, sources: ptr ALuint) =
  ## Reuses an ID to expose stale caller references after source deletion.
  doAssert count == 1
  sources[] = 3
  sourcePlaying = false

proc alGetError(): ALenum =
  ## Keeps source creation independent of an OpenAL runtime.
  AL_NO_ERROR

proc alSourcei(id: ALuint, parameter: ALenum, value: ALint) =
  ## Accepts attaching the test's empty sound buffer.
  discard

proc alGetSourcei(id: ALuint, parameter: ALenum, value: ptr ALint) =
  ## Returns playback state only for a live source handle.
  doAssert id == 3
  value[] = if sourcePlaying: AL_PLAYING else: AL_STOPPED

proc alSourcePlay(id: ALuint) =
  ## Starts the mock source.
  doAssert id == 3
  sourcePlaying = true

proc alSourceStop(id: ALuint) =
  ## Stops the mock source.
  doAssert id == 3
  sourcePlaying = false

proc alDeleteSources(count: ALsizei, sources: ptr ALuint) =
  ## Records source deletion while its owning context remains current.
  doAssert count == 1 and sources[] == 3
  doAssert currentContext != nil
  inc deletedSources

proc alDeleteBuffers(count: ALsizei, buffers: ptr ALuint) =
  ## Keeps the empty test sound independent of an OpenAL runtime.
  discard

# Including the implementation binds its calls to the mock functions above.
include ../src/slappy

slappyClose()
for injected in [OpenFailure, ContextFailure, CurrentFailure]:
  failure = injected
  var failed = false
  try:
    slappyInit()
  except SlappyError:
    failed = true
  doAssert failed
  doAssert openedDevices == closedDevices
  doAssert createdContexts == destroyedContexts
  doAssert currentContext == nil
  slappyClose()

failure = NoFailure
slappyInit()
slappyInit()
doAssert openedDevices == closedDevices + 1
doAssert createdContexts == destroyedContexts + 1

let testSound = newSound()
let oldSource = testSound.play()
doAssert oldSource.playing
oldSource.stop()
slappyTick()
doAssert deletedSources == 1
doAssert not oldSource.playing

let nextSource = testSound.play()
oldSource.stop()
doAssert nextSource.playing
nextSource.stop()
oldSource.play()
doAssert not nextSource.playing
nextSource.play()

slappyClose()
doAssert not nextSource.playing
doAssert activeSources.len == 0
doAssert currentContext == nil
doAssert openedDevices == closedDevices
doAssert createdContexts == destroyedContexts
doAssert deletedSources == 2
slappyClose()
slappyTick()
slappyInit()
slappyClose()
doAssert openedDevices == closedDevices
doAssert createdContexts == destroyedContexts
echo "Audio lifecycle tests passed without an output device."
