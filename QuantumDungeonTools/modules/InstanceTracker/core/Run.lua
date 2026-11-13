-- modules/InstanceTracker/core/Run.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- One "run" = one pass through a dungeon instance: its bosses (killed or not, and WHEN, as a
-- split relative to the start), the elapsed time and the XP gained. The wow/ layer feeds it
-- (lockout list, ENCOUNTER_END, XP deltas) and persists it with toTable()/fromTable().
--
-- Injected deps (never called from WoW directly):
--   now()        -> seconds (the wow/ layer passes `time()`: survives /reload and relog)
--   isSecret(v)  -> boolean (issecretvalue)
-- Every value that comes from the game is checked with isSecret BEFORE any other test.
local _, ns = ...

local Run = {}
Run.__index = Run
ns.InstanceRun = Run

local function defaultNow() return 0 end
local function never() return false end

-- Fields persisted by toTable()/fromTable() (bosses are copied apart).
local FIELDS = {
  "instanceID", "name", "difficulty", "startedAt", "finishedAt",
  "listKnown", "xp", "degraded", "archived", "endedAt", "lockKilled",
}

-- info = { instanceID = number, name = string, difficulty = string }
function Run.new(info, deps)
  info, deps = info or {}, deps or {}
  local self = setmetatable({}, Run)
  self._now = deps.now or defaultNow
  self._isSecret = deps.isSecret or never
  self.instanceID = info.instanceID
  self.name = info.name or "?"
  self.difficulty = info.difficulty or ""
  self.startedAt = self._now()
  self.finishedAt = nil
  self.bosses = {}        -- ordered: { name, killed, killedAt (split, seconds) | nil, preKilled }
  self.listKnown = false  -- true once the full boss list came from the lockout
  self.xp = 0
  self.degraded = 0       -- values dropped because they were secret
  self.archived = false   -- already copied to the history
  self.lockKilled = 0     -- most kills the LOCKOUT itself has reported (not the events)
  return self
end

------------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------------
function Run:total() return #self.bosses end

function Run:killedCount()
  local n = 0
  for _, b in ipairs(self.bosses) do
    if b.killed then n = n + 1 end
  end
  return n
end

function Run:isFinished() return self.finishedAt ~= nil end

-- Seconds since the start; frozen once the run is finished (or closed unfinished).
function Run:elapsed()
  local e = (self.finishedAt or self.endedAt or self._now()) - (self.startedAt or 0)
  if e < 0 then return 0 end
  return e
end

------------------------------------------------------------------------------
-- Internals
------------------------------------------------------------------------------
function Run:_find(name)
  for _, b in ipairs(self.bosses) do
    if b.name == name then return b end
  end
end

-- Guard order: isSecret FIRST, then any truth test (see CLAUDE.md global).
function Run:_validName(name)
  if self._isSecret(name) then
    self.degraded = self.degraded + 1
    return false
  end
  return type(name) == "string" and name ~= ""
end

function Run:_checkFinished()
  if self.finishedAt or not self.listKnown then return false end
  local total = self:total()
  if total > 0 and self:killedCount() == total then
    self.finishedAt = self._now()
    return true
  end
  return false
end

-- Does a lockout list share at least one boss name with the known list? A list with no
-- overlap is stale (it belongs to another instance) and must be ignored.
function Run:_overlaps(list)
  for _, entry in ipairs(list) do
    if not self._isSecret(entry.name) and self:_find(entry.name) then return true end
  end
  return false
end

------------------------------------------------------------------------------
-- Feeding
------------------------------------------------------------------------------

