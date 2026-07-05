-- module requirements for all actions
-- doesn't provide any action by itself, so don't map any shortcut to it or run this action

-- fixing script path for correct require calls
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

-- other packages
local smallfolk = require('smallfolk')

-- constants

local activeProjectIndex = 0
local sectionName = "com.timtam.AccessiChord"

-- deferred notes action command ids
local deferredNotesCommandIDs = {
  '_RS7d3c_812d04a3603d4fe85af259a0898def88ffcc2d9b', -- installed in ReaPack MIDI Editor folder
}

local deserializeTable = smallfolk.loads
local serializeTable = smallfolk.dumps

-- source: stackoverflow (https://stackoverflow.com/questions/11669926/is-there-a-lua-equivalent-of-scalas-map-or-cs-select-function)
local function map(f, t)
  local t1 = {}
  local t_len = #t
  for i = 1, t_len do
    t1[i] = f(t[i])
  end
  return t1
end

local function setValuePersist(key, value)
  reaper.SetProjExtState(activeProjectIndex, sectionName, key, value)
end

local function getValuePersist(key, defaultValue)

  local valueExists, value = reaper.GetProjExtState(activeProjectIndex, sectionName, key)

  if valueExists == 0 then
    setValuePersist(key, defaultValue)
    return defaultValue
  end

  return value
end

local function setValue(key, value)
  reaper.SetExtState(sectionName, key, value, false)
end

local function getValue(key, defaultValue)

  local valueExists = reaper.HasExtState(sectionName, key)

  if valueExists == false then
    setValue(key, defaultValue)
    return defaultValue
  end

  local value = reaper.GetExtState(sectionName, key)

  return value
end

-- Resolve the command id of the "process notes deferred" action.
-- We first try an id the action recorded about itself (see registerDeferredCommand),
-- which makes local/manually loaded installs work without hardcoding a machine
-- specific id, then fall back to the known ReaPack ids shipped above.
local function resolveDeferredCommandID()

  local candidates = {}

  local registered = getValue('deferred_notes_command_name', '')

  if registered ~= '' then
    table.insert(candidates, registered)
  end

  for i = 1, #deferredNotesCommandIDs do
    table.insert(candidates, deferredNotesCommandIDs[i])
  end

  for i = 1, #candidates do

    local commandID = reaper.NamedCommandLookup(candidates[i])

    if commandID ~= 0 then
      return commandID
    end

  end

  return 0
end

-- Called by the "process notes deferred" action so it can record its own command
-- id. Stored persistently (survives REAPER restarts) so resolveDeferredCommandID
-- can find it on any install without a hardcoded id.
local function registerDeferredCommand()

  local cmdID = ({reaper.get_action_context()})[4]
  local named = reaper.ReverseNamedCommandLookup(cmdID)

  if named ~= nil then
    reaper.SetExtState(sectionName, 'deferred_notes_command_name', '_' .. named, true)
  end
end

local function print(message)

  if type(message) == "table" then
    message = serializeTable(message)
  end

  reaper.ShowConsoleMsg("AccessiChords: "..tostring(message).."\n")
end

local function getCurrentPitchCursorNote()

  local activeMidiEditor = reaper.MIDIEditor_GetActive()

  if activeMidiEditor == nil then
    return
  end

  local currentPitchCursor = reaper.MIDIEditor_GetSetting_int(activeMidiEditor, "active_note_row")

  return currentPitchCursor

end

local function getCurrentNoteChannel()

  local activeMidiEditor = reaper.MIDIEditor_GetActive()

  if activeMidiEditor == nil then
    return
  end

  return reaper.MIDIEditor_GetSetting_int(activeMidiEditor, "default_note_chan")
end

local function getCurrentVelocity()

  local activeMidiEditor = reaper.MIDIEditor_GetActive()

  if activeMidiEditor == nil then
    return 96
  end

  return reaper.MIDIEditor_GetSetting_int(activeMidiEditor, "default_note_vel")
end

local function playNotes(...)

  local noteChannel = getCurrentNoteChannel()

  if noteChannel == nil then
    return
  end

  local noteOnCommand = 0x90 + noteChannel

  for _, note in pairs({...}) do

    reaper.StuffMIDIMessage(0, noteOnCommand, note, 96)
  end

end

local function stopNotes(...)

  local notes = {...}
  local noteChannel = getCurrentNoteChannel()
  local noteOffCommand = 0x80 + noteChannel
  local _, midiNote

  if #notes == 0 then

    for midiNote = 0, 127 do

      reaper.StuffMIDIMessage(0, noteOffCommand, midiNote, 0)

    end
  else
  
    for _, midiNote in pairs(notes) do

      reaper.StuffMIDIMessage(0, noteOffCommand, midiNote, 0)

    end

  end
end

local function getAllChords()

  return {
    {
      name = 'major',
      create = function(note)
        return {
          note,
          note + 4,
          note + 7
        }
      end
    },
    {
      name = 'minor',
      create = function(note)
        return {
          note,
          note + 3,
          note + 7
        }
      end
    },
    {
      name = 'diminished',
      create = function(note)
        return {
          note,
          note + 3,
          note + 6
        }
      end
    },
    {
      name = 'augmented',
      create = function(note)
        return {
          note,
          note + 4,
          note + 8
        }
      end
    },
    {
      name = 'suspended second',
      create = function(note)
        return {
          note,
          note + 2,
          note + 7
        }
      end
    },
    {
      name = 'suspended fourth',
      create = function(note)
        return {
          note,
          note + 5,
          note + 7
        }
      end
    },
    {
      name = 'power',
      create = function(note)
        return {
          note,
          note + 7
        }
      end
    },
    {
      name = 'flat fifth',
      create = function(note)
        return {
          note,
          note + 6
        }
      end
    },
    {
      name = 'added ninth',
      create = function(note)
        return {
          note,
          note + 2,
          note + 4,
          note + 7
        }
      end
    },
    {
      name = 'minor added ninth',
      create = function(note)
        return {
          note,
          note + 2,
          note + 3,
          note + 7
        }
      end
    },
    {
      name = 'major sixth',
      create = function(note)
        return {
          note,
          note + 4,
          note + 7,
          note + 9
        }
      end
    },
    {
      name = 'minor sixth',
      create = function(note)
        return {
          note,
          note + 3,
          note + 7,
          note + 9
        }
      end
    },
    {
      name = 'dominant seventh',
      create = function(note)
        return {
          note,
          note + 4,
          note + 7,
          note + 10
        }
      end
    },
    {
      name = 'major seventh',
      create = function(note)
        return {
          note,
          note + 4,
          note + 7,
          note + 11
        }
      end
    },
    {
      name = 'minor seventh',
      create = function(note)
        return {
          note,
          note + 3,
          note + 7,
          note + 10
        }
      end
    },
    {
      name = 'minor major seventh',
      create = function(note)
        return {
          note,
          note + 3,
          note + 7,
          note + 11
        }
      end
    },
    {
      name = 'half diminished seventh',
      create = function(note)
        return {
          note,
          note + 3,
          note + 6,
          note + 10
        }
      end
    },
    {
      name = 'diminished seventh',
      create = function(note)
        return {
          note,
          note + 3,
          note + 6,
          note + 9
        }
      end
    },
    {
      name = 'augmented seventh',
      create = function(note)
        return {
          note,
          note + 4,
          note + 8,
          note + 10
        }
      end
    },
    {
      name = 'major seventh sharp fifth',
      create = function(note)
        return {
          note,
          note + 4,
          note + 8,
          note + 11
        }
      end
    },
    {
      name = 'dominant seventh flat fifth',
      create = function(note)
        return {
          note,
          note + 4,
          note + 6,
          note + 10
        }
      end
    },
    {
      name = 'dominant seventh flat ninth',
      create = function(note)
        return {
          note,
          note + 1,
          note + 4,
          note + 7,
          note + 10
        }
      end
    },
    {
      name = 'dominant seventh sharp ninth',
      create = function(note)
        return {
          note,
          note + 3,
          note + 4,
          note + 7,
          note + 10
        }
      end
    },
    {
      name = 'dominant ninth',
      create = function(note)
        return {
          note,
          note + 2,
          note + 4,
          note + 7,
          note + 10
        }
      end
    },
    {
      name = 'major ninth',
      create = function(note)
        return {
          note,
          note + 2,
          note + 4,
          note + 7,
          note + 11
        }
      end
    },
    {
      name = 'minor ninth',
      create = function(note)
        return {
          note,
          note + 2,
          note + 3,
          note + 7,
          note + 10
        }
      end
    },
    {
      name = 'minor eleventh',
      create = function(note)
        return {
          note,
          note + 2,
          note + 3,
          note + 5,
          note + 7,
          note + 10
        }
      end
    },
    {
      name = 'dominant eleventh',
      create = function(note)
        return {
          note,
          note + 2,
          note + 5,
          note + 7,
          note + 10
        }
      end
    },
    {
      name = 'dominant thirteenth',
      create = function(note)
        return {
          note,
          note + 2,
          note + 4,
          note + 7,
          note + 9,
          note + 10
        }
      end
    },
    {
      name = 'major thirteenth',
      create = function(note)
        return {
          note,
          note + 2,
          note + 4,
          note + 7,
          note + 9,
          note + 11
        }
      end
    }
  }
end

local function notesAreValid(...)

  local valid = true
  local _, note

  for _, note in pairs({...}) do

    if note > 127 or note < 0 then
      valid = false
    end
      
  end

  return valid

end

local function getChordInversion(step, ...)

  local notes = {...}

  if step >= #notes then
    return nil
  end
  
  local i

  for i = 1, step do
    notes[i] = notes[i] + 12
  end

  -- Raising the lowest notes leaves the array out of pitch order, so sort it
  -- ascending. Block mode plays all notes together and doesn't care, but the
  -- broken (arpeggiated) modes step through the array in order and need it
  -- low to high to sound the inversion correctly.
  table.sort(notes)

  return notes
end

-- highest inversion available for the chord at the given position in the chord
-- list. A chord of n notes has n - 1 inversions (each inversion raises one more
-- of the lowest notes by an octave), so this scales with the size of the chord
-- rather than being a fixed maximum.
local function getMaxInversion(note, chordIndex)

  local chordGenerators = getAllChords()

  if chordGenerators[chordIndex] == nil then
    return 0
  end

  return #(chordGenerators[chordIndex].create(note)) - 1
end

local function getChordsForNote(note, inversion)

  inversion = inversion or 0
  local chordGenerators = getAllChords()
  
  local chords = {}

  local _, gen, notes

  for _, gen in pairs(chordGenerators) do

    notes = gen.create(note)

    if notesAreValid(table.unpack(notes)) == false then
      notes = {}
    else

      if inversion > 0 then

        notes = getChordInversion(inversion, table.unpack(notes))

        if notes == nil then
          notes = {}
        else

          if notesAreValid(table.unpack(notes)) == false then
            notes = {}
          end

        end

      end

      table.insert(chords, notes)

    end

  end

  return chords

end

-- outputs text through OSARA's speech. Stays silent when text is nil or "" so an
-- empty result (e.g. a describe() that has no words for the analysis) announces
-- nothing rather than a blank message.
local function speak(text)
  if text ~= nil and text ~= "" and reaper.osara_outputMessage ~= nil then
    reaper.osara_outputMessage(text)
  end
end

local function getAllNoteNames()
  return {
    'C',
    'C sharp',
    'D',
    'D sharp',
    'E',
    'F',
    'F sharp',
    'G',
    'G sharp',
    'A',
    'A sharp',
    'B'
  }
end

local function getNoteName(note)

  if notesAreValid(note) == false then
    return 'unknown'
  end

  local noteIndex = (note % 12) + 1
  local octave = math.floor(note/12)-1

  return getAllNoteNames()[noteIndex].." "..tostring(octave)
end

-- spoken name for an inversion. root position and the first three inversions
-- use their conventional ordinal names; higher inversions (only reachable on the
-- extended five and six note chords) fall back to "inversion n" since ordinal
-- names above third are not commonly used.
local function getInversionName(inversion)

  if inversion == 0 then
    return "root position"
  elseif inversion == 1 then
    return "first inversion"
  elseif inversion == 2 then
    return "second inversion"
  elseif inversion == 3 then
    return "third inversion"
  end

  return "inversion "..tostring(inversion)
end

-- spoken name for a chord mode. block is the plain simultaneous chord, the other
-- two are the ascending and descending arpeggios.
local function getModeName(mode)

  if mode == 1 then
    return "low to high"
  elseif mode == 2 then
    return "high to low"
  end

  return "block"
end

local function getChordNamesForNote(note, inversion, mode)

  inversion = inversion or 0
  mode = mode or 0

  local chordGenerators = getAllChords()

  local names = {}
  local name

  for _, gen in pairs(chordGenerators) do

    name = getNoteName(note).." "..gen.name

    -- root position is the common case, so it is left unspoken in the full chord
    -- name; only actual inversions are appended
    if inversion > 0 then
      name = name.." "..getInversionName(inversion)
    end

    if mode > 0 then
      name = name .. " (" .. getModeName(mode) .. ")"
    end

    table.insert(names, name)

  end

  return names

end

local function getActiveMidiTake()

  local activeMidiEditor = reaper.MIDIEditor_GetActive()

  return reaper.MIDIEditor_GetTake(activeMidiEditor)
end

local function getCursorPosition()
  return reaper.GetCursorPosition()
end

local function getCursorPositionPPQ()
  return reaper.MIDI_GetPPQPosFromProjTime(getActiveMidiTake(), getCursorPosition())
end

local function getActiveMediaItem()
  return reaper.GetMediaItemTake_Item(getActiveMidiTake())
end

local function getMediaItemStartPosition()
  return reaper.GetMediaItemInfo_Value(getActiveMediaItem(), "D_POSITION")
end

local function getMediaItemStartPositionPPQ()
  return reaper.MIDI_GetPPQPosFromProjTime(getActiveMidiTake(), getMediaItemStartPosition())
end

local function getMediaItemStartPositionQN()
  return reaper.MIDI_GetProjQNFromPPQPos(getActiveMidiTake(), getMediaItemStartPositionPPQ())
end

local function getGridUnitLength()

  local gridLengthQN = reaper.MIDI_GetGrid(getActiveMidiTake())
  local mediaItemPlusGridLengthPPQ = reaper.MIDI_GetPPQPosFromProjQN(getActiveMidiTake(), getMediaItemStartPositionQN() + gridLengthQN)
  local mediaItemPlusGridLength = reaper.MIDI_GetProjTimeFromPPQPos(getActiveMidiTake(), mediaItemPlusGridLengthPPQ)
  return mediaItemPlusGridLength - getMediaItemStartPosition()
end

local function getNextNoteLength()

  local activeMidiEditor = reaper.MIDIEditor_GetActive()
  
  if activeMidiEditor == nil then
    return 0
  end
  
  local noteLen = reaper.MIDIEditor_GetSetting_int(activeMidiEditor, "default_note_len")

  if noteLen == 0 then
    return 0
  end

  return reaper.MIDI_GetProjTimeFromPPQPos(getActiveMidiTake(), noteLen)
end

local function getMidiEndPositionPPQ()

  local startPosition = getCursorPosition()
  local startPositionPPQ = getCursorPositionPPQ()

  local noteLength = getNextNoteLength()
  
  if noteLength == 0 then
    noteLength = getGridUnitLength()
  end

  local endPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(getActiveMidiTake(), startPosition+noteLength)

  return endPositionPPQ
end

local function insertMidiNotes(...)

  local startPositionPPQ = getCursorPositionPPQ()
  local endPositionPPQ = getMidiEndPositionPPQ()

  local channel = getCurrentNoteChannel()
  local take = getActiveMidiTake()
  local velocity = getCurrentVelocity()
  local _, note

  for _, note in pairs({...}) do
    reaper.MIDI_InsertNote(take, false, false, startPositionPPQ, endPositionPPQ, channel, note, velocity, false)
  end

  local endPosition = reaper.MIDI_GetProjTimeFromPPQPos(take, endPositionPPQ)

  reaper.SetEditCurPos(endPosition, true, false)
end

-- duration in defer ticks (ca 33 msec)
local function stopNotesDeferred(duration, ...)

  local notes = {...}
  local noteTable = deserializeTable(getValue('deferred_notes', serializeTable({})))
  local deferCount = tonumber(getValue('deferred_notes_defer_count', 0))

  local _, i, note, found, noteIndex
  
  for _, note in pairs(notes) do

    found = false

    for i = 1, #noteTable do

      if noteTable[i]['note'] == note and noteTable[i]['action'] == 'stop' then
        found = true
        noteIndex = i
        break
      end
    end

    if found == true then
      -- note is already in the list
      -- hence we will set the time to the current defer count + duration
      noteTable[noteIndex]['time'] = deferCount + duration
    else

      -- add the note to the list
      table.insert(noteTable, {
        action = 'stop',
        time = deferCount + duration + 1,
        note = note
      })
  
    end
  end

  setValue('deferred_notes', serializeTable(noteTable))
    
  if deferCount == 0 then

    -- we have to manually launch the action
    local commandID = resolveDeferredCommandID()

    if commandID ~= 0 then

      -- to prevent many calls before even the first defer in the action fires, we'll have to set defer count to 1 already
      setValue('deferred_notes_defer_count', 1)

      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), commandID)

    else
      -- message box informing about missing action
      stopNotes(table.unpack(notes))
      reaper.MB('The action to process notes deferred could not be found. That will cause issues with real-time generated samples. Please make sure to follow the installation instructions which can be found in the documentation', 'AccessiChords - Error', 0)
    end

  end
