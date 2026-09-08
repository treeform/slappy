import slappy/fades

block:
  var fade = initGainFade(0.0'f32, 1.0'f32, 2.0'f32)
  doAssert fade.gain == 0.0'f32
  doAssert fade.advance(0.5'f32) == 0.25'f32
  doAssert fade.advance(0.5'f32) == 0.5'f32
  doAssert fade.advance(1.0'f32) == 1.0'f32
  doAssert fade.finished

block:
  var fade = initGainFade(1.0'f32, 0.0'f32, 0.0'f32)
  doAssert fade.gain == 0.0'f32
  doAssert fade.finished

block:
  var fade = initGainFade(1.0'f32, 0.0'f32, 1.0'f32)
  doAssert fade.advance(-1.0'f32) == 1.0'f32
  doAssert fade.advance(2.0'f32) == 0.0'f32
  doAssert fade.finished
