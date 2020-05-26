import euphony/vorbis, euphony/wav, openal, strutils, vmath

type
  Listener* = object
  Sound* = ref object
    id: ALuint
  Source* = ref object
    id: ALuint

var
  listener* = Listener()
  activeSources: seq[Source]
  device: ALCdevice
  ctx: ALCcontext

## Listener functions

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

## Source functions

proc playing*(source: Source): bool {.inline.} =
  var state: ALenum
  alGetSourcei(source.id, AL_SOURCE_STATE, addr state)
  result = state == AL_PLAYING

proc stop*(source: Source) =
  alSourceStop(source.id)

proc play*(source: Source) =
  alSourcePlay(source.id)

proc `pitch=`*(source: Source, v: float32) =
  alSourcef(source.id, AL_PITCH, v)

proc `pitch`*(source: Source): float32 =
  alGetSourcef(source.id, AL_PITCH, addr result)

proc `gain=`*(source: Source, v: float32) =
  alSourcef(source.id, AL_GAIN, v)

proc `gain`*(source: Source): float32 =
  alGetSourcef(source.id, AL_GAIN, addr result)

proc `maxDistance=`*(source: Source, v: float32) =
  ## Set the Inverse Clamped Distance Model to set the
  ## distance where there will no longer be any attenuation
  ## of the source.
  alSourcef(source.id, AL_MAX_DISTANCE, v)

proc `maxDistance`*(source: Source): float32 =
  alGetSourcef(source.id, AL_MAX_DISTANCE, addr result)

proc `rolloffFactor=`*(source: Source, v: float32) =
  ## Set rolloff rate for the source. Default is 1.0.
  alSourcef(source.id, AL_ROLLOFF_FACTOR, v)

proc `rolloffFactor`*(source: Source): float32 =
  alGetSourcef(source.id, AL_ROLLOFF_FACTOR, addr result)

proc `halfDistance=`*(source: Source, v: float32) =
  ## The distance under which the volume for the source
  ## would normally drop by half (before being influenced
  ## by rolloff factor or maxDistance).
  alSourcef(source.id, AL_REFERENCE_DISTANCE, v)

proc `halfDistance`*(source: Source): float32 =
  alGetSourcef(source.id, AL_REFERENCE_DISTANCE, addr result)

proc `minGain=`*(source: Source, v: float32) =
  ## The minimum gain for this source.
  alSourcef(source.id, AL_MIN_GAIN, v)

proc `minGain`*(source: Source): float32 =
  alGetSourcef(source.id, AL_MIN_GAIN, addr result)

proc `maxGain=`*(source: Source, v: float32) =
  ## The minimum gain for this source.
  alSourcef(source.id, AL_MAX_GAIN, v)

proc `maxGain`*(source: Source): float32 =
  alGetSourcef(source.id, AL_MAX_GAIN, addr result)

proc `coneOuterGain=`*(source: Source, v: float32) =
  ## The gain when outside the oriented cone.
  alSourcef(source.id, AL_CONE_OUTER_GAIN, v)

proc `coneOuterGain`*(source: Source): float32 =
  alGetSourcef(source.id, AL_CONE_OUTER_GAIN, addr result)

proc `coneInnerAngle=`*(source: Source, v: float32) =
  ## Inner angle of the sound cone, in degrees. Default is 360.
  alSourcef(source.id, AL_CONE_INNER_ANGLE, v)

proc `coneInnerAngle`*(source: Source): float32 =
  alGetSourcef(source.id, AL_CONE_INNER_ANGLE, addr result)

proc `coneOuterAngle=`*(source: Source, v: float32) =
  ## Outer angle of the sound cone, in degrees. Default is 360.
  alSourcef(source.id, AL_CONE_OUTER_ANGLE, v)

proc `coneOuterAngle`*(source: Source): float32 =
  alGetSourcef(source.id, AL_CONE_OUTER_ANGLE, addr result)

