---@diagnostic disable: undefined-global
-- modules/InstanceTracker/wow/CheckF1.lua -- `/qdt check f1`: Forever probes (plan M1, F1).
--
-- MEASURES what F2-F5 take for granted and dumps it to QuantumDungeonToolsDB._checkF1, which
-- the agent reads with scripts/read-check-f1.lua (never by hand). It changes nothing else.
--   * snapshot (manual or automatic): instance info, lockout totals, EVERY return value of
--     GetInstanceLockTimeRemainingEncounter(i) (the 4th boolean), saved instances, GUIDs of
--     target/mouseover/boss1 split into fields (zoneUID).
--   * static: presence and text of the localized globals (money, faction, reset, 10/hour),
--     validity of the events F4/F5 need, presence of the APIs.
--   * passive log (armed by the first `/qdt check f1`, survives /reload, `off` disarms it):
--     zoneUIDs seen on target/mouseover inside instances, chat money/faction/system lines,
--     UI errors, encounter events; an automatic snapshot on entering an instance, on pull and
--     a few seconds after each kill (so the isKilled question needs no manual timing).
-- Every value is encoded through issecretvalue FIRST ("SECRET"), every call goes through pcall.
-- Never measures nameplates (GetCenter throws on restricted regions, global doc).
local _, ns = ...
local L = ns.L
local Guid = ns.InstanceGuid
local issecretvalue = ns.issecretvalue

local C = {}
ns.CheckF1 = C

local FORMAT = 1
local SNAPSHOT_MAX = 80
local LOG_MAX = 600   -- a whole dungeon run (owner cannot /reload mid-run)
local ZONE_MAX = 60
local GLOBAL_SCAN_MAX = 200
local ENCOUNTER_MAX = 20
local SAVED_MAX = 20
local AFTER_KILL_DELAY = 4   -- seconds: after Tracker's own RequestRaidInfo (2 s)

local UNITS = { "target", "mouseover", "boss1" }

local GLOBALS = {
  "GOLD_AMOUNT", "SILVER_AMOUNT", "COPPER_AMOUNT",
  "GOLD_AMOUNT_TEXTURE", "SILVER_AMOUNT_TEXTURE", "COPPER_AMOUNT_TEXTURE",
  "YOU_LOOT_MONEY", "LOOT_MONEY", "LOOT_MONEY_SPLIT", "LOOT_MONEY_SPLIT_GUILD",
  "FACTION_STANDING_INCREASED", "FACTION_STANDING_INCREASED_GENERIC",
  "FACTION_STANDING_INCREASED_BONUS", "FACTION_STANDING_INCREASED_DOUBLE_BONUS",
  "FACTION_STANDING_INCREASED_ACH_BONUS", "FACTION_STANDING_DECREASED",
  "FACTION_STANDING_DECREASED_GENERIC",
  "INSTANCE_RESET_SUCCESS", "INSTANCE_RESET_FAILED", "INSTANCE_RESET_FAILED_OFFLINE",
  "INSTANCE_RESET_FAILED_ZONING", "ERR_TOO_MANY_INSTANCES", "TOO_MANY_INSTANCES",
  "INSTANCE_SAVED", "ERR_INSTANCE_LIMIT",
}

-- Name patterns for the _G scan (catches spellings the list above does not know).
local NAME_PATTERNS = {
  "^FACTION_STANDING_", "^INSTANCE_RESET", "INSTANCES", "^ERR_.*INSTANCE", "^ERR_.*RESET",
  "LOOT_MONEY", "^GOLD_", "^SILVER_", "^COPPER_",
}
-- Value patterns (lowercase): the 10/hour message in whatever global holds it.
local VALUE_PATTERNS = { "too many instances", "demasiadas instancias", "per hour", "por hora" }

local EVENTS = {
  "CHAT_MSG_MONEY", "CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE",
  "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "UPDATE_INSTANCE_INFO", "PLAYER_DEAD",
  "INSTANCE_BOOT_START", "INSTANCE_LOCK_START", "INSTANCE_LOCK_WARNING", "PLAYER_MONEY",
  "UPDATE_FACTION", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_ENTERING_WORLD",
}