end

-- delay = defer tick delay after which to play the notes
-- duration in defer ticks
local function playNotesDeferred(delay, duration, ...)

  local notes = {...}
  local noteTable = deserializeTable(getValue('deferred_notes', serializeTable({})))
  local deferCount = tonumber(getValue('deferred_notes_defer_count', 0))

  local _, i, note, found, noteIndex
  
  for _, note in pairs(notes) do

    found = false

    for i = 1, #noteTable do

      if noteTable[i]['note'] == note and noteTable[i]['action'] == 'play' then
        found = true
        noteIndex = i
        break
      end
    end

    if found == true then
      -- note is already in the list
      -- hence we will set the time to the current defer count + delay
      noteTable[noteIndex]['time'] = deferCount + duration
      noteTable[noteIndex]['delay'] = delay
    else

      -- add the note to the list
      table.insert(noteTable, {
        action = 'play',
        time = deferCount + delay + 1,
        note = note,
        duration = duration
      })
  
    end
  end

  setValue('deferred_notes', serializeTable(noteTable))
    
  if deferCount == 0 then

    -- we have to manually launch the action
    local commandID = resolveDeferredCommandID()

    if commandID ~= 0 then

      -- to prevent many calls before even the first defer in the action fires, we'll have to set defer count to 1 already
      setValue('deferred_notes_defer_count', 1)

      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), commandID)

    else
      -- message box informing about missing action
      playNotes(table.unpack(notes))
      reaper.MB('The action to process notes deferred could not be found. That will cause issues with real-time generated samples. Please make sure to follow the installation instructions which can be found in the documentation', 'AccessiChords - Error', 0)
    end

  end
