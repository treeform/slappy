import
  std/[os, strformat],
  vmath,
  slappy

proc check(filePath: string)=
  ## (temporary)
  ## Simple sound playing helper, to avoid repeated code on this WIP file.
  ## Will remove when emscripten support is complete. test.nim achieves the same goal.
  let sound = newSound(filePath)
  echo &"playing {filePath} file"
  assert sound.duration != 0
  discard sound.play()
  sleep(int(sound.duration * 1000))

slappyInit()

block:
  # check "dist/data/ding.wav"
  check "dist/data/xylophone-sweep.slappy"
  # check "dist/data/ascension_short_by_ross_bugden.ogg"  # WARN: Makes the page unresponsive for +1min when it loads

block:
  let sound = newSound("dist/data/ding.wav")
  echo "playing on the right"
  var source = sound.play()
  assert sound.duration != 0
  source.pos = vec3(1, 0, 0)
  source.gain = 1.0
  sleep(int(sound.duration * 1000))
  # source.stop()
  # source.play()

  # source.pos = vec3(-1, 0, 0)
  # sleep(int(sound.duration * 1000))
  # source.stop()

  # sleep(500)

  # echo "playing on the left"
  # source = sound.play()
  # # source.pos = vec3(-1, 0, 0)
  # sleep(int(sound.duration * 1000))
  # source.stop()

