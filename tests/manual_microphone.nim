import
  std/[os, strformat, strutils, parseopt],
  slappy

var frequency = 44100

var p = initOptParser(commandLineParams())
for kind, key, val in p.getopt():
  case kind
  of cmdLongOption:
    if key == "hz":
      frequency = parseInt(val)
  of cmdShortOption, cmdArgument, cmdEnd:
    discard

slappyInit()

block:
  echo "listing capture devices"
  let devices = listCaptureDevices()
  if devices.len == 0:
    echo "  no capture devices found"
  else:
    for d in devices:
      echo "  device: ", d

block:
  echo &"opening default capture device ({frequency} Hz, mono, 16-bit)"
  let mic = newMicrophone(frequency = frequency)
  echo "  frequency: ", mic.frequency, " Hz"
  echo "  channels: ", mic.channels
  echo "  bits: ", mic.bits

  echo "recording for 2 seconds..."
  mic.start()
  sleep(2000)
  mic.stop()

  let available = mic.samplesAvailable
  echo "  samples available: ", available

  let data = mic.readAll()
  let bytesPerSample = (mic.bits div 8) * mic.channels
  let durationSecs = if bytesPerSample > 0 and mic.frequency > 0:
    float(data.len div bytesPerSample) / float(mic.frequency)
  else:
    0.0
  echo &"  captured {data.len} bytes ({durationSecs:.2f} seconds)"

  if data.len > 0:
    echo "playing back captured audio..."
    let sound = mic.toSound(data)
    discard sound.play()
    sleep(int(durationSecs * 1000) + 500)
  else:
    echo "  no data captured, skipping playback"

  mic.close()
  echo "  capture device closed"

slappyClose()
