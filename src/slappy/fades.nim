## Deterministic gain envelopes for audio playback.

type GainFade* = object
  startGain*: float32
  targetGain*: float32
  duration*: float32
  elapsed*: float32

proc initGainFade*(
  startGain,
  targetGain,
  duration: float32
): GainFade =
  ## Creates a linear gain envelope measured in seconds.
  result = GainFade(
    startGain: startGain,
    targetGain: targetGain,
    duration: max(duration, 0.0'f32)
  )

proc finished*(fade: GainFade): bool {.inline.} =
  ## Returns true when the envelope reached its target.
  fade.elapsed >= fade.duration

proc gain*(fade: GainFade): float32 =
  ## Returns the gain at the envelope's current position.
  if fade.duration <= 0.0'f32:
    return fade.targetGain
  let progress = min(fade.elapsed / fade.duration, 1.0'f32)
  fade.startGain + (fade.targetGain - fade.startGain) * progress

proc advance*(fade: var GainFade; seconds: float32): float32 =
  ## Advances the envelope and returns its new gain.
  fade.elapsed = min(fade.duration, fade.elapsed + max(seconds, 0.0'f32))
  fade.gain()
