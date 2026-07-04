--[[
  chordreport.lua  --  reads the selected MIDI notes and speaks the chord.

  OSARA's chord-navigation actions leave all of the chord's notes selected, so
  after running one of them we read the selected notes from the active MIDI
  editor take, identify them with chordlib and speak the result via speech.

  Enharmonic spelling (flats vs sharps) follows REAPER's native snap-to-key,
  read from the take with reaper.MIDI_GetScale. When no scale is set we fall back
  to flats.

  Requires package.path to be set to the script folder first (the action scripts
  do this), so that chordlib and speech can be required.
]]

local chordlib = require('chordlib')
local speech = require('speech')

local M = {}

-- Major-key tonic pitch class -> spell with flats? (true = flats, false = sharps)
local MAJOR_USES_FLATS = {
  [0]=true,  [1]=true,  [2]=false, [3]=true,  [4]=false, [5]=true,
  [6]=false, [7]=false, [8]=true,  [9]=false, [10]=true, [11]=false,
}

-- REAPER scale name (lower case) -> semitones from its tonic up to the tonic of
-- its relative major, so we can look the accidental count up in MAJOR_USES_FLATS.
local RELATIVE_MAJOR_OFFSET = {
  major = 0, ionian = 0,
  minor = 3, aeolian = 3,
  dorian = 10, phrygian = 8, lydian = 7, mixolydian = 5, locrian = 1,
}

local function say(text)
  if text ~= nil and text ~= "" and reaper.osara_outputMessage ~= nil then
    reaper.osara_outputMessage(text)
  end
end

-- Decide flats vs sharps for a REAPER scale. Non-diatonic scales we don't have a
-- key signature for default to flats (more readable for unknown context).
local function useFlatsForScale(root, name)
  local offset = RELATIVE_MAJOR_OFFSET[tostring(name):lower()]
  if offset == nil then
    return true
  end
  return MAJOR_USES_FLATS[(root + offset) % 12]
end

-- Read REAPER's native snap-to-key for the take and return a key context table
-- { useFlats = bool } for the speller, or nil if no scale is set / unavailable.
local function currentKey(take)
  if take == nil or reaper.MIDI_GetScale == nil then
    return nil
  end
  local enabled, root, _, name = reaper.MIDI_GetScale(take, 0, 0, "")
  if not enabled then
    return nil
  end
  return { useFlats = useFlatsForScale(root, name) }
end

-- Return a list of MIDI note numbers for the currently selected notes in the
-- given take (duplicates kept, so voicing can detect doublings).
local function selectedPitches(take)
  local pitches = {}
  local _, noteCount = reaper.MIDI_CountEvts(take)
  local i
  for i = 0, noteCount - 1 do
    local ok, selected, _, _, _, _, pitch = reaper.MIDI_GetNote(take, i)
    if ok and selected then
      pitches[#pitches + 1] = pitch
    end
  end
  return pitches
end

-- Identify and speak the currently selected notes, spelled per the native key.
function M.report()

  local activeMidiEditor = reaper.MIDIEditor_GetActive()

  if activeMidiEditor == nil then
    return
  end

  local take = reaper.MIDIEditor_GetTake(activeMidiEditor)

  if take == nil then
    return
  end

  local pitches = selectedPitches(take)

  if #pitches == 0 then
    say("no notes")
    return
  end

  local speller = speech.makeSpeller(currentKey(take))
  local result = chordlib.analyze(pitches)

  say(speech.describe(result, {
    speller = speller,
    octaveOffset = 0,
  }))
end

return M
