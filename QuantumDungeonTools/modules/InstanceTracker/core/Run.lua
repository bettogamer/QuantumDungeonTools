-- modules/InstanceTracker/core/Run.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- One "run" = one pass through a dungeon instance: its bosses (killed or not, and WHEN, as a
-- split relative to the start), the elapsed time and the XP gained. The wow/ layer feeds it
-- (lockout list, ENCOUNTER_END, XP deltas) and persists it with toTable()/fromTable().
--
-- Injected deps (never called from WoW directly):
--   now()        -> seconds (the wow/ layer passes `time()`: survives /reload and relog)
--   isSecret(v)  -> boolean (issecretvalue)
--   resolve(instanceID, name) -> { order, rare } | nil   (core/Dungeons.find + learned IDs)
--
-- With a resolver the list follows the ROUTE (data order; unknown names after, in arrival
-- order; rares last) and rares never count for total()/killedCount()/the end of the run.
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
  "listKnown", "xp", "degraded", "archived", "endedAt", "lockKilled", "copy",
  "pausedAt", "pausedTotal", "deaths", "pb", "newRecord", "copper", "group", "levels", "trash",
  "char", "waiting", "clockAt",
}

-- A kill (PARTY_KILL) and a boss event this close are the same death (ForeverDungeonJournal
-- merges its kill sources in the same window, RunLog.lua MERGE_WINDOW).
Run.MERGE_WINDOW = 3

