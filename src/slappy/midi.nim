import flatty/binny, flatty/hexprint, print

type

  Track = ref object
    name: string

  MidiFile = ref object
    stuff: int
    tracks: seq[Track]

proc parseQuantity(s: string, i: var int): int =
  ## parse Variable Length Quantity
  ## These numbers are represented 7 bits per byte, most significant bits first.
  ## All bytes except the last have bit 7 set, and the last byte has bit 7
  ## clear. If the number is between 0 and 127, it is thus represented exactly
  ## as one byte.
  for _ in 0 ..< 4:
    var data = s.readUint8(i)
    result = result or (data and 0b0111_1111).int
    inc i
    if (data and 0b1000_0000) == 0:
      break
    result = result shl 7

proc parseQuantity(s: string): int =
  var i = 0
  parseQuantity(s, i)


doAssert 0x00000000 == parseQuantity("\x00")
doAssert 0x00000040 == parseQuantity("\x40")
doAssert 0x0000007F == parseQuantity("\x7F")
doAssert 0x00000080 == parseQuantity("\x81\x00")
doAssert 0x00002000 == parseQuantity("\xC0\x00")
doAssert 0x00003FFF == parseQuantity("\xFF\x7F")
doAssert 0x00004000 == parseQuantity("\x81\x80\x00")
doAssert 0x00100000 == parseQuantity("\xC0\x80\x00")
doAssert 0x001FFFFF == parseQuantity("\xFF\xFF\x7F")
doAssert 0x00200000 == parseQuantity("\x81\x80\x80\x00")
doAssert 0x08000000 == parseQuantity("\xC0\x80\x80\x00")
doAssert 0x0FFFFFFF == parseQuantity("\xFF\xFF\xFF\x7F")

block:
  let data: seq[uint8] = @[
    # The entire format 0 MIDI file contents in hex follow.
    # First, the header chunk:
    0x4D.uint8, 0x54, 0x68, 0x64, # MThd
    0x00, 0x00, 0x00, 0x06, # chunk length
    0x00, 0x00, # format 0
    0x00, 0x01, # one track
    0x00, 0x60, # 96 per quarter-note

    # Then the track chunk. Its header followed by the events
    # (notice the running status is used in places):
    0x4D, 0x54, 0x72, 0x6B, # MTrk
    0x00, 0x00, 0x00, 0x3B, # chunk length (59)
    # Delta-Time Event Comments
    0x00, 0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08, # time signature
    0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, # tempo
    0x00, 0xC0, 0x05,
    0x00, 0xC1, 0x2E,
    0x00, 0xC2, 0x46,
    0x00, 0x92, 0x30, 0x60,
    0x00, 0x3C, 0x60, # running status
    0x60, 0x91, 0x43, 0x40,
    0x60, 0x90, 0x4C, 0x20,
    0x81, 0x40, 0x82, 0x30, 0x40, # two-byte delta-time
    0x00, 0x3C, 0x40, # running status
    0x00, 0x81, 0x43, 0x40,
    0x00, 0x80, 0x4C, 0x40,
    0x00, 0xFF, 0x2F, 0x00, # end of track

    # #A format 1 representation of the file is slightly different. Its header chunk:
    # 0x4D, 0x54, 0x68, 0x64, # MThd
    # 0x00, 0x00, 0x00, 0x06, # chunk length
    # 0x00, 0x01, # format 1
    # 0x00, 0x04, # four tracks
    # 0x00, 0x60, 0x96, # per quarter note
    # #First, the track chunk for the time signature/tempo track. Its header, followed by the events:
    # 0x4D, 0x54, 0x72, 0x6B, # MTrk
    # 0x00, 0x00, 0x00, 0x14, # chunk length (0x20,)
    # #Delta-Time Event Comments
    # 0x00, 0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08, time signature
    # 0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, tempo
    # 0x83, 0x00, 0xFF, 0x2F, 0x00, end of track
    # #Then, the track chunk for the first music track. The MIDI convention for note on/off running status is used in this example:
    # 0x4D, 0x54, 0x72, 0x6B, MTrk
    # 0x00, 0x00, 0x00, 0x10, chunk length (0x16,)
    # #Delta-Time Event Comments
    # 0x00, 0xC0, 0x05,
    # 0x81, 0x40, 0x90, 0x4C, 0x20,
    # 0x81, 0x40, 0x4C, 0x00, Running status: note on, vel=0
    # 0x00, 0xFF, 0x2F, 0x00,
    # #Then, the track chunk for the second music track:
    # 0x4D, 0x54, 0x72, 0x6B, MTrk
    # 0x00, 0x00, 0x00, 0x0F, chunk length (0x15,)
    # #Delta-Time Event Comments
    # 0x00, 0xC1, 0x2E,
    # 0x60, 0x91, 0x43, 0x40,
    # 0x82, 0x20, 0x43, 0x00, running status
    # 0x00, 0xFF, 0x2F, 0x00, end of track
    # #Then, the track chunk for the third music track:
    # 0x4D, 0x54, 0x72, 0x6B, MTrk
    # 0x00, 0x00, 0x00, 0x15, chunk length (0x21,)
    # #Delta-Time Event Comments
    # 0x00, 0xC2, 0x46,
    # 0x00, 0x92, 0x30, 0x60,
    # 0x00, 0x3C, 0x60, running status
    # 0x83, 0x00, 0x30, 0x00, two-byte delta-time, running status
    # 0x00, 0x3C, 0x00, running status
    # 0x00, 0xFF, 0x2F, 0x00, end of track
  ]

  writeFile("tests/test0.mid", data)

proc parseMidi(s: string, i: var int): MidiFile =
  result = MidiFile()
  echo "here"
  if s.readStr(i, 4) != "MThd":
    raise newException(ValueError, "Not a valid midi file")
  i += 4
  let length = s.readUint32(i).swap()
  print length
  i += 4
  let format = s.readUint16(i).swap()
  print format
  i += 2
  let numTracks = s.readUint16(i).swap()
  print numTracks
  i += 2
  let division = s.readUint16(i).swap()
  i += 2
  #print division
  if (division and 0b1000_0000) != 0:
    raise newException(ValueError, "Not supported: negative SMPTE format.")
  let ticksPerQuarter = division
  print ticksPerQuarter

  for track in 0 ..< numTracks.int:
    echo "track: ", track
    if s.readStr(i, 4) != "MTrk":
      raise newException(ValueError, "Not a valid midi chunk")
    i += 4
    let length = s.readUint32(i).swap()
    print length
    i += 4

    while true:
      echo "event"
      let deltaTime = s.parseQuantity(i)
      print deltaTime
      let eventData = s.readUint8(i)
      inc i

      print eventData

      if eventData == 0xFF:
        # meta event
        let metaEventType = s.readUint8(i)
        inc i
        print metaEventType

      else:

        let eventTypeValue = eventData shr 4
        let midiChannel = eventData and 0b1111

        print eventTypeValue
        print midiChannel

      quit()


let data = readFile("tests/test0.mid")
var i = 0
discard parseMidi(data, i)
