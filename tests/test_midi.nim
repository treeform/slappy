import slappy/midi

echo "Loading fur_elise.mid"
let m = readMidi("tests/fur_elise.mid")

doAssert m.header.format == Format1
doAssert m.header.trackCount == 5
doAssert m.header.ticksPerQuarter == 384
doAssert m.tracks.len == 5
doAssert m.tracks[1].name == "Piano RH"
doAssert m.tracks[2].name == "Piano LH"

echo m

echo "\nAll MIDI tests passed."
