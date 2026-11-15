---@diagnostic disable: undefined-global
-- modules/MinimapLens/wow/Lens.lua -- Minimap Lens on the real Minimap (plan M2 F2).
--
-- On: snapshot the Minimap (anchors, size, scale, alpha, zoom, ring), grow it into a square of
-- `size` x the original side, move it to its own spot, one zoom step closer (F1 rule: SetSize +
-- a zoom step, never SetScale nor size alone), square mask + GetMinimapShape only on Blizzard's
-- minimap, Blizzard's ring hidden and a QDT outline drawn, LibDBIcon buttons re-laid around it
-- (not with EllesmereUI). Off: put every field back. Everything works in combat (F1 gotchas 10
-- and 18), every call goes through pcall and every read through issecretvalue first.
-- Never reparents the Minimap and never touches MinimapCluster (Blizzard's buttons stay put).
--
-- The lens does not survive a reload or a loading screen (gotcha 3): PLAYER_LEAVING_WORLD
-- restores it. The original zoom also lives in the DB while it is on (gotcha 16).
-- Triggers (binding, magnifier button, auto-close on leaving the instance) are F4; the
-- coexistence warning is F3 (it reads LensUI.moveHeld).
local _, ns = ...
local L = ns.L
local Lens = ns.MinimapLens
local issecretvalue = ns.issecretvalue

local UI = {}
ns.MinimapLensUI = UI

local Weave = LibStub and LibStub("Weave-1.0", true)
local FADE = 0.2                      -- Craft motionBase, in and out (one tween)
local MOVE_CHECK = 0.6                -- past EUI's resize repositioning (throttle 50 ms + tail <= 0.5 s)

local snap        -- what to put back; nil = lens off
local outline     -- QDT outline frame (child of the Minimap: fades with it)
local fade        -- { goal, tween, effect } over the Minimap alpha
local leaving     -- fading out before the restore
local token = 0   -- invalidates pending timers of an older on/off

local function db() return ns.db and ns.db.minimapLens end

local function call(obj, method, ...)
  local fn = obj and obj[method]
  if type(fn) ~= "function" then return false end
  return pcall(fn, obj, ...)
end

-- Who owns the minimap (same detection as the F1 probe; F3 refines it).
function UI.owner()
  local elv = _G.ElvUI_MinimapHolder ~= nil
  local okE, eui = pcall(C_AddOns.IsAddOnLoaded, "EllesmereUIMinimap")
  eui = okE and not issecretvalue(eui) and eui == true
  if elv and eui then return "elvui+eui" end
  return elv and "elvui" or eui and "eui" or "none"
end

------------------------------------------------------------------------------
-- Reading the Minimap
------------------------------------------------------------------------------
local function readPoints()
  local okN, n = call(Minimap, "GetNumPoints")
  if not okN or issecretvalue(n) or type(n) ~= "number" then return nil end
  local points = {}
  for i = 1, n do
    local ok, p, rel, rp, x, y = call(Minimap, "GetPoint", i)
    if not ok or issecretvalue(p) or issecretvalue(x) or issecretvalue(y) then return nil end
    points[#points + 1] = { p, rel, rp, x, y }
  end
  return points
end

-- The Minimap's anchor as { point, x, y }, only if it is a single point on UIParent.
local function anchor()
  local okN, n = call(Minimap, "GetNumPoints")
  if not okN or issecretvalue(n) or n ~= 1 then return nil end
  local ok, p, rel, _, x, y = call(Minimap, "GetPoint", 1)
  if not ok or issecretvalue(p) or issecretvalue(x) or issecretvalue(y) or rel ~= UIParent then return nil end
  return { point = p, x = x, y = y }
end

local function takeSnapshot()
  local _, w, h = call(Minimap, "GetSize")
  local _, scale = call(Minimap, "GetScale")
  local _, alpha = call(Minimap, "GetAlpha")
  local _, zoom = call(Minimap, "GetZoom")
  local s = { points = readPoints(), w = w, h = h, scale = scale, alpha = alpha, zoom = zoom }
  local ok, why = Lens.validSnapshot(s, issecretvalue)
  if not ok then return nil, why end
  local bd = _G.MinimapBackdrop
  local okB, shown = call(bd, "IsShown")
  s.backdrop = bd
  s.backdropShown = okB and not issecretvalue(shown) and shown == true
  s.shapeFn = GetMinimapShape
  s.owner = UI.owner()
  s.plan = Lens.plan(s.owner)
  return s
end

------------------------------------------------------------------------------
-- Pieces: outline, icons, shape, fade
------------------------------------------------------------------------------
local function edges(f, offset, size, c)
  local function tex()
    local t = f:CreateTexture(nil, "BORDER")
    t:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    return t
  end
  local o, e = offset, offset + size
  local top, bottom, left, right = tex(), tex(), tex(), tex()
  top:SetPoint("BOTTOMLEFT", f, "TOPLEFT", -e, o)
  top:SetPoint("TOPRIGHT", f, "TOPRIGHT", e, e)
  bottom:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -e, -o)
  bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", e, -e)
  left:SetPoint("TOPRIGHT", f, "TOPLEFT", -o, o)
  left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -e, -o)
  right:SetPoint("TOPLEFT", f, "TOPRIGHT", o, o)
  right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", e, -o)
