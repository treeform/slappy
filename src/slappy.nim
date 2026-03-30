import
  std/[strformat, strutils],
  openal, vmath,
  slappy/[wav, vorbis, slappyformat]

type
  Listener* = object
  Sound* = ref object
    id: ALuint
  Source* = ref object
    id: ALuint
  Microphone* = ref object
    device: ALCdevice
    captureFreq: int
    captureFormat: ALenum
    captureChannels: int
    captureBits: int
    captureBufferSize: int
  StreamingSource* = ref object
    ## A source that plays sequential PCM chunks via OpenAL buffer queuing.
    sourceId: ALuint
    format: ALenum
    freq: int
    queuedBuffers: seq[ALuint]
  SlappyError* = object of IOError

proc cleanup(sound: var typeof(Sound()[])) =
  alDeleteBuffers(1, addr sound.id)
  sound.id = 0

template cleanup(sound: var Sound) =
  sound[].cleanup()

proc `=destroy`(sound: var typeof(Sound()[])) =
  sound.cleanup()

var
  listener* = Listener()
  activeSources: seq[Source]
  device: ALCdevice
  ctx: ALCcontext

proc up*(a: Mat4): Vec3 {.inline.} =
  ## Returns the up direction extracted from a matrix.
  result.x = a[1, 0]
  result.y = a[1, 1]
  result.z = a[1, 2]

proc forward*(a: Mat4): Vec3 {.inline.} =
  ## Returns the forward direction extracted from a matrix.
  result.x = a[2, 0]
  result.y = a[2, 1]
  result.z = a[2, 2]

proc pos*(a: Mat4): Vec3 {.inline.} =
  ## Returns the position extracted from a matrix.
  result.x = a[3, 0]
  result.y = a[3, 1]
  result.z = a[3, 2]

proc `gain=`*(listener: Listener, v: float32) =
  ## Set Master gain. Value should be positive.
  alListenerf(AL_GAIN, v)

proc `gain`*(listener: Listener): float32 =
  ## Get master gain.
  alGetListenerf(AL_GAIN, addr result)

proc `pos=`*(listener: Listener, pos: Vec3) =
  ## Set position of the main listener.
  alListener3f(AL_POSITION, pos.x, pos.y, pos.z)

proc `pos`*(listener: Listener): Vec3 =
  ## Get position of the main listener.
  var tmp = [ALfloat(0.0), 0.0, 0.0]
  alGetListenerfv(AL_POSITION, addr tmp[0])
  return vec3(tmp[0], tmp[1], tmp[2])

proc `vel=`*(listener: Listener, vel: Vec3) =
  ## Set velocity of the main listener.
  alListener3f(AL_VELOCITY, vel.x, vel.y, vel.z)

proc `vel`*(listener: Listener): Vec3 =
  ## Get velocity of the main listener.
  var tmp = [ALfloat(0.0), 0.0, 0.0]
  alGetListenerfv(AL_VELOCITY, addr tmp[0])
  return vec3(tmp[0], tmp[1], tmp[2])

proc `mat=`*(listener: Listener, mat: Mat4) =
  ## Set orientation of the main listener.
  var tmp1 = [ALfloat(0.0), 0.0, 0.0]
  tmp1[0] = mat.pos.x
  tmp1[1] = mat.pos.y
  tmp1[2] = mat.pos.z
  alListenerfv(AL_POSITION, addr tmp1[0])
  var tmp2 = [ALfloat(0.0), 0.0, 0.0, 0.0, 0.0, 0.0]
  tmp2[0] = mat.forward.x
  tmp2[1] = mat.forward.y
  tmp2[2] = mat.forward.z
  tmp2[3] = mat.up.x
  tmp2[4] = mat.up.y
  tmp2[5] = mat.up.z
  alListenerfv(AL_ORIENTATION, addr tmp2[0])

