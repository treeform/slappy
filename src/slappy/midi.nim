import std/[streams, strformat, strutils]

## MIDI file format is a standard for storing music in a digital format.
## It is a binary format that is a kint to a vector format for music synthesis.

const NoteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

type
  Format* = enum ## MIDI file format type.
    Format0 ## Single track.
    Format1 ## Multiple simultaneous tracks.
    Format2 ## Multiple independent tracks.

  EventKind* = enum ## Discriminator for the type of MIDI event.
    NoteOff ## Key released.
    NoteOn ## Key pressed.
    ControlChange ## Controller value changed.
    ProgramChange ## Instrument/patch changed.
    PitchBend ## Pitch wheel moved.
    Meta ## Non-musical meta event.

  MetaKind* = enum ## Discriminator for the type of meta event.
    MetaTrackName ## Name of the track.
    MetaEndOfTrack ## Marks the end of a track.
    MetaTempo ## Tempo in microseconds per quarter note.
    MetaTimeSignature ## Time signature numerator and denominator.
    MetaKeySignature ## Key signature sharps/flats and major/minor.
    MetaSequencerSpecific ## Vendor-specific sequencer data.
    MetaOther ## Any other unrecognized meta event.

  Header* = object ## Parsed MIDI file header chunk.
    format*: Format ## File format type.
    trackCount*: int ## Number of tracks in the file.
    ticksPerQuarter*: int ## Ticks per quarter note resolution.

  Event* = object ## A single parsed MIDI event with absolute tick position.
    tick*: int ## Absolute tick position in the track.
    kind*: EventKind ## Which type of event this is.
    channel*: int ## MIDI channel 0-15.
    note*: int ## Note number 0-127 for NoteOn/NoteOff.
    velocity*: int ## Velocity 0-127 for NoteOn/NoteOff.
    controller*: int ## Controller number 0-127 for ControlChange.
    value*: int ## Controller value 0-127 for ControlChange.
    program*: int ## Program number 0-127 for ProgramChange.
    pitch*: int ## Pitch bend value centered at 0.
    metaKind*: MetaKind ## Sub-type for Meta kind events.
    tempo*: int ## Microseconds per quarter note for MetaTempo.
    numerator*: int ## Time signature numerator.
    denominator*: int ## Time signature denominator.
    sharps*: int ## Positive for sharps, negative for flats.
    minor*: bool ## True if minor key, false if major.
    data*: string ## Raw bytes for track name or unknown meta events.

  Track* = object ## A single MIDI track containing a sequence of events.
    name*: string ## Track name from the TrackName meta event.
    events*: seq[Event] ## All events in absolute tick order.

  File* = object ## A fully parsed standard MIDI file.
    header*: Header ## The file header with format and timing info.
    tracks*: seq[Track] ## All tracks in the file.

proc readVarLen(s: Stream): int =
  ## Reads a MIDI variable-length quantity from the stream.
  var b = s.readUint8().int
  result = b and 0x7F
  while (b and 0x80) != 0:
    b = s.readUint8().int
    result = (result shl 7) or (b and 0x7F)

proc readBigEndian16(s: Stream): int =
  ## Reads a 16-bit big-endian integer.
  let hi = s.readUint8().int
  let lo = s.readUint8().int
  result = (hi shl 8) or lo

proc readBigEndian32(s: Stream): int =
  ## Reads a 32-bit big-endian integer.
  let b3 = s.readUint8().int
  let b2 = s.readUint8().int
  let b1 = s.readUint8().int
  let b0 = s.readUint8().int
  result = (b3 shl 24) or (b2 shl 16) or (b1 shl 8) or b0

proc readBigEndian24(s: Stream): int =
  ## Reads a 24-bit big-endian integer.
  let b2 = s.readUint8().int
  let b1 = s.readUint8().int
  let b0 = s.readUint8().int
  result = (b2 shl 16) or (b1 shl 8) or b0