local APIS = {
  "GetInstanceInfo", "GetInstanceLockTimeRemaining", "GetInstanceLockTimeRemainingEncounter",
  "GetNumSavedInstances", "GetSavedInstanceInfo", "RequestRaidInfo", "ResetInstances",
  "CanShowResetInstances", "IsInInstance", "GetMoney", "GetWatchedFactionInfo", "GetFactionInfo",
  "GetNumFactions", "GetDifficultyInfo", "UnitGUID", "issecretvalue", "issecrettable",
  "C_Reputation", "C_MajorFactions",
}

------------------------------------------------------------------------------
-- Encoding (secret guard first)
------------------------------------------------------------------------------
local function enc(v)
  if issecretvalue(v) then return "SECRET" end
  if v == nil then return "nil" end
  local t = type(v)
  if t == "string" or t == "number" or t == "boolean" then return t .. ":" .. tostring(v) end
  return t
end

local function pack(...) return { n = select("#", ...), ... } end

-- All return values of fn(...), encoded; { "MISSING" } / { "ERROR:<msg>" } when it cannot run.
local function probe(fn, ...)
  if type(fn) ~= "function" then return { "MISSING" } end
  local r = pack(pcall(fn, ...))
  if not r[1] then return { "ERROR:" .. tostring(r[2]) } end
  local out = {}
  for i = 2, r.n do out[#out + 1] = enc(r[i]) end
  return out
end

local function publicNum(v)
  if issecretvalue(v) or type(v) ~= "number" then return nil end
  return v
end

local function publicStr(v)
  if issecretvalue(v) or type(v) ~= "string" then return nil end
  return v
end

local function push(list, item, max)
  list[#list + 1] = item
  while #list > max do table.remove(list, 1) end
end

local function store() return QuantumDungeonToolsDB and QuantumDungeonToolsDB._checkF1 end

-- itype + instanceID when inside a party/raid instance.
local function instanceKey()
  local ok, _, itype, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
  if not ok then return nil end
  itype = publicStr(itype)
  if itype ~= "party" and itype ~= "raid" then return nil end
  return publicNum(instanceID)
end

------------------------------------------------------------------------------
-- Readers
------------------------------------------------------------------------------
local function readUnit(unit)
  local u = { unit = unit, exists = probe(UnitExists, unit)[1], name = probe(UnitName, unit)[1] }
  local ok, guid = pcall(UnitGUID, unit)
  if not ok then
    u.guid = "ERROR"
  elseif issecretvalue(guid) then
    u.guid = "SECRET"
  else
    u.guid = enc(guid)
    local g = Guid.parse(guid)
    if g then
      u.type, u.instanceID, u.zoneUID, u.npcID, u.spawnUID = g.type, g.instanceID, g.zoneUID, g.npcID, g.spawnUID
    end
  end
  return u
end

local function readEncounters(lock)
  local list = {}
  local total = lock and lock.total
  if not total then return list end
  for i = 1, math.min(total + 1, ENCOUNTER_MAX) do   -- +1: what does past-the-end return?
    list[#list + 1] = probe(GetInstanceLockTimeRemainingEncounter, i)
  end
  return list
end

local function readLock()
  local raw = probe(GetInstanceLockTimeRemaining)
  local ok, _, _, total, killed = pcall(GetInstanceLockTimeRemaining)
  local lock = { raw = raw }
  if ok then lock.total, lock.killed = publicNum(total), publicNum(killed) end
  return lock
end

local function readSaved()
  local out = {}
  local ok, n = pcall(GetNumSavedInstances)
  n = ok and publicNum(n) or nil
  out.count = n and n or enc(n)
  if not n then return out end
  for i = 1, math.min(n, SAVED_MAX) do out[#out + 1] = probe(GetSavedInstanceInfo, i) end
  return out
end

function C:Snapshot(label)
  local s = store()
  if not s then return nil end
  local lock = readLock()
  local snap = {
    label = label or "manual",
    t = time(),
    instance = probe(GetInstanceInfo),
    lock = lock,
    encounters = readEncounters(lock),
    saved = readSaved(),
    units = {},
  }
  for _, unit in ipairs(UNITS) do snap.units[#snap.units + 1] = readUnit(unit) end
  push(s.snapshots, snap, SNAPSHOT_MAX)
  return snap
end

local scratch
local function readStatic()
  local st = { build = probe(GetBuildInfo), globals = {}, scan = {}, events = {}, apis = {} }
  st.realIssecretvalue = rawget(_G, "issecretvalue") ~= nil
  for _, name in ipairs(GLOBALS) do st.globals[name] = enc(rawget(_G, name)) end

  local n = 0
  for k, v in pairs(_G) do
    if n >= GLOBAL_SCAN_MAX then break end
    if type(k) == "string" and not issecretvalue(v) and type(v) == "string" then
      local hit = false
      for _, p in ipairs(NAME_PATTERNS) do if k:find(p) then hit = true break end end
      if not hit then
        local low = v:lower()
        for _, p in ipairs(VALUE_PATTERNS) do if low:find(p, 1, true) then hit = true break end end
      end
      if hit then st.scan[k] = v; n = n + 1 end
    end
  end
  st.scanCapped = n >= GLOBAL_SCAN_MAX

  scratch = scratch or CreateFrame("Frame")
  for _, ev in ipairs(EVENTS) do
    local ok = pcall(scratch.RegisterEvent, scratch, ev)
    st.events[ev] = ok
    if ok then pcall(scratch.UnregisterEvent, scratch, ev) end
  end
  for _, api in ipairs(APIS) do st.apis[api] = type(rawget(_G, api)) end
  return st
end

------------------------------------------------------------------------------
-- Passive log
------------------------------------------------------------------------------
local frame

local function countOnly(event)
  local s = store()
  if s then s.counts[event] = (s.counts[event] or 0) + 1 end
end

local function logEvent(event, ...)
  local s = store()
  if not s then return end
  s.counts[event] = (s.counts[event] or 0) + 1
  local r = pack(...)
  local args = {}
  for i = 1, math.min(r.n, 8) do args[i] = enc(r[i]) end
  push(s.log, { t = time(), ev = event, inst = instanceKey(), args = args }, LOG_MAX)
end

-- Records a GUID seen inside an instance: per source, how many came public/secret/unparsable
-- (s.guidSources), and the zoneUIDs the public ones carry (s.zoneUIDs). Sources mirror Naowh
-- Forever's ReadZone: target, mouseover, nameplate tokens and the player's own castGUIDs.
local function noteGuid(guid, source)
  local s = store()
  local inst = s and instanceKey()
  if not inst then return end
  s.guidSources = s.guidSources or {}
  local src = s.guidSources[source] or { public = 0, secret = 0, noZone = 0 }
  s.guidSources[source] = src
  if issecretvalue(guid) then src.secret = src.secret + 1 return end
  local g = Guid.parse(guid)
  if not (g and g.zoneUID) then
    src.noZone = src.noZone + 1
    src.sample = src.sample or enc(guid)
    return
  end
  src.public = src.public + 1
  src.sample = src.sample or guid
  local key = inst .. ":" .. g.zoneUID
  local z = s.zoneUIDs[key]
  if not z then
    local count = 0
    for _ in pairs(s.zoneUIDs) do count = count + 1 end
    if count >= ZONE_MAX then return end
    z = { first = time(), count = 0, npcID = g.npcID, guidInstanceID = g.instanceID, source = source }
    s.zoneUIDs[key] = z
  end
  z.last, z.count = time(), z.count + 1
end

local function noteUnit(unit, source)
  if issecretvalue(unit) or type(unit) ~= "string" then return end
  local ok, guid = pcall(UnitGUID, unit)
  if ok then noteGuid(guid, source) end
end

-- Only lines that matter: chat money/faction always; system/UI errors when they mention
-- instances or resets (they also fire outside, where the reset message lives).
local function mentionsInstance(text)
  text = publicStr(text)
  if not text then return true end   -- secret or odd: keep it, it is a finding by itself
  local low = text:lower()
  return low:find("nstanc", 1, true) or low:find("reset", 1, true) or low:find("reinici", 1, true)
end

local handlers = {}
function handlers.PLAYER_TARGET_CHANGED() noteUnit("target", "target") end
function handlers.UPDATE_MOUSEOVER_UNIT() noteUnit("mouseover", "mouseover") end
-- Only the token's GUID: nameplates are never measured (GetCenter throws, global doc).
function handlers.NAME_PLATE_UNIT_ADDED(unit) noteUnit(unit, "nameplate") end
-- UNIT_SPELLCAST_SENT: unit, target, castGUID, spellID
function handlers.UNIT_SPELLCAST_SENT(_, _, castGUID) noteGuid(castGUID, "cast:sent") end
-- UNIT_SPELLCAST_START / _CHANNEL_START: unit, castGUID, spellID
function handlers.UNIT_SPELLCAST_START(_, castGUID) noteGuid(castGUID, "cast:start") end
function handlers.UNIT_SPELLCAST_CHANNEL_START(_, castGUID) noteGuid(castGUID, "cast:channel") end
function handlers.CHAT_MSG_MONEY(...) logEvent("CHAT_MSG_MONEY", ...) end
function handlers.CHAT_MSG_COMBAT_FACTION_CHANGE(...) logEvent("CHAT_MSG_COMBAT_FACTION_CHANGE", ...) end
function handlers.CHAT_MSG_SYSTEM(text, ...)
  if instanceKey() or mentionsInstance(text) then logEvent("CHAT_MSG_SYSTEM", text, ...) end
end
function handlers.UI_ERROR_MESSAGE(kind, text, ...)
  if mentionsInstance(text) then logEvent("UI_ERROR_MESSAGE", kind, text, ...) end
end
function handlers.INSTANCE_BOOT_START(...) logEvent("INSTANCE_BOOT_START", ...) end
function handlers.PLAYER_DEAD(...) logEvent("PLAYER_DEAD", ...) end
function handlers.ENCOUNTER_START(...)
  logEvent("ENCOUNTER_START", ...)
  C:Snapshot("auto:pull")
end
local function afterKill(event, ...)
  logEvent(event, ...)
  C_Timer.After(1, function() if RequestRaidInfo then pcall(RequestRaidInfo) end end)
  C_Timer.After(AFTER_KILL_DELAY, function() C:Snapshot("auto:after-kill") end)
end
function handlers.ENCOUNTER_END(...) afterKill("ENCOUNTER_END", ...) end
function handlers.BOSS_KILL(...) afterKill("BOSS_KILL", ...) end
function handlers.ZONE_CHANGED_NEW_AREA(...) logEvent("ZONE_CHANGED_NEW_AREA", ...) end
function handlers.PLAYER_LEAVING_WORLD(...) logEvent("PLAYER_LEAVING_WORLD", ...) end
function handlers.PLAYER_ALIVE(...) logEvent("PLAYER_ALIVE", ...) end
function handlers.PLAYER_UNGHOST(...) logEvent("PLAYER_UNGHOST", ...) end
function handlers.PLAYER_REGEN_DISABLED(...) logEvent("PLAYER_REGEN_DISABLED", ...) end
function handlers.PLAYER_REGEN_ENABLED(...) logEvent("PLAYER_REGEN_ENABLED", ...) end
-- High-volume events: counted only (the run trace below carries their effect).
function handlers.PLAYER_XP_UPDATE() countOnly("PLAYER_XP_UPDATE") end
function handlers.CHAT_MSG_COMBAT_XP_GAIN() countOnly("CHAT_MSG_COMBAT_XP_GAIN") end
function handlers.PLAYER_LEVEL_UP(...) logEvent("PLAYER_LEVEL_UP", ...) end
function handlers.UPDATE_INSTANCE_INFO() countOnly("UPDATE_INSTANCE_INFO") end
function handlers.GROUP_ROSTER_UPDATE() countOnly("GROUP_ROSTER_UPDATE") end
-- PLAYER_ENTERING_WORLD: isInitialLogin, isReloadingUi
function handlers.PLAYER_ENTERING_WORLD(...)
  logEvent("PLAYER_ENTERING_WORLD", ...)
  -- The lockout list arrives later: give the server a moment before reading it.
  C_Timer.After(AFTER_KILL_DELAY, function()
    if instanceKey() then C:Snapshot("auto:enter") end
  end)
end

-- Run trace: what the Tracker's model did, logged as QDT_RUN only when its state changes.
local lastRunSig
local function runSignature(run)
  if not run then return "none" end
  local parts = {}
  for _, b in ipairs(run.bosses or {}) do
    local mark = b.preKilled and "pre" or (b.killedAt and tostring(b.killedAt)) or (b.killed and "k") or "-"
    parts[#parts + 1] = tostring(b.name) .. "@" .. mark
  end
  return ("%s|%s|id=%s|start=%s|k=%d/%d|xp=%s|fin=%s|end=%s|deg=%s|list=%s|%s"):format(
    tostring(run.name), tostring(run.difficulty), tostring(run.instanceID), tostring(run.startedAt),
    run:killedCount(), run:total(), tostring(run.xp), tostring(run.finishedAt), tostring(run.endedAt),
    tostring(run.degraded), tostring(run.listKnown), table.concat(parts, ","))
end

local function traceRun(reason)
  local s = store()
  local T = ns.InstanceTracker
  if not (s and T) then return end
  local sig = runSignature(T.run)
  if sig == lastRunSig then return end
  lastRunSig = sig
  push(s.log, { t = time(), ev = "QDT_RUN", inst = instanceKey(),
    args = { tostring(reason), "in=" .. tostring(T.inInstance), sig } }, LOG_MAX)
end

local traced
local function arm()
  if not traced and ns.InstanceTracker then
    traced = true
    ns.InstanceTracker:OnChange(traceRun)
  end
  frame = frame or CreateFrame("Frame")
  for ev in pairs(handlers) do pcall(frame.RegisterEvent, frame, ev) end
  frame:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
  end)
end

local function disarm()
  if frame then frame:UnregisterAllEvents() end
end

------------------------------------------------------------------------------
-- Entry points
------------------------------------------------------------------------------
function C:Init()
  if store() then arm() end
end

local function say(text) ns.say(text) end

local function countKeys(t, pred)
  local n, total = 0, 0
  for _, v in pairs(t) do
    total = total + 1
    if pred(v) then n = n + 1 end
  end
  return n, total
end

-- /qdt check f1 [label]  |  /qdt check f1 off
function C:Run(arg)
  if arg == "off" then
    QuantumDungeonToolsDB._checkF1 = nil
    disarm()
    return say(L.CHECK_F1_OFF)
  end
  local s = store()
  if not s or s.format ~= FORMAT then
    s = { format = FORMAT, snapshots = {}, log = {}, zoneUIDs = {}, counts = {} }
    QuantumDungeonToolsDB._checkF1 = s
  end
  s.static = readStatic()
  arm()
  local snap = self:Snapshot(arg ~= "" and arg or nil)

  local g, gt = countKeys(s.static.globals, function(v) return v ~= "nil" end)
  local e, et = countKeys(s.static.events, function(v) return v end)
  local lock = snap.lock
  local u = snap.units[1]
  say(L.CHECK_F1_SAVED:format(#s.snapshots, snap.label))
  print("  " .. L.CHECK_F1_LOCK:format(tostring(lock.killed or "?"), tostring(lock.total or "?"),
    #snap.encounters))
  print("  " .. L.CHECK_F1_TARGET:format(tostring(u.zoneUID or u.guid)))
  print("  " .. L.CHECK_F1_STATIC:format(g, gt, e, et))
  print("  " .. L.CHECK_F1_ARMED)
end
