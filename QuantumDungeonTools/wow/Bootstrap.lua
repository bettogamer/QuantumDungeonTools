---@diagnostic disable: undefined-global
-- wow/Bootstrap.lua -- THE WoW INTEGRATION LAYER.
--
-- Responsibility: create the event frame, manage SavedVariables and -- the important part --
-- INJECT the real game dependencies (scheduler, secret detector) into the pure core. It is
-- the only place (along with Config.lua) allowed to touch WoW API at level M.
local ADDON, ns = ...
local L = ns.L

-- Real secret-value detector (WoW 12.0+), with a shim for clients without the API. See docs/05.
local issecretvalue = issecretvalue or function() return false end
local issecrettable = issecrettable or function() return false end
ns.issecretvalue, ns.issecrettable = issecretvalue, issecrettable

-- Every chat line of the addon goes through here: gold "QDT:" prefix (core/Brand.lua).
function ns.say(text) print(ns.Brand.prefix() .. text) end

------------------------------------------------------------------------------
-- SavedVariables
------------------------------------------------------------------------------
local DB_VERSION = 1

function ns.InitDB()
  QuantumDungeonToolsDB = QuantumDungeonToolsDB or {}
  local db = QuantumDungeonToolsDB

  -- Explicit per-version migrations (never delete the user's data)
  if (db._version or 0) < DB_VERSION then
    db._version = DB_VERSION
  end

  -- Defaults without clobbering what is there (0 and false are valid values -> compare to nil)
  if db.enabled == nil then db.enabled = true end
  -- Module: Instance Tracker
  db.instanceTracker = db.instanceTracker or {}
  local it = db.instanceTracker
  if it.autoShow == nil then it.autoShow = true end
  if it.compact == nil then it.compact = false end   -- F2: one-line widget (additive field, no migration)
  it.history = it.history or {}
  it.records = it.records or {}     -- F3: PB per dungeon + difficulty (additive, no migration)
  it.trash = it.trash or {}         -- F4c: trash per dungeon (instanceID), learned from clean runs
  it.hourly = it.hourly or {}       -- F5: instances entered in the last hour, account-wide (additive)
  if it.pingMarker == nil then it.pingMarker = 8 end   -- right click on a boss: skull (additive)

  ns.db = db
end

------------------------------------------------------------------------------
-- Addon version
------------------------------------------------------------------------------
-- The .toc says `## Version: @project-version@`, and the CurseForge packager substitutes it
-- ONLY when publishing. Outside a published build GetAddOnMetadata returns the LITERAL token
-- -- which is not nil -- so `or "dev"` does not cover it and the addon announces itself as
-- "QuantumDungeonTools v@project-version@". Comparing against the token spelled out here does not work
-- either: the packager substitutes inside .lua files too, so that comparison would be true in
-- the published build. Look for the at-sign instead.
function ns.resolveVersion(raw)
  if type(raw) ~= "string" or raw == "" or raw:find("@", 1, true) then return "dev" end
  return raw
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    ns.InitDB()
  elseif event == "PLAYER_LOGIN" then
    -- World loaded: start the modules (each one injects the real game deps into its pure core).
    if ns.InstanceTracker then ns.InstanceTracker:Init() end
    if ns.InstanceTrackerUI then ns.InstanceTrackerUI:Init() end
    if ns.InstanceAlertsUI then ns.InstanceAlertsUI:Init() end
    if ns.CheckF1 then ns.CheckF1:Init() end   -- re-arms the F1 passive log if it is on
    ns.version = ns.resolveVersion(C_AddOns.GetAddOnMetadata(ADDON, "Version"))
    print(L.MSG_LOADED:format(ns.Brand.title(), ns.version))
  end
end)
