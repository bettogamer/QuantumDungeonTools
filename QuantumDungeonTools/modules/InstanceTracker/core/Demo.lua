-- modules/InstanceTracker/core/Demo.lua -- PURE: fake runs for `/qdt it demo <state>`.
--
-- The numbers are the ones of the design canvas artboards (Main, Completada, PrimeraVez,
-- Compacto), so a screenshot of the demo can be compared with its artboard one to one. Lets the
-- owner (and ui-critic) see every state without a dungeon group: solo, no boss can be killed.
local _, ns = ...
local Run = ns.InstanceRun

local Demo = {}
ns.InstanceTrackerDemo = Demo

local START = 1000
local BOSSES = { "Witherfang", "The Abandoned", "The Butcher", "Lordaeron Captain", "Viktor the Vile",
  "Bjork", "Rath'mael" }
-- Kill times of the completed artboard (seconds since the start).
local KILLS = { 238, 521, 773, 1022, 1300, 1531, 1791 }
-- Personal record: total 31:40 and the splits that give the artboard deltas.
local PB = {
  total = 1900,
  splits = { Witherfang = 250, ["The Abandoned"] = 501, ["The Butcher"] = 790, ["Lordaeron Captain"] = 1065,
    ["Viktor the Vile"] = 1350, Bjork = 1625, ["Rath'mael"] = 1900 },
}

local function makeRun(kills, elapsed, finished, xp)
  local bosses = {}
  for i, name in ipairs(BOSSES) do
    local at = kills[i]
    bosses[i] = { name = name, killed = at ~= nil, killedAt = at }
  end
  local t = {
    instanceID = 2999, name = "Ruins of Lordaeron", difficulty = "Normal",
    startedAt = START, finishedAt = finished and (START + elapsed) or nil,
    listKnown = true, xp = xp, bosses = bosses,
  }
  return Run.fromTable(t, { now = function() return START + elapsed end })
end

local LIVE_KILLS = { KILLS[1], KILLS[2], KILLS[3] }
local XP_MAX = 88000

local SCENARIOS = {
  -- Main: 16:22 with 3/7, record 31:40, ahead by 0:17.
  live = function()
    return makeRun(LIVE_KILLS, 982, false, 18450), {
      pb = PB, deaths = 2, instances = { count = 8, limit = 10, freeIn = 760 },
      xp = { level = 54, xp = 54560, max = XP_MAX, rested = 15840 },
    }
  end,
  -- Completada: 29:51, new record by 1:49, crossed a level.
  done = function()
    return makeRun(KILLS, 1791, true, 41220), {
      pb = PB, deaths = 3, instances = { count = 9, limit = 10, freeIn = 665 },
      xp = { level = 55, xp = 29920, max = XP_MAX, rested = 0 },
    }
  end,
  -- PrimeraVez: same run, no record yet.
  first = function()
    return makeRun(LIVE_KILLS, 982, false, 18450), {
      deaths = 1, instances = { count = 3, limit = 10 },
      xp = { level = 54, xp = 54560, max = XP_MAX, rested = 15840 },
    }
  end,
}
SCENARIOS.compact = SCENARIOS.live

Demo.NAMES = { "live", "done", "first", "compact" }

-- Demo.get(name) -> run, opts, compact | nil
function Demo.get(name)
  local make = SCENARIOS[name]
  if not make then return nil end
  local run, opts = make()
  return run, opts, name == "compact"
end

return Demo
