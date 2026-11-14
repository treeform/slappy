# Playback fades

`source.fadeTo(targetGain, durationSeconds, stopAfterFade = false)` changes
a playing source's absolute gain linearly. Use `stopAfterFade = true` to
stop it when the fade finishes. Zero or negative durations apply the
target immediately. Gains must be finite and nonnegative; durations must
be finite. Invalid arguments raise `SlappyError` before changing playback.

`source.fadeIn(durationSeconds, targetGain = 1)` starts or restarts an
existing voice at zero gain and fades it up. `sound.fadeIn(...)` creates a
temporary voice and returns it, like `sound.play()`.

```nim
slappyInit()
block:
  let
    first = newSound("first.ogg", forceMono = false)
    second = newSound("second.ogg", forceMono = false)
    current = newSource()
    replacement = newSource()
  current.sound = first
  replacement.sound = second
  current.fadeIn(1.0, targetGain = 0.5)

  # Call slappyTick() in the application's update loop to advance fades.
  # Later, start the replacement and stop the current voice over two seconds.
  crossfade(current, replacement, 2.0, replacementGain = 0.5)

  current.close()
  replacement.close()
slappyClose()
```

`crossfade` requires two distinct, live sources. It starts or restarts the
replacement and stops the outgoing source when its fade reaches
zero. A reusable outgoing source remains available for reuse; a temporary
one is released by `slappyTick`. The curves are linear, so perceived
loudness can dip in the middle when crossfading unrelated recordings.

Call one of these tick functions regularly:

- `slappyTick()` uses monotonic wall time since each fade started or was
  last advanced. Loading time before a fade starts is never counted.
- `slappyTick(deltaSeconds)` advances every active fade by exactly that
  amount. Negative deltas count as zero; nonfinite deltas raise
  `SlappyError`. This also resets each active fade's wall-clock anchor, so
  a following automatic tick does not count that interval again.

For deterministic playback, consistently use explicit deltas. Ticks also
retain their existing job of releasing finished temporary voices.

A fade belongs to one playback. Calling `play`, `stop`, assigning `sound`,
closing the voice, or observing natural completion cancels its fade.
Start playback before calling `fadeTo`, or use `fadeIn`. Calling
`cancelFade()` preserves the current gain and playback state.

An explicit `source.gain = value` cancels the fade and takes effect
immediately. Fade targets are absolute source gains. Use `listener.gain`
for master volume that multiplies the fade without cancelling it. An
application with separate mixer buses should apply its own volume and
envelope multiplication when writing source gains.

Fades on preloaded reusable sources require no additional Nim allocations
or OpenAL source creation. Emscripten keeps its normal Web Audio playback
behavior; this does not promise allocation-free browser or driver internals.
