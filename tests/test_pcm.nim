import openal

const MockCapacity = 32

type BufferFailure = enum
  NoBufferFailure, FailWithoutBuffer, FailAfterBuffer, FailUpload

var
  pendingError: ALenum
  bufferFailure: BufferFailure
  nextBuffer: ALuint
  generatedBuffers, deletedBuffers, uploadCount: int
  liveBuffers: array[MockCapacity, bool]
  uploadedFormat: ALenum
  uploadedFrequency: ALsizei
  uploadedData: seq[uint8]

proc alGetError(): ALenum =
  ## Returns and clears the most recent injected OpenAL failure.
  result = pendingError
  pendingError = AL_NO_ERROR

proc alGenBuffers(count: ALsizei, buffers: ptr ALuint) =
  ## Models buffer creation failing before or after an ID is allocated.
  doAssert count == 1
  if bufferFailure == FailWithoutBuffer:
    buffers[] = 0
    pendingError = AL_OUT_OF_MEMORY
    return
  inc nextBuffer
  doAssert nextBuffer < MockCapacity
  buffers[] = nextBuffer
  liveBuffers[nextBuffer] = true
  inc generatedBuffers
  if bufferFailure == FailAfterBuffer:
    pendingError = AL_OUT_OF_MEMORY

proc alBufferData(id: ALuint, format: ALenum, data: pointer,
    size, frequency: ALsizei) =
  ## Copies PCM bytes as OpenAL does, without retaining the caller's memory.
  doAssert liveBuffers[id] and size > 0 and frequency > 0
  inc uploadCount
  if bufferFailure == FailUpload:
    pendingError = AL_INVALID_VALUE
    return
  uploadedFormat = format
  uploadedFrequency = frequency
  uploadedData.setLen(int(size))
  copyMem(addr uploadedData[0], data, int(size))

proc alDeleteBuffers(count: ALsizei, buffers: ptr ALuint) =
  ## Requires every allocated buffer to be released exactly once.
  doAssert count == 1
  if buffers[] == 0:
    return
  doAssert liveBuffers[buffers[]]
  liveBuffers[buffers[]] = false
  inc deletedBuffers

# The implementation binds to the mock functions declared above.
include ../src/slappy

template expectPcmError(body: untyped) =
  ## Requires invalid PCM input to fail before creating or uploading a buffer.
  block:
    let
      generatedBefore = generatedBuffers
      uploadedBefore = uploadCount
    var failed = false
    try:
      body
    except SlappyError:
      failed = true
    doAssert failed
    doAssert generatedBuffers == generatedBefore
    doAssert uploadCount == uploadedBefore

proc testFormats() =
  ## Checks all supported PCM formats, defaults, copying, and buffer lifetime.
  let formats = [
    (1, 8, AL_FORMAT_MONO8),
    (1, 16, AL_FORMAT_MONO16),
    (2, 8, AL_FORMAT_STEREO8),
    (2, 16, AL_FORMAT_STEREO16)
  ]
  for (channels, bits, format) in formats:
    var pcm = [0'u8, 20, 40, 60, 80, 100, 120, 140]
    block:
      let sound = newSound(pcm, 22050, channels, bits)
      doAssert sound.id != 0
      doAssert uploadedFormat == format
      doAssert uploadedFrequency == 22050
      doAssert uploadedData == @pcm
      pcm[0] = 255
      doAssert uploadedData[0] == 0
    doAssert generatedBuffers == deletedBuffers
  block:
    let sound = newSound([0'u8, 0], 44100)
    doAssert sound.id != 0
    doAssert uploadedFormat == AL_FORMAT_MONO16
    doAssert uploadedFrequency == 44100
  doAssert generatedBuffers == deletedBuffers

proc testInvalidPcm() =
  ## Checks malformed parameters and incomplete mono or stereo sample frames.
  expectPcmError:
    discard newSound([], 44100)
  for frequency in [0, -1]:
    expectPcmError:
      discard newSound([0'u8, 0], frequency)
  for channels in [-1, 0, 3, high(int)]:
    expectPcmError:
      discard newSound([0'u8, 0], 44100, channels)
  for bits in [-1, 0, 24, 32, high(int)]:
    expectPcmError:
      discard newSound([0'u8, 0], 44100, 1, bits)
  for (channels, bits) in [(1, 16), (2, 8), (2, 16)]:
    expectPcmError:
      discard newSound([0'u8], 44100, channels, bits)
  when sizeof(int) > sizeof(ALsizei):
    # Exercise size limits without allocating a multi-gigabyte test buffer.
    expectPcmError:
      discard pcmFormat(int(high(ALsizei)) + 1, 44100, 1, 8)
    expectPcmError:
      discard newSound([0'u8, 0], int(high(ALsizei)) + 1)

proc testFailures() =
  ## Checks failed creation and upload release any acquired buffer exactly once.
  for failure in [FailWithoutBuffer, FailAfterBuffer, FailUpload]:
    let uploadedBefore = uploadCount
    bufferFailure = failure
    var failed = false
    try:
      discard newSound([0'u8, 0], 44100)
    except SlappyError:
      failed = true
    doAssert failed
    doAssert generatedBuffers == deletedBuffers
    if failure == FailUpload:
      doAssert uploadCount == uploadedBefore + 1
    else:
      doAssert uploadCount == uploadedBefore
  bufferFailure = NoBufferFailure
  pendingError = AL_INVALID_VALUE
  block:
    let sound = newSound([0'u8, 0], 44100)
    doAssert sound.id != 0
  doAssert generatedBuffers == deletedBuffers

proc testFileFormat() =
  ## Keeps file decoding compatible with 64-bit WAV metadata on 32-bit targets.
  doAssert alFormat(1'i64, 16'i64) == AL_FORMAT_MONO16
  doAssert alFormat(2'i64, 8'i64) == AL_FORMAT_STEREO8
  block:
    let sound = newSound("tests/data/ding.wav")
    doAssert sound.id != 0
    doAssert uploadedFormat == AL_FORMAT_MONO16
    doAssert uploadedData.len > 0
  doAssert generatedBuffers == deletedBuffers

testFormats()
testInvalidPcm()
testFailures()
testFileFormat()
echo "PCM buffer formats, validation, ownership, and failure cleanup passed."
