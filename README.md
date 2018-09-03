# Euphony - 3d sound api for nim.

> Euphony - *noun*: the quality of being pleasing to the ear

Big thanks to [yglukhov's sound](https://github.com/yglukhov/sound) library!

This library provides more high level interface to the [OpenAL](https://github.com/treeform/openal) library.

Which provides the standard features of:
* 3d positions of sounds.
* 3d position of listner.
* Doppler shift.
* Acoustic attenuation.

It also providies some extra features such as:
* A much more nim-like api.
* `.wav` and `.ogg` loading.
* Sound priority. (in preogress)
* Max number of the same sound played. (in preogress)
* Fade in and fade out. (in preogress)
* Ability to queueup sounds. (in preogress)

## Example:

```nim
# rotate sound in 3d
let sound = newSound("tests/drums.mono.wav")
var source = sound.play()
source.looping = true
echo "rotateing sound in 3d, 1 rotation"
for i in 0..360:
  let a = float(i) / 180 * PI
  source.pos = vec3(sin(a), cos(a), 0)
  sleep(20)
source.stop()
sleep(500)
```

See [test.nim](https://github.com/treeform/euphony/blob/master/tests/test.nim) for more details.

## Basic concepts

### Listeren

**Listeren** is the main ear of abstract person in the 3d world.

It has the following properites:
  * gain - Volume on which the listern hears.
  * pos - Position
  * vel - Velocity
  * mat - Orientation matrix

You get one global listeren.

### Sound

**Sound** the recording of the sound that can be played.

It can be loaded with:
`sound = newSound("path/to/wav.or.ogg")`

It has the following functions:
  * play() - Creates a `Source` objects that has the sound playing.

It has the following properites, that are read only:
  * bits - Bit rate or number of bits per sample.
  * size - Number of byte the sound takes up.
  * freq - Frequency or the samples per second rate.
  * channels - Number of channels, only 1 or 2 supported. `WARNING`: 2 channel sounds can't be positioned in 3d
  * samples - Number of samples, a sample is a single integer that sets the position of the speaker membrane.
  * duration - duration of the sound in seconds.

### Source

**Source** represnts the sound playing in a 3d world, kind of like an abstract speaker.

It has the following functions:
  * stop() - Stop the sound.
  * play() - Start plaing the sound (if it was stopped before).

It has the following properites:
  * pitch - How fast the sound plays, or how low or high it sounds.
  * gain - Volume of the sound.
  * maxDistance - Inverse Clamped Distance Model, where sound will not longer be played.
  * rolloffFactor - Set rolloff rate for the source.
  * halfDistance - The distance under which the volume for the source would normally drop by half.
  * minGain - The minimum gain for this source.
  * maxGain - The minimum gain for this source.
  * playing - Is the sound playing.
  * looping - Should the sound loop.
  * pos - Position
  * vel - Velocity
  * mat - Orientation matrix
  * playback - playback position in seconds (offset)
