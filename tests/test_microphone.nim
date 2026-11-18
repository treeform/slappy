import openal

type CaptureFailure = enum
  NoFailure, OpenFailure, StartFailure, StopFailure, QueryFailure,
  ReadFailure, CloseFailure

var
  captureFailure: CaptureFailure
  captureError: ALCenum
  captureOpen, capturing: bool
  openCalls, closeCalls, readCalls, startCalls, stopCalls: int
  openedName: string
  openedDefault: bool
  openedFrequency: ALCuint
  openedFormat: ALCenum
  openedCapacity: ALCsizei
  frameBytes: int
  capturedBytes: seq[uint8]

proc alcCaptureOpenDevice(
  name: cstring,
  frequency: ALCuint,
  format: ALCenum,
  capacity: ALCsizei
): ALCdevice =
  ## Models opening a capture device without requesting microphone access.
  inc openCalls
  doAssert not captureOpen
  if captureFailure == OpenFailure:
    return nil
  openedDefault = name == nil
  openedName = $name
  openedFrequency = frequency
  openedFormat = format
  openedCapacity = capacity
  frameBytes =
    case format
    of AL_FORMAT_MONO8: 1
    of AL_FORMAT_MONO16, AL_FORMAT_STEREO8: 2
    of AL_FORMAT_STEREO16: 4
    else: 0
  doAssert frameBytes > 0
  captureOpen = true
  captureError = ALC_NO_ERROR
  capturedBytes.setLen(0)
  cast[pointer](1)

proc alcCaptureStart(device: ALCdevice) =
  ## Tracks capture starts without touching operating system audio.
  doAssert captureOpen and device == cast[pointer](1)
  inc startCalls
  if captureFailure == StartFailure:
    captureError = ALC_INVALID_DEVICE
    return
  capturing = true

proc alcCaptureStop(device: ALCdevice) =
  ## Tracks capture stops while retaining unread samples.
  doAssert captureOpen and device == cast[pointer](1)
  inc stopCalls
  if captureFailure == StopFailure:
    captureError = ALC_INVALID_DEVICE
    return
  capturing = false

proc alcCaptureCloseDevice(device: ALCdevice): bool =
  ## Leaves a failed close open so the caller can retry it.
  doAssert captureOpen and device == cast[pointer](1)
  inc closeCalls
  if captureFailure == CloseFailure:
    return false
  captureOpen = false
  capturing = false
  capturedBytes.setLen(0)
  true

proc alcGetIntegerv(
  device: ALCdevice,
  parameter: ALCenum,
  count: ALCsizei,
  value: ptr ALCint
) =
  ## Reports sample frames rather than bytes or individual channel samples.
  doAssert captureOpen and device == cast[pointer](1)
  doAssert parameter == ALC_CAPTURE_SAMPLES and count == 1
  if captureFailure == QueryFailure:
    captureError = ALC_INVALID_DEVICE
    return
  value[] = ALCint(capturedBytes.len div frameBytes)

proc alcGetError(device: ALCdevice): ALCenum =
  ## Consumes the injected capture error just like OpenAL does.
  doAssert captureOpen and device == cast[pointer](1)
  result = captureError
  captureError = ALC_NO_ERROR

proc alcCaptureSamples(
  device: ALCdevice,
  destination: pointer,
  count: ALCsizei
) =
  ## Copies only the requested frames and preserves the unread remainder.
  doAssert captureOpen and device == cast[pointer](1)
  doAssert count > 0
  inc readCalls
  if captureFailure == ReadFailure:
    captureError = ALC_INVALID_DEVICE
    return
  let byteCount = int(count) * frameBytes
  doAssert byteCount <= capturedBytes.len
  copyMem(destination, addr capturedBytes[0], byteCount)
  capturedBytes = capturedBytes[byteCount ..< capturedBytes.len]

# Including the implementation binds capture calls to the mocks above.
include ../src/slappy

template expectCaptureError(body: untyped) =
  ## Requires a library exception rather than an assertion or silent failure.
  block:
    var failed = false
    try:
      body
    except SlappyError:
      failed = true
    doAssert failed

block:
  let previousCalls = openCalls
  for frequency in [-1, 0]:
    expectCaptureError:
      discard newMicrophone(frequency = frequency)
  for capacity in [-1, 0]:
    expectCaptureError:
      discard newMicrophone(bufferSize = capacity)
  expectCaptureError:
    discard newMicrophone(bufferSize = int(high(ALsizei)), channels = 2)
  for channels in [0, 3]:
    expectCaptureError:
      discard newMicrophone(channels = channels)
  for bits in [0, 24, 32]:
    expectCaptureError:
      discard newMicrophone(bits = bits)
  when sizeof(int) > sizeof(int32):
    let tooLarge = int(high(int32)) + 1
    expectCaptureError:
      discard newMicrophone(frequency = tooLarge)
    expectCaptureError:
      discard newMicrophone(bufferSize = tooLarge)
  doAssert openCalls == previousCalls

