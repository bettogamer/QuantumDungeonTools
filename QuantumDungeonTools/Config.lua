---@diagnostic disable: undefined-global
-- Config.lua -- slash commands (and, as it grows, the options UI).
local _, ns = ...
local L = ns.L

local function say(text) ns.say(text) end

-- `/qdt info`: version of the addon and of EVERY vendored lib actually loaded (if any).
local function info()
  say(("%s v%s"):format(ns.Brand.title(), ns.version or "dev"))
  if not LibStub then return end
  local names = {}
  for name in LibStub:IterateLibraries() do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local lib, minor = LibStub:GetLibrary(name, true)
    print(("  %s  MINOR %s  version %s"):format(name, tostring(minor),
      tostring(type(lib) == "table" and (lib._VERSION or lib.VERSION) or "?")))
  end
end

SLASH_QDT1 = "/qdt"
SlashCmdList.QDT = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" then
    ns.MainWindow:Toggle("home")
  elseif not ns.itLoaded and (msg == "it" or msg == "tracker" or msg == "new" or msg == "auto"
      or msg:find("^it ") or msg:find("^check f")) then
    say(L.IT_MODULE_OFF)   -- module switched off: nothing of it is running
  elseif msg == "it" or msg == "tracker" then
    ns.InstanceTrackerUI:Toggle()
  elseif msg == "new" then
    ns.InstanceTracker:NewRun()
    say(ns.InstanceTracker.run and L.IT_NEW_RUN or L.IT_RUN_CLOSED)
  elseif msg == "history" then
    ns.InstanceTrackerPage:OpenHistory()   -- the History tab of the main window (F6d)
  elseif msg == "auto" then
    local it = ns.db.instanceTracker
    it.autoShow = not it.autoShow
    say(L.IT_AUTO:format(it.autoShow and L.MSG_ON or L.MSG_OFF))
    ns.InstanceTrackerUI:Update()
  elseif msg == "it compact" then
    say(L.IT_COMPACT:format(ns.InstanceTrackerUI:ToggleCompact() and L.MSG_ON or L.MSG_OFF))
  elseif msg == "it mark" or msg:find("^it mark ") then
    local idx = ns.InstanceTrackerView.markerIndex((msg:gsub("^it mark%s*", "")))
    if idx then
      ns.db.instanceTracker.pingMarker = idx
      ns.InstanceTrackerUI:SyncPings()   -- out of combat now, or when it ends
      say(L.IT_MARK:format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. idx .. ":0|t"))
    else
      say(L.IT_MARK_USAGE)
    end
  elseif msg == "it demo" or msg:find("^it demo ") then
    local name = msg:gsub("^it demo%s*", "")
    if ns.InstanceTrackerUI:Demo(name) then
      say(name == "off" and L.IT_DEMO_OFF or L.IT_DEMO:format(name))
    else
      say(L.IT_DEMO_USAGE:format(table.concat(ns.InstanceTrackerDemo.NAMES, ", ")))
    end
  elseif msg == "it alert" or msg:find("^it alert ") then
    if not ns.InstanceAlertsUI:Preview((msg:gsub("^it alert%s*", ""))) then say(L.IT_A_USAGE) end
  elseif msg == "check f2" then
    ns.CheckF2:Run()
  elseif msg == "check f1" or msg:find("^check f1 ") then
    ns.CheckF1:Run((msg:gsub("^check f1%s*", "")))
  elseif msg == "check m2" or msg:find("^check m2 ") then
    ns.CheckM2:Run((msg:gsub("^check m2%s*", "")))
  elseif msg == "check pos" or msg:find("^check pos ") then
    ns.CheckPos:Run((msg:gsub("^check pos%s*", "")))
  elseif msg == "lens" or msg == "lens bind" then
    -- "lens bind" is what Bindings.xml runs (the self-check tells the two apart).
    ns.MinimapLensTriggers:Toggle(msg == "lens bind" and "bind" or "slash")
  elseif msg == "lens button" then
    say(L.LENS_PREVIEW:format(ns.MinimapLensTriggers:Preview() and L.MSG_ON or L.MSG_OFF))
  elseif msg:find("^lens notice") then
    if not ns.MinimapLensUI:PreviewNotice((msg:gsub("^lens notice%s*", ""))) then say(L.LENS_NOTICE_USAGE) end
  elseif msg == "minimap" then
    local shown = not ns.Minimap:IsShown()
    ns.Minimap:SetShown(shown)
    say(L.MM_TOGGLED:format(shown and L.MSG_ON or L.MSG_OFF))
  elseif msg == "info" then
    info()
  else
    say(L.HELP_USAGE)
    for _, line in ipairs(L.HELP_LINES) do print("  " .. line) end
  end
end