proc `mat`*(listener: Listener): Mat4 =
  ## Get orientation of the main listener.
  var tmp1 = [ALfloat(0.0), 0.0, 0.0]
  alGetListenerfv(AL_POSITION, addr tmp1[0])
  var tmp2 = [ALfloat(0.0), 0.0, 0.0, 0.0, 0.0, 0.0]
  alGetListenerfv(AL_ORIENTATION, addr tmp2[0])
  return lookAt(
    vec3(tmp1[0], tmp1[1], tmp1[2]),
    vec3(tmp2[0], tmp2[1], tmp2[2]),
    vec3(tmp2[3], tmp2[4], tmp2[5])
  )

proc playing*(source: Source): bool {.inline.} =
  ## Returns true when the source is currently playing.
  var state: ALenum
  alGetSourcei(source.id, AL_SOURCE_STATE, addr state)
  result = state == AL_PLAYING

proc stop*(source: Source) =
  ## Stops source playback.
  alSourceStop(source.id)

proc play*(source: Source) =
  ## Starts source playback.
  alSourcePlay(source.id)

proc `pitch=`*(source: Source, v: float32) =
  ## Sets source pitch.
  alSourcef(source.id, AL_PITCH, v)

proc `pitch`*(source: Source): float32 =
  ## Gets source pitch.
  alGetSourcef(source.id, AL_PITCH, addr result)

proc `gain=`*(source: Source, v: float32) =
  ## Sets source gain.
  alSourcef(source.id, AL_GAIN, v)

proc `gain`*(source: Source): float32 =
  ## Gets source gain.
  alGetSourcef(source.id, AL_GAIN, addr result)

proc `maxDistance=`*(source: Source, v: float32) =
  ## Set the Inverse Clamped Distance Model to set the
  ## distance where there will no longer be any attenuation
  ## of the source.
  alSourcef(source.id, AL_MAX_DISTANCE, v)

proc `maxDistance`*(source: Source): float32 =
  ## Gets max distance for attenuation.
  alGetSourcef(source.id, AL_MAX_DISTANCE, addr result)

proc `rolloffFactor=`*(source: Source, v: float32) =
  ## Set rolloff rate for the source. Default is 1.0.
  alSourcef(source.id, AL_ROLLOFF_FACTOR, v)

proc `rolloffFactor`*(source: Source): float32 =
  ## Gets source rolloff factor.
  alGetSourcef(source.id, AL_ROLLOFF_FACTOR, addr result)

proc `halfDistance=`*(source: Source, v: float32) =
  ## The distance under which the volume for the source
  ## would normally drop by half (before being influenced
  ## by rolloff factor or maxDistance).
  alSourcef(source.id, AL_REFERENCE_DISTANCE, v)

proc `halfDistance`*(source: Source): float32 =
  ## Gets reference distance for attenuation.
  alGetSourcef(source.id, AL_REFERENCE_DISTANCE, addr result)

proc `minGain=`*(source: Source, v: float32) =
  ## The minimum gain for this source.
  alSourcef(source.id, AL_MIN_GAIN, v)

proc `minGain`*(source: Source): float32 =
  ## Gets minimum source gain.
  alGetSourcef(source.id, AL_MIN_GAIN, addr result)

proc `maxGain=`*(source: Source, v: float32) =
  ## The maximum gain for this source.
  alSourcef(source.id, AL_MAX_GAIN, v)

proc `maxGain`*(source: Source): float32 =
  ## Gets maximum source gain.
  alGetSourcef(source.id, AL_MAX_GAIN, addr result)

proc `coneOuterGain=`*(source: Source, v: float32) =
  ## The gain when outside the oriented cone.
  alSourcef(source.id, AL_CONE_OUTER_GAIN, v)

proc `coneOuterGain`*(source: Source): float32 =
  ## Gets source gain outside the cone.
  alGetSourcef(source.id, AL_CONE_OUTER_GAIN, addr result)

proc `coneInnerAngle=`*(source: Source, v: float32) =
  ## Inner angle of the sound cone, in degrees. Default is 360.
  alSourcef(source.id, AL_CONE_INNER_ANGLE, v)

proc `coneInnerAngle`*(source: Source): float32 =
  ## Gets inner cone angle in degrees.
  alGetSourcef(source.id, AL_CONE_INNER_ANGLE, addr result)

