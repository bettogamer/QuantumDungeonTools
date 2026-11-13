-- modules/InstanceTracker/core/Dungeons.lua -- PURE lookups over the generated DungeonData.
--
-- The lockout list (GetInstanceLockTimeRemainingEncounter) gives only localized names, in an
-- order that is not the route, and mixes rares with bosses (docs/11). This module answers, for
-- a boss name inside an instance: its route order and whether it is a rare. Names are English
-- in the data; `learned` (name -> encounterID, filled from ENCOUNTER_END by the wow/ layer)
-- covers other locales and names the data gets wrong.
local _, ns = ...

local Dungeons = {}
ns.InstanceDungeons = Dungeons

local byEncounter, byInstance -- built on first use

local function build()
  byEncounter, byInstance = {}, {}
  for _, d in ipairs(ns.InstanceDungeonData or {}) do
    local list = byInstance[d.instance]
    if not list then
      list = {}
      byInstance[d.instance] = list
    end
    for order, b in ipairs(d.bosses) do
      local info = { dungeon = d.key, order = order, rare = b.rare == true, names = b.names }
      list[#list + 1] = info
      for _, id in ipairs(b.ids) do byEncounter[id] = info end
    end
  end
end

-- forEncounter(id) -> { dungeon, order, rare, names } | nil
function Dungeons.forEncounter(id)
  if not byEncounter then build() end
  if type(id) ~= "number" then return nil end
  return byEncounter[id]
end

-- find(instanceID, name, learned) -> { dungeon, order, rare, names } | nil
-- A learned encounterID wins over the English names of the data.
function Dungeons.find(instanceID, name, learned)
  if not byEncounter then build() end
  if type(name) ~= "string" or name == "" then return nil end
  if type(learned) == "table" then
    local hit = Dungeons.forEncounter(learned[name])
    if hit then return hit end
  end
  for _, info in ipairs(byInstance[instanceID] or {}) do
    for _, n in ipairs(info.names) do
      if n == name then return info end
    end
  end
  return nil
end

-- Test hook: forget the index so a spec can swap ns.InstanceDungeonData.
function Dungeons._reset() byEncounter, byInstance = nil, nil end
