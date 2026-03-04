import math, times, tables, slappy, slappy/midi

slappyInit()

let m = readMidi("tests/data/fur_elise.mid")
let piano = newSound("tests/data/piano_c1.wav")

# Piano C1 is MIDI note 24. We shift down 2 octaves to keep pitch ratios sane.
const BaseNote = 24
const OctaveShift = 24

# Pre-compute a pitch ratio for every possible MIDI note.
var pitchRatios: array[128, float]
for i in 0 ..< 128:
  pitchRatios[i] = pow(2.0, (i.float - BaseNote.float - OctaveShift.float) / 12.0)

# Active sources keyed by note number so we can stop them on NoteOff.
var playing: Table[int, Source]

# Use the Piano RH track.
let track = m.tracks[1]
echo "Playing: ", track.name

# Grab initial tempo.
var usPerQuarter = 800000
for e in m.tracks[0].events:
  if e.kind == Meta and e.metaKind == MetaTempo:
    usPerQuarter = e.tempo
    break

let ticksPerQuarter = m.header.ticksPerQuarter

# Convert ticks to seconds.
proc tickToSec(tick: int): float =
  tick.float * usPerQuarter.float / (ticksPerQuarter.float * 1_000_000.0)

let startTime = epochTime()
var eventIdx = 0

while eventIdx < track.events.len:
  let now = epochTime() - startTime
  let e = track.events[eventIdx]
  let eventTime = tickToSec(e.tick)
  # Wait until it is time for this event.
  if now < eventTime:
    slappyTick()
    continue
  # Process the event.
  if e.kind == NoteOn:
    if e.note in playing:
      playing[e.note].stop()
    var source = piano.play()
    source.pitch = pitchRatios[e.note]
    source.gain = e.velocity.float / 127.0
    playing[e.note] = source
    echo "  ON  ", noteName(e.note), " (", e.note, ")"
  elif e.kind == NoteOff:
    if e.note in playing:
      playing[e.note].stop()
      playing.del(e.note)
    echo "  OFF ", noteName(e.note), " (", e.note, ")"
  inc eventIdx
  slappyTick()

slappyClose()
