import
  std/[monotimes, times],
  openal

when not defined(nimAllocStats):
  {.error: "Run source fade tests with -d:nimAllocStats.".}

const MockCapacity = 64

type MockVoice = object
  live, playing: bool
  gain: ALfloat

var
  clockNow: MonoTime
  nextSource: ALuint
  generatedSources, deletedSources: int
  voices: array[MockCapacity, MockVoice]

proc getMonoTime(): MonoTime =
  ## Supplies a deterministic clock without sleeping between assertions.
  clockNow

proc advanceClock(milliseconds: int) =
  ## Moves the mock wall clock independently of explicit simulation ticks.
  clockNow = clockNow + initDuration(milliseconds = milliseconds)

proc alGetError(): ALenum =
  ## Keeps these playback tests independent of an OpenAL device.
  AL_NO_ERROR

proc alGenSources(count: ALsizei, sources: ptr ALuint) =
  ## Creates a voice in fixed storage so allocation checks cover Slappy.
  doAssert count == 1
  inc nextSource
  doAssert nextSource < MockCapacity
  sources[] = nextSource
  voices[nextSource] = MockVoice(live: true, gain: 1)
  inc generatedSources

proc alDeleteSources(count: ALsizei, sources: ptr ALuint) =
  ## Records exactly one release for each live voice.
  doAssert count == 1 and voices[sources[]].live
  voices[sources[]] = MockVoice()
  inc deletedSources

proc alSourcei(id: ALuint, parameter: ALenum, value: ALint) =
  ## Accepts attaching an empty sound without consulting an audio driver.
  doAssert voices[id].live and parameter == AL_BUFFER
  doAssert not voices[id].playing

proc alGetSourcei(id: ALuint, parameter: ALenum, value: ptr ALint) =
  ## Reports whether the mock source is playing.
  doAssert voices[id].live and parameter == AL_SOURCE_STATE
  value[] = if voices[id].playing: AL_PLAYING else: AL_STOPPED

proc alSourcePlay(id: ALuint) =
  ## Starts or restarts a live source.
  doAssert voices[id].live
  voices[id].playing = true

proc alSourceStop(id: ALuint) =
  ## Stops a live source while preserving its gain.
  doAssert voices[id].live
  voices[id].playing = false

proc alSourcef(id: ALuint, parameter: ALenum, value: ALfloat) =
  ## Stores gain and accepts only the native macOS offset workaround.
  doAssert voices[id].live
  case parameter
  of AL_GAIN:
    voices[id].gain = value
  of AL_SEC_OFFSET:
    doAssert defined(macosx) and not defined(emscripten)
  else:
    doAssert false

proc alGetSourcef(id: ALuint, parameter: ALenum, value: ptr ALfloat) =
  ## Returns gain while rejecting reads through released source handles.
  doAssert voices[id].live and parameter == AL_GAIN
  value[] = voices[id].gain

proc alDeleteBuffers(count: ALsizei, buffers: ptr ALuint) =
  ## Allows the empty sound handles used by these source-only tests.
  doAssert count == 1 and buffers[] == 0

# The implementation binds to the clock and OpenAL functions above.
include ../src/slappy

proc expectGain(source: Source, expected: float32) =
  ## Compares gains with tolerance for float32 interpolation.
  doAssert abs(source.gain - expected) < 0.00001'f

template expectFailure(body: untyped) =
  ## Requires invalid requests to report Slappy's public exception type.
  block:
    var rejected = false
    try:
      body
    except SlappyError:
      rejected = true
    doAssert rejected

echo "New fades start when scheduled and keep independent clocks."
block:
  let
    first = newSource()
    second = newSource()
  advanceClock(2000)
  first.fadeIn(1)
  slappyTick()
  first.expectGain(0)
  advanceClock(250)
  slappyTick()
  first.expectGain(0.25)
  advanceClock(250)
  second.fadeIn(1)
  slappyTick()
  first.expectGain(0.5)
  second.expectGain(0)
  advanceClock(250)
  slappyTick()
  first.expectGain(0.75)
  second.expectGain(0.25)
  first.close()
  second.close()

echo "Explicit ticks advance exactly their delta and reset wall anchors."
block:
  let source = newSource()
  source.fadeIn(1)
  advanceClock(200)
  slappyTick(0.5)
  source.expectGain(0.5)
  slappyTick()
  source.expectGain(0.5)
  advanceClock(250)
  slappyTick()
  source.expectGain(0.75)
  advanceClock(20)
  slappyTick(-1)
  source.expectGain(0.75)
  slappyTick()
  source.expectGain(0.75)
  slappyTick(0.25)
  source.expectGain(1)
  doAssert not source.fading and source.playing
  source.close()

echo "Replacing a fade starts from its current gain and scheduling time."
block:
  let source = newSource()
  source.fadeIn(2)
  slappyTick(1)
  source.expectGain(0.5)
  advanceClock(1000)
  source.fadeTo(0, 1, stopAfterFade = true)
  slappyTick()
  source.expectGain(0.5)
  advanceClock(500)
  slappyTick()
  source.expectGain(0.25)
  source.close()
  doAssert not source.fading
  advanceClock(1000)
  slappyTick()

