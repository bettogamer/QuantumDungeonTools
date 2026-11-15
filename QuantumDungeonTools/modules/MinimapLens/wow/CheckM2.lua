---@diagnostic disable: undefined-global
-- modules/MinimapLens/wow/CheckM2.lua -- `/qdt check m2`: Forever probes for Minimap Lens (plan M2, F1).
--
-- MEASURES what F2-F5 take for granted and dumps it to QuantumDungeonToolsDB._checkM2.runs[cfg]
-- (cfg = "none" | "eui" | "elvui" | "elvui+eui", detected), read by scripts/read-check-m2.lua.
--   /qdt check m2          tour (~36 s): baseline, SetSize x2 + zoom + square mask + hidden ring,
--                          readings at +0/1/2/5/10/30 s, alpha 0.5, move, restore + diff, then the
--                          SetScale x2 variant, restore + diff.
--   /qdt check m2 ab       flicker A/B for the owner's eyes: A SetSize, B +SetZoom, C +nudge, D SetScale.
--   /qdt check m2 on|off   leave the lens on (survives /reload: compares the state after the reload
--                          with the baseline, then re-applies), off restores it and disarms.
--   /qdt check m2 alpha    while on: toggle Minimap alpha 0.5.
--   /qdt check m2 combat   apply + restore inside the next combat (or now, if already in combat).
--   /qdt check m2 reset    clear every dump.
-- While armed, read-only hooks on the Minimap setters log WHO writes (addon from debugstack),
-- plus PEW / regen / edit mode / blocked-action events. Every call through pcall, every value
-- through issecretvalue first. Never reparents the Minimap and never touches MinimapCluster.
local _, ns = ...
local L = ns.L
local issecretvalue = ns.issecretvalue

local C = {}
ns.CheckM2 = C

local FORMAT = 1
local LOG_MAX = 400
local STATES_MAX = 40
local FACTOR = 2
local MASK_SQUARE = 130937   -- interface\chatframe\chatframebackground (what ElvUI/EUI use)
local MASK_ROUND = 186178    -- textures\minimapmask (ElvUI/EUI round): our guess of Blizzard's
local HOOKED = { "SetSize", "SetWidth", "SetHeight", "SetPoint", "ClearAllPoints", "SetParent",
  "SetZoom", "SetScale", "SetAlpha", "SetMaskTexture" }
local ANCHORED = { "Minimap", "MinimapContainer", "MinimapBackdrop", "ZoneTextButton",
  "GameTimeFrame", "AddonCompartmentFrame", "QueueStatusButton" }
local METHODS = { "SetBlipTexture", "SetPlayerTexture", "SetPOIArrowTexture", "SetStaticPOIArrowTexture",
  "SetIconScale", "SetArchBlobRingScalar", "SetMaskTexture", "GetZoomLevels", "UpdateBlips" }

-- Bindings.xml (S: does the AddOns header show in Key Bindings?). F4 replaces this binding.
BINDING_HEADER_QDT = "Quantum Dungeon Tools"
BINDING_NAME_QDT_LENS_PROBE = "Minimap Lens (probe)"

---------------------------------------------------------------------------------------------
-- Encoding (secret first, numbers rounded so the dump stays small)
---------------------------------------------------------------------------------------------
local function enc(v)
  if issecretvalue(v) then return "SECRET" end
  local t = type(v)
  if t == "number" then return math.floor(v * 100 + 0.5) / 100 end
  if t == "nil" then return "nil" end
  if t == "boolean" or t == "string" then return v end
  return "<" .. t .. ">"
end

local function call(obj, method, ...)
  local fn = obj and obj[method]
  if type(fn) ~= "function" then return false, "absent" end
  return pcall(fn, obj, ...)
end

local function val(obj, method, ...)
  local ok, v = call(obj, method, ...)
  if not ok then return v == "absent" and "absent" or ("error: " .. tostring(v)) end
  return enc(v)
end