proc `looping=`*(source: Source, v: bool) =
  var looping: ALint = 0
  if v == true: looping = 1
  alSourcei(source.id, AL_LOOPING, looping)

proc `looping`*(source: Source): bool =
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
  var tmp = [ALfloat(0.0), 0.0, 0.0]
  alGetSourcefv(source.id, AL_POSITION, addr tmp[0])
  return vec3(tmp[0], tmp[1], tmp[2])

proc `vel=`*(source: Source, vel: Vec3) =
  alSource3f(source.id, AL_VELOCITY, vel.x, vel.y, vel.z)

proc `vel`*(source: Source): Vec3 =
  var tmp = [ALfloat(0.0), 0.0, 0.0]
  alGetSourcefv(source.id, AL_VELOCITY, addr tmp[0])
  return vec3(tmp[0], tmp[1], tmp[2])

proc `mat=`*(source: Source, mat: Mat4) =
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
  var tmp1 = [ALfloat(0.0), 0.0, 0.0]
  alGetSourcefv(source.id, AL_POSITION, addr tmp1[0])
  var tmp2 = [ALfloat(0.0), 0.0, 0.0, 0.0, 0.0, 0.0]
  alGetSourcefv(source.id, AL_ORIENTATION, addr tmp2[0])
  return lookAt(
    vec3(tmp1[0], tmp1[1], tmp1[2]),
    vec3(tmp2[0], tmp2[1], tmp2[2]),
    vec3(tmp2[3], tmp2[4], tmp2[5])
  )

## Euphony functions

proc euphonyInit*() =
  ## Call this on start of your program.
  device = alcOpenDevice(nil)
  if device == nil:
    quit "Euphony: failed to get default device"
  ctx = device.alcCreateContext(nil)
  if ctx == nil:
    quit "Euphony: failed to create context"
  if not alcMakeContextCurrent(ctx):
    quit "Euphony: failed to make context current"

proc euphonyClose*() =
  ## Call this on exit.
  alcDestroyContext(ctx)
  if not alcCloseDevice(device):
    quit "Euphony: failed to close device"

proc euphonyTick*() =
  ## Updates all sources and sounds.
  var i = 0
  while i < activeSources.len:
    let source = activeSources[i]
    if not source.playing:
      activeSources.del(i)
      dec i
      alDeleteSources(1, addr source.id)
    inc i

## Sound functions

proc newSound*(): Sound =
  result.new()

proc newSound*(filePath: string): Sound =
  var
    sound = Sound()
  alGenBuffers(1, addr sound.id)

  proc format(bits, channels: int): ALenum =
    if channels == 1:
      if bits == 16:
        result = AL_FORMAT_MONO16
      elif bits == 8:
        result = AL_FORMAT_MONO8
      else:
        echo "Only 8 or 16 bits per sample are supported"
    elif channels == 2:
      if bits == 16:
        result = AL_FORMAT_STEREO16
      elif bits == 8:
        result = AL_FORMAT_STEREO8
      else:
        echo "Only 8 or 16 bits per sample are supported"
    else:
      echo "Only 1 or 2 channel sounds supported"

  if filePath.endswith(".wav"):
    var
      wav = readWav(filePath)
    alBufferData(
      sound.id,
      format(wav.bits, wav.channels),
      wav.data,
      ALsizei wav.size,
      ALsizei wav.freq
    )
  elif filePath.endswith(".ogg"):
    var
      verbis = readVorbis(filePath)
    alBufferData(
      sound.id,
      format(verbis.bits, verbis.channels),
      verbis.data,
      ALsizei verbis.size,
      ALsizei verbis.freq
    )
    verbis.free()
  else:
    echo "File format not suppoerted ", filePath

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

proc play*(sound: Sound): Source =
  var source = Source()
  alGenSources(1, addr source.id)
  activeSources.add(source)
  alSourcei(source.id, AL_BUFFER, cast[ALint](sound.id))
  alSourcePlay(source.id)
  return source