proc `coneOuterAngle=`*(source: Source, v: float32) =
  ## Outer angle of the sound cone, in degrees. Default is 360.
  alSourcef(source.id, AL_CONE_OUTER_ANGLE, v)

proc `coneOuterAngle`*(source: Source): float32 =
  ## Gets outer cone angle in degrees.
  alGetSourcef(source.id, AL_CONE_OUTER_ANGLE, addr result)

proc `looping=`*(source: Source, v: bool) =
  ## Enables or disables looping for the source.
  var looping: ALint = 0
  if v:
    looping = 1
  alSourcei(source.id, AL_LOOPING, looping)

proc `looping`*(source: Source): bool =
  ## Returns true when source looping is enabled.
  var looping: ALint
  alGetSourcei(source.id, AL_LOOPING, addr looping)
  return looping == 1

proc `playback=`*(source: Source, v: float32) =
  ## Set playback position in seconds (offset).
  alSourcef(source.id, AL_SEC_OFFSET, v)

proc `playback`*(source: Source): float32 =
  ## Get the playback position in seconds (offset).
  alGetSourcef(source.id, AL_SEC_OFFSET, addr result)

proc `pos=`*(source: Source, pos: Vec3) =
  ## Set source position.
  alSource3f(source.id, AL_POSITION, pos.x, pos.y, pos.z)

proc `pos`*(source: Source): Vec3 =
  ## Gets source position.
  var tmp = [ALfloat(0.0), 0.0, 0.0]
  alGetSourcefv(source.id, AL_POSITION, addr tmp[0])
  return vec3(tmp[0], tmp[1], tmp[2])

proc `vel=`*(source: Source, vel: Vec3) =
  ## Sets source velocity.
  alSource3f(source.id, AL_VELOCITY, vel.x, vel.y, vel.z)

proc `vel`*(source: Source): Vec3 =
  ## Gets source velocity.
  var tmp = [ALfloat(0.0), 0.0, 0.0]
  alGetSourcefv(source.id, AL_VELOCITY, addr tmp[0])
  return vec3(tmp[0], tmp[1], tmp[2])

proc `mat=`*(source: Source, mat: Mat4) =
  ## Set source position and cone direction from a matrix.
  var tmp1 = [ALfloat(0.0), 0.0, 0.0]
  tmp1[0] = mat.pos.x
  tmp1[1] = mat.pos.y
  tmp1[2] = mat.pos.z
  alSourcefv(source.id, AL_POSITION, addr tmp1[0])
  var tmp2 = [ALfloat(0.0), 0.0, 0.0, 0.0, 0.0, 0.0]
  tmp2[0] = mat.forward.x
  tmp2[1] = mat.forward.y
  tmp2[2] = mat.forward.z
  tmp2[3] = mat.up.x
  tmp2[4] = mat.up.y
  tmp2[5] = mat.up.z
  alSourcefv(source.id, AL_ORIENTATION, addr tmp2[0])

proc `mat`*(source: Source): Mat4 =
  ## Gets source transform from position and orientation.
  var tmp1 = [ALfloat(0.0), 0.0, 0.0]
  alGetSourcefv(source.id, AL_POSITION, addr tmp1[0])
  var tmp2 = [ALfloat(0.0), 0.0, 0.0, 0.0, 0.0, 0.0]
  alGetSourcefv(source.id, AL_ORIENTATION, addr tmp2[0])
  return lookAt(
    vec3(tmp1[0], tmp1[1], tmp1[2]),
    vec3(tmp2[0], tmp2[1], tmp2[2]),
    vec3(tmp2[3], tmp2[4], tmp2[5])
  )

template fail(msg: string) =
  ## Raises a slappy-specific exception with context.
  raise newException(SlappyError, msg)