end

local function buildOutline()
  local f = CreateFrame("Frame", nil, Minimap)
  f:SetAllPoints(Minimap)
  local offset = 0
  for _, ring in ipairs(Lens.OUTLINE) do
    edges(f, offset, ring.size, ring.color)
    offset = offset + ring.size
  end
  f:Hide()
  return f
end

local function setOutline(shown)
  if shown and not outline then
    local ok, f = pcall(buildOutline)
    if not ok then return end
    outline = f
  end
  if outline then
    pcall(outline.SetFrameLevel, outline, (select(2, call(Minimap, "GetFrameLevel")) or 1) + 1)
    pcall(outline.SetShown, outline, shown)
  end
end

local function refreshIcons(plan)
  if not plan.icons then return end
  local icon = LibStub and LibStub("LibDBIcon-1.0", true)
  if not icon then return end
  local ok, list = pcall(icon.GetButtonList, icon)
  if not ok or type(list) ~= "table" then return end
  for _, name in ipairs(list) do pcall(icon.Refresh, icon, name) end
end

local function squareShape() return "SQUARE" end

local function maxZoomLevels()
  local ok, n = call(Minimap, "GetZoomLevels")
  return ok and not issecretvalue(n) and n or nil
end

local function motion()
  local kit = ns.Kit and ns.Kit:Get()
  local m = kit and kit.ctx and kit.ctx:get()
  return Weave.easing[m and m.motionEasing] or Weave.easing.outQuad
end

-- Tweens the Minimap alpha to `to`; `done` runs when it gets there (or right away without Weave).
local function fadeTo(to, done)
  if not Weave then
    pcall(Minimap.SetAlpha, Minimap, to)
    if done then done() end
    return
  end
  if not fade then
    fade = { goal = Weave.signal(0) }
    fade.tween = Weave.tween(fade.goal, { duration = FADE, easing = motion() })
    fade.effect = Weave.effect(function()
      local v = fade.tween()
      if type(v) == "number" then pcall(Minimap.SetAlpha, Minimap, v) end
    end)
  end
  local okA, from = call(Minimap, "GetAlpha")
  fade.goal:set(to)
  fade.tween:snap((okA and not issecretvalue(from) and type(from) == "number") and from or 0)
  local my = token
  C_Timer.After(FADE, function()
    if my == token and done then done() end
  end)
end

------------------------------------------------------------------------------
-- Self-check (AGENTS.md section 7): the last on/off goes to QuantumDungeonToolsDB._checkLens,
-- read by the agent with a reducer. Plain numbers and strings only.
------------------------------------------------------------------------------
local function dump(key, t)
  local root = QuantumDungeonToolsDB
  if type(root) ~= "table" then return end
  root._checkLens = root._checkLens or {}
  t.t = GetTime()
  t.combat = InCombatLockdown() and true or false
  root._checkLens[key] = t
end

