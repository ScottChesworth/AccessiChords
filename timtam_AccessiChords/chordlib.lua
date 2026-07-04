--[[
  chordlib.lua  --  chord identification engine (pure Lua, no REAPER dependency)

  Input  : a list of MIDI note numbers (integers, duplicates / octaves allowed).
  Output : a structured result table describing what was found. Naming/spelling is
           NOT done here -- that lives in speech.lua so the same analysis can be
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
    * Enharmonic spelling is decided in speech.lua from the key/scale context.
]]

local M = {}

-- Chord-quality templates. `iv` = intervals in semitones from the root.
-- `common` is a popularity weight used only as a tie-breaker (0-100).
-- Order does not matter; scoring decides the winner.
M.templates = {
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

-- Interval names for two-note dyads, indexed by semitone distance 0-12.
M.intervals = {
  [0]="unison", [1]="minor 2nd", [2]="major 2nd", [3]="minor 3rd",
  [4]="major 3rd", [5]="perfect 4th", [6]="tritone", [7]="perfect 5th",
  [8]="minor 6th", [9]="major 6th", [10]="minor 7th", [11]="major 7th",
  [12]="octave",
}

-- semitone-from-root -> spoken tension degree, used to describe leftover "extra"
-- notes that no template absorbed.
M.tensionDegree = {
  [1]="flat 9", [2]="9", [3]="sharp 9", [5]="11", [6]="sharp 11",
  [8]="flat 13", [9]="13", [10]="7", [11]="major 7",
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

    for _, t in ipairs(M.templates) do
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
function M.analyze(pitches)
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

return M