local function nameOf(f)
  if f == nil then return "nil" end
  if issecretvalue(f) then return "SECRET" end
  if type(f) ~= "table" then return tostring(enc(f)) end
  local ok, n = call(f, "GetName")
  if ok and type(n) == "string" and not issecretvalue(n) then return n end
  return "<anon>"
end

local function frame(name)
  return _G[name] or (MinimapCluster and MinimapCluster[name]) or nil
end

local function push(list, item, max)
  list[#list + 1] = item
  if #list > max then table.remove(list, 1) end
end

---------------------------------------------------------------------------------------------
-- Readers
---------------------------------------------------------------------------------------------
local function readPoints(f)
  local out, live = {}, {}
  local ok, n = call(f, "GetNumPoints")
  if not ok or issecretvalue(n) or type(n) ~= "number" then return { "error: " .. tostring(n) }, nil end
  for i = 1, n do
    local okp, p, rel, rp, x, y = call(f, "GetPoint", i)
    if okp then
      live[#live + 1] = { p, rel, rp, x, y }
      out[#out + 1] = ("%s>%s:%s(%s,%s)"):format(tostring(enc(p)), nameOf(rel), tostring(enc(rp)),
        tostring(enc(x)), tostring(enc(y)))
    else
      out[#out + 1] = "error: " .. tostring(p)
      live = nil
    end
  end
  return out, live
end

local function frameState(f)
  if not f then return "absent" end
  local okw, w, h = call(f, "GetSize")
  return {
    shown = val(f, "IsShown"), visible = val(f, "IsVisible"),
    size = okw and (tostring(enc(w)) .. "x" .. tostring(enc(h))) or ("error: " .. tostring(w)),
    scale = val(f, "GetScale"), eff = val(f, "GetEffectiveScale"),
    alpha = val(f, "GetAlpha"), effAlpha = val(f, "GetEffectiveAlpha"),
    parent = nameOf(select(2, call(f, "GetParent"))),
    points = (readPoints(f)),
  }
end

local function libIcon() return LibStub and LibStub("LibDBIcon-1.0", true) end

local function readIcons()
  local icon, out = libIcon(), {}
  if not icon then return "no LibDBIcon" end
  local ok, list = pcall(icon.GetButtonList, icon)
  if not ok or type(list) ~= "table" then return "error: " .. tostring(list) end
  local half = select(2, call(Minimap, "GetWidth"))
  half = type(half) == "number" and not issecretvalue(half) and half / 2 or nil
  for _, name in ipairs(list) do
    local b = icon:GetMinimapButton(name)
    local okp, _, rel, _, x, y = call(b, "GetPoint", 1)
    local r
    if okp and type(x) == "number" and type(y) == "number" and not issecretvalue(x) and not issecretvalue(y) then
      r = math.sqrt(x * x + y * y)
    end
    out[name] = ("%s,%s r=%s half=%s rel=%s shown=%s effAlpha=%s"):format(tostring(enc(x)), tostring(enc(y)),
      tostring(enc(r)), tostring(enc(half)), okp and nameOf(rel) or "?", tostring(val(b, "IsShown")),
      tostring(val(b, "GetEffectiveAlpha")))
  end
  return out
end

local function shape()
  if type(GetMinimapShape) ~= "function" then return type(GetMinimapShape) end
  local ok, v = pcall(GetMinimapShape)
  return ok and enc(v) or ("error: " .. tostring(v))
end

local function viewRadius()
  if not (C_Minimap and C_Minimap.GetViewRadius) then return "absent" end
  local ok, v = pcall(C_Minimap.GetViewRadius)
  return ok and enc(v) or ("error: " .. tostring(v))
end

local function readState(label)
  return {
    label = label, t = enc(GetTime()), combat = enc(InCombatLockdown()),
    minimap = frameState(Minimap), zoom = val(Minimap, "GetZoom"), zoomLevels = val(Minimap, "GetZoomLevels"),
    viewRadius = viewRadius(), shape = shape(),
    backdrop = frameState(frame("MinimapBackdrop")), container = frameState(frame("MinimapContainer")),
    cluster = frameState(MinimapCluster), icons = readIcons(),
  }
end

local function configKey()
  local elv = _G.ElvUI_MinimapHolder ~= nil
  local eui = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUIMinimap") or false
  if elv and eui then return "elvui+eui" end
  return elv and "elvui" or eui and "eui" or "none"
end

local function readStatic()
  local st = { methods = {}, anchors = {}, tracking = {}, addons = {} }
  local okb, ver, build = pcall(GetBuildInfo)
  st.build = okb and (tostring(ver) .. " " .. tostring(build)) or "?"
  for _, m in ipairs(METHODS) do st.methods[m] = type(Minimap[m]) end
  st.getMinimapShape = shape()
  st.elvHolder = _G.ElvUI_MinimapHolder ~= nil
  for _, a in ipairs({ "EllesmereUIMinimap", "ElvUI", "DungeonLens", "FarmHud", "SexyMap", "BasicMinimap" }) do
    st.addons[a] = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(a) or false
  end
  for _, n in ipairs(ANCHORED) do st.anchors[n] = frameState(frame(n)) end
  if C_Minimap and C_Minimap.GetNumTrackingTypes then
    local ok, n = pcall(C_Minimap.GetNumTrackingTypes)
    st.trackingCount = ok and enc(n) or "error"
    if ok and type(n) == "number" and not issecretvalue(n) then
      for i = 1, math.min(n, 40) do
        local okI, info = pcall(C_Minimap.GetTrackingInfo, i)
        local okF, filter = pcall(C_Minimap.GetTrackingFilter, i)
        local row = tostring(i)
        if okI and type(info) == "table" and not (issecrettable and issecrettable(info)) then
          row = row .. " " .. tostring(enc(info.name)) .. " spell=" .. tostring(enc(info.spellID)) .. " type="
            .. tostring(enc(info.type)) .. "/" .. tostring(enc(info.subType))
            .. " active=" .. tostring(enc(info.active))
        end
        if okF and type(filter) == "table" and not (issecrettable and issecrettable(filter)) then
          row = row .. " filterID=" .. tostring(enc(filter.filterID)) .. " fActive=" .. tostring(enc(filter.isActive))
        end
        st.tracking[#st.tracking + 1] = row
      end
    end
  end
  st.cvarTracked = GetCVar and enc(GetCVar("minimapTrackedInfov4")) or "absent"
  local okK, key = pcall(GetBindingKey, "QDT_LENS_PROBE")
  st.bindingKey = okK and enc(key) or "error"
  st.editModeRegistry = EventRegistry ~= nil and type(EventRegistry.RegisterCallback) == "function"
  st.dbIcons = readIcons()
  return st
end

---------------------------------------------------------------------------------------------
-- Store + write log
---------------------------------------------------------------------------------------------
local recording, selfWriting, phase = false, false, "-"

local function root() return QuantumDungeonToolsDB and QuantumDungeonToolsDB._checkM2 end

local function run(create)
  local r = root()
  if (not r or r.format ~= FORMAT) and create then
    r = { format = FORMAT, runs = {} }
    QuantumDungeonToolsDB._checkM2 = r
  end
  if not r then return nil end
  local key = configKey()
  if not r.runs[key] and create then
    r.runs[key] = { log = {}, counts = {}, states = {}, events = {}, errors = {}, t0 = GetTime() }
  end
  return r.runs[key]
end

local function note(s, text) push(s.log, ("%.1f %s [%s]"):format(GetTime() - s.t0, text, phase), LOG_MAX) end

local function writer()
  if selfWriting then return "QDT" end
  local ok, st = pcall(debugstack, 3, 8, 0)
  if not ok or type(st) ~= "string" then return "?" end
  for addon in st:gmatch("AddOns[/\\]([^/\\]+)") do
    if addon ~= "QuantumDungeonTools" then return addon end
  end
  return (st:match("^[^\n]*") or "?"):sub(1, 80)
end

local function argText(...)
  local parts = {}
  for i = 1, math.min(select("#", ...), 3) do
    local v = select(i, ...)
    parts[#parts + 1] = type(v) == "table" and not issecretvalue(v) and nameOf(v) or tostring(enc(v))
  end
  return table.concat(parts, ",")
end

local function onWrite(method, ...)
  if not recording then return end
  local s = run(false)
  if not s then return end
  local who = writer()
  local key = method .. " | " .. who
  s.counts[key] = (s.counts[key] or 0) + 1
  note(s, method .. "(" .. argText(...) .. ") by " .. who)
end

local hooked = false
local function installHooks()
  if hooked then return end
  hooked = true
  for _, m in ipairs(HOOKED) do
    if type(Minimap[m]) == "function" then
      hooksecurefunc(Minimap, m, function(_, ...) onWrite(m, ...) end)
    end
  end
end

local function saveState(s, label)
  push(s.states, readState(label), STATES_MAX)
end

local function err(s, where, e)
  push(s.errors, where .. ": " .. tostring(e), 60)
end

---------------------------------------------------------------------------------------------
-- Lens apply / restore (probe version of what F2 will do)
---------------------------------------------------------------------------------------------
local live   -- frame refs for the restore; never persisted

local function snapshotLive()
  local _, points = readPoints(Minimap)
  local okw, w, h = call(Minimap, "GetSize")
  local oks, scale = call(Minimap, "GetScale")
  local oka, alpha = call(Minimap, "GetAlpha")
  local okz, zoom = call(Minimap, "GetZoom")
  for _, v in ipairs({ w, h, scale, alpha, zoom }) do
    if issecretvalue(v) then return nil, "secret" end
  end
  if not (points and okw and oks and oka and okz) then return nil, "read failed" end
  local bd = frame("MinimapBackdrop")
  return {
    points = points, w = w, h = h, scale = scale, alpha = alpha, zoom = zoom,
    backdrop = bd, backdropShown = bd and select(2, call(bd, "IsShown")) or false,
    shapeFn = GetMinimapShape, cfg = configKey(),
  }
end

-- EllesmereUIMinimap owns the LibDBIcon buttons (hides them in its drawer): Refresh would Show
-- them and leave them shown after the restore (measured with EUI, 2026-11-15). Hands off there.
local function refreshIcons()
  local icon = libIcon()
  if not icon or configKey():find("eui", 1, true) then return end
  local ok, list = pcall(icon.GetButtonList, icon)
  if not ok or type(list) ~= "table" then return end
  for _, name in ipairs(list) do pcall(icon.Refresh, icon, name) end
end

local function squareShape() return "SQUARE" end

local function maxZoom()
  local ok, n = call(Minimap, "GetZoomLevels")
  return ok and type(n) == "number" and not issecretvalue(n) and n - 1 or 5
end

-- opts: mode "size"|"scale", zoom (+1), nudge, square, ring (hide the ring)
local function apply(s, opts)
  if live then return true end
  local snap, why = snapshotLive()
  if not snap then err(s, "snapshot", why) return false end
  live = snap
  selfWriting = true
  local ok, e = pcall(function()
    if opts.mode == "scale" then
      Minimap:SetScale(live.scale * FACTOR)
    else
      Minimap:SetSize(live.w * FACTOR, live.h * FACTOR)
    end
    if opts.square and live.cfg == "none" then
      Minimap:SetMaskTexture(MASK_SQUARE)
      if GetMinimapShape == nil then GetMinimapShape = squareShape end
    end
    if opts.ring and live.backdrop then live.backdrop:Hide() end
    if opts.zoom then Minimap:SetZoom(math.min(live.zoom + 1, maxZoom())) end
    if opts.nudge then
      local z = Minimap:GetZoom()
      Minimap:SetZoom(z > 0 and 0 or 1)
      Minimap:SetZoom(z)
    end
  end)
  selfWriting = false
  if not ok then err(s, "apply " .. tostring(opts.mode), e) end
  refreshIcons()
  return ok
end

local function restore(s)
  if not live then return true end
  local snap = live
  live = nil
  selfWriting = true
  local ok, e = pcall(function()
    Minimap:SetScale(snap.scale)
    Minimap:SetSize(snap.w, snap.h)
    Minimap:ClearAllPoints()
    for _, p in ipairs(snap.points) do Minimap:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    Minimap:SetAlpha(snap.alpha)
    Minimap:SetZoom(snap.zoom)
    if snap.cfg == "none" then Minimap:SetMaskTexture(MASK_ROUND) end
    if GetMinimapShape == squareShape then GetMinimapShape = snap.shapeFn end
    if snap.backdrop and snap.backdropShown then snap.backdrop:Show() end
  end)
  selfWriting = false
  if not ok then err(s, "restore", e) end
  refreshIcons()
  return ok
end

-- Field-by-field diff of two encoded states (only what the restore must bring back).
local function diff(a, b)
  local out = {}
  local function cmp(path, x, y)
    if type(x) == "table" and type(y) == "table" then
      for k, v in pairs(x) do cmp(path .. "." .. tostring(k), v, y[k]) end
      for k, v in pairs(y) do if x[k] == nil then cmp(path .. "." .. tostring(k), nil, v) end end
    elseif x ~= y then
      out[#out + 1] = path .. ": " .. tostring(x) .. " -> " .. tostring(y)
    end
  end
  for _, k in ipairs({ "minimap", "zoom", "viewRadius", "shape", "backdrop", "container", "cluster", "icons" }) do
    cmp(k, a[k], b[k])
  end
  return out
end

---------------------------------------------------------------------------------------------
-- Events while armed
---------------------------------------------------------------------------------------------
local events = CreateFrame("Frame")
local LENS = { mode = "size", zoom = true, square = true, ring = true }

local function lensSize(s)
  if not s.lensOn or not live then return end
  local okw, w = call(Minimap, "GetWidth")
  if not okw or issecretvalue(w) then return end
  local want = s.lensWidth
  if want and math.abs(w - want) > 0.5 then
    note(s, ("STOMPED: width %.1f, lens %.1f -> re-apply once"):format(w, want))
    selfWriting = true
    local h = select(2, call(Minimap, "GetHeight"))
    pcall(Minimap.SetSize, Minimap, want, (live and live.h * FACTOR) or h)
    selfWriting = false
    C_Timer.After(1, function() saveState(s, phase .. ":after-reapply") end)
  end
end

local function after(s, label, delays, fn)
  for _, d in ipairs(delays) do
    C_Timer.After(d, function()
      saveState(s, label .. "+" .. d)
      if fn then fn(d) end
    end)
  end
end

local combatStep

local handlers = {}
function handlers.PLAYER_ENTERING_WORLD(isLogin, isReload)
  local s = run(false)
  if not s then return end
  note(s, ("EVENT PEW login=%s reload=%s"):format(tostring(isLogin), tostring(isReload)))
  if s.lensOn and (isLogin or isReload) and not live then
    phase = "reload"
    s.reload = { after = readState("after-reload") }
    if s.baseline then s.reload.diff = diff(s.baseline, s.reload.after) end
    C_Timer.After(1, function()
      if apply(s, LENS) then
        s.lensWidth = select(2, call(Minimap, "GetWidth"))
        saveState(s, "reload:re-applied")
      end
    end)
  elseif s.lensOn then
    phase = "pew"
    after(s, "pew", { 0.5, 2 }, function(d) if d == 2 then lensSize(s) end end)
  end
end
function handlers.PLAYER_REGEN_ENABLED()
  local s = run(false)
  if not s then return end
  note(s, "EVENT REGEN_ENABLED")
  if s.lensOn then
    phase = "regen"
    after(s, "regen", { 0.5, 2 }, function(d) if d == 2 then lensSize(s) end end)
  end
end
function handlers.PLAYER_REGEN_DISABLED()
  local s = run(false)
  if not s then return end
  note(s, "EVENT REGEN_DISABLED")
  if s.combatArmed then combatStep(s) end
end
local function logOnly(ev)
  handlers[ev] = function(...)
    local s = run(false)
    if s then note(s, "EVENT " .. ev .. " " .. argText(...)) end
  end
end
for _, ev in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "MINIMAP_UPDATE_TRACKING",
  "MINIMAP_UPDATE_ZOOM", "ZONE_CHANGED_NEW_AREA", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
  logOnly(ev)
end

events:SetScript("OnEvent", function(_, ev, ...)
  local h = handlers[ev]
  if h then h(...) end
end)

local editHooked = false
local function hookEditMode()
  if editHooked or not (EventRegistry and EventRegistry.RegisterCallback) then return end
  editHooked = true
  for _, e in ipairs({ "EditMode.Enter", "EditMode.Exit" }) do
    pcall(EventRegistry.RegisterCallback, EventRegistry, e, function()
      local s = run(false)
      if not s or not recording then return end
      note(s, "EVENT " .. e)
      saveState(s, e)
    end, C)
  end
end

local function arm()
  installHooks()
  hookEditMode()
  recording = true
  for ev in pairs(handlers) do pcall(events.RegisterEvent, events, ev) end
end

local function disarm()
  recording = false
  events:UnregisterAllEvents()
end

---------------------------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------------------------
local function say(text) ns.say(text) end
local busy = false

local function tour(s)
  busy = true
  phase = "tour"
  s.t0 = GetTime()
  note(s, "== tour ==")
  local before = readState("tour:before")
  s.tour = { before = before }
  push(s.states, before, STATES_MAX)
  if not apply(s, LENS) then busy = false return say(L.CHECK_M2_FAIL) end
  after(s, "tour:size", { 0, 1, 2, 5 })
  C_Timer.After(6, function()
    selfWriting = true; pcall(Minimap.SetAlpha, Minimap, 0.5); selfWriting = false
    saveState(s, "tour:alpha0.5")
    selfWriting = true; pcall(Minimap.SetAlpha, Minimap, 1); selfWriting = false
  end)
  C_Timer.After(8, function()
    selfWriting = true
    local ok, e = pcall(function()
      Minimap:ClearAllPoints()
      Minimap:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)
    selfWriting = false
    if not ok then err(s, "move", e) end
    saveState(s, "tour:moved")
  end)
  after(s, "tour:size", { 10, 30 })
  C_Timer.After(31, function()
    restore(s)
    s.tour.restored = readState("tour:restored")
    s.tour.diff = diff(before, s.tour.restored)
    phase = "tour:scale"
    if apply(s, { mode = "scale", zoom = true, ring = true }) then
      after(s, "tour:scale", { 0, 2 })
    end
  end)
  C_Timer.After(35, function()
    restore(s)
    s.tour.restored2 = readState("tour:restored2")
    s.tour.diff2 = diff(before, s.tour.restored2)
    busy = false
    phase = "-"
    say(L.CHECK_M2_TOUR_DONE:format(#s.tour.diff, #s.tour.diff2, #s.errors))
  end)
  say(L.CHECK_M2_TOUR)
end

local AB = {
  { "A", L.CHECK_M2_AB_A, { mode = "size" } },
  { "B", L.CHECK_M2_AB_B, { mode = "size", zoom = true } },
  { "C", L.CHECK_M2_AB_C, { mode = "size", nudge = true } },
  { "D", L.CHECK_M2_AB_D, { mode = "scale" } },
}

local function ab(s)
  busy = true
  s.t0 = GetTime()
  phase = "ab"
  note(s, "== ab ==")
  for i, v in ipairs(AB) do
    local t = (i - 1) * 5
    C_Timer.After(t, function()
      phase = "ab:" .. v[1]
      say(v[1] .. ": " .. v[2])
      apply(s, v[3])
      saveState(s, "ab:" .. v[1])
    end)
    C_Timer.After(t + 3, function() restore(s) end)
  end
  C_Timer.After(#AB * 5, function()
    busy = false
    phase = "-"
    say(L.CHECK_M2_AB_DONE)
  end)
end

local function lensOn(s)
  phase = "on"
  s.baseline = readState("on:baseline")
  if not apply(s, LENS) then return say(L.CHECK_M2_FAIL) end
  s.lensOn = true
  s.lensWidth = select(2, call(Minimap, "GetWidth"))
  saveState(s, "on:applied")
  say(L.CHECK_M2_ON)
end

local function lensOff(s)
  phase = "off"
  local hadLive = live ~= nil
  restore(s)
  s.lensOn = nil
  s.lensWidth = nil
  local state = readState("off:restored")
  push(s.states, state, STATES_MAX)
  if s.baseline then s.offDiff = diff(s.baseline, state) end
  disarm()
  say(L.CHECK_M2_OFF:format(hadLive and #(s.offDiff or {}) or -1))
end

function combatStep(s)
  s.combatArmed = nil
  phase = "combat"
  s.combat = { inLockdown = enc(InCombatLockdown()) }
  local okA = apply(s, { mode = "size", zoom = true, ring = true })
  s.combat.apply = okA
  selfWriting = true
  local okM, eM = pcall(function()
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end)
  selfWriting = false
  s.combat.move = okM or tostring(eM)
  saveState(s, "combat:applied")
  C_Timer.After(3, function()
    s.combat.inLockdownAtRestore = enc(InCombatLockdown())
    -- Tracking and CVar writes with the SAME value (no-op) to see whether they throw in combat.
    if C_Minimap and C_Minimap.GetTrackingInfo and C_Minimap.SetTracking then
      local okI, info = pcall(C_Minimap.GetTrackingInfo, 1)
      if okI and type(info) == "table" and not issecretvalue(info.active) then
        local okT, eT = pcall(C_Minimap.SetTracking, 1, info.active and true or false)
        s.combat.setTracking = okT or tostring(eT)
      end
    end
    if GetCVar and SetCVar then
      local okC, eC = pcall(SetCVar, "minimapTrackingShowAll", GetCVar("minimapTrackingShowAll"))
      s.combat.setCVar = okC or tostring(eC)
    end
    s.combat.restore = restore(s)
    saveState(s, "combat:restored")
    if s.combatBaseline then s.combat.diff = diff(s.combatBaseline, readState("combat:check")) end
    say(L.CHECK_M2_COMBAT_DONE:format(tostring(s.combat.apply), tostring(s.combat.restore), #s.errors))
  end)
end

function C:Init()
  local s = run(false)
  if s and (s.lensOn or s.combatArmed) then arm() end
end

-- /qdt check m2 [ab|on|off|toggle|alpha|combat|reset]
function C:Run(arg)
  if arg == "reset" then
    QuantumDungeonToolsDB._checkM2 = nil
    if live then restore({ errors = {} }) end
    disarm()
    return say(L.CHECK_M2_RESET)
  end
  if busy then return say(L.CHECK_M2_BUSY) end
  local s = run(true)
  s.static = readStatic()
  arm()
  if arg == "" then
    if live then return say(L.CHECK_M2_BUSY) end
    tour(s)
  elseif arg == "ab" then
    if live then return say(L.CHECK_M2_BUSY) end
    ab(s)
  elseif arg == "on" or (arg == "toggle" and not live) then
    lensOn(s)
  elseif arg == "off" or arg == "toggle" then
    lensOff(s)
  elseif arg == "alpha" then
    if not live then return say(L.CHECK_M2_NOT_ON) end
    local a = select(2, call(Minimap, "GetAlpha"))
    selfWriting = true
    pcall(Minimap.SetAlpha, Minimap, (type(a) == "number" and not issecretvalue(a) and a < 0.9) and 1 or 0.5)
    selfWriting = false
    saveState(s, "alpha")
  elseif arg == "combat" then
    if live then return say(L.CHECK_M2_BUSY) end
    s.combatBaseline = readState("combat:baseline")
    if InCombatLockdown() then combatStep(s) else
      s.combatArmed = true
      say(L.CHECK_M2_COMBAT)
    end
  else
    say(L.CHECK_M2_USAGE)
  end
end
