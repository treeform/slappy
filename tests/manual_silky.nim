import
  std/[os, strformat],
  bumpy, vmath, chroma,
  silky, slappy

const
  SoundFiles = [
    "data/ding.wav",
    "data/drums.mono.wav",
    "data/drums.stereo.wav",
    "data/siren.wav",
    "data/robo.ogg",
    "data/xylophone-sweep.ogg",
    "data/xylophone-sweep.slappy",
    "data/xylophone-sweep.wav",
    "data/ascension_short_by_ross_bugden.ogg"
  ]

proc check(filePath: string)=
  ## Simple sound playing helper, to avoid repeated code on this file.
  let sound = newSound(filePath)
  echo &"playing {filePath} file"
  assert sound.duration != 0
  discard sound.play()

slappyInit()

let builder = newAtlasBuilder(1024, 4)
builder.addDir("data", "data")
builder.addFont("data/IBMPlexSans-Regular.ttf", "H1", 32.0)
builder.addFont("data/IBMPlexSans-Regular.ttf", "Default", 18.0)
builder.write("dist/atlas.png")

let window = newWindow(
  "Basic Window",
  ivec2(800, 600),
  vsync = false
)
makeContextCurrent(window)
loadExtensions()

let sk = newSilky("dist/atlas.png")

window.runeInputEnabled = true
window.onRune = proc(rune: Rune) =
  sk.inputRunes.add(rune)

var
  showWindow = true

window.onFrame = proc() =
  sk.beginUI(window, window.size)

  # Draw tiled test texture as the background.
  for x in 0 ..< 16:
    for y in 0 ..< 10:
      sk.at = vec2(x.float32 * 256, y.float32 * 256)
      image("testTexture", rgbx(30, 30, 30, 255))

  subWindow("A SubWindow", showWindow, vec2(100, 100), vec2(400, 700)):
    # Add all soundfiles as buttons to play them on click.
    for filePath in SoundFiles:
      button("Play "&filePath):
        check filePath

  if not showWindow:
    if window.buttonPressed[MouseLeft]:
      showWindow = true
    sk.at = vec2(100, 100)
    text("Click anywhere to show the window")

  let ms = sk.avgFrameTime * 1000
  sk.at = sk.pos + vec2(sk.size.x - 250, 20)
  text(&"frame time: {ms:>7.3f}ms")

  sk.endUi()
  window.swapBuffers()

when isMainModule:
  while not window.closeRequested:
    pollEvents()
  slappyClose()