-- setBosses(list): list = { { name = string, killed = boolean }, ... } from the lockout.
-- Merges into the known list keeping order and split times. A boss already dead the first
-- time we see it is "preKilled" (its time is unknown). Returns true if something changed.
function Run:setBosses(list)
  if type(list) ~= "table" or #list == 0 then return false end
  if self.listKnown and not self:_overlaps(list) then return false end

  local firstList = not self.listKnown
  local changed = false
  for _, entry in ipairs(list) do
    local name = entry.name
    if self:_validName(name) then
      local b = self:_find(name)
      if not b then
        b = { name = name, killed = false }
        self.bosses[#self.bosses + 1] = b
        changed = true
        if entry.killed == true then
          b.killed = true
          b.preKilled = firstList or nil
          if not firstList then b.killedAt = self:elapsed() end
        end
      elseif entry.killed == true and not b.killed then
        b.killed = true
        b.killedAt = self:elapsed()
        changed = true
      end
    end
  end
  local reported = 0
  for _, entry in ipairs(list) do
    if entry.killed == true then reported = reported + 1 end
  end
  if reported > (self.lockKilled or 0) then self.lockKilled = reported end
  self.listKnown = true
  if self:_checkFinished() then changed = true end
  return changed
end

-- markKilled(name): a boss died now (ENCOUNTER_END / BOSS_KILL). Idempotent.
-- If the full list is already known and the name is not in it, it is ignored (the next
-- lockout refresh is the source of truth); otherwise the boss is appended.
function Run:markKilled(name)
  if not self:_validName(name) then return false end
  local b = self:_find(name)
  if not b then
    if self.listKnown then return false end
    b = { name = name, killed = false }
    self.bosses[#self.bosses + 1] = b
  elseif b.killed then
    return false
  end
  b.killed = true
  b.killedAt = self:elapsed()
  self:_checkFinished()
  return true
end

-- The instance was reset (new copy, same instanceID) if the lockout reports FEWER kills than
-- it reported itself before, for a list that is really ours (shares names). It compares with
-- the lockout's own count, never with kills seen by event: in a Normal dungeon of WoW Forever
-- the lockout may never mark a boss as killed, and comparing with event kills wiped every
-- kill 2 s later (bug seen in Ruins of Lordaeron, 2026-11-13).
function Run:lockoutWasReset(list)
  if type(list) ~= "table" or #list == 0 or not self.listKnown then return false end
  if not self:_overlaps(list) then return false end
  local killed = 0
  for _, entry in ipairs(list) do
    if entry.killed == true then killed = killed + 1 end
  end
  return killed < (self.lockKilled or 0)
end

-- close(): the run is abandoned (new run, instance reset). Freezes its clock without
-- marking it finished, so the history shows the time actually played.
function Run:close()
  if not self.finishedAt and not self.endedAt then self.endedAt = self._now() end
end

function Run:addXP(n)
  if self._isSecret(n) then
    self.degraded = self.degraded + 1
    return false
  end
  if type(n) ~= "number" or n <= 0 then return false end
  self.xp = self.xp + n
  return true
end

-- xpDelta(prev, cur): XP gained between two snapshots { xp, max, level }, across a level-up.
-- Snapshots come already scrubbed (plain numbers) from the wow/ layer.
function Run.xpDelta(prev, cur)
  if type(prev) ~= "table" or type(cur) ~= "table" then return 0 end
  if cur.level == prev.level then
    return math.max(0, cur.xp - prev.xp)
  elseif cur.level == prev.level + 1 then
    return math.max(0, (prev.max - prev.xp) + cur.xp)
  end
  return 0  -- jump of several levels or level down: unknowable, do not invent
end

------------------------------------------------------------------------------
-- Persistence
------------------------------------------------------------------------------
local function copyBosses(src)
  local out = {}
  for i, b in ipairs(src or {}) do
    out[i] = { name = b.name, killed = b.killed, killedAt = b.killedAt, preKilled = b.preKilled }
  end
  return out
end

function Run:toTable()
  local t = {}
  for _, k in ipairs(FIELDS) do t[k] = self[k] end
  t.bosses = copyBosses(self.bosses)
  return t
end

function Run.fromTable(t, deps)
  if type(t) ~= "table" then return nil end
  local self = Run.new(nil, deps)
  for _, k in ipairs(FIELDS) do
    if t[k] ~= nil then self[k] = t[k] end
  end
  self.bosses = copyBosses(t.bosses)
  return self
end

return Run
