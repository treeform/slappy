# Reusable playback sources

Load sound buffers and allocate reusable voices during startup. A voice
created with `newSource()` remains allocated when playback finishes, when
stopped, and when `slappyTick()` runs. Assign its `sound` property to attach
a loaded buffer, then use the existing gain, position, play, and stop APIs.

```nim
slappyInit()
block:
  let hit = newSound("hit.ogg")
  let voice = newSource()
  voice.sound = hit
  voice.gain = 0.5
  voice.play()

  # Subsequent triggers reuse the existing source and decoded sound.
  voice.stop()
  voice.play()

  voice.close()
slappyClose()
```

Assigning `voice.sound` stops playback before attaching the new buffer.
Assign `nil` to detach the buffer. A voice retains its attached sound, so
the buffer cannot be destroyed while the source uses it. Keep preloaded
sounds alive for the complete playback session to avoid releasing buffers
when changing a voice's sound.

Stopping a reusable voice explicitly resets its playback offset on macOS.
This avoids an OpenAL issue where rapid stop/replay can retain a stale
offset and silently leave the source stopped. Set `playback` after stopping
if the next playback should begin at a particular offset. Other platforms
use their normal OpenAL stop behavior.

`close()` releases a source explicitly and can be called repeatedly.
`slappyClose()` also releases all remaining voices before their context.
Release voices and sound buffers before closing that context.

`sound.source()` and `sound.play()` still create temporary voices that
`slappyTick()` releases once playback stops. Use them when allocation-free
playback is not required.

Reusable sources avoid Nim allocations and OpenAL source creation or
deletion during playback. They do not guarantee allocation behavior inside
an OpenAL implementation. In particular, Emscripten's OpenAL playback uses
one-shot Web Audio nodes internally.

## Sounds from memory

`newSound(pcm, frequency, channels = 1, bits = 16)` copies raw PCM bytes
from an `openArray[uint8]` into a sound buffer. The caller may reuse or
release those bytes after the call. Use unsigned 8-bit or signed 16-bit
samples in native byte order, with one or two interleaved channels.
Stereo buffers do not support spatial positioning.

The input must be nonempty, contain complete sample frames, and fit
OpenAL's signed 32-bit byte count. The sample rate must be positive and
fit OpenAL's signed 32-bit frequency field. Invalid inputs raise
`SlappyError` before allocating a buffer.

Create PCM buffers during preload, just like file-backed sounds. Playback
and [fades](fades.md) can then reuse the same voices and buffers.
