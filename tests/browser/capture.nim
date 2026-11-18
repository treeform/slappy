import ../../src/slappy

var
  microphone: Microphone
  captured: seq[uint8]
  allocation: seq[uint8]
  lastError: string

template checked(body: untyped): cint =
  ## Converts library errors into observable browser-test results.
  lastError.setLen(0)
  try:
    body
  except SlappyError as error:
    lastError = error.msg
    -1.cint

proc captureOpen(
  frequency, channels, bits, capacity: cint
): cint {.exportc: "capture_open", cdecl.} =
  ## Opens a microphone using only the public Slappy API.
  checked:
    microphone = newMicrophone(
      frequency = frequency.int,
      channels = channels.int,
      bits = bits.int,
      bufferSize = capacity.int
    )
    1.cint

proc captureStart(): cint {.exportc: "capture_start", cdecl.} =
  ## Requests capture without waiting for browser permission.
  checked:
    microphone.start()
    1.cint

proc captureStop(): cint {.exportc: "capture_stop", cdecl.} =
  ## Stops capture while keeping already captured frames readable.
  checked:
    microphone.stop()
    1.cint

proc captureStopping(): cint {.exportc: "capture_stopping", cdecl.} =
  ## Reports when all audio-thread frames have arrived after stopping.
  checked:
    microphone.stopping.cint

proc captureClose(): cint {.exportc: "capture_close", cdecl.} =
  ## Closes the current microphone, including pending permission requests.
  checked:
    microphone.close()
    1.cint

proc captureReady(): cint {.exportc: "capture_ready", cdecl.} =
  ## Reports pending, ready, closed, and asynchronous errors.
  checked:
    microphone.ready.cint

proc captureAvailable(): cint {.exportc: "capture_available", cdecl.} =
  ## Returns the number of complete sample frames buffered for reading.
  checked:
    microphone.samplesAvailable.cint

proc captureRead(count: cint): cint {.exportc: "capture_read", cdecl.} =
  ## Keeps returned PCM alive until the next read.
  checked:
    captured = microphone.read(count.int)
    captured.len.cint

proc captureReadAll(): cint {.exportc: "capture_read_all", cdecl.} =
  ## Reads all buffered PCM using the public convenience procedure.
  checked:
    captured = microphone.readAll()
    captured.len.cint

proc captureData(): pointer {.exportc: "capture_data", cdecl.} =
  ## Exposes the retained PCM bytes to the browser assertion code.
  if captured.len > 0:
    addr captured[0]
  else:
    nil

proc captureError(): cstring {.exportc: "capture_error", cdecl.} =
  ## Exposes the latest library exception text without allocating in JavaScript.
  lastError.cstring

proc captureGrow(): cint {.exportc: "capture_grow", cdecl.} =
  ## Forces heap growth before a subsequent microphone read.
  allocation = newSeq[uint8](32 * 1024 * 1024)
  allocation[^1] = 7
  allocation.len.cint

proc captureFrequency(): cint {.exportc: "capture_frequency", cdecl.} =
  ## Reads the public capture frequency property.
  microphone.frequency.cint

proc captureChannels(): cint {.exportc: "capture_channels", cdecl.} =
  ## Reads the public capture channel count property.
  microphone.channels.cint

proc captureBits(): cint {.exportc: "capture_bits", cdecl.} =
  ## Reads the public capture sample width property.
  microphone.bits.cint
