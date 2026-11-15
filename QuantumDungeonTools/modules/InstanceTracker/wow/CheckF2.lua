---@diagnostic disable: undefined-global
-- modules/InstanceTracker/wow/CheckF2.lua -- `/qdt check f2`: widget + Craft self-test (plan M1 F2).
--
-- Verifies by code what the F2 in-game test would otherwise ask the owner: the vendored libs
-- loaded (and which copy won LibStub), our theme context exists, the BettoGeo files load, every
-- demo state of the widget builds with a non-zero size, and what the XP APIs answer in Forever
-- (max level, rested). Dumps to QuantumDungeonToolsDB._checkF2 (reader: scripts/read-check-f2.lua)
-- and prints only the failures. Leaves the widget as it found it (demo off).
local _, ns = ...
local L = ns.L
local issecretvalue = ns.issecretvalue

local C = {}
ns.CheckF2 = C

local FONTS = { "BettoGeo-Regular.ttf", "BettoGeo-Medium.ttf", "BettoGeo-Bold.ttf" }

-- Plain, persistable encoding of any value (secret first).
local function enc(v)
  if issecretvalue(v) then return "SECRET" end
  local t = type(v)
  if t == "nil" then return "nil" end
  if t == "number" or t == "boolean" or t == "string" then return v end
  return "<" .. t .. ">"
end

local function probe(fn, ...)
  if not fn then return "absent" end
  local ok, v = pcall(fn, ...)
  if not ok then return "error: " .. tostring(v) end
  return enc(v)
end

function C:Run()
  local results = {}
  local function check(name, ok, detail)
    results[#results + 1] = { name = name, ok = ok and true or false, detail = enc(detail) }
  end

  local Craft = LibStub and LibStub("Craft-2.0", true)
  local Weave = LibStub and LibStub("Weave-1.0", true)
  check("libstub", LibStub ~= nil, LibStub and LibStub.minor)
  check("craft", Craft ~= nil, Craft and (tostring(Craft.VERSION) .. " build " .. tostring(Craft.BUILD)))
  check("craft>=2.47.0", Craft and (Craft.BUILD or 0) >= 49, Craft and Craft.BUILD)
  check("craft.mediaPath", Craft and type(Craft.mediaPath) == "string", Craft and Craft.mediaPath)
  check("weave", Weave ~= nil, Weave and Weave._VERSION)

  local ctx = Craft and Craft.Theme._contexts and Craft.Theme._contexts.QuantumDungeonTools
  check("theme context", ctx ~= nil, ctx and ctx.name)
  if ctx then
    local t = ctx:get()
    check("context font = BettoGeo", type(t.font) == "string" and t.font:find("BettoGeo", 1, true) ~= nil, t.font)
    check("context outline", t.fontFlags == "OUTLINE, SLUG", t.fontFlags)
  end

  -- Font files: SetFont returns false when the file does not load.
  if Craft then
    local holder = CreateFrame("Frame")
    holder:Hide()
    local fs = holder:CreateFontString(nil, "OVERLAY")
    for _, file in ipairs(FONTS) do
      local ok, res = pcall(fs.SetFont, fs, Craft.mediaPath .. file, 12, "OUTLINE")
      check("font " .. file, ok and res ~= false, ok and tostring(res) or ("error: " .. tostring(res)))
    end
  end

  -- Every demo state builds and has a size.
  local UI, Demo = ns.InstanceTrackerUI, ns.InstanceTrackerDemo
  local sizes = {}
  if Craft then
    for _, name in ipairs(Demo.NAMES) do
      local ok, err = pcall(UI.Demo, UI, name)
      local snap = UI:Snapshot()
      local w, h = snap.width or 0, snap.height or 0
      sizes[name] = { w = w, h = h }
      check("demo " .. name, ok and snap.shown and w > 10 and h > 10,
        ok and (math.floor(w) .. "x" .. math.floor(h)) or err)
    end
    -- F6c: a line switched off shrinks the widget (boss list off, then back as it was).
    local it = ns.db.instanceTracker
    local saved = it.showBosses
    it.showBosses = true
    pcall(UI.Demo, UI, "live")
    local h1 = UI:Snapshot().height or 0
    it.showBosses = false
    pcall(UI.Demo, UI, "live")
    local h2 = UI:Snapshot().height or 0
    it.showBosses = saved
    check("line bosses off", h2 > 0 and h2 < h1, math.floor(h1) .. " -> " .. math.floor(h2))
    pcall(UI.Demo, UI, "off")
  end

  -- F6c: the module page of the main window builds its 8 settings.
  local MW, Page = ns.MainWindow, ns.InstanceTrackerPage
  local pageProbe
  if Craft and MW and Page then
    local wasShown = MW:IsShown()
    local ok, err = pcall(MW.Open, MW, "it")
    local ps = Page:Snapshot()
    check("page it", ok and ps.built and ps.cells == 8, ok and ps.cells or err)
    pageProbe = ps.probe
    -- Rects only resolve once the page has been on screen: checked when the window was open.
    if wasShown then check("page it painted", ps.painted, ps.probe and ps.probe.last) end
    -- F6d: the History tab builds its 9 columns and paints one row per saved run that passes
    -- the filters (then the tab the owner had open comes back).
    local before = Page:ActiveTab()
    local okH, errH = pcall(Page.ShowTab, Page, "history")
    local hs = ns.InstanceHistoryTab:Snapshot()
    check("page history", okH and hs.built and hs.cols == 9 and hs.shown == hs.filtered,
      okH and (hs.cols .. " cols, " .. hs.shown .. "/" .. hs.filtered .. " rows, " .. hs.saved .. " saved") or errH)
    if before ~= "history" then pcall(Page.ShowTab, Page, before) end
    if not wasShown and MW:IsShown() then MW:Toggle() end
  end

  -- XP APIs in Forever (informative: the widget hides the XP bar when atMax).
  local xp = ns.InstanceTracker:XPSnapshot()
  check("xp snapshot", xp ~= nil, xp and (xp.level .. " " .. xp.xp .. "/" .. xp.max .. " rested " .. xp.rested
    .. (xp.atMax and " atMax" or "")))
  local apis = {
    GetMaxLevelForPlayerExpansion = probe(GetMaxLevelForPlayerExpansion),
    GetMaxPlayerLevel = probe(GetMaxPlayerLevel),
    GetXPExhaustion = probe(GetXPExhaustion),
    IsXPUserDisabled = probe(IsXPUserDisabled),
    GetLocale = probe(GetLocale),
  }

  local okCount = 0
  for _, r in ipairs(results) do if r.ok then okCount = okCount + 1 end end
  local build = { GetBuildInfo() }
  QuantumDungeonToolsDB._checkF2 = {
    at = time(), build = { enc(build[1]), enc(build[2]), enc(build[4]) },
    results = results, apis = apis, sizes = sizes, ui = UI:Snapshot(), page = pageProbe,
  }
  ns.say(L.CHECK_F2_SAVED:format(okCount, #results, tostring(build[1])))
  for _, r in ipairs(results) do
    if not r.ok then print(L.CHECK_F2_FAIL:format(r.name, tostring(r.detail))) end
  end
end

return C
