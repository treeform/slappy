import streams

type WavFile* = object
  data*: pointer
  size*: int
  freq*: int
  bits*: int
  channels*: int


proc readWav*(
  filePath: string,
  ): WavFile =
  # load PCM data from wav file
  var f = newFileStream(open(filePath))
  let
    chunkID = f.readStr(4)
    chunkSize = f.readUint32()
    format = f.readStr(4)

    subchunk1ID = f.readStr(4)
    subchunk1Size = f.readUint32()
    audioFormat = f.readUint16()
    numChannels = f.readUint16()
    sampleRate = f.readUint32()
    byteRate = f.readUint32()
    blockAlign = f.readUint16()
    bitsPerSample = f.readUint16()

  assert chunkID == "RIFF"
  assert format == "WAVE"
  assert subchunk1ID == "fmt "
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
    echo repr(subchunk2ID)
    echo subchunk2Size
    echo bitsPerSample
    echo numChannels

  result.channels = int numChannels
  result.size = data.len
  result.freq = int sampleRate
  result.bits = int bitsPerSample
  result.data = unsafeAddr data[0]
