import streams


{.compile: "verbis.c".}


type
  Vorbis = ptr object
  VorbisInfo = object
    sample_rate: cuint
    channels: cint
    setup_memory_required: cuint
    setup_temp_memory_required: cuint
    temp_memory_required: cuint
    max_frame_size: cint

  VerbisFile* = object
    data*: pointer
    size*: int
    freq*: int
    bits*: int
    channels*: int


proc c_malloc(size: csize): pointer {.importc: "malloc", header: "<stdlib.h>".}
proc c_free(p: pointer) {.importc: "free", header: "<stdlib.h>".}


proc stb_vorbis_open_memory(data: pointer, len: cint, error: ptr cint, alloc_buffer: pointer): Vorbis {.importc, noconv.}
proc stb_vorbis_get_info(f: Vorbis): VorbisInfo {.importc, noconv.}
proc stb_vorbis_stream_length_in_samples(f: Vorbis): cuint {.importc, noconv.}
proc stb_vorbis_get_samples_short_interleaved(f: Vorbis, channels: cint, buffer: pointer, num_shorts: cint): cint {.importc, noconv.}
proc stb_vorbis_close(f: Vorbis) {.importc, noconv.}


proc readVerbis*(
  filePath: string,
  ): VerbisFile =
  ## Read and decodes a whole ogg file at once

  # read the verbis file
  var f = newFileStream(open(filePath))
  var data = f.readAll()

  # get verbis context
  var verbisCtx = stb_vorbis_open_memory(addr data[0], cint(data.len), nil, nil)
  if verbisCtx == nil:
    echo "Could not decode OGG file ", filePath

  # get verbis info
  let verbisInfo = stb_vorbis_get_info(verbisCtx)
  const bytesPerSample = 2
  let channels = verbisInfo.channels

  # get num samples
  let numSamples = stb_vorbis_stream_length_in_samples(verbisCtx)
  result.size = cint(numSamples) * channels * bytesPerSample

  # allocate primary buffer
  var buffer = c_malloc(result.size)

  # decode whole file at once
  let dataRead = stb_vorbis_get_samples_short_interleaved(
    verbisCtx,
    verbisInfo.channels,
    buffer,
    cint(numSamples * cuint(channels))
  ) * channels * bytesPerSample

  # make sure the decode was successful
  if dataRead != result.size:
    echo "Could not read all OGG data at once ", filePath
  elif dataRead == 0:
    echo "Could not decode OGG file data ", filePath

  # prepare the result
  result.data = buffer
  result.freq = int(verbisInfo.sampleRate)
  result.bits = bytesPerSample * 8
  result.channels = verbisInfo.channels

  # close the reader context
  stb_vorbis_close(verbisCtx)


proc free*(verbis: VerbisFile) =
  ## Frees the potentially huge chunk of sound data
  c_free(verbis.data)