proc slappyInit*() {.raises: [SlappyError].} =
  ## Call this on start of your program.
  when defined(emscripten):
    # Always open the first device for emscripten.
    # Emscripten exposes only one device, so alcGetString is invalid.
    device = alcOpenDevice(nil)
  else:
    # Find the first available device on the devices list.
    let deviceNames = $alcGetString(nil, ALC_ALL_DEVICES_SPECIFIER)
    for deviceName in deviceNames.split(char(0)):
      device = alcOpenDevice(deviceName.cstring)
      if device != nil:
        break

  if device == nil:
    fail "Failed to get default device."
  else:
    let deviceName = alcGetString(device, ALC_DEVICE_SPECIFIER)
    echo "Using : ", deviceName, " for sound!"

  ctx = device.alcCreateContext(nil)
  if ctx == nil:
    fail "Failed to create context."
  if not alcMakeContextCurrent(ctx):
    fail "Failed to make context current."

proc slappyClose*() {.raises: [SlappyError].} =
  ## Call this on exit.
  alcDestroyContext(ctx)
  if not alcCloseDevice(device):
    fail "Failed to close device."

proc slappyTick*() =
  ## Updates all sources and sounds.
  var i = 0
  while i < activeSources.len:
    let source = activeSources[i]
    if not source.playing:
      activeSources.del(i)
      dec i
      alDeleteSources(1, addr source.id)
    inc i

proc cleanupOnError(sound: var Sound; msg: string) =
  let hasError = alGetError() != AL_NO_ERROR
  if not hasError: return
  sound.cleanup()
  fail(msg)

proc listCaptureDevices*(): seq[string] =
  ## Returns a list of available audio capture device names.
  when defined(emscripten):
    return @[]
  else:
    let deviceNames = $alcGetString(nil, ALC_CAPTURE_DEVICE_SPECIFIER)
    for name in deviceNames.split(char(0)):
      if name.len > 0:
        result.add(name)

proc newMicrophone*(
  deviceName: string = "",
  frequency: int = 44100,
  channels: int = 1,
  bits: int = 16,
  bufferSize: int = 44100 * 10
): Microphone {.raises: [SlappyError].} =
  ## Opens an audio capture device for microphone input.
  ## Pass an empty deviceName for the default capture device.
  when defined(emscripten):
    fail "Microphone capture is not supported on emscripten."
  else:
    let mic = Microphone()
    mic.captureFreq = frequency
    mic.captureChannels = channels
    mic.captureBits = bits
    mic.captureBufferSize = bufferSize

    if channels == 1:
      if bits == 16: mic.captureFormat = AL_FORMAT_MONO16
      elif bits == 8: mic.captureFormat = AL_FORMAT_MONO8
      else: fail &"Got {bits} bits, only 8 or 16 bits per sample are supported."
    elif channels == 2:
      if bits == 16: mic.captureFormat = AL_FORMAT_STEREO16
      elif bits == 8: mic.captureFormat = AL_FORMAT_STEREO8
      else: fail &"Got {bits} bits, only 8 or 16 bits per sample are supported."
    else:
      fail &"Got {channels} channels, only 1 or 2 channel capture is supported."

    let name = if deviceName.len == 0: nil else: deviceName.cstring
    mic.device = alcCaptureOpenDevice(
      name,
      ALCuint(frequency),
      mic.captureFormat,
      ALCsizei(bufferSize)
    )
    if mic.device == nil:
      fail "Failed to open capture device."

    return mic

proc start*(mic: Microphone) =
  ## Starts audio capture on the microphone.
  alcCaptureStart(mic.device)

proc stop*(mic: Microphone) =
  ## Stops audio capture on the microphone.
  alcCaptureStop(mic.device)

proc close*(mic: Microphone) {.raises: [SlappyError].} =
  ## Closes the capture device and releases resources.
  if not alcCaptureCloseDevice(mic.device):
    fail "Failed to close capture device."

proc samplesAvailable*(mic: Microphone): int =
  ## Returns the number of captured samples available for reading.
  var samples: ALCint
  alcGetIntegerv(mic.device, ALC_CAPTURE_SAMPLES, 1, addr samples)
  return int(samples)

proc read*(mic: Microphone, sampleCount: int): seq[uint8] =
  ## Reads captured PCM samples as raw bytes.
  let bytesPerSample = (mic.captureBits div 8) * mic.captureChannels
  result = newSeq[uint8](sampleCount * bytesPerSample)
  alcCaptureSamples(mic.device, addr result[0], ALCsizei(sampleCount))