echo "Playback changes cancel stale fade-outs before source reuse."
block:
  let
    source = newSource()
    sound = newSound()
  for operation in 0 ..< 5:
    source.gain = 1
    source.play()
    source.fadeTo(0, 1, stopAfterFade = true)
    slappyTick(0.25)
    source.expectGain(0.75)
    case operation
    of 0:
      source.stop()
      source.play()
    of 1:
      source.play()
    of 2:
      source.sound = sound
      source.play()
    of 3:
      source.gain = 0.8
    else:
      source.cancelFade()
    slappyTick(2)
    doAssert source.playing and not source.fading
    source.expectGain(if operation == 3: 0.8'f else: 0.75'f)
  source.fadeTo(0, 1, stopAfterFade = true)
  voices[source.id].playing = false
  slappyTick(0.25)
  doAssert not source.fading
  source.play()
  slappyTick(1)
  doAssert source.playing
  source.close()
  source.fadeTo(1, 1)
  source.fadeIn(1)
  source.cancelFade()
  source.close()
  slappyTick()

echo "Crossfades stop the old voice and preserve the replacement."
block:
  let
    first = newSource()
    second = newSource()
  first.gain = 0.8
  first.play()
  crossfade(first, second, 2, replacementGain = 0.6)
  first.expectGain(0.8)
  second.expectGain(0)
  doAssert first.playing and second.playing
  slappyTick(1)
  first.expectGain(0.4)
  second.expectGain(0.3)
  slappyTick(1)
  first.expectGain(0)
  second.expectGain(0.6)
  doAssert not first.playing and second.playing
  doAssert first.id != 0 and second.id != 0
  crossfade(second, first, 0, replacementGain = 0.7)
  doAssert first.playing and not second.playing
  first.expectGain(0.7)
  second.expectGain(0)
  first.fadeTo(0.4, -1)
  first.expectGain(0.4)
  doAssert not first.fading
  first.fadeTo(0, 0, stopAfterFade = true)
  doAssert not first.playing
  first.close()
  second.close()

echo "One-shot fade completion retires sources and releases ownership."
block:
  let
    sound = newSound()
    source = sound.fadeIn(1, targetGain = 0.8)
    sourceId = source.id
    deletedBefore = deletedSources
  doAssert source.playing and source.sound == sound
  slappyTick(0.5)
  source.expectGain(0.4)
  source.fadeTo(0, 0.5, stopAfterFade = true)
  slappyTick(0.5)
  doAssert source.id == 0 and source.sound == nil
  doAssert not voices[sourceId].live
  doAssert deletedSources == deletedBefore + 1
  source.close()
  let completed = sound.fadeIn(1)
  voices[completed.id].playing = false
  slappyTick(0.1)
  doAssert completed.id == 0 and not completed.fading
  doAssert deletedSources == deletedBefore + 2

echo "Invalid fades fail before altering playback or existing envelopes."
block:
  let
    first = newSource()
    second = newSource()
  first.gain = 0.8
  first.play()
  first.fadeTo(0.4, 1)
  second.gain = 0.6
  second.play()
  for invalid in [-1.0'f, Inf.float32, NegInf.float32, NaN.float32]:
    expectFailure:
      first.fadeTo(invalid, 1)
    expectFailure:
      first.fadeIn(1, invalid)
    expectFailure:
      crossfade(first, second, 1, invalid)
    first.expectGain(0.8)
    second.expectGain(0.6)
    doAssert first.fading and not second.fading
    doAssert first.playing and second.playing
  for invalid in [Inf.float32, NegInf.float32, NaN.float32]:
    expectFailure:
      first.fadeTo(0, invalid)
    expectFailure:
      first.fadeIn(invalid)
    expectFailure:
      crossfade(first, second, invalid)
    expectFailure:
      slappyTick(invalid)
    first.expectGain(0.8)
    second.expectGain(0.6)
    doAssert first.fading and not second.fading
  expectFailure:
    crossfade(first, first, 1)
  first.expectGain(0.8)
  doAssert first.fading and first.playing
  slappyTick(0.5)
  first.expectGain(0.6)
  first.close()
  expectFailure:
    crossfade(first, second, 1)
  expectFailure:
    crossfade(second, first, 1)
  second.expectGain(0.6)
  doAssert second.playing and not second.fading
  second.close()

echo "Reused fade envelopes and ticks allocate no Nim memory."
block:
  let
    first = newSource()
    second = newSource()
    memoryBefore = getAllocStats()
    sourcesBefore = (generatedSources, deletedSources)
  for round in 0 ..< 1000:
    first.fadeIn(1)
    advanceClock(250)
    slappyTick()
    first.expectGain(0.25)
    slappyTick(0.25)
    first.expectGain(0.5)
    crossfade(first, second, 0.5, replacementGain = 0.8)
    slappyTick(0.25)
    slappyTick(0.25)
    doAssert not first.playing and second.playing
    second.expectGain(0.8)
    second.stop()
  let memoryAfter = getAllocStats()
  doAssert memoryBefore == memoryAfter, $(memoryAfter - memoryBefore)
  doAssert (generatedSources, deletedSources) == sourcesBefore
  first.close()
  second.close()

doAssert activeSources.len == 0
doAssert generatedSources == deletedSources
echo "Source fade tests passed with zero playback allocations."
