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
-- Lockout order (not the route): makeRun sorts it with the dungeon table, like a real run.
local BOSSES = { "Witherfang", "The Abandoned", "The Butcher", "Lordaeron Captain", "Viktor the Vile",
  "Bjork", "Rath'mael" }
-- Kill times of the completed artboard (seconds since the start); the rare stays alive.
local KILLS = { Witherfang = 238, ["The Butcher"] = 521, ["Viktor the Vile"] = 773,
  ["The Abandoned"] = 1090, Bjork = 1442, ["Rath'mael"] = 1791 }
-- Personal record: total 31:40 and the splits that give the artboard deltas. It carries the
-- rare's split on purpose: the view must ignore it (no tick, no delta).
local PB = {
  total = 1900,
  at = START - 3 * 86400,   -- Compacto: "31:40 · hace 3 días"
  splits = { Witherfang = 250, ["The Butcher"] = 501, ["Viktor the Vile"] = 790, ["Lordaeron Captain"] = 1065,
    ["The Abandoned"] = 1133, Bjork = 1536, ["Rath'mael"] = 1900 },
}

local function resolve(instanceID, name)
  return ns.InstanceDungeons.find(instanceID, name)
end

local function makeRun(kills, elapsed, finished, xp)
  local bosses = {}
  for i, name in ipairs(BOSSES) do
    local at = kills[name]
    bosses[i] = { name = name, killed = at ~= nil, killedAt = at }
  end
  local t = {
    instanceID = 2999, name = "Ruins of Lordaeron", difficulty = "Normal",
    startedAt = START, finishedAt = finished and (START + elapsed) or nil,
    listKnown = true, xp = xp, bosses = bosses,
  }
  return Run.fromTable(t, { now = function() return START + elapsed end, resolve = resolve })
end

-- Totals row of the artboards: "+4g 12s" and "+350 Undercity".
local function withLoot(run, copper, rep)
  run.copper, run.rep = copper, rep
  return run
end

local LIVE_KILLS = { Witherfang = KILLS.Witherfang, ["The Butcher"] = KILLS["The Butcher"],
  ["Viktor the Vile"] = KILLS["Viktor the Vile"] }
-- PrimeraVez: the same 3 bosses plus the rare killed at 6:10.
local FIRST_KILLS = { Witherfang = 238, ["The Butcher"] = 521, ["Viktor the Vile"] = 773,
  ["Lordaeron Captain"] = 370 }
local XP_MAX = 88000

-- Detalle: two earlier clean runs with this group (best 28:05) and one with another group.
local GROUP = "Ann,Bob,Cid,Dee"
local function past(elapsed, group)
  local r = makeRun(KILLS, elapsed, true, 39800)
  r.group = group
  return r:toTable()
end

local SCENARIOS = {
  -- Main: 16:22 with 3/6, record 31:40, ahead by 0:17.
  live = function()
    return withLoot(makeRun(LIVE_KILLS, 982, false, 18450), 41200, { Undercity = 350 }), {
      pb = PB, deaths = 2, now = START + 982,
      instances = { count = 8, limit = 10, freeIn = 760, slots = { 760, 1275 } },
      xp = { level = 54, xp = 54560, max = XP_MAX, rested = 15840 },
      group = GROUP, history = { past(1685, GROUP), past(1902, GROUP), past(1750, "Zed") },
    }
  end,
  -- Completada: 29:51, new record by 1:49, crossed a level.
  done = function()
    local run = withLoot(makeRun(KILLS, 1791, true, 41220), 87512, { Undercity = 725, ["The Forsaken"] = 150 })
    run.levels = 1   -- "+41,220 XP en la run · 1 nivel"
    return run, {
      pb = PB, deaths = 3, now = START + 1791, instances = { count = 9, limit = 10, freeIn = 665 },
      xp = { level = 55, xp = 29920, max = XP_MAX, rested = 0 },
    }
  end,
  -- PrimeraVez: same run, no record yet.
  first = function()
    return makeRun(FIRST_KILLS, 982, false, 18450), {
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
