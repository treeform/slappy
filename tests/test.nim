import os, math
import vmath
import euphony

euphonyInit()

block:
  echo "playing wav file"
  let sound = newSound("tests/xylophone-sweep.wav")
  discard sound.play()
  sleep(2500)

block:
  echo "playing ogg file"
  let sound = newSound("tests/robo.ogg")
  echo "duration ", sound.duration
  discard sound.play()
  sleep(1000)

block:
  # playing sound in 3d
  let sound = newSound("tests/drums.mono.wav")
  echo "playing on the right"
  var source = sound.play()
  source.pos = vec3(1,0,0)
  sleep(1500)
  source.stop()

  sleep(500)

  echo "playing on the left"
  source = sound.play()
  source.pos = vec3(-1,0,0)
  sleep(1500)
  source.stop()

block:
  echo "rotate sound in 3d"
  let sound = newSound("tests/drums.mono.wav")
  var source = sound.play()
  source.looping = true
  for i in 0..360:
    let a = float(i) / 180 * PI
    source.pos = vec3(sin(a), cos(a), 0)
    sleep(20)
  source.stop()
  sleep(500)

block:
  echo "doppler waves shift as police car pases"
  let sound = newSound("tests/siren.wav")
  var source = sound.play()
  source.looping = true
  source.pos = vec3(-100, -100, 0)
  source.vel = vec3(1, 1, 0) * 50
  source.gain = 10
  for i in 1..200:
    source.pos = source.pos + source.vel / 50
    echo "    ", source.pos, source.vel
    sleep(20)
  source.stop()
  sleep(500)

block:
  echo "setting gain from 0 to 2"
  let sound = newSound("tests/drums.sterio.wav")
  echo "loaded"
  var source = sound.play()
  echo "play"
  source.looping = true
  for i in 0..100:
    let a = float(i)/100
    source.gain = a * a
    echo "    ", source.gain
    sleep(20)
  source.stop()
  sleep(500)

block:
  # set pitch
  let sound = newSound("tests/ding.wav")
  # make 2 rounds
  echo "setting pitch from 1/7 to 7/7 th"
  for i in 1..7:
    var source = sound.play()
    source.pitch = float(i) / 7.0
    echo "    ", source.pitch
    sleep(1000)
    source.stop()
  sleep(500)

block:
  # reset offset
  let sound = newSound("tests/drums.sterio.wav")
  var source = sound.play()
  # make 2 rounds
  echo "restarting source 3 times"
  for i in 0..2:
    source.playback = 0
    source.play()
    sleep(300)
    echo "    ", source.playback
    source.stop()
  sleep(500)

block:
  echo "try to play fur elise "
  let sound = newSound("tests/ding.wav")
  proc playNote(freq: int) =
    var source = sound.play()
    source.pitch = float(freq) * 0.002
    sleep int(120.0 * 1.5)
    euphanyTick()
  playNote(659)
  playNote(622)
  playNote(659)
  playNote(622)
  playNote(659)
  playNote(494)
  playNote(587)
  playNote(523)
  playNote(440)
  playNote(262)
  playNote(330)
  playNote(440)
  playNote(494)
  playNote(330)
  playNote(415)
  playNote(494)
  playNote(523)
  playNote(330)
  playNote(659)
  playNote(622)
  playNote(659)
  playNote(622)
  playNote(659)
  playNote(494)
  playNote(587)
  playNote(523)
  playNote(440)
  playNote(262)
  playNote(330)
  playNote(440)
  playNote(494)
  playNote(330)
  playNote(523)
  playNote(494)
  playNote(440)
  sleep 1000

block:
  echo "long ogg file"
  let sound = newSound("tests/ascension_short_by_ross_bugden.ogg")
  echo "duration ", sound.duration
  discard sound.play()
  sleep(int sound.duration * 1000)

euphanyClose()