proc readAll*(mic: Microphone): seq[uint8] =
  ## Reads all available captured samples as raw bytes.
  let count = mic.samplesAvailable
  if count > 0:
    return mic.read(count)

proc frequency*(mic: Microphone): int {.inline.} =
  ## Gets the capture frequency in Hz.
  return mic.captureFreq

proc channels*(mic: Microphone): int {.inline.} =
  ## Gets the number of capture channels.
  return mic.captureChannels

proc bits*(mic: Microphone): int {.inline.} =
  ## Gets the bits per sample for capture.
  return mic.captureBits

proc toSound*(mic: Microphone, data: seq[uint8]): Sound =
  ## Creates a playable Sound from captured PCM data.
  var
    sound = Sound()
  discard alGetError() # Clear error code
  alGenBuffers(1, addr sound.id)
  sound.cleanupOnError("Couldn't create a buffer ID for a Microphone's sound data.")
  alBufferData(
    sound.id,
    mic.captureFormat,
    unsafeAddr data[0],
    ALsizei(data.len),
    ALsizei(mic.captureFreq)
  )
  sound.cleanupOnError("Couldn't convert a Microphone into a sound's buffer data.")
  return sound

proc newSound*(): Sound =
  ## Returns an empty sound handle.
  new Sound

proc newSound*(filePath: string): Sound =
  ## Loads a sound buffer from wav, slappy, or ogg files.
  var
    sound = newSound()
  discard alGetError() # Clear error code
  alGenBuffers(1, addr sound.id)
  sound.cleanupOnError("Couldn't create a sound's buffer ID.")

  proc format(bits, channels: SomeInteger): ALenum =
    if channels == 1:
      if bits == 16:
        result = AL_FORMAT_MONO16
      elif bits == 8:
        result = AL_FORMAT_MONO8
      else:
        fail &"Got {bits} bits, only 8 or 16 bits per sample are supported"
    elif channels == 2:
      if bits == 16:
        result = AL_FORMAT_STEREO16
      elif bits == 8:
        result = AL_FORMAT_STEREO8
      else:
        fail &"Got {bits} bits, only 8 or 16 bits per sample are supported"
    else:
      fail &"Got {channels} channels, only 1 or 2 channel sounds supported"

  var wav: WavFile
  if filePath.endswith(".wav"):
    wav = loadWav(filePath)
  elif filePath.endswith(".slappy"):
    wav = loadSlappy(filePath)
  elif filePath.endswith(".ogg"):
    wav = loadVorbis(filePath)
  else:
    fail "File format not supported."

  alBufferData(
    sound.id,
    format(wav.bits, wav.channels),
    addr wav.data[0],
    ALsizei wav.size,
    ALsizei wav.freq
  )
  sound.cleanupOnError("Couldn't load a sound's buffer data.")

  return sound

proc bits*(sound: Sound): int {.inline.} =
  ## Gets the bit rate or bits per sample, only 8bits and 16bits per sample supported.
  var
    tmp: ALint
  alGetBufferi(sound.id, AL_BITS, addr tmp)
  return int tmp

proc size*(sound: Sound): int {.inline.} =
  ## Gets the size of the sound buffer in bytes.
  var
    tmp: ALint
  alGetBufferi(sound.id, AL_SIZE, addr tmp)
  return int tmp

proc freq*(sound: Sound): int {.inline.} =
  ## Gets the frequency or the samples per second rate.
  var
    tmp: ALint
  alGetBufferi(sound.id, AL_FREQUENCY, addr tmp)
  return int tmp

proc channels*(sound: Sound): int {.inline.} =
  ## Gets number of channels, only 1 or 2 are supported.
  ## WARNING: 2 channel sounds can't be positioned in 3d.
  var
    tmp: ALint
  alGetBufferi(sound.id, AL_CHANNELS, addr tmp)
  return int tmp

