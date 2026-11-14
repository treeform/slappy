import slappy/fades

block:
  var fade = initGainFade(0.0'f, 1.0'f, 2.0'f)
  doAssert fade.gain == 0.0'f
  doAssert fade.advance(0.5'f) == 0.25'f
  doAssert fade.advance(0.5'f) == 0.5'f
  doAssert fade.advance(1.0'f) == 1.0'f
  doAssert fade.finished

block:
  var fade = initGainFade(1.0'f, 0.0'f, 0.0'f)
  doAssert fade.gain == 0.0'f
  doAssert fade.finished

block:
  var fade = initGainFade(1.0'f, 0.0'f, 1.0'f)
  doAssert fade.advance(-1.0'f) == 1.0'f
  doAssert fade.advance(2.0'f) == 0.0'f
  doAssert fade.finished

block:
  var fade = initGainFade(1e10'f, 0.125'f, 1.0'f)
  doAssert fade.advance(1.0'f) == 0.125'f