proc readTrack(s: Stream): Track =
  ## Reads a single MIDI track chunk from the stream.
  let chunkId = s.readStr(4)
  if chunkId != "MTrk":
    raise newException(IOError, &"Expected MTrk, got {chunkId}")
  let chunkLen = readBigEndian32(s)
  let endPos = s.getPosition() + chunkLen
  var
    absoluteTick = 0
    runningStatus = 0
  while s.getPosition() < endPos:
    let delta = readVarLen(s)
    absoluteTick += delta
    var statusByte = s.readUint8().int
    # Handle running status.
    if (statusByte and 0x80) == 0:
      # Not a status byte, reuse previous status.
      s.setPosition(s.getPosition() - 1)
      statusByte = runningStatus
    else:
      runningStatus = statusByte
    let highNibble = statusByte and 0xF0
    let channel = statusByte and 0x0F
    case highNibble
    of 0x80: # Note Off.
      let note = s.readUint8().int
      let vel = s.readUint8().int
      result.events.add Event(
        tick: absoluteTick,
        kind: NoteOff,
        channel: channel,
        note: note,
        velocity: vel
      )
    of 0x90: # Note On (velocity 0 treated as Note Off).
      let note = s.readUint8().int
      let vel = s.readUint8().int
      if vel == 0:
        result.events.add Event(
          tick: absoluteTick,
          kind: NoteOff,
          channel: channel,
          note: note,
          velocity: 0
        )
      else:
        result.events.add Event(
          tick: absoluteTick,
          kind: NoteOn,
          channel: channel,
          note: note,
          velocity: vel
        )
    of 0xB0: # Control Change.
      let ctrl = s.readUint8().int
      let val = s.readUint8().int
      result.events.add Event(
        tick: absoluteTick,
        kind: ControlChange,
        channel: channel,
        controller: ctrl,
        value: val
      )
    of 0xC0: # Program Change.
      let prog = s.readUint8().int
      result.events.add Event(
        tick: absoluteTick,
        kind: ProgramChange,
        channel: channel,
        program: prog
      )
    of 0xE0: # Pitch Bend.
      let lo = s.readUint8().int
      let hi = s.readUint8().int
      result.events.add Event(
        tick: absoluteTick,
        kind: PitchBend,
        channel: channel,
        pitch: (hi shl 7) or lo - 8192
      )
    of 0xF0: # System / Meta events.
      if statusByte == 0xFF:
        # Meta event.
        let metaType = s.readUint8().int
        let metaLen = readVarLen(s)
        case metaType
        of 0x03: # Track Name.
          let name = s.readStr(metaLen)
          result.name = name
          result.events.add Event(
            tick: absoluteTick,
            kind: Meta,
            metaKind: MetaTrackName,
            data: name
          )
        of 0x2F: # End of Track.
          discard s.readStr(metaLen)
          result.events.add Event(
            tick: absoluteTick,
            kind: Meta,
            metaKind: MetaEndOfTrack
          )
        of 0x51: # Tempo.
          let uspqn = readBigEndian24(s)
          result.events.add Event(
            tick: absoluteTick,
            kind: Meta,
            metaKind: MetaTempo,
            tempo: uspqn
          )
        of 0x58: # Time Signature.
          let num = s.readUint8().int
          let denPow = s.readUint8().int
          discard s.readUint8() # clocks per metronome click
          discard s.readUint8() # 32nd notes per quarter
          result.events.add Event(
            tick: absoluteTick,
            kind: Meta,
            metaKind: MetaTimeSignature,
            numerator: num,
            denominator: 1 shl denPow
          )
        of 0x59: # Key Signature.
          let sf = s.readInt8().int
          let mi = s.readUint8().int
          result.events.add Event(
            tick: absoluteTick,
            kind: Meta,
            metaKind: MetaKeySignature,
            sharps: sf,
            minor: mi != 0
          )
        of 0x7F: # Sequencer Specific.
          let raw = s.readStr(metaLen)
          result.events.add Event(
            tick: absoluteTick,
            kind: Meta,
            metaKind: MetaSequencerSpecific,
            data: raw
          )
        else:
          let raw = s.readStr(metaLen)
          result.events.add Event(
            tick: absoluteTick,
            kind: Meta,
            metaKind: MetaOther,
            data: raw
          )
      elif statusByte == 0xF0 or statusByte == 0xF7:
        # SysEx event, skip it.
        let sysLen = readVarLen(s)
        discard s.readStr(sysLen)
      else:
        raise newException(IOError, &"Unknown status byte: 0x{statusByte:02X}")
    else:
      raise newException(IOError, &"Unknown status byte: 0x{statusByte:02X}")
  # Make sure we land exactly at the end.
  s.setPosition(endPos)

