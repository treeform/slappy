# Slappy - 3d sound api for nim.

`nimble install slappy`

![Github Actions](https://github.com/treeform/slappy/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/slappy)

## About

Big thanks to [yglukhov's sound](https://github.com/yglukhov/sound) library!

This library provides higher level interface to the [OpenAL](https://github.com/treeform/openal) library.

Slappy provides the standard features of:
* 3d positions of sounds.
* 3d position of listener.
* Doppler shift.
* Acoustic attenuation.

Slappy also provides some extra features such as:
* A much more nim-like api.
* `.wav` and `.ogg` loading.
* Sound priority. (in progress)
* Max number of the same sound played. (in progress)
* Fade in and fade out. (in progress)
* Ability to queued sounds. (in progress)

## Example:

```nim
# rotate sound in 3d
let sound = newSound("tests/drums.mono.wav")
var source = sound.play()
source.looping = true
echo "rotating sound in 3d, 1 rotation"
for i in 0..360:
  let a = float(i) / 180 * PI
  source.pos = vec3(sin(a), cos(a), 0)
  sleep(20)
source.stop()
sleep(500)
```

See [test.nim](https://github.com/treeform/Slappy/blob/master/tests/test.nim) for more details.

## Basic concepts

### Listener

**Listener** is the main ear of abstract person in the 3d world.

Listener has the following properties:
  * gain - Volume on which the listener hears.
  * pos - Position
  * vel - Velocity
  * mat - Orientation matrix

You get one global Listener.

### Sound

**Sound** the recording of the sound that can be played.

Sound can be loaded with:
`sound = newSound("path/to/wav.or.ogg")`

Sound has the following functions:
  * play() - Creates a `Source` objects that has the sound playing.

Sound has the following properties, that are read only:
  * bits - Bit rate or number of bits per sample.
  * size - Number of byte the sound takes up.
  * freq - Frequency or the samples per second rate.
  * channels - Number of channels, only 1 or 2 supported. `WARNING`: 2 channel sounds can't be positioned in 3d
  * samples - Number of samples, a sample is a single integer that sets the position of the speaker membrane.
  * duration - duration of the sound in seconds.

### Source

**Source** represents the sound playing in a 3d world, kind of like an abstract speaker.

Source has the following functions:
  * stop() - Stop the sound.
  * play() - Start playing the sound (if it was stopped before).

Source has the following properties:
  * pitch - How fast the sound plays, or how low or high it sounds.
  * gain - Volume of the sound.
  * maxDistance - Inverse Clamped Distance Model, where sound will not longer be played.
  * rolloffFactor - Set roll off rate for the source.
  * halfDistance - The distance under which the volume for the source would normally drop by half.
  * minGain - The minimum gain for this source.
  * maxGain - The minimum gain for this source.
  * playing - Is the sound playing.
  * looping - Should the sound loop.
  * pos - Position
  * vel - Velocity
  * mat - Orientation matrix
  * playback - playback position in seconds (offset)

# API: slappy

```nim
import slappy
```

## **type** Listener


```nim
Listener = object
```

## **type** Sound


```nim
Sound = ref object
 id: ALuint
```

## **type** Source


```nim
Source = ref object
 id: ALuint
```

## **var** listener


```nim
listener = Listener()
```

## **proc** gain=

Set Master gain. Value should be positive.

```nim
proc gain=(listener: Listener; v: float32)
```

## **proc** gain

Get master gain.

```nim
proc gain(listener: Listener): float32
```

## **proc** pos=

Set position of the main listener.

```nim
proc pos=(listener: Listener; pos: Vec3)
```

## **proc** pos

Get position of the main listener.

```nim
proc pos(listener: Listener): Vec3
```

## **proc** vel=

Set velocity of the main listener.

```nim
proc vel=(listener: Listener; vel: Vec3)
```

## **proc** vel

Get velocity of the main listener.

```nim
proc vel(listener: Listener): Vec3
```

## **proc** mat=

Set orientation of the main listener.

```nim
proc mat=(listener: Listener; mat: Mat4)
```

## **proc** mat

Get orientation of the main listener.

```nim
proc mat(listener: Listener): Mat4
```

## **proc** playing


```nim
proc playing(source: Source): bool {.inline.}
```

## **proc** stop


```nim
proc stop(source: Source)
```

## **proc** play


```nim
proc play(source: Source)
```

## **proc** pitch=


```nim
proc pitch=(source: Source; v: float32)
```

## **proc** pitch


```nim
proc pitch(source: Source): float32
```

## **proc** gain=


```nim
proc gain=(source: Source; v: float32)
```

## **proc** gain


```nim
proc gain(source: Source): float32
```

## **proc** maxDistance=

Set the Inverse Clamped Distance Model to set the distance where there will no longer be any attenuation of the source.

```nim
proc maxDistance=(source: Source; v: float32)
```

## **proc** maxDistance


```nim
proc maxDistance(source: Source): float32
```

## **proc** rolloffFactor=

Set rolloff rate for the source. Default is 1.0.

```nim
proc rolloffFactor=(source: Source; v: float32)
```

## **proc** rolloffFactor


```nim
proc rolloffFactor(source: Source): float32
```

## **proc** halfDistance=

The distance under which the volume for the source would normally drop by half (before being influenced by rolloff factor or maxDistance).

```nim
proc halfDistance=(source: Source; v: float32)
```

## **proc** halfDistance


```nim
proc halfDistance(source: Source): float32
```

## **proc** minGain=

The minimum gain for this source.

```nim
proc minGain=(source: Source; v: float32)
```

## **proc** minGain


```nim
proc minGain(source: Source): float32
```

## **proc** maxGain=

The minimum gain for this source.

```nim
proc maxGain=(source: Source; v: float32)
```

## **proc** maxGain


```nim
proc maxGain(source: Source): float32
```

## **proc** coneOuterGain=

The gain when outside the oriented cone.

```nim
proc coneOuterGain=(source: Source; v: float32)
```

## **proc** coneOuterGain


```nim
proc coneOuterGain(source: Source): float32
```

## **proc** coneInnerAngle=

Inner angle of the sound cone, in degrees. Default is 360.

```nim
proc coneInnerAngle=(source: Source; v: float32)
```

## **proc** coneInnerAngle


```nim
proc coneInnerAngle(source: Source): float32
```

## **proc** coneOuterAngle=

Outer angle of the sound cone, in degrees. Default is 360.

```nim
proc coneOuterAngle=(source: Source; v: float32)
```

## **proc** coneOuterAngle


```nim
proc coneOuterAngle(source: Source): float32
```

## **proc** looping=


```nim
proc looping=(source: Source; v: bool)
```

## **proc** looping


```nim
proc looping(source: Source): bool
```

## **proc** playback=

Set playback position in seconds (offset).

```nim
proc playback=(source: Source; v: float32)
```

## **proc** playback

Get the playback position in seconds (offset).

```nim
proc playback(source: Source): float32
```

## **proc** pos=

Set source position.

```nim
proc pos=(source: Source; pos: Vec3)
```

## **proc** pos


```nim
proc pos(source: Source): Vec3
```

## **proc** vel=


```nim
proc vel=(source: Source; vel: Vec3)
```

## **proc** vel


```nim
proc vel(source: Source): Vec3
```

## **proc** mat=


```nim
proc mat=(source: Source; mat: Mat4)
```

## **proc** mat


```nim
proc mat(source: Source): Mat4
```

## **proc** slappyInit

Call this on start of your program.

```nim
proc slappyInit()
```

## **proc** slappyClose

Call this on exit.

```nim
proc slappyClose()
```

## **proc** slappyTick

Updates all sources and sounds.

```nim
proc slappyTick()
```

## **proc** newSound


```nim
proc newSound(): Sound
```

## **proc** newSound


```nim
proc newSound(filePath: string): Sound {.raises: [Defect, IOError, OSError, Exception, ValueError], tags: [ReadIOEffect, WriteIOEffect].}
```

## **proc** bits

Gets the bit rate or bits per sample, only 8bits and 16bits per sample supported.

```nim
proc bits(sound: Sound): int {.inline.}
```

## **proc** size

Gets the size of the sound buffer in bytes.

```nim
proc size(sound: Sound): int {.inline.}
```

## **proc** freq

Gets the frequency or the samples per second rate.

```nim
proc freq(sound: Sound): int {.inline.}
```

## **proc** channels

Gets number of channels, only 1 or 2 are supported. WARNING: 2 channel sounds can't be positioned in 3d.

```nim
proc channels(sound: Sound): int {.inline.}
```

## **proc** samples

Gets number of samples.

```nim
proc samples(sound: Sound): int {.inline.}
```

## **proc** duration

Gets duration of the sound in seconds.

```nim
proc duration(sound: Sound): float32 {.inline.}
```

## **proc** play


```nim
proc play(sound: Sound): Source
```
