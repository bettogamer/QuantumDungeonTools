-- modules/InstanceTracker/core/Records.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- Personal records (PB) per dungeon + difficulty (plan M1 F3). The store is a plain table
-- (db.instanceTracker.records): key -> { total, splits = { [bossName] = sec }, deaths, at }.
-- Records never expire and live apart from the history (owner, 2026-11-12).
--
-- A run races against the record it STARTED with (run.pb, a copy): when it beats it the store
-- changes, but the widget keeps showing the deltas against the old one ("new record −0:42").
local _, ns = ...

local Records = {}
ns.InstanceRecords = Records

local function num(v) return type(v) == "number" and v == v end

-- "2999|Normal": instanceID when known (locale-proof), else the dungeon name.
function Records.key(run)
  if not run then return nil end
  local id = run.instanceID
  if id == nil or id == "" then id = run.name end
  if id == nil then return nil end
  return tostring(id) .. "|" .. tostring(run.difficulty or "")
end

local function copy(rec)
  if type(rec) ~= "table" or not num(rec.total) then return nil end
  local splits = {}
  for name, at in pairs(rec.splits or {}) do
    if num(at) then splits[name] = at end
  end
  return { total = rec.total, splits = splits, deaths = rec.deaths, at = rec.at }
end

-- The record of this run's dungeon + difficulty, as a COPY (safe to keep in the run).
function Records.get(store, run)
  local key = Records.key(run)
  if type(store) ~= "table" or not key then return nil end
  return copy(store[key])
end

-- Only a finished, clean run can be a record: every counted boss killed during the run,
-- none of them already dead when it started (preKilled), each with its split.
function Records.eligible(run)
  if not run or not run:isFinished() then return false end
  local counted = 0
  for _, b in ipairs(run.bosses) do
    if not b.rare then
      if b.preKilled or not b.killed or not num(b.killedAt) then return false end
      counted = counted + 1
    end
  end
  return counted > 0
end

-- The record a run would leave: its time and the split of every counted boss.
function Records.fromRun(run)
  local splits = {}
  for _, b in ipairs(run.bosses) do
    if not b.rare and num(b.killedAt) then splits[b.name] = b.killedAt end
  end
  return { total = run:elapsed(), splits = splits, deaths = run.deaths or 0, at = run.startedAt }
end

-- consider(store, run) -> true if the run became the new record (first clean run, or faster).
function Records.consider(store, run)
  if type(store) ~= "table" or not Records.eligible(run) then return false end
  local key = Records.key(run)
  if not key then return false end
  local rec = Records.fromRun(run)
  if rec.total <= 0 then return false end
  local old = store[key]
  if type(old) == "table" and num(old.total) and old.total <= rec.total then return false end
  store[key] = rec
  return true
end

-- learnTrash(store, run) -> true if the dungeon's trash total grew (F4c). FDJ ships no totals: it
-- learns them as max(total, kills) from completed runs (RunLog.lua:498-503); we do the same, but
-- only from CLEAN runs (Records.eligible), keyed by instanceID: trash does not change with the
-- difficulty. store = db.instanceTracker.trash.
function Records.learnTrash(store, run)
  if type(store) ~= "table" or not Records.eligible(run) then return false end
  local id, n = run.instanceID, run.trash
  if not num(id) or not num(n) or n <= 0 then return false end
  local old = store[id]
  if num(old) and old >= n then return false end
  store[id] = n
  return true
end

return Records
