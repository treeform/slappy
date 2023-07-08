import streams, strformat

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
    subChunk1Size = f.readUint32()
    audioFormat = f.readUint16()
    numChannels = f.readUint16()
    sampleRate = f.readUint32()
    byteRate = f.readUint32()
    blockAlign = f.readUint16()
    bitsPerSample = f.readUint16()

  if chunkID != "RIFF":
    raise newException(IOError, &"Got chunkID:{chunkID} expected RIFF")
  if format != "WAVE":
    raise newException(IOError, &"Got format:{chunkID} expected WAVE")
  if subChunk1ID != "fmt ":
    raise newException(IOError, &"Got subChunk1:{subChunk1ID} expected fmt")
  if audioFormat notin [1.uint16, 65534]:
    raise newException(IOError, &"Got audioFormat:{audioFormat} expected 1")

  if audioFormat == 65534:
    let
      samples1 = f.readUint16()
      samples2 = f.readUint16()
      channelMask = f.readUint32()
      subFormat = f.readStr(16)

  var
    subChunk2ID: string
    subChunk2Size: uint32
    data: string

  # Skip chunks till we get to the data chunk.
  while subChunk2ID != "data":
    subChunk2ID = f.readStr(4)
    subChunk2Size = f.readUint32()
    data = f.readStr(int subChunk2Size)

  result.channels = int numChannels
  result.size = data.len
  result.freq = int sampleRate
  result.bits = int bitsPerSample
  result.data = cast[seq[uint8]](data)