proc readMidi*(filePath: string): File =
  ## Reads a standard MIDI file and returns a fully parsed File object.
  var s = newFileStream(filePath, fmRead)
  if s == nil:
    raise newException(IOError, &"Cannot open {filePath}")
  defer: s.close()
  let chunkId = s.readStr(4)
  if chunkId != "MThd":
    raise newException(IOError, &"Expected MThd, got {chunkId}")
  let headerLen = readBigEndian32(s)
  if headerLen != 6:
    raise newException(IOError, &"Expected header length 6, got {headerLen}")
  let fmt = readBigEndian16(s)
  let nTracks = readBigEndian16(s)
  let division = readBigEndian16(s)
  result.header = Header(
    format: Format(fmt),
    trackCount: nTracks,
    ticksPerQuarter: division
  )
  for i in 0 ..< nTracks:
    result.tracks.add readTrack(s)

proc noteName*(note: int): string =
  ## Converts a MIDI note number to a human-readable name like C4 or A#5.
  let octave = note div 12 - 1
  let name = NoteNames[note mod 12]
  result = &"{name}{octave}"

proc bpm*(tempo: int): float =
  ## Converts microseconds per quarter note to beats per minute.
  result = 60_000_000.0 / tempo.float

proc `$`*(e: Event): string =
  ## Returns a one-line description of a MIDI event.
  case e.kind
  of NoteOn:
    result = &"{e.tick}: NoteOn ch:{e.channel} {noteName(e.note)}({e.note}) vel:{e.velocity}"
  of NoteOff:
    result = &"{e.tick}: NoteOff ch:{e.channel} {noteName(e.note)}({e.note}) vel:{e.velocity}"
  of ControlChange:
    result = &"{e.tick}: ControlChange ch:{e.channel} ctrl:{e.controller} val:{e.value}"
  of ProgramChange:
    result = &"{e.tick}: ProgramChange ch:{e.channel} program:{e.program}"
  of PitchBend:
    result = &"{e.tick}: PitchBend ch:{e.channel} pitch:{e.pitch}"
  of Meta:
    case e.metaKind
    of MetaTrackName:
      result = &"{e.tick}: TrackName \"{e.data}\""
    of MetaEndOfTrack:
      result = &"{e.tick}: EndOfTrack"
    of MetaTempo:
      result = &"{e.tick}: Tempo {bpm(e.tempo):.2f} bpm ({e.tempo} us/qn)"
    of MetaTimeSignature:
      result = &"{e.tick}: TimeSignature {e.numerator}/{e.denominator}"
    of MetaKeySignature:
      let mode = if e.minor: "minor" else: "major"
      result = &"{e.tick}: KeySignature sharps:{e.sharps} {mode}"
    of MetaSequencerSpecific:
      result = &"{e.tick}: SequencerSpecific ({e.data.len} bytes)"
    of MetaOther:
      result = &"{e.tick}: MetaOther ({e.data.len} bytes)"

proc `$`*(t: Track): string =
  ## Returns a multi-line description of a track.
  result = &"Track \"{t.name}\" ({t.events.len} events)"
  for e in t.events:
    result.add "\n  " & $e

proc `$`*(f: File): string =
  ## Returns a full description of a MIDI file.
  result = &"MIDI {f.header.format} {f.header.trackCount} tracks {f.header.ticksPerQuarter} ticks/quarter"
  for i, t in f.tracks:
    result.add &"\n\nTrack {i}: " & $t