captureFailure = OpenFailure
expectCaptureError:
  discard newMicrophone()
doAssert not captureOpen
captureFailure = NoFailure

block:
  let mic: Microphone = nil
  doAssert not mic.ready
  doAssert not mic.stopping
  mic.close()

for channels in [1, 2]:
  for bits in [8, 16]:
    let
      mic = newMicrophone(
        frequency = 24000,
        channels = channels,
        bits = bits,
        bufferSize = 32
      )
      bytesPerFrame = channels * (bits div 8)
    doAssert mic.ready
    doAssert not mic.stopping
    doAssert mic.frequency == 24000
    doAssert mic.channels == channels
    doAssert mic.bits == bits
    doAssert openedDefault
    doAssert openedFrequency == 24000
    doAssert openedCapacity == 32
    doAssert openedFormat == (
      if channels == 1:
        if bits == 8: AL_FORMAT_MONO8 else: AL_FORMAT_MONO16
      else:
        if bits == 8: AL_FORMAT_STEREO8 else: AL_FORMAT_STEREO16
    )
    doAssert mic.samplesAvailable == 0
    doAssert mic.readAll().len == 0
    mic.start()
    doAssert capturing
    doAssert not mic.stopping
    for i in 0 ..< 8 * bytesPerFrame:
      capturedBytes.add(uint8(i + 1))
    let original = capturedBytes
    doAssert mic.samplesAvailable == 8
    block:
      let previousReads = readCalls
      doAssert mic.read(0).len == 0
      expectCaptureError:
        discard mic.read(-1)
      expectCaptureError:
        discard mic.read(9)
      doAssert readCalls == previousReads
      doAssert mic.samplesAvailable == 8
    doAssert mic.read(3) == original[0 ..< 3 * bytesPerFrame]
    doAssert mic.samplesAvailable == 5
    mic.stop()
    doAssert not capturing
    doAssert not mic.stopping
    doAssert mic.readAll() == original[3 * bytesPerFrame ..< original.len]
    doAssert mic.samplesAvailable == 0
    doAssert mic.readAll().len == 0
    mic.close()
    doAssert not captureOpen
    doAssert not mic.ready
    doAssert not mic.stopping
    block:
      let previousCloses = closeCalls
      mic.close()
      doAssert closeCalls == previousCloses
    expectCaptureError:
      mic.start()
    expectCaptureError:
      mic.stop()
    expectCaptureError:
      discard mic.samplesAvailable
    expectCaptureError:
      discard mic.read(0)

block:
  let mic = newMicrophone(deviceName = "Mock microphone")
  doAssert not openedDefault
  doAssert openedName == "Mock microphone"
  capturedBytes = @[1'u8, 2, 3, 4]
  captureFailure = ReadFailure
  expectCaptureError:
    discard mic.read(1)
  captureFailure = NoFailure
  doAssert mic.readAll() == @[1'u8, 2, 3, 4]
  captureFailure = CloseFailure
  expectCaptureError:
    mic.close()
  doAssert captureOpen
  doAssert mic.ready
  captureFailure = NoFailure
  mic.close()
  doAssert not captureOpen

doAssert startCalls == 4
doAssert stopCalls == 4

block:
  let mic = newMicrophone()
  captureFailure = StartFailure
  expectCaptureError:
    mic.start()
  doAssert not capturing
  captureFailure = NoFailure
  captureError = ALC_INVALID_VALUE
  mic.start()
  doAssert capturing
  captureFailure = StopFailure
  expectCaptureError:
    mic.stop()
  doAssert capturing
  captureFailure = NoFailure
  captureError = ALC_INVALID_VALUE
  mic.stop()
  doAssert not capturing
  captureFailure = QueryFailure
  expectCaptureError:
    discard mic.samplesAvailable
  captureFailure = NoFailure
  captureError = ALC_INVALID_VALUE
  doAssert mic.samplesAvailable == 0
  capturedBytes = @[1'u8, 2]
  captureError = ALC_INVALID_VALUE
  doAssert mic.read(1) == @[1'u8, 2]
  mic.close()

echo "Microphone tests passed without opening an audio device."