proc samples*(sound: Sound): int {.inline.} =
  ## Gets number of samples.
  let bytesPerSample = sound.bits div 8
  let samplesInChannel = sound.size div bytesPerSample
  return samplesInChannel div sound.channels

proc duration*(sound: Sound): float32 {.inline.} =
  ## Gets duration of the sound in seconds.
  return sound.samples / sound.freq

proc source*(sound: Sound): Source =
  ## Gets the source for the sound.
  var source = Source()
  alGenSources(1, addr source.id)
  activeSources.add(source)
  alSourcei(source.id, AL_BUFFER, cast[ALint](sound.id))
  return source

proc play*(sound: Sound): Source =
  ## Plays the sound.
  var source = sound.source()
  source.play()
  return source

# --- Streaming audio ---

proc alFormat(channels, bits: int): ALenum =
  ## Resolves the OpenAL format enum for a given channel and bit configuration.
  if channels == 1:
    if bits == 16: return AL_FORMAT_MONO16
    elif bits == 8: return AL_FORMAT_MONO8
  elif channels == 2:
    if bits == 16: return AL_FORMAT_STEREO16
    elif bits == 8: return AL_FORMAT_STEREO8
  fail &"Unsupported format: {channels} channels, {bits} bits."

proc newStreamingSource*(
  frequency: int = 24000,
  channels: int = 1,
  bits: int = 16
): StreamingSource =
  ## Creates a streaming audio source for sequential PCM playback.
  ## Call queueData to append PCM chunks, then pump to reclaim processed buffers.
  let ss = StreamingSource()
  ss.format = alFormat(channels, bits)
  ss.freq = frequency
  alGenSources(1, addr ss.sourceId)
  return ss

proc queueData*(ss: StreamingSource, data: seq[uint8]) =
  ## Queues a chunk of raw PCM data for sequential playback.
  if data.len == 0:
    return
  var bufId: ALuint
  alGenBuffers(1, addr bufId)
  alBufferData(bufId, ss.format, unsafeAddr data[0], ALsizei(data.len), ALsizei(ss.freq))
  alSourceQueueBuffers(ss.sourceId, 1, addr bufId)
  ss.queuedBuffers.add(bufId)

  # Auto-start playback if the source isn't already playing.
  var state: ALenum
  alGetSourcei(ss.sourceId, AL_SOURCE_STATE, addr state)
  if state != AL_PLAYING:
    alSourcePlay(ss.sourceId)

proc pump*(ss: StreamingSource) =
  ## Reclaims processed buffers to free resources.
  ## Call this periodically (e.g. each main loop iteration).
  var processed: ALint
  alGetSourcei(ss.sourceId, AL_BUFFERS_PROCESSED, addr processed)
  while processed > 0:
    var bufId: ALuint
    alSourceUnqueueBuffers(ss.sourceId, 1, addr bufId)
    alDeleteBuffers(1, addr bufId)
    let idx = ss.queuedBuffers.find(bufId)
    if idx >= 0:
      ss.queuedBuffers.del(idx)
    dec processed

proc playing*(ss: StreamingSource): bool =
  ## Returns true when the streaming source is currently playing.
  var state: ALenum
  alGetSourcei(ss.sourceId, AL_SOURCE_STATE, addr state)
  return state == AL_PLAYING

proc stop*(ss: StreamingSource) =
  ## Stops playback immediately.
  alSourceStop(ss.sourceId)

proc flush*(ss: StreamingSource) =
  ## Stops playback and discards all queued audio.
  alSourceStop(ss.sourceId)

  # Unqueue and delete all buffers.
  var queued: ALint
  alGetSourcei(ss.sourceId, AL_BUFFERS_QUEUED, addr queued)
  while queued > 0:
    var bufId: ALuint
    alSourceUnqueueBuffers(ss.sourceId, 1, addr bufId)
    alDeleteBuffers(1, addr bufId)
    dec queued
  ss.queuedBuffers.setLen(0)

proc close*(ss: StreamingSource) =
  ## Stops playback and releases the OpenAL source.
  ss.flush()
  alDeleteSources(1, addr ss.sourceId)
