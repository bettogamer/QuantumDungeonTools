-- modules/InstanceTracker/core/Hourly.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- Instances entered in the last hour, for the whole account (plan M1 F5): the game lets an
-- account into 10 NEW instances per sliding hour. The rule ported from Naowh Forever (only the
-- rule, not the code; docs/10 §2.7): an entry counts when we walk into a copy that is new for
-- this run (wow/Tracker.lua decides that); re-entering a copy already counted in the last hour
-- does not count again. The copy (zoneUID) is only known at the first cast inside, so an entry
-- is noted without it and bound later (bindCopy), which may turn it into a duplicate.
--
-- The list lives in QuantumDungeonToolsDB.instanceTracker.hourly (account-wide SavedVariables):
--   { { at = time(), instanceID = n, name = "...", char = "Name-Realm", copy = zoneUID|nil }, ... }
local _, ns = ...

local Hourly = {}
ns.InstanceHourly = Hourly

Hourly.LIMIT = 10
Hourly.HOUR = 3600

local function num(v) return type(v) == "number" and v == v end

local function fresh(e, now)
  return type(e) == "table" and num(e.at) and now - e.at < Hourly.HOUR and now - e.at >= 0
end

-- Drops the entries older than an hour (and anything malformed). Returns the list.
function Hourly.prune(list, now)
  if type(list) ~= "table" or not num(now) then return list end
  for i = #list, 1, -1 do
    if not fresh(list[i], now) then table.remove(list, i) end
  end
  return list
end

-- Notes an entry into `info` ({ instanceID, name, char?, copy? }). With a copy that is already
-- counted in the last hour it does nothing. Returns the new entry, or nil when it did not count.
function Hourly.note(list, now, info)
  if type(list) ~= "table" or not num(now) or type(info) ~= "table" or not num(info.instanceID) then
    return nil
  end
  Hourly.prune(list, now)
  if info.copy ~= nil then
    for _, e in ipairs(list) do
      if e.instanceID == info.instanceID and e.copy == info.copy then return nil end
    end
  end
  local e = { at = now, instanceID = info.instanceID, name = info.name, char = info.char, copy = info.copy }
  list[#list + 1] = e
  return e
end

-- The first cast inside told us the copy of the newest entry of `instanceID`.
-- Returns "bound" (copy saved), "dup" (that copy was already counted: the entry is removed),
-- "known" (the entry already had a copy) or nil (no entry of that instance in the last hour).
function Hourly.bindCopy(list, now, instanceID, copy)
  if type(list) ~= "table" or not num(now) or copy == nil then return nil end
  Hourly.prune(list, now)
  local newest
  for i = #list, 1, -1 do
    if list[i].instanceID == instanceID then newest = i break end
  end
  if not newest then return nil end
  local e = list[newest]
  if e.copy ~= nil then return "known" end
  for i, other in ipairs(list) do
    if i ~= newest and other.instanceID == instanceID and other.copy == copy then
      table.remove(list, newest)
      return "dup"
    end
  end
  e.copy = copy
  return "bound"
end

-- The castGUID zoneUID of the SAME copy changed (it did across a /reload, Forever 2026-11-20):
-- the entries of `instanceID` with copy `old` now carry `new`, so a later re-entry still
-- dedups. Returns how many entries changed.
function Hourly.rebindCopy(list, now, instanceID, old, new)
  if type(list) ~= "table" or not num(now) or old == nil or new == nil then return 0 end
  Hourly.prune(list, now)
  local n = 0
  for _, e in ipairs(list) do
    if e.instanceID == instanceID and e.copy == old then
      e.copy = new
      n = n + 1
    end
  end
  return n
end

-- { count, limit, slots = { seconds until each slot frees, soonest first }, freeIn = slots[1] }
-- The shape Detail.build takes as opts.instances.
function Hourly.snapshot(list, now, limit)
  limit = limit or Hourly.LIMIT
  local slots = {}
  if type(list) == "table" and num(now) then
    for _, e in ipairs(list) do
      if fresh(e, now) then slots[#slots + 1] = e.at + Hourly.HOUR - now end
    end
  end
  table.sort(slots)
  return { count = #slots, limit = limit, slots = slots, freeIn = slots[1] }
end

return Hourly
