-- fixing script path for correct require calls
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

-- Moves to the previous chord in the MIDI editor using OSARA's own chord
-- navigation. OSARA's report for the move is muted so that AccessiChords
-- describes the chord itself instead, using its own chord identification.

local AccessiChords = require('timtam_AccessiChords')

AccessiChords.moveToChord("_OSARA_PREVCHORD", "previous")
