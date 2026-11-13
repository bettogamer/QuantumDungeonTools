---@diagnostic disable: undefined-global
-- modules/InstanceTracker/wow/Tracker.lua -- WoW integration of the Instance Tracker.
--
-- Reads the game (instance, lockout boss list, ENCOUNTER_END, XP), feeds the pure Run model
-- (core/Run.lua), persists it in QuantumDungeonToolsDB.instanceTracker and notifies listeners
-- (the UI). Facts this relies on (measured in WoW Forever, docs/00-contexto-sesion-origen.md):
--   * GetInstanceLockTimeRemaining() -> _, _, total, killed   (works in Normal too)
--   * GetInstanceLockTimeRemainingEncounter(i) -> name, texture, isKilled
--   * There is NO player position inside instances: this module never asks for it.
--   * The castGUID of the player's own spells (UNIT_SPELLCAST_SENT) is public inside
--     instances and carries the zoneUID of the COPY ("Cast-3-server-instanceID-zoneUID-...");
--     the GUIDs of target/mouseover/nameplates are secret there. It tells the leader's copy
--     from ours after joining a group, and a reset from a re-entry.
-- WoW Forever runs the 12.1.5 engine (secret values): every game value goes through
-- issecretvalue FIRST, and API calls go through pcall.
local _, ns = ...
local Run = ns.InstanceRun
local Records = ns.InstanceRecords
local Guid = ns.InstanceGuid
local issecretvalue = ns.issecretvalue

