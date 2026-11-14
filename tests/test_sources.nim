import openal

when not defined(nimAllocStats):
  {.error: "Run reusable-source tests with -d:nimAllocStats.".}

const MockCapacity = 128

type
  SourceFailure = enum
    NoSourceFailure, FailWithoutSource, FailAfterSource
  MockVoice = object
    live, playing: bool
    buffer: ALuint
    gain, x, y, z, offset: ALfloat

var
  currentContext: ALCcontext
  pendingError: ALenum
  sourceFailure: SourceFailure
  bindingFailure: bool
  nextSource, nextBuffer: ALuint
  generatedSources, deletedSources: int
  generatedBuffers, deletedBuffers: int
  mockVoices: array[MockCapacity, MockVoice]
  liveBuffers: array[MockCapacity, bool]

proc alcGetString(device: ALCdevice, param: ALCenum): cstring =
  ## Supplies one output device without touching operating system audio.
  "Mock output"

proc alcOpenDevice(name: cstring): ALCdevice =
  ## Supplies a stable mock device handle.
  cast[pointer](1)

proc alcCloseDevice(device: ALCdevice): bool =
  ## Requires all playback contexts to be released first.
  doAssert currentContext == nil
  true

proc alcCreateContext(device: ALCdevice, attributes: ptr ALCint): ALCcontext =
  ## Supplies a stable mock context handle.
  cast[pointer](2)

proc alcMakeContextCurrent(context: ALCcontext): bool =
  ## Records which context owns source and buffer operations.
  currentContext = context
  true

proc alcDestroyContext(context: ALCcontext) =
  ## Requires source cleanup before the context is destroyed.
  doAssert currentContext != context
  for voice in mockVoices:
    doAssert not voice.live

proc alGetError(): ALenum =
  ## Returns and clears the most recent injected OpenAL failure.
  result = pendingError
  pendingError = AL_NO_ERROR

proc alGenSources(count: ALsizei, sources: ptr ALuint) =
  ## Allocates a mock source ID, optionally failing before or after creation.
  doAssert currentContext != nil and count == 1
  if sourceFailure == FailWithoutSource:
    sources[] = 0
    pendingError = AL_OUT_OF_MEMORY
    return
  inc nextSource
  doAssert nextSource < MockCapacity
  sources[] = nextSource
  mockVoices[nextSource] = MockVoice(live: true)
  inc generatedSources
  if sourceFailure == FailAfterSource:
    pendingError = AL_OUT_OF_MEMORY

proc alDeleteSources(count: ALsizei, sources: ptr ALuint) =
  ## Releases a source and detaches its buffer before buffer destruction.
  doAssert currentContext != nil and count == 1
  doAssert mockVoices[sources[]].live
  mockVoices[sources[]] = MockVoice()
  inc deletedSources

proc alSourcei(id: ALuint, parameter: ALenum, value: ALint) =
  ## Models stopped-source buffer attachment and a rejected replacement.
  doAssert mockVoices[id].live and parameter == AL_BUFFER
  doAssert not mockVoices[id].playing
  if bindingFailure:
    pendingError = AL_INVALID_VALUE
    return
  doAssert value == 0 or liveBuffers[value]
  mockVoices[id].buffer = ALuint(value)

proc alGetSourcei(id: ALuint, parameter: ALenum, value: ptr ALint) =
  ## Reports the current playback state of a live voice.
  doAssert mockVoices[id].live and parameter == AL_SOURCE_STATE
  value[] = if mockVoices[id].playing: AL_PLAYING else: AL_STOPPED

proc alSourcePlay(id: ALuint) =
  ## Activates an already allocated voice with its existing buffer.
  doAssert mockVoices[id].live
  mockVoices[id].playing = mockVoices[id].buffer != 0

proc alSourceStop(id: ALuint) =
  ## Models a stopped voice retaining a stale driver playback offset.
  doAssert mockVoices[id].live
  mockVoices[id].playing = false
  if mockVoices[id].buffer != 0:
    mockVoices[id].offset = 0.01'f

proc alSourcef(id: ALuint, parameter: ALenum, value: ALfloat) =
  ## Records gain and offset updates without allocating mock storage.
  doAssert mockVoices[id].live
  case parameter
  of AL_GAIN:
    mockVoices[id].gain = value
  of AL_SEC_OFFSET:
    mockVoices[id].offset = value
  else:
    doAssert false

proc alSource3f(id: ALuint, parameter: ALenum, x, y, z: ALfloat) =
  ## Records position updates in fixed mock storage.
  doAssert mockVoices[id].live and parameter == AL_POSITION
  mockVoices[id].x = x
  mockVoices[id].y = y
  mockVoices[id].z = z

proc alGenBuffers(count: ALsizei, buffers: ptr ALuint) =
  ## Creates one mock buffer during the initial sound preload.
  doAssert currentContext != nil and count == 1
  inc nextBuffer
  doAssert nextBuffer < MockCapacity
  buffers[] = nextBuffer
  liveBuffers[nextBuffer] = true
  inc generatedBuffers

proc alBufferData(id: ALuint, format: ALenum, data: pointer,
    size, frequency: ALsizei) =
  ## Accepts real decoded fixture PCM into the preallocated mock buffer.
  doAssert liveBuffers[id] and size > 0 and frequency > 0

