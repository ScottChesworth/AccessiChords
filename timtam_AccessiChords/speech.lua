--[[
  speech.lua  --  turns a chordlib result into a spoken, full-words string.

  Everything a user hears is assembled here, so this is the file to edit to
  reword anything. It has no REAPER dependency; the caller passes in the current
  key/scale context (spelling) and hands the result to reaper.osara_outputMessage.

  Adapted for AccessiChords: the quality names match the spoken chord names used
  by the chord insertion actions (e.g. "dominant seventh", "half diminished
  seventh") so the toolset speaks with one voice.
]]

local M = {}

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
M.quality = {
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
M.inversion = { [1]="first inversion", [2]="second inversion", [3]="third inversion" }

-- Interval semitone -> spoken interval name (full words).
M.interval = {
  [0]="unison", [1]="minor second", [2]="major second", [3]="minor third",
  [4]="major third", [5]="perfect fourth", [6]="tritone", [7]="perfect fifth",
  [8]="minor sixth", [9]="major sixth", [10]="minor seventh", [11]="major seventh",
  [12]="octave",
}

-- Tension semitone-from-root -> spoken degree, for leftover "extra" notes.
M.tension = {
  [1]="flat nine", [2]="nine", [3]="sharp nine", [5]="eleven", [6]="sharp eleven",
  [8]="flat thirteen", [9]="thirteen", [10]="seven", [11]="major seven",
}

-- Build a speller for a key context: { tonicPc = 0-11, useFlats = bool }.
-- Returns a function pc -> spoken note name. Flats are the safer default for
-- unknown keys (more readable: "E flat" vs "D sharp").
function M.makeSpeller(key)
  local useFlats = true
  if key and key.useFlats ~= nil then useFlats = key.useFlats end
  local names = useFlats and FLAT_NAMES or SHARP_NAMES
  return function(pc) return names[pc % 12] end
end

-- Render a chordlib result to a spoken string. Returns "" when nothing should
-- be said (empty selection). `opts.speller` is required for spelling; if absent
-- a flats speller is used.
function M.describe(result, opts)
  opts = opts or {}
  local spell = opts.speller or M.makeSpeller(nil)
  if not result then return "" end

  local k = result.kind
  if k == "empty" then
    return ""

  elseif k == "note" then
    return M.octaveName(result.pitch, spell, opts.octaveOffset)

  elseif k == "interval" then
    local name = M.interval[result.semis] or (result.semis .. " semitones")
    return name .. ", " .. spell(result.bassPc) .. " and " .. spell(result.otherPc)

  elseif k == "chord" then
    local parts = { spell(result.rootPc) .. " " .. (M.quality[result.quality] or result.quality) }
    if result.extras and #result.extras > 0 then
      for _, iv in ipairs(result.extras) do
        local deg = M.tension[iv]
        if deg then parts[#parts+1] = "add " .. deg end
      end
    end
    local line = table.concat(parts, " ")
    if result.inversion == "over" then
      line = line .. " over " .. spell(result.bassPc)
    elseif type(result.inversion) == "number" and result.inversion > 0 then
      line = line .. ", " .. M.inversion[result.inversion]
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
function M.octaveName(pitch, speller, offset)
  offset = offset or 0
  local octave = math.floor(pitch / 12) - 1 + offset
  return speller(pitch % 12) .. " " .. octave
end

return M