-- copyPending: we re-entered the instance of an existing run and do not know yet whether it
-- is the same copy; the lockout is not merged until the first cast tells us (it may belong
-- to the leader's copy, not to this run).
local T = { listeners = {}, inInstance = false, copyPending = false }
ns.InstanceTracker = T

local HISTORY_MAX = 100
local REFRESH_DELAY = 2   -- seconds after a kill before re-reading the lockout
local RESUME_WINDOW = 30 * 60   -- away longer than this = a new copy (owner, plan M1 point 6)

local deps = {
  now = function() return time() end,
  isSecret = issecretvalue,
  -- Route order and rare flag from the dungeon table; `learned` (name -> encounterID, from
  -- ENCOUNTER_END) covers other locales and names the table gets wrong.
  resolve = function(instanceID, name)
    local learned = ns.db and ns.db.instanceTracker and ns.db.instanceTracker.learned
    return ns.InstanceDungeons.find(instanceID, name, learned)
  end,
}

------------------------------------------------------------------------------
-- Safe readers (secret guard first, then pcall'd probe)
------------------------------------------------------------------------------
local function scrubNum(v)
  if issecretvalue(v) then return nil end
  if v == nil then return nil end
  local ok, n = pcall(function() return v + 0 end)
  if ok then return n end
end

local function safeStr(v)
  if issecretvalue(v) then return nil end
  if type(v) == "string" and v ~= "" then return v end
end

local function db() return ns.db.instanceTracker end

-- { instanceID, name, difficulty } when inside a 5-man or raid instance, else nil.
local function currentInstance()
  local ok, name, itype, _, diffName, _, _, _, instanceID = pcall(GetInstanceInfo)
  if not ok or issecretvalue(itype) then return nil end
  if itype ~= "party" and itype ~= "raid" then return nil end
  instanceID = scrubNum(instanceID)
  if not instanceID then return nil end
  return { instanceID = instanceID, name = safeStr(name) or "?", difficulty = safeStr(diffName) or "" }
end

-- Lockout boss list of the CURRENT instance, or nil when the game has none (yet).
local function readBosses()
  if not GetInstanceLockTimeRemaining or not GetInstanceLockTimeRemainingEncounter then return nil end
  local ok, _, _, total = pcall(GetInstanceLockTimeRemaining)
  total = ok and scrubNum(total) or nil
  if not total or total <= 0 then return nil end
  local list = {}
  for i = 1, total do
    local ok2, name, _, killed = pcall(GetInstanceLockTimeRemainingEncounter, i)
    name = ok2 and safeStr(name) or nil
    if name then
      if issecretvalue(killed) then killed = false end
      list[#list + 1] = { name = name, killed = killed == true }
    end
  end
  if #list == 0 then return nil end
  return list
end

local function readXP()
  local xp, max, level = scrubNum(UnitXP("player")), scrubNum(UnitXPMax("player")), scrubNum(UnitLevel("player"))
  if xp and max and level then return { xp = xp, max = max, level = level } end
end

-- Max level of this character: the retail API first, the classic one as fallback (Forever has
-- not been measured for either: both under pcall, nil when neither answers).
local function maxLevel()
  local fns = { GetMaxLevelForPlayerExpansion or false, GetMaxPlayerLevel or false }   -- no nil holes
  for _, fn in ipairs(fns) do
    if fn then
      local ok, v = pcall(fn)
      v = ok and scrubNum(v) or nil
      if v and v > 0 then return v end
    end
  end
end

-- XP snapshot for the widget: { level, xp, max, rested, atMax } (plain numbers) or nil.
function T:XPSnapshot()
  local cur = readXP()
  if not cur then return nil end
  local rested
  if GetXPExhaustion then
    local ok, v = pcall(GetXPExhaustion)
    rested = ok and scrubNum(v) or nil
  end
  local cap = maxLevel()
  local disabled = false
  if IsXPUserDisabled then
    local ok, v = pcall(IsXPUserDisabled)
    disabled = ok and not issecretvalue(v) and v == true
  end
  cur.rested = rested or 0
  cur.atMax = disabled or (cap ~= nil and cur.level >= cap) or cur.max <= 0
  return cur
end

local function requestLockout()
  if RequestRaidInfo then pcall(RequestRaidInfo) end
end

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------
function T:OnChange(fn) self.listeners[#self.listeners + 1] = fn end

-- Persist + archive a finished run + tell the listeners. reason: "zone" | "data" | "tick".
function T:_notify(reason)
  local run = self.run
  if run and run:isFinished() and not run.archived then
    run.archived = true
    if Records.consider(db().records, run) then run.newRecord = true end
    self:_pushHistory(run)
  end
  db().current = run and run:toTable() or nil
  for _, fn in ipairs(self.listeners) do
    local ok, err = pcall(fn, reason or "data")
    if not ok then geterrorhandler()(err) end
  end
end

function T:_pushHistory(run)
  local h = db().history
  table.insert(h, 1, run:toTable())
  while #h > HISTORY_MAX do table.remove(h) end
end

-- Closes the current run. Unfinished runs with at least one kill also go to the history
-- (marked as not completed); empty ones are dropped.
function T:_close()
  local run = self.run
  if run then run:close() end
  if run and not run.archived and run:killedCount() > 0 then
    run.archived = true
    self:_pushHistory(run)
  end
  self.run = nil
end

-- A new run races against the record of its dungeon + difficulty as it is NOW (a copy).
local function newRun(inst)
  local run = Run.new(inst, deps)
  run.pb = Records.get(db().records, run)
  return run
end

function T:StartRun(inst, copy)
  self:_close()
  self.run = newRun(inst)
  self.copyPending = false
  if copy then self.run:observeCopy(copy) end
  self:Refresh()
end

-- Re-reads the lockout of the current instance and merges it into the run.
function T:Refresh()
  local run = self.run
  if run and self.inInstance and not self.copyPending then
    local list = readBosses()
    if list then
      if run:lockoutWasReset(list) then
        local inst = { instanceID = run.instanceID, name = run.name, difficulty = run.difficulty }
        self:_close()
        self.run = newRun(inst)
        run = self.run
      end
      run:setBosses(list)
    end
  end
  self:_notify("data")
end

function T:CheckZone()
  local inst = currentInstance()
  self.inInstance = inst ~= nil
  local run = self.run
  if inst then
    if not run or not run:canResume(inst, RESUME_WINDOW) then
      self:StartRun(inst)
    else
      -- Same dungeon again: resume the clock; same copy or not is confirmed by the first
      -- cast (_onCast), which starts a new run if it is another copy.
      run:resume()
      self.copyPending = run.copy ~= nil
      self:Refresh()
    end
    requestLockout()   -- the answer (UPDATE_INSTANCE_INFO) refreshes again
  elseif run then
    run:pause()        -- outside: the clock stops until we come back
  end
  self:_notify("zone")
end

-- /qdt new: forget the current run and start over (inside an instance) or just close it.
function T:NewRun()
  local inst = currentInstance()
  self.inInstance = inst ~= nil
  if inst then
    self:StartRun(inst)
  else
    self:_close()
    self:_notify("data")
  end
end

function T:History() return db().history end

-- A castGUID of the player inside the instance: which copy is this?
function T:_onCast(castGUID)
  if issecretvalue(castGUID) or type(castGUID) ~= "string" then return end
  local run = self.run
  if not run or not self.inInstance then return end
  local g = Guid.parse(castGUID)
  if not g or g.type ~= "Cast" or g.instanceID ~= run.instanceID then return end
  local seen = run:observeCopy(g.zoneUID)
  if seen == "other" then
    -- Another copy of this dungeon (the group leader's, or a reset): new run. The old one
    -- goes to the history only if it had kills (_close).
    self:StartRun({ instanceID = run.instanceID, name = run.name, difficulty = run.difficulty }, g.zoneUID)
    requestLockout()
  elseif seen ~= nil and self.copyPending then
    self.copyPending = false
    self:Refresh()
  elseif seen == "first" then
    self:_notify("data")
  end
end

------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------
function T:PLAYER_ENTERING_WORLD() self:CheckZone() end

-- Deaths only count inside the instance, while the run is live (Run:addDeath guards the rest).
function T:PLAYER_DEAD()
  if self.run and self.inInstance and self.run:addDeath() then self:_notify("data") end
end
function T:ZONE_CHANGED_NEW_AREA() self:CheckZone() end
function T:UPDATE_INSTANCE_INFO() self:Refresh() end

-- Logging out (or /reload) inside the instance: pause, so the time offline never counts.
-- On login PLAYER_ENTERING_WORLD -> CheckZone resumes it (or starts a new run).
function T:PLAYER_LOGOUT()
  local run = self.run
  if run and run:pause() then db().current = run:toTable() end
end

local function bossDied(name)
  local run = T.run
  if run and T.inInstance and run:markKilled(safeStr(name)) then T:_notify("data") end
  C_Timer.After(REFRESH_DELAY, function()
    requestLockout()
    T:Refresh()
  end)
end

-- Remembers name -> encounterID when the table knows that ID (persisted, locale-proof).
local function learn(encounterID, encounterName)
  local id, name = scrubNum(encounterID), safeStr(encounterName)
  if not id or not name or not ns.InstanceDungeons.forEncounter(id) then return end
  local d = db()
  d.learned = d.learned or {}
  if d.learned[name] ~= id then
    d.learned[name] = id
    if T.run then T.run:reclassify() end
  end
end

-- ENCOUNTER_END: encounterID, encounterName, difficultyID, groupSize, success
function T:ENCOUNTER_END(encounterID, encounterName, _, _, success)
  if issecretvalue(success) or success ~= 1 then return end
  learn(encounterID, encounterName)
  bossDied(encounterName)
end

-- BOSS_KILL: encounterID, encounterName (may not exist in every client: registered with pcall)
function T:BOSS_KILL(_, encounterName) bossDied(encounterName) end

-- CHAT_MSG_SYSTEM "<instance> has been reset." (INSTANCE_RESET_SUCCESS, measured in Forever):
-- the next entry is a new copy, so the run of that dungeon ends here. It also covers runs saved
-- without a copy (castGUID) and members who reset without casting afterwards.
function T:CHAT_MSG_SYSTEM(text)
  local run = self.run
  if not run then return end
  local name = Run.resetName(INSTANCE_RESET_SUCCESS, text, issecretvalue)
  if name and name == run.name then
    self:_close()
    self.copyPending = false
    self:_notify("data")
  end
end

-- UNIT_SPELLCAST_SENT: unit, target, castGUID, spellID (only fires for the player)
function T:UNIT_SPELLCAST_SENT(unit, _, castGUID)
  if issecretvalue(unit) or unit ~= "player" then return end
  self:_onCast(castGUID)
end

-- XP is sampled, not trusted to one event: in WoW Forever PLAYER_XP_UPDATE never fired during
-- a whole dungeon at level 26 (Ruins of Lordaeron, 2026-11-13). Every sample adds the delta
-- since the previous one, so extra samples are harmless.
function T:SampleXP()
  local cur = readXP()
  local prev = self.xpPrev
  self.xpPrev = cur
  local run = self.run
  if cur and prev and run and self.inInstance and run:addXP(Run.xpDelta(prev, cur)) then
    self:_notify("data")
  end
end

function T:PLAYER_XP_UPDATE(unit)
  if issecretvalue(unit) or (unit ~= nil and unit ~= "player") then return end
  self:SampleXP()
end
function T:CHAT_MSG_COMBAT_XP_GAIN() self:SampleXP() end
function T:PLAYER_LEVEL_UP() C_Timer.After(1, function() T:SampleXP() end) end
function T:PLAYER_REGEN_ENABLED() self:SampleXP() end
function T:QUEST_TURNED_IN() C_Timer.After(1, function() T:SampleXP() end) end

local EVENTS = {
  "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UPDATE_INSTANCE_INFO",
  "ENCOUNTER_END", "BOSS_KILL", "PLAYER_XP_UPDATE", "CHAT_MSG_COMBAT_XP_GAIN",
  "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "QUEST_TURNED_IN", "UNIT_SPELLCAST_SENT",
  "CHAT_MSG_SYSTEM", "PLAYER_LOGOUT", "PLAYER_DEAD",
}

local frame
function T:Init()
  local saved = db().current
  if saved then self.run = Run.fromTable(saved, deps) end
  self.xpPrev = readXP()

  frame = frame or CreateFrame("Frame")
  for _, ev in ipairs(EVENTS) do
    pcall(frame.RegisterEvent, frame, ev)   -- unknown event in this client: skip, do not break
  end
  frame:SetScript("OnEvent", function(_, event, ...)
    local handler = T[event]
    if not handler then return end
    local ok, err = pcall(handler, T, ...)
    if not ok then geterrorhandler()(err) end
  end)
end
