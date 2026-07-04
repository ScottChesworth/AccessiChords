-- fixing script path for correct require calls
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

-- Moves to the next chord in the MIDI editor using OSARA's own chord navigation.
-- OSARA's report for the move is muted so that AccessiChords describes the chord
-- itself instead, using its own chord identification.

local chordreport = require('chordreport')

local activeMidiEditor = reaper.MIDIEditor_GetActive()

if activeMidiEditor == nil then
  return
end

local muteCommand = reaper.NamedCommandLookup("_OSARA_ME_MUTENEXTMESSAGE")
local moveCommand = reaper.NamedCommandLookup("_OSARA_NEXTCHORD")

if moveCommand == 0 then
  reaper.MB('The OSARA action to move to the next chord could not be found. Please make sure a recent version of OSARA is installed.', 'AccessiChords - Error', 0)
  return
end

-- muting is best effort - if the OSARA action is missing (older OSARA) we still
-- move, OSARA just reports the chord in its own words
if muteCommand ~= 0 then
  reaper.MIDIEditor_OnCommand(activeMidiEditor, muteCommand)
end

reaper.MIDIEditor_OnCommand(activeMidiEditor, moveCommand)

chordreport.report()
