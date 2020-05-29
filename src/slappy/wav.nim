import streams

type WavFile* = object
  data*: seq[uint8]
  size*: int
  freq*: int
  bits*: int
  channels*: int

proc loadWav*(filePath: string): WavFile =
  # Load PCM data from wav file.
  var f = newFileStream(filePath)
  let
    chunkID = f.readStr(4)
    chunkSize = f.readUint32()
    format = f.readStr(4)

    subChunk1ID = f.readStr(4)
    subchunk1Size = f.readUint32()
    audioFormat = f.readUint16()
    numChannels = f.readUint16()
    sampleRate = f.readUint32()
    byteRate = f.readUint32()
    blockAlign = f.readUint16()
    bitsPerSample = f.readUint16()

  assert chunkID == "RIFF"
  assert format == "WAVE"
  assert subChunk1ID == "fmt "
  assert audioFormat == 1

  var
    subchunk2ID: string
    subchunk2Size: uint32
    data: string

  # skip chunks till we get to the data chunk
  while subchunk2ID != "data":
    subchunk2ID = f.readStr(4)
    subchunk2Size = f.readUint32()
    data = f.readStr(int subchunk2Size)

  result.channels = int numChannels
  result.size = data.len
  result.freq = int sampleRate
  result.bits = int bitsPerSample
  result.data = cast[seq[uint8]](data)