end

-- immediately stops any preview notes that are still sounding or scheduled, so
-- that rapidly triggered previews (e.g. quickly browsing chords or inversions)
-- interrupt each other instead of stacking up into noise.
-- deferred_notes_defer_count is intentionally left untouched so an already
-- running deferred loop keeps servicing the next preview rather than a second
-- loop being launched.
local function stopPendingPreview()

  local noteTable = deserializeTable(getValue('deferred_notes', serializeTable({})))

  if #noteTable == 0 then
    return
  end

  local notes = {}
  local seen = {}
  local i

  for i = 1, #noteTable do
    if seen[noteTable[i]['note']] == nil then
      seen[noteTable[i]['note']] = true
      table.insert(notes, noteTable[i]['note'])
    end
  end

  stopNotes(table.unpack(notes))

  setValue('deferred_notes', serializeTable({}))
end

-- iteration direction over a chord's notes for a broken-chord mode: mode 1
-- (low to high) walks forwards, mode 2 (high to low) backwards. returns start,
-- stop, step for a numeric for-loop over the note list (indices 1..count), or
-- nothing for other modes, matching the previous inline behaviour where the loop
-- bounds were left unset.
local function chordModeRange(mode, count)
  if mode == 1 then
    return 1, count, 1
  elseif mode == 2 then
    return count, 1, -1
  end
