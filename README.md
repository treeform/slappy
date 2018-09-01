# Euphony - 3d sound api for nim.

> Euphony - *noun*: the quality of being pleasing to the ear

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

See test.nim for more details.