proc alDeleteBuffers(count: ALsizei, buffers: ptr ALuint) =
  ## Rejects deleting a buffer while any live source still references it.
  doAssert count == 1
  if buffers[] == 0:
    return
  doAssert currentContext != nil and liveBuffers[buffers[]]
  for voice in mockVoices:
    doAssert not voice.live or voice.buffer != buffers[]
  liveBuffers[buffers[]] = false
  inc deletedBuffers

# The implementation binds to the mock functions declared above.
include ../src/slappy

proc boundTo(voice: Source, expected: Sound): bool =
  ## Compares buffer ownership without retaining a module-scope getter result.
  voice.sound == expected

slappyInit()
var
  first = newSound("tests/data/ding.wav")
  second = newSound("tests/data/ding.wav")
  pool: array[24, Source]
for voice in pool.mitems:
  voice = newSource()
  doAssert voice.boundTo(nil) and not voice.playing
  voice.sound = first
  doAssert voice.boundTo(first)
  doAssert mockVoices[voice.id].buffer == first.id
slappyTick()
doAssert generatedSources == pool.len and deletedSources == 0

echo "Reusable voices preserve their handles after stopping and completion."
let completedId = pool[0].id
pool[0].play()
mockVoices[completedId].playing = false
slappyTick()
doAssert pool[0].id == completedId
pool[0].play()
doAssert pool[0].playing
pool[0].stop()
slappyTick()
doAssert pool[0].id == completedId and deletedSources == 0
doAssert mockVoices[completedId].offset == 0

echo "Legacy one-shots retire without affecting reusable voices."
let
  completed = first.play()
  legacyActive = second.play()
completed.stop()
slappyTick()
doAssert not completed.playing and completed.boundTo(nil)
doAssert legacyActive.playing and deletedSources == 1
completed.close()
doAssert deletedSources == 1
legacyActive.close()
legacyActive.close()
doAssert deletedSources == 2
doAssert activeSources.len == pool.len

echo "Rejected buffer changes preserve the previous retained sound."
bindingFailure = true
var rejected = false
try:
  pool[0].sound = second
except SlappyError:
  rejected = true
bindingFailure = false
doAssert rejected and pool[0].boundTo(first)
doAssert mockVoices[pool[0].id].buffer == first.id

block rejectedInitialBinding:
  let
    activeBefore = activeSources.len
    generatedBefore = generatedSources
    deletedBefore = deletedSources
  bindingFailure = true
  var failed = false
  try:
    discard first.source()
  except SlappyError:
    failed = true
  bindingFailure = false
  doAssert failed and activeSources.len == activeBefore
  doAssert generatedSources == generatedBefore + 1
  doAssert deletedSources == deletedBefore + 1

echo "Preloaded playback, rebinds, gain and position allocate nothing."
let
  memoryBefore = getAllocStats()
  sourcesBefore = (generatedSources, deletedSources)
  buffersBefore = (generatedBuffers, deletedBuffers)
for round in 0 ..< 1000:
  for i, voice in pool:
    voice.stop()
    doAssert mockVoices[voice.id].offset == 0
    voice.sound = if (round + i) mod 2 == 0: first else: second
    voice.gain = 0.5'f
    voice.pos = vec3(i.float32, 0, -1)
    voice.play()
    doAssert voice.playing
    doAssert mockVoices[voice.id].gain == 0.5'f
    doAssert mockVoices[voice.id].x == i.float32
    voice.stop()
  slappyTick()
let memoryAfter = getAllocStats()
doAssert memoryAfter == memoryBefore, $(memoryAfter - memoryBefore)
doAssert (generatedSources, deletedSources) == sourcesBefore
doAssert (generatedBuffers, deletedBuffers) == buffersBefore

echo "Bound sounds survive callers and release only after detachment."
let retained = newSource()
var temporary = newSound("tests/data/ding.wav")
let temporaryId = temporary.id
retained.sound = temporary
temporary = nil
doAssert liveBuffers[temporaryId]
retained.play()
retained.sound = first
doAssert not liveBuffers[temporaryId]
doAssert retained.boundTo(first)
retained.sound = nil
doAssert retained.boundTo(nil)
doAssert mockVoices[retained.id].buffer == 0
retained.close()
retained.close()

echo "Failed source creation cleans up without entering the active registry."
for injected in [FailWithoutSource, FailAfterSource]:
  sourceFailure = injected
  let activeBefore = activeSources.len
  var failed = false
  try:
    discard newSource()
  except SlappyError:
    failed = true
  doAssert failed and activeSources.len == activeBefore
sourceFailure = NoSourceFailure

echo "Shutdown releases all voices before their last retained buffers."
first = nil
second = nil
slappyClose()
doAssert generatedSources == deletedSources
doAssert generatedBuffers == deletedBuffers
doAssert activeSources.len == 0
for voice in pool:
  doAssert not voice.playing and voice.boundTo(nil)
  voice.close()
slappyClose()
slappyTick()
slappyInit()
let reopened = newSource()
reopened.close()
slappyClose()
doAssert generatedSources == deletedSources
echo "Reusable source tests passed with zero playback allocations."
