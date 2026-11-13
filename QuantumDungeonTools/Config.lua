---@diagnostic disable: undefined-global
-- Config.lua -- slash commands (and, as it grows, the options UI).
local _, ns = ...
local L = ns.L

local HISTORY_SHOWN = 5

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

local function history()
  local list = ns.InstanceTracker:History()
  if #list == 0 then return say(L.IT_HISTORY_EMPTY) end
  say(L.IT_HISTORY_HEADER)
  for i = 1, math.min(HISTORY_SHOWN, #list) do
    local run = ns.InstanceRun.fromTable(list[i])
    local done = run.finishedAt ~= nil
    print("  " .. L.IT_HISTORY_LINE:format(run.name, run.difficulty, run:killedCount(), run:total(),
      ns.Format.duration(run:elapsed()), ns.Format.thousands(run.xp), done and "" or L.IT_INCOMPLETE))
  end
end

SLASH_QDT1 = "/qdt"
SlashCmdList.QDT = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "it" or msg == "tracker" then
    ns.InstanceTrackerUI:Toggle()
  elseif msg == "new" then
    ns.InstanceTracker:NewRun()
    say(ns.InstanceTracker.run and L.IT_NEW_RUN or L.IT_RUN_CLOSED)
  elseif msg == "history" then
    history()
  elseif msg == "auto" then
    local it = ns.db.instanceTracker
    it.autoShow = not it.autoShow
    say(L.IT_AUTO:format(it.autoShow and L.MSG_ON or L.MSG_OFF))
    ns.InstanceTrackerUI:Update()
  elseif msg == "it compact" then
    say(L.IT_COMPACT:format(ns.InstanceTrackerUI:ToggleCompact() and L.MSG_ON or L.MSG_OFF))
  elseif msg == "it demo" or msg:find("^it demo ") then
    local name = msg:gsub("^it demo%s*", "")
    if ns.InstanceTrackerUI:Demo(name) then
      say(name == "off" and L.IT_DEMO_OFF or L.IT_DEMO:format(name))
    else
      say(L.IT_DEMO_USAGE:format(table.concat(ns.InstanceTrackerDemo.NAMES, ", ")))
    end
  elseif msg == "check f2" then
    ns.CheckF2:Run()
  elseif msg == "check f1" or msg:find("^check f1 ") then
    ns.CheckF1:Run((msg:gsub("^check f1%s*", "")))
  elseif msg == "info" then
    info()
  else
    say(L.HELP_USAGE)
    for _, line in ipairs(L.HELP_LINES) do print("  " .. line) end
  end
end
