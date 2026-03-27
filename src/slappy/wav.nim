import streams, strformat

type WavFile* = object
  data*: seq[uint8]
  size*: int64
  freq*: int64
  bits*: int64
  channels*: int64

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
    if subChunk2Size > int32.high.uint32:
      raise newException(IOError, &"subChunk2Size > int32.high")
    data = f.readStr(subChunk2Size.int32)

  result.channels = numChannels.int64
  result.size = data.len
  result.freq = sampleRate.int64
  result.bits = bitsPerSample.int64
  result.data = cast[seq[uint8]](data)

func stereoToMono[T: uint8 | int16](data: openArray[uint8]): seq[uint8] =
  let samples = cast[ptr UncheckedArray[T]](unsafeAddr data[0])
  let sampleCount = data.len div sizeof(T)
  var monoData = newSeq[T](sampleCount div 2)
  for i in 0 ..< monoData.len:
    monoData[i] = T((int32(samples[i * 2]) + int32(samples[i * 2 + 1])) div 2)
  result = newSeq[uint8](monoData.len * sizeof(T))
  copyMem(addr result[0], addr monoData[0], result.len)

func toMono*(wav: var WavFile): var WavFile {.discardable.}=
  if wav.channels == 1: return
  case wav.bits
  of 8: wav.data = stereoToMono[uint8](wav.data)
  of 16: wav.data = stereoToMono[int16](wav.data)
  else: discard
  wav.channels = 1
  wav.size = wav.data.len
  return wav