-- What the restore did not bring back (tolerance 0.5): size, scale, alpha, zoom, anchors.
local function restoreDiff(s)
  local out = {}
  local function cmp(name, a, b)
    if issecretvalue(b) or type(b) ~= "number" then out[#out + 1] = name .. ": unreadable"
    elseif math.abs(a - b) > 0.5 then out[#out + 1] = ("%s: %.2f -> %.2f"):format(name, a, b) end
  end
  local _, w, h = call(Minimap, "GetSize")
  cmp("w", s.w, w)
  cmp("h", s.h, h)
  cmp("scale", s.scale, select(2, call(Minimap, "GetScale")))
  cmp("alpha", s.alpha, select(2, call(Minimap, "GetAlpha")))
  cmp("zoom", s.zoom, select(2, call(Minimap, "GetZoom")))
  local now = readPoints() or {}
  if #now ~= #s.points then out[#out + 1] = ("points: %d -> %d"):format(#s.points, #now) end
  for i, p in ipairs(s.points) do
    local q = now[i]
    if q and (q[1] ~= p[1] or q[3] ~= p[3] or math.abs(q[4] - p[4]) > 0.5 or math.abs(q[5] - p[5]) > 0.5) then
      out[#out + 1] = ("point %d: %s %.1f,%.1f -> %s %.1f,%.1f"):format(i, p[1], p[4], p[5], q[1], q[4], q[5])
    end
  end
  return out
end

------------------------------------------------------------------------------
-- Apply / restore
------------------------------------------------------------------------------
local function checkMove(my)
  local want = snap.pos
  C_Timer.After(MOVE_CHECK, function()
    if my ~= token or not snap then return end
    if Lens.held(want, anchor()) then
      UI.moveHeld = true
      dump("move", { held = true, retried = false })
      return
    end
    -- Undone (EUI reanchors on resize): one more try past its window, then a frame to look.
    local p = want
    pcall(function()
      Minimap:ClearAllPoints()
      Minimap:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    end)
    C_Timer.After(0, function()
      if my ~= token or not snap then return end
      UI.moveHeld = Lens.held(want, anchor())
      dump("move", { held = UI.moveHeld, retried = true })
    end)
  end)
end

local function apply(s, d)
  local _, uiH = call(UIParent, "GetHeight")
  if issecretvalue(uiH) then uiH = nil end
  local side = Lens.side(s.w, s.h, d.size, uiH)
  s.side = side
  s.pos = Lens.position(d.pos, uiH)
  s.lensZoom = Lens.zoomIn(s.zoom, maxZoomLevels())
  local p = s.pos
  return pcall(function()
    Minimap:SetSize(side, side)
    Minimap:ClearAllPoints()
    Minimap:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    if s.plan.mask then Minimap:SetMaskTexture(Lens.MASK_SQUARE) end
    if s.plan.shape and GetMinimapShape == nil then GetMinimapShape = squareShape end
    if s.backdrop and s.backdropShown then s.backdrop:Hide() end
    Minimap:SetZoom(s.lensZoom)
  end)
end

local function restore(s)
  local ok, e = pcall(function()
    Minimap:SetScale(s.scale)
    Minimap:SetSize(s.w, s.h)
    Minimap:ClearAllPoints()
    for _, p in ipairs(s.points) do Minimap:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    Minimap:SetAlpha(s.alpha)
    Minimap:SetZoom(s.zoom)
    if s.plan.mask then Minimap:SetMaskTexture(Lens.MASK_ROUND) end
    if GetMinimapShape == squareShape then GetMinimapShape = s.shapeFn end
    if s.backdrop and s.backdropShown then s.backdrop:Show() end
  end)
  setOutline(false)
  refreshIcons(s.plan)
  Lens.markRestored(db())
  return ok, e
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------
function UI:IsOn() return snap ~= nil and not leaving end

function UI:On()
  if snap and not leaving then return true end
  if leaving then   -- reopened while fading out: just fade back in
    leaving = false
    token = token + 1
    fadeTo(Lens.clamp(db().opacity, Lens.OPACITY))
    return true
  end
  local s, why = takeSnapshot()
  if not s then
    ns.say(L.LENS_FAIL:format(tostring(why)))
    return false
  end
  token = token + 1
  snap, UI.moveHeld = s, nil
  local d = db()
  Lens.markApplied(d, s.zoom)
  pcall(Minimap.SetAlpha, Minimap, 0)   -- grow unseen, then fade in (never tween the size)
  local ok, e = apply(s, d)
  if not ok then
    restore(s)
    snap = nil
    ns.say(L.LENS_FAIL:format(tostring(e)))
    return false
  end
  setOutline(true)
  refreshIcons(s.plan)
  dump("on", { owner = s.owner, w = s.w, h = s.h, side = s.side, zoom = s.zoom, lensZoom = s.lensZoom,
    point = s.pos.point, x = s.pos.x, y = s.pos.y, mask = s.plan.mask, icons = s.plan.icons,
    ring = s.backdropShown,
    shape = type(GetMinimapShape) == "function" and select(2, pcall(GetMinimapShape)) or "nil" })
  fadeTo(Lens.clamp(d.opacity, Lens.OPACITY))
  checkMove(token)
  return true
end

-- instant: no fade (leaving the world, logout).
function UI:Off(instant)
  if not snap then return true end
  local s = snap
  local function finish()
    leaving = false
    snap = nil
    token = token + 1
    -- Park the tween on the original alpha first: a frame still in flight must not write over
    -- the restore (and the next fade starts from a known value).
    if fade then
      fade.goal:set(s.alpha)
      fade.tween:snap(s.alpha)
    end
    local ok, e = restore(s)
    if not ok then ns.say(L.LENS_FAIL:format(tostring(e))) end
    local diff = restoreDiff(s)
    dump("off", { ok = ok, err = not ok and tostring(e) or nil, instant = instant and true or false,
      diffs = #diff, diff = table.concat(diff, " | ") })
  end
  if instant or not Weave then return finish() end
  if leaving then return true end
  leaving = true
  token = token + 1
  fadeTo(0, finish)
  return true
end

function UI:Toggle()
  if self:IsOn() then return self:Off() end
  return self:On()
end

-- Opacity slider (F5): live while on.
function UI:SetOpacity(v)
  local d = db()
  d.opacity = Lens.clamp(v, Lens.OPACITY)
  if self:IsOn() then fadeTo(d.opacity) end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then UI:Off(true) end
end)

function UI:Init()
  -- A crash or a disconnect with the lens on: put the original zoom back (gotcha 16).
  local z = Lens.takePendingZoom(db())
  if z then pcall(Minimap.SetZoom, Minimap, z) end
  events:RegisterEvent("PLAYER_LEAVING_WORLD")
  events:RegisterEvent("PLAYER_LOGOUT")
end