end

-- plays notes according to chord mode (either full, broken or broken from last to first)
-- broken chords will take the current note length into consideration
-- duration in defer ticks (ca 33 msec)
local function playNotesByChordMode(duration, mode, ...)

  local notes = {...}

  stopPendingPreview()
  
  local lstart, lend, lstep, i
  local offset = 0

  local stepTime = math.floor(reaper.MIDI_GetProjTimeFromPPQPos(getActiveMidiTake(), getMidiEndPositionPPQ() - getCursorPositionPPQ()) * 1000 / 33)

  if mode == 0 then
    playNotes(table.unpack(notes))
    stopNotesDeferred(duration, table.unpack(notes))
    return
  end

  lstart, lend, lstep = chordModeRange(mode, #notes)

  for i = lstart, lend, lstep do

    playNotesDeferred(offset, duration, notes[i])
    offset = offset + stepTime

  end

end

local function insertMidiNotesByChordMode(mode, ...)

  local notes = {...}

  if mode == 0 then
    insertMidiNotes(table.unpack(notes))
    return
  end

  local lstart, lend, lstep, i
  
  lstart, lend, lstep = chordModeRange(mode, #notes)
  
  for i = lstart, lend, lstep do
    insertMidiNotes(notes[i])
  end
end

-- ==========================================================================
-- chord identification engine (merged from chordlib.lua)
-- ==========================================================================

--[[
  Chord identification engine (pure Lua, no REAPER dependency).

  Input  : a list of MIDI note numbers (integers, duplicates / octaves allowed).
  Output : a structured result table describing what was found. Naming/spelling is
           NOT done here -- that lives in the speech section below so the same analysis can be
           rendered in different ways.

  Approach (see project notes):
    * Reduce sounding notes to a pitch-class set (0-11), but remember the bass
      (lowest MIDI note) and the full sorted pitch list for voicing.
    * Try every present pitch class as a candidate root. For each root, transpose
      so root = 0 and test it against a table of chord-quality templates.
    * A template matches if all its tones are present (the perfect 5th may be
      omitted, which is extremely common). Remaining notes become "extras"
      (tensions). Candidates are scored, biased toward the bass being the root,
      toward fuller/cleaner matches, and toward more common qualities.
    * Inversion is derived from the bass relative to the chosen root.

  Known v1 limitations (documented, not bugs):
    * Rootless voicings (root pitch absent) are not detected -- only present
      pitch classes are tried as roots.
    * Enharmonic spelling is decided in the speech section from the key/scale context.
]]

local chordlib = {}

-- Chord-quality templates. `iv` = intervals in semitones from the root.
-- `common` is a popularity weight used only as a tie-breaker (0-100).
-- Order does not matter; scoring decides the winner.
chordlib.templates = {
  -- triads
  { key = "major",      iv = {0,4,7},          common = 100 },
  { key = "minor",      iv = {0,3,7},          common = 100 },
  { key = "diminished", iv = {0,3,6},          common = 70  },
  { key = "augmented",  iv = {0,4,8},          common = 50  },
  { key = "sus4",       iv = {0,5,7},          common = 60  },
  { key = "sus2",       iv = {0,2,7},          common = 55  },
  -- sixths
  { key = "6",          iv = {0,4,7,9},        common = 70  },
  { key = "min6",       iv = {0,3,7,9},        common = 55  },
  -- sevenths
  { key = "dom7",       iv = {0,4,7,10},       common = 95  },
  { key = "maj7",       iv = {0,4,7,11},       common = 95  },
  { key = "min7",       iv = {0,3,7,10},       common = 95  },
  { key = "m7b5",       iv = {0,3,6,10},       common = 75  },
  { key = "dim7",       iv = {0,3,6,9},        common = 70  },
  { key = "minMaj7",    iv = {0,3,7,11},       common = 40  },
  { key = "aug7",       iv = {0,4,8,10},       common = 35  }, -- 7 #5
  { key = "maj7s5",     iv = {0,4,8,11},       common = 25  },
  { key = "7b5",        iv = {0,4,6,10},       common = 35  },
  -- added-note (no 7th)
  { key = "add9",       iv = {0,4,7,2},        common = 50  },
  { key = "madd9",      iv = {0,3,7,2},        common = 45  },
  -- ninths
  { key = "dom9",       iv = {0,4,7,10,2},     common = 70  },
  { key = "maj9",       iv = {0,4,7,11,2},     common = 65  },
  { key = "min9",       iv = {0,3,7,10,2},     common = 65  },
  { key = "7b9",        iv = {0,4,7,10,1},     common = 45  },
  { key = "7s9",        iv = {0,4,7,10,3},     common = 45  },
  -- elevenths / thirteenths (often omit tones; subset matching handles that)
  { key = "min11",      iv = {0,3,7,10,2,5},   common = 40  },
  { key = "dom11",      iv = {0,7,10,2,5},     common = 30  },
  { key = "dom13",      iv = {0,4,7,10,2,9},   common = 35  },
  { key = "maj13",      iv = {0,4,7,11,2,9},   common = 25  },
}

local PERFECT_FIFTH = 7

-- Map a bass interval (semitones above the root) to an inversion ordinal.
-- 0 = root position; 1/2/3 = first/second/third; "over" = bass is a non-standard
-- chord tone (rendered as a slash / "over <note>").
local function inversionFromBass(bassInterval)
  if bassInterval == 0 then return 0 end
  if bassInterval == 3 or bassInterval == 4 then return 1 end
  if bassInterval == 6 or bassInterval == 7 or bassInterval == 8 then return 2 end
  if bassInterval == 9 or bassInterval == 10 or bassInterval == 11 then return 3 end
  return "over"
end

-- Build a set {pitchclass=true} and return it plus a sorted list of classes.
local function pitchClassSet(pitches)
  local set, list = {}, {}
  for _, p in ipairs(pitches) do
    local pc = p % 12
    if not set[pc] then set[pc] = true; list[#list+1] = pc end
  end
  table.sort(list)
  return set, list
end

-- Score one (root, template) candidate against the present pitch classes.
-- Returns a score and an `extras` list, or nil if the template cannot match.
local function scoreCandidate(rel, relCount, root, bassPc, t)
  local tmpl = {}
  for _, iv in ipairs(t.iv) do tmpl[iv] = true end

  -- Every template tone must be present, except the perfect 5th may be omitted.
  local missPenalty = 0
  for _, iv in ipairs(t.iv) do
    if not rel[iv] then
      if iv == PERFECT_FIFTH then
        missPenalty = missPenalty + 1
      else
        return nil
      end
    end
  end

  -- Present tones the template does not account for become tensions.
  local extras = {}
  for iv in pairs(rel) do
    if not tmpl[iv] then extras[#extras+1] = iv end
  end
  table.sort(extras)

  local spec = #t.iv
  local score = spec * 10 - #extras * 4 - missPenalty * 3 + t.common * 0.1
  if root == bassPc then score = score + 5 end

  return score, extras
end

-- Analyse a chord (3+ pitch classes).
local function analyseChord(pcs, bassPc, pitches)
  local best
  for _, root in ipairs(pcs) do
    -- pitch classes relative to this candidate root
    local rel = {}
    for _, pc in ipairs(pcs) do rel[(pc - root) % 12] = true end

    for _, t in ipairs(chordlib.templates) do
      local score, extras = scoreCandidate(rel, #pcs, root, bassPc, t)
      if score and (not best or score > best.score) then
        best = { score = score, root = root, template = t, extras = extras }
      end
    end
  end

  if not best then
    return { kind = "unknown", notes = pitches, bassPc = bassPc, guessRootPc = bassPc }
  end

  local bassInterval = (bassPc - best.root) % 12
  return {
    kind      = "chord",
    rootPc    = best.root,
    quality   = best.template.key,
    bassPc    = bassPc,
    inversion = inversionFromBass(bassInterval),
    extras    = best.extras,          -- list of semitone intervals from root
    notes     = pitches,              -- sorted unique pitches, for voicing
  }
end

-- Public entry point. `pitches` is a list of MIDI note numbers.
function chordlib.analyze(pitches)
  -- collect, sort, de-duplicate exact pitches (keep octave info for voicing)
  local seen, uniq = {}, {}
  for _, p in ipairs(pitches or {}) do
    if type(p) == "number" and not seen[p] then seen[p] = true; uniq[#uniq+1] = p end
  end
  table.sort(uniq)

  if #uniq == 0 then return { kind = "empty" } end

  local bass = uniq[1]
  local set, pcs = pitchClassSet(uniq)

  if #pcs == 1 then
    return { kind = "note", pitch = bass, pc = bass % 12, notes = uniq }
  end

  if #pcs == 2 then
    -- Name the interval from the bass pitch class to the other pitch class, so
    -- octave doublings (e.g. C4 G4 C5) don't get mis-measured between extremes.
    local bassPc = bass % 12
    local otherPc = (pcs[1] == bassPc) and pcs[2] or pcs[1]
    local semis = (otherPc - bassPc) % 12   -- 1..11; unison/octave are 1 pc
    return {
      kind    = "interval",
      semis   = semis,
      bassPc  = bassPc,
      otherPc = otherPc,
      bass    = bass,
      notes   = uniq,
    }
  end

  return analyseChord(pcs, bass % 12, uniq)
end

-- ==========================================================================
-- chord speech rendering (merged from speech.lua)
-- ==========================================================================

--[[
  Turns a chordlib result into a spoken, full-words string.

  Everything a user hears is assembled here, so this is the section to edit to
  reword anything. It has no REAPER dependency; the caller passes in the current
  key/scale context (spelling) and hands the result to reaper.osara_outputMessage.

  Adapted for AccessiChords: the quality names match the spoken chord names used
  by the chord insertion actions (e.g. "dominant seventh", "half diminished
  seventh") so the toolset speaks with one voice.
]]

local speech = {}

-- Note spellings. Sharps vs flats is chosen from the key/scale context; the
-- chord root then drives which set we use, so e.g. a D7 spells "F sharp".
local SHARP_NAMES = {
  [0]="C", [1]="C sharp", [2]="D", [3]="D sharp", [4]="E", [5]="F",
  [6]="F sharp", [7]="G", [8]="G sharp", [9]="A", [10]="A sharp", [11]="B",
}
local FLAT_NAMES = {
  [0]="C", [1]="D flat", [2]="D", [3]="E flat", [4]="E", [5]="F",
  [6]="G flat", [7]="G", [8]="A flat", [9]="A", [10]="B flat", [11]="B",
}

-- Quality keys (from chordlib) -> spoken words. These mirror the chord names
-- used by the AccessiChords insertion actions.
speech.quality = {
  major="major", minor="minor", diminished="diminished", augmented="augmented",
  sus4="suspended fourth", sus2="suspended second",
  ["6"]="major sixth", min6="minor sixth",
  dom7="dominant seventh", maj7="major seventh", min7="minor seventh",
  m7b5="half diminished seventh", dim7="diminished seventh",
  minMaj7="minor major seventh", aug7="augmented seventh",
  maj7s5="major seventh sharp fifth", ["7b5"]="dominant seventh flat fifth",
  add9="added ninth", madd9="minor added ninth",
  dom9="dominant ninth", maj9="major ninth", min9="minor ninth",
  ["7b9"]="dominant seventh flat ninth", ["7s9"]="dominant seventh sharp ninth",
  min11="minor eleventh", dom11="dominant eleventh",
  dom13="dominant thirteenth", maj13="major thirteenth",
}

-- Inversion ordinal -> words. Root position (0) is intentionally silent.
speech.inversion = { [1]="first inversion", [2]="second inversion", [3]="third inversion" }

-- Interval semitone -> spoken interval name (full words).
speech.interval = {
  [0]="unison", [1]="minor second", [2]="major second", [3]="minor third",
  [4]="major third", [5]="perfect fourth", [6]="tritone", [7]="perfect fifth",
  [8]="minor sixth", [9]="major sixth", [10]="minor seventh", [11]="major seventh",
  [12]="octave",
}

-- Tension semitone-from-root -> spoken degree, for leftover "extra" notes.
speech.tension = {
  [1]="flat nine", [2]="nine", [3]="sharp nine", [5]="eleven", [6]="sharp eleven",
  [8]="flat thirteen", [9]="thirteen", [10]="seven", [11]="major seven",
}

-- Build a speller for a key context: { tonicPc = 0-11, useFlats = bool }.
-- Returns a function pc -> spoken note name. Flats are the safer default for
-- unknown keys (more readable: "E flat" vs "D sharp").
function speech.makeSpeller(key)
  local useFlats = true
  if key and key.useFlats ~= nil then useFlats = key.useFlats end
  local names = useFlats and FLAT_NAMES or SHARP_NAMES
  return function(pc) return names[pc % 12] end
end

-- Render a chordlib result to a spoken string. Returns "" when nothing should
-- be said (empty selection). `opts.speller` is required for spelling; if absent
-- a flats speller is used.
function speech.describe(result, opts)
  opts = opts or {}
  local spell = opts.speller or speech.makeSpeller(nil)
  if not result then return "" end

  local k = result.kind
  if k == "empty" then
    return ""

  elseif k == "note" then
    return speech.octaveName(result.pitch, spell, opts.octaveOffset)

  elseif k == "interval" then
    local name = speech.interval[result.semis] or (result.semis .. " semitones")
    return name .. ", " .. spell(result.bassPc) .. " and " .. spell(result.otherPc)

  elseif k == "chord" then
    local parts = { spell(result.rootPc) .. " " .. (speech.quality[result.quality] or result.quality) }
    if result.extras and #result.extras > 0 then
      for _, iv in ipairs(result.extras) do
        local deg = speech.tension[iv]
        if deg then parts[#parts+1] = "add " .. deg end
      end
    end
    local line = table.concat(parts, " ")
    if result.inversion == "over" then
      line = line .. " over " .. spell(result.bassPc)
    elseif type(result.inversion) == "number" and result.inversion > 0 then
      line = line .. ", " .. speech.inversion[result.inversion]
    end
    return line

  elseif k == "unknown" then
    -- read out the notes we couldn't name
    local names = {}
    local seen = {}
    for _, p in ipairs(result.notes or {}) do
      local pc = p % 12
      if not seen[pc] then seen[pc] = true; names[#names+1] = spell(pc) end
    end
    return "unrecognised, " .. table.concat(names, " ")
  end

  return ""
end

-- Spoken note name with octave, e.g. "C 4". `offset` shifts the octave number to
-- match REAPER's display; 0 gives middle C = C 4, as the rest of AccessiChords
-- reports it.
function speech.octaveName(pitch, speller, offset)
  offset = offset or 0
  local octave = math.floor(pitch / 12) - 1 + offset
  return speller(pitch % 12) .. " " .. octave
end

-- ==========================================================================
-- chord reporting for the MIDI editor (merged from chordreport.lua)
-- ==========================================================================

--[[
  Reads the selected MIDI notes and speaks the chord.

  OSARA's chord-navigation actions leave all of the chord's notes selected, so
  after running one of them we read the selected notes from the active MIDI
  editor take, identify them with the chordlib section above and speak the result
  via the speech section above.

  Enharmonic spelling (flats vs sharps) follows REAPER's native snap-to-key,
  read from the take with reaper.MIDI_GetScale. When no scale is set we fall back
  to flats.
]]

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
local function reportChord()

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
    speak("no notes")
    return
  end

  local speller = speech.makeSpeller(currentKey(take))
  local result = chordlib.analyze(pitches)

  speak(speech.describe(result, {
    speller = speller,
    octaveOffset = 0,
  }))
end

-- Move through the MIDI editor's chords using OSARA's own chord navigation, then
-- describe the chord we land on in AccessiChords' own voice. commandName is the
-- OSARA named command to run (e.g. "_OSARA_NEXTCHORD"); direction names it for the
-- error message ("next" / "previous"). OSARA's own report is muted (best effort,
-- so older OSARA versions still move) so that reportChord speaks instead.
local function moveToChord(commandName, direction)

  local activeMidiEditor = reaper.MIDIEditor_GetActive()

  if activeMidiEditor == nil then
    return
  end

  local muteCommand = reaper.NamedCommandLookup("_OSARA_ME_MUTENEXTMESSAGE")
  local moveCommand = reaper.NamedCommandLookup(commandName)

  if moveCommand == 0 then
    reaper.MB('The OSARA action to move to the '..direction..' chord could not be found. Please make sure a recent version of OSARA is installed.', 'AccessiChords - Error', 0)
    return
  end

  if muteCommand ~= 0 then
    reaper.MIDIEditor_OnCommand(activeMidiEditor, muteCommand)
  end

  reaper.MIDIEditor_OnCommand(activeMidiEditor, moveCommand)

  reportChord()
end

return {
  deserializeTable = deserializeTable,
  getChordInversion = getChordInversion,
  getInversionName = getInversionName,
  getMaxInversion = getMaxInversion,
  getModeName = getModeName,
  getChordNamesForNote = getChordNamesForNote,
  getChordsForNote = getChordsForNote,
  getCurrentPitchCursorNote = getCurrentPitchCursorNote,
  getNoteName = getNoteName,
  getValue = getValue,
  getValuePersist = getValuePersist,
  insertMidiNotes = insertMidiNotes,
  insertMidiNotesByChordMode = insertMidiNotesByChordMode,
  map = map,
  moveToChord = moveToChord,
  playNotes = playNotes,
  playNotesByChordMode = playNotesByChordMode,
  playNotesDeferred = playNotesDeferred,
  print = print,
  registerDeferredCommand = registerDeferredCommand,
  reportChord = reportChord,
  serializeTable = serializeTable,
  setValue = setValue,
  setValuePersist = setValuePersist,
  speak = speak,
  stopNotes = stopNotes,
  stopNotesDeferred = stopNotesDeferred
}