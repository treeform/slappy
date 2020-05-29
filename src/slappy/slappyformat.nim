## Snappy format is very simple format that uses snappy for compression.

import snappy, wav, streams

proc saveSlappy*(fileName: string, wav: WavFile) =
  ## Saves wav file in a snappy format.
  var f = newFileStream(fileName, fmWrite)
  f.write("SLAPPY01")
  f.write(wav.size)
  f.write(wav.freq)
  f.write(wav.bits)
  f.write(wav.channels)
  let compressedData = cast[string](compress(wav.data))
  f.write(compressedData.len)
  f.write(compressedData)
  f.close()

proc loadSlappy*(fileName: string): WavFile =
  ## Loads a snappy file.
  var f = newFileStream(fileName)
  let header = f.readStr(8)
  doAssert "SLAPPY01" == header
  f.read(result.size)
  f.read(result.freq)
  f.read(result.bits)
  f.read(result.channels)
  let compressedLen = f.readInt64().int
  let compressedData = f.readStr(compressedLen)
  result.data = cast[seq[uint8]](uncompress(compressedData))
  f.close()