-- info = { instanceID = number, name = string, difficulty = string }
function Run.new(info, deps)
  info, deps = info or {}, deps or {}
  local self = setmetatable({}, Run)
  self._now = deps.now or defaultNow
  self._isSecret = deps.isSecret or never
  self._resolve = deps.resolve
  self._seq = 0
  self.instanceID = info.instanceID
  self.name = info.name or "?"
  self.difficulty = info.difficulty or ""
  self.startedAt = self._now()
  self.finishedAt = nil
  self.bosses = {}        -- ordered: { name, killed, killedAt (split, seconds) | nil, preKilled,
                          --            order | nil, rare | nil, kind | nil, seq }
                          -- rare = does not count; kind = "optional" | "quest" | nil (docs/16)
  self.listKnown = false  -- true once the full boss list came from the lockout
  self.xp = 0
  self.levels = 0         -- levels gained during the run (artboard Completada: "· 1 nivel")
  self.degraded = 0       -- values dropped because they were secret
  self.archived = false   -- already copied to the history
  self.lockKilled = 0     -- most kills the LOCKOUT itself has reported (not the events)
  self.copy = nil         -- zoneUID of the instance COPY (from the player's castGUIDs)
  self.pausedAt = nil     -- set while the player is outside the instance (or logged out)
  self.pausedTotal = 0    -- seconds spent paused; they never count for the clock
  self.deaths = 0         -- player deaths inside the instance during the run
  self.pb = nil           -- the record this run races against (core/Records.lua copy), set at start
  self.copper = 0         -- money the player looted during the run (F4)
  self.rep = {}           -- reputation gained during the run: { [factionName] = amount } (F4)
  self.group = nil        -- signature of the party (Detail.groupKey), last seen while live (F4b)
  self.trash = 0          -- non-boss kills of the group during the run (F4c, PARTY_KILL)
  self.char = info.char   -- "Name-Realm" of the player who ran it (F6; older runs: nil)
  -- The clock starts at the first combat inside, not at the door (waiting for the group does
  -- not count; owner 2026-11-20). info.waitCombat opts in (wow/Tracker always does): waiting =
  -- true until then; clockAt = when it started. Runs saved before this have neither and keep
  -- counting from startedAt.
  self.waiting = info.waitCombat == true or nil
  self.clockAt = nil
  return self
end

------------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------------
-- Bosses that count (rares are listed but never count).
function Run:total()
  local n = 0
  for _, b in ipairs(self.bosses) do
    if not b.rare then n = n + 1 end
  end
  return n
end

function Run:killedCount()
  local n = 0
  for _, b in ipairs(self.bosses) do
    if b.killed and not b.rare then n = n + 1 end
  end
  return n
end

function Run:isFinished() return self.finishedAt ~= nil end

-- Seconds played: since the clock started (first combat; startedAt for older runs) minus the
-- pauses; 0 while waiting; frozen once the run is finished, closed unfinished or paused.
function Run:elapsed()
  if self.waiting then return 0 end
  local stop = self.finishedAt or self.endedAt or self.pausedAt or self._now()
  local e = stop - (self.clockAt or self.startedAt or 0) - (self.pausedTotal or 0)
  if e < 0 then return 0 end
  return e
end

function Run:isWaiting() return self.waiting == true end

-- startClock(): first combat (or first kill) inside. Pauses before it do not count either.
-- Returns true when the clock started now.
function Run:startClock()
  if not self.waiting or self.endedAt or self.pausedAt then return false end
  self.waiting = nil
  self.clockAt = self._now()
  self.pausedTotal = 0
  return true
end

------------------------------------------------------------------------------
-- Internals
------------------------------------------------------------------------------
function Run:_find(name)
  for _, b in ipairs(self.bosses) do
    if b.name == name then return b end
  end
end

function Run:_add(name)
  self._seq = self._seq + 1
  local b = { name = name, killed = false, seq = self._seq }
  self:_classify(b)
  self.bosses[#self.bosses + 1] = b
  return b
end

-- Fills order/rare from the resolver once (a name it does not know stays unknown until a
-- later call, e.g. after the wow/ layer learned its encounterID).
function Run:_classify(b)
  if b.order or not self._resolve then return false end
  local ok, info = pcall(self._resolve, self.instanceID, b.name)
  if not ok or type(info) ~= "table" or type(info.order) ~= "number" then return false end
  b.order = info.order
  b.rare = info.rare == true or nil
  b.kind = info.kind
  return true
end

-- Route order: known bosses by data order, then unknown ones by arrival, then rares.
local function sortKey(b)
  if b.rare then return 3, b.order or 0 end
  if b.order then return 1, b.order end
  return 2, 0
end

function Run:_sort()
  table.sort(self.bosses, function(a, b)
    local ga, oa = sortKey(a)
    local gb, ob = sortKey(b)
    if ga ~= gb then return ga < gb end
    if oa ~= ob then return oa < ob end
    return (a.seq or 0) < (b.seq or 0)
  end)
end

-- reclassify(): resolve the bosses still unknown and re-sort. Returns true if any changed.
function Run:reclassify()
  local changed = false
  for _, b in ipairs(self.bosses) do
    if self:_classify(b) then changed = true end
  end
  if changed then self:_sort() end
  return changed
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
        b = self:_add(name)
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
  self:_sort()
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
    b = self:_add(name)
  elseif b.killed then
    return false
  end
  self:_classify(b)
  self:_sort()
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

-- observeCopy(zoneUID): the copy the player is in, read from one of their own castGUIDs.
-- Returns "first" (the run adopts it), "same", "other" (another copy of the same dungeon:
-- joined a group and entered the leader's copy, or a reset) or nil (unusable value).
function Run:observeCopy(zoneUID)
  if self._isSecret(zoneUID) then
    self.degraded = self.degraded + 1
    return nil
  end
  if type(zoneUID) ~= "string" or zoneUID == "" then return nil end
  if self.copy == nil then
    self.copy = zoneUID
    return "first"
  end
  if self.copy == zoneUID then return "same" end
  return "other"
end

-- close(): the run is abandoned (new run, instance reset). Freezes its clock without
-- marking it finished, so the history shows the time actually played (a paused run ends
-- when it was paused: the time outside never counts).
function Run:close()
  if not self.finishedAt and not self.endedAt then self.endedAt = self.pausedAt or self._now() end
  self.closed = true   -- a finished run has no endedAt: this stops the money/rep counting too
end

-- addDeath(): the player died inside. Not counted once the run is finished, closed or paused.
function Run:addDeath()
  if self.finishedAt or self.endedAt or self.pausedAt then return false end
  self.deaths = (self.deaths or 0) + 1
  return true
end

-- Money and reputation keep counting after the last boss (its loot and its rep arrive a moment
-- later), but not while paused or once the run is closed.
local function collecting(self) return not self.endedAt and not self.pausedAt and not self.closed end

function Run:addMoney(copper)
  if not collecting(self) or type(copper) ~= "number" or copper ~= copper or copper <= 0 then return false end
  self.copper = (self.copper or 0) + copper
  return true
end

function Run:addRep(faction, amount)
  if not collecting(self) or type(faction) ~= "string" or faction == "" then return false end
  if type(amount) ~= "number" or amount ~= amount or amount == 0 then return false end
  self.rep = self.rep or {}
  self.rep[faction] = (self.rep[faction] or 0) + amount
  return true
end

-- Reputation as a list sorted by amount (largest gain first): { { name, amount } }.
function Run:repList()
  local list = {}
  for name, n in pairs(self.rep or {}) do
    if n ~= 0 then list[#list + 1] = { name = name, amount = n } end
  end
  table.sort(list, function(a, b)
    if a.amount ~= b.amount then return a.amount > b.amount end
    return a.name < b.name
  end)
  return list
end

-- Trash (F4c). Inside a dungeon PARTY_KILL does not say WHO died (secret GUID), so every kill of
-- the group counts, minus the ones a boss event claims within MERGE_WINDOW (either order). The
-- pairing state lives only in memory: a /reload in the middle of a pull may miscount one kill.
function Run:addKill()
  if self.finishedAt or self.endedAt or self.pausedAt or self.closed then return false end
  local now = self._now()
  if self._bossAt and now - self._bossAt <= Run.MERGE_WINDOW and not self._bossPaired then
    self._bossPaired = true   -- the killing blow of the boss that just died
    return false
  end
  self.trash = (self.trash or 0) + 1
  self._killAt = now
  return true
end

-- noteBossDeath(): a boss event (ENCOUNTER_END / BOSS_KILL) arrived. Call it BEFORE markKilled
-- (the last boss finishes the run). Two events of the same death count once.
function Run:noteBossDeath()
  if self.endedAt or self.closed then return false end
  local now = self._now()
  if self._bossAt and now - self._bossAt <= Run.MERGE_WINDOW then return false end
  self._bossAt, self._bossPaired = now, false
  if self._killAt and now - self._killAt <= Run.MERGE_WINDOW and (self.trash or 0) > 0 then
    self.trash = self.trash - 1
    self._killAt, self._bossPaired = nil, true
    return true
  end
  return false
end

-- Seconds spent outside the instance during the run (corpse runs, a step outside, logged out):
-- the closed pauses plus the open one, if the run is still running.
function Run:awayTime()
  if self.waiting then return 0 end   -- before the clock starts, being outside costs nothing
  local t = self.pausedTotal or 0
  if self.pausedAt and not self.finishedAt and not self.endedAt then
    t = t + math.max(0, self._now() - self.pausedAt)
  end
  return t
end

function Run:isPaused() return self.pausedAt ~= nil end

-- pause(): the player left the instance (or logged out). Idempotent; no-op once closed.
-- A FINISHED run also records when it was left (canResume needs it), but its clock is
-- already frozen at finishedAt, so its pauses never touch it.
function Run:pause()
  if self.endedAt or self.pausedAt then return false end
  self.pausedAt = self._now()
  return true
end

-- resume(): back in the same copy; the paused time is discounted from the clock.
function Run:resume()
  if not self.pausedAt then return false end
  local away = self._now() - self.pausedAt
  if away > 0 and not self.finishedAt then self.pausedTotal = (self.pausedTotal or 0) + away end
  self.pausedAt = nil
  return true
end

-- canResume(info, window, finishedWindow): re-entering an instance with this run open, is it
-- (most likely) the same copy? Same instanceID and difficulty, still running, and paused for at
-- most `window` seconds (`finishedWindow` instead once every counted boss is dead; owner plan M1
-- point 8a: 90 / 20 min, as ForeverDungeonJournal). A finished run also "resumes" (it keeps
-- showing as completed: /reload, a step outside). The window is generous on purpose: the
-- castGUID of the first spell has the last word (wow/Tracker) and starts a new run if it is
-- another copy; a reset message closes the run before this.
-- An EMPTY difficulty on either side does not block: on the first PLAYER_ENTERING_WORLD of a
-- dungeon GetInstanceInfo may not have it yet ("" in Deadmines, owner 2026-11-13), and after a
-- /reload it says "Normal": comparing them started a new run and lost the kills.
function Run:canResume(info, window, finishedWindow)
  if type(info) ~= "table" or self.endedAt then return false end
  if info.instanceID ~= self.instanceID then return false end
  local a, b = info.difficulty or "", self.difficulty or ""
  if a ~= "" and b ~= "" and a ~= b then return false end
  if self.finishedAt and finishedWindow then window = finishedWindow end
  if self.pausedAt and window and self._now() - self.pausedAt > window then return false end
  return true
end

-- fillDifficulty(d): the run was created before the game knew its difficulty; take it now.
-- Only fills an empty one (a known difficulty never changes inside a run). Returns true if set.
function Run:fillDifficulty(d)
  if self._isSecret(d) or type(d) ~= "string" or d == "" or (self.difficulty or "") ~= "" then
    return false
  end
  self.difficulty = d
  return true
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

function Run:addLevels(n)
  if self._isSecret(n) or type(n) ~= "number" or n <= 0 then return false end
  self.levels = (self.levels or 0) + n
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
    out[i] = { name = b.name, killed = b.killed, killedAt = b.killedAt, preKilled = b.preKilled,
               order = b.order, rare = b.rare, kind = b.kind, seq = b.seq or i }
  end
  return out
end

-- Run.resetName(fmt, text): the instance name in a reset system message, or nil.
-- fmt = INSTANCE_RESET_SUCCESS ("%s has been reset." in enUS, localized in other clients).
function Run.resetName(fmt, text, isSecret)
  isSecret = isSecret or never
  if isSecret(fmt) or isSecret(text) then return nil end
  if type(fmt) ~= "string" or type(text) ~= "string" or not fmt:find("%s", 1, true) then return nil end
  local pattern = fmt:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
  pattern = pattern:gsub("%%s", "(.+)", 1)
  return text:match("^" .. pattern .. "$")
end

local function copyRep(rep)
  if type(rep) ~= "table" then return nil end
  local out = {}
  for k, v in pairs(rep) do out[k] = v end
  return out
end

local function copyPB(pb)
  if type(pb) ~= "table" then return nil end
  local splits = {}
  for k, v in pairs(pb.splits or {}) do splits[k] = v end
  return { total = pb.total, splits = splits, deaths = pb.deaths, at = pb.at }
end

function Run:toTable()
  local t = {}
  for _, k in ipairs(FIELDS) do t[k] = self[k] end
  t.bosses = copyBosses(self.bosses)
  t.pb = copyPB(self.pb)
  t.rep = copyRep(self.rep)
  return t
end

function Run.fromTable(t, deps)
  if type(t) ~= "table" then return nil end
  local self = Run.new(nil, deps)   -- not waiting: only a run SAVED waiting is (older ones count from startedAt)
  for _, k in ipairs(FIELDS) do
    if t[k] ~= nil then self[k] = t[k] end
  end
  self.bosses = copyBosses(t.bosses)
  self.pb = copyPB(t.pb)
  self.rep = copyRep(t.rep) or {}
  self._seq = #self.bosses
  for _, b in ipairs(self.bosses) do
    if b.seq > self._seq then self._seq = b.seq end
  end
  -- Saved before the dungeon table existed: classify now. The end of the run is NOT
  -- re-checked here (its time would be the load time, not the kill).
  self:reclassify()
  return self
end

return Run
