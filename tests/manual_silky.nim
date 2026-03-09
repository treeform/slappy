import
  std/[strformat],
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

proc playSound(
  filePath: string;
  gain: float32= 1.0;
  leftRight: float32= 0.0;
  nearFar: float32= 0.0;
  rotation: float32= 0.0;
  pitch: float32= 1.0
)=
  ## Simple sound playing helper, to avoid repeated code on this file.
  let
    radians = rotation * PI / 180'f32
    sound = newSound(filePath)
  echo &"playing {filePath} file"
  assert sound.duration != 0
  var source = sound.play()
  source.gain = gain
  source.pos = vec3(leftRight + sin(radians), nearFar + cos(radians), 0)
  source.pitch = pitch

slappyInit()

let builder = newAtlasBuilder(1024, 4)
builder.addDir("data/", "data/")
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
  gain = 1.0'f32
  pitch = 1.0'f32
  positionLeftRight = 0.0'f32
  positionNearFar = 0.0'f32
  rotation = 0.0'f32

window.onFrame = proc() =
  sk.beginUI(window, window.size)

  # Draw tiled test texture as the background.
  for x in 0 ..< 16:
    for y in 0 ..< 10:
      sk.at = vec2(x.float32 * 256, y.float32 * 256)
      image("testTexture", rgbx(30, 30, 30, 255))

  subWindow("A SubWindow", showWindow, vec2(100, 100), vec2(400, 700)):
    text("Note:")
    text("Some features have no effect on some sounds.")
    text(" ")

    # Create the UI for controling the Gain value.
    text("Gain (volume):")
    scrubber("gainValue", gain, 0.0, 1.0)

    # Create the UI for controling the 3D sound feature: Left/Right.
    text("Position: Left/Right")
    scrubber("positionLeftRight", positionLeftRight, -1.0, 1.0)

    # Create the UI for controling the 3D sound feature: Near/Far.
    text("Position: Near/Far")
    scrubber("positionNearFar", positionNearFar, 0.0, 100.0)

    # Create the UI for controling the 3D sound feature: Rotation.
    text("Rotation: [0..360] degrees")
    scrubber("rotation", rotation, 0.0, 360.0)

    # Create the UI for testing the Pitch feature.
    text("Pitch (note/tone):")
    scrubber("pitchValue", pitch, 0.05, 4.0)

    # Add all soundfiles as buttons to play them on click.
    for filePath in SoundFiles:
      button("Play "&filePath):
        playSound filePath, gain, positionLeftRight, positionNearFar, rotation, pitch

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

