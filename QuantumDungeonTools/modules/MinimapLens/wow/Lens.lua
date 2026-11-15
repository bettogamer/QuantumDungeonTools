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
-- Triggers (binding, magnifier button, auto-close on leaving the instance) are F4.
--
-- Coexistence (F3, soft mode): hooks on the Minimap's setters see every write that is not ours
-- (`writing` marks ours). Once the lens has settled (the move check is done), a foreign write
-- waits REAPPLY s for the other UI to finish, then only what drifted is put back
-- (Lens.drift); a referee yields after Lens.REFEREE fixes and the lens stays as it was left.
-- The anchor is not fought when the move did not hold (EUI with the minimap pinned). Each case
-- warns once per session with the LensAviso toast.
local _, ns = ...
local L = ns.L
local Lens = ns.MinimapLens
local issecretvalue = ns.issecretvalue

local UI = {}
ns.MinimapLensUI = UI

local Weave = LibStub and LibStub("Weave-1.0", true)
local FADE = 0.2                      -- Craft motionBase, in and out (one tween)
local MOVE_CHECK = 0.6                -- past EUI's resize repositioning (throttle 50 ms + tail <= 0.5 s)
local REAPPLY = 0.6                   -- same window: let the other UI finish before putting back
local AFTER_COMBAT = 1.5              -- EUI reanchors at +0.7 s after combat (gotcha 10): look again
local NOTICE_SECONDS = 8              -- LensAviso: closes by itself after 8 s

local snap        -- what to put back; nil = lens off
local outline     -- QDT outline frame (child of the Minimap: fades with it)
local fade        -- { goal, tween, effect } over the Minimap alpha
local leaving     -- fading out before the restore
local token = 0   -- invalidates pending timers of an older on/off
local writing = false   -- true while the lens itself writes on the Minimap (the hooks skip it)
local settled = false   -- the move check is done: from here on, foreign writes are watched
local fadingUntil = 0   -- GetTime() when the running fade ends (alpha is not watched before)
local referee           -- Lens.newReferee() of the current lens
local maskDirty = false -- someone else called SetMaskTexture (there is no getter to compare)
local watchToken = 0    -- debounces the reapply after a burst of foreign writes
local warned = {}       -- warnings already shown this session (soft, pinned)

local function db() return ns.db and ns.db.minimapLens end

local function call(obj, method, ...)
  local fn = obj and obj[method]
  if type(fn) ~= "function" then return false end
  return pcall(fn, obj, ...)
end

-- Runs fn as the lens's own write (the setter hooks ignore it). Returns pcall's results.
local function mine(fn, ...)
  local was = writing   -- nests (a tween frame inside another write)
  writing = true
  local ok, e = pcall(fn, ...)
  writing = was
  return ok, e
end

local function squareShape() return "SQUARE" end

-- Who owns the minimap: ElvUI (its holder exists only with its minimap module on), EllesmereUI
-- (its minimap module cannot be turned off live, gotcha 27), or "other" when an unknown addon
-- already says the minimap is not round (SexyMap, Leatrix... own the mask then).
function UI.owner()
  local elv = _G.ElvUI_MinimapHolder ~= nil
  local okE, eui = pcall(C_AddOns.IsAddOnLoaded, "EllesmereUIMinimap")
  eui = okE and not issecretvalue(eui) and eui == true
  if elv and eui then return "elvui+eui" end
  if elv then return "elvui" end
  if eui then return "eui" end
  local fn = GetMinimapShape
  if type(fn) == "function" and fn ~= squareShape then
    local ok, shape = pcall(fn)
    if ok and not issecretvalue(shape) and type(shape) == "string" and shape ~= "ROUND" then return "other" end
  end
  return "none"
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
  fadingUntil = GetTime() + FADE + 0.1
  if not Weave then
    mine(Minimap.SetAlpha, Minimap, to)
    if done then done() end
    return
  end
  if not fade then
    fade = { goal = Weave.signal(0) }
    fade.tween = Weave.tween(fade.goal, { duration = FADE, easing = motion() })
    fade.effect = Weave.effect(function()
      local v = fade.tween()
      if type(v) == "number" then mine(Minimap.SetAlpha, Minimap, v) end
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
------------------------------------------------------------------------------
-- Coexistence (F3): warnings, watching and putting back
------------------------------------------------------------------------------
local function ownerLabel(owner) return Lens.ownerName(owner) or L.LENS_OTHER_UI end

-- kind: "soft" (another UI keeps writing; the lens yields) or "pinned" (the move did not hold).
-- Once per session each; the toast of the Instance Tracker alerts, or a chat line without it.
function UI:Warn(kind, owner)
  if warned[kind] then return end
  warned[kind] = true
  local body
  if kind == "pinned" then
    body = owner == "eui" and L.LENS_PINNED_EUI or L.LENS_PINNED:format(ownerLabel(owner))
  else
    body = L.LENS_SOFT_BODY:format(ownerLabel(owner))
  end
  local alerts = ns.InstanceAlertsUI
  local ok, shown = false, false
  if alerts and alerts.ShowNotice then
    ok, shown = pcall(alerts.ShowNotice, alerts, { icon = "search", title = L.LENS_SOFT_TITLE, body = body,
      seconds = NOTICE_SECONDS })
  end
  if not ok or not shown then ns.say(body) end
end

local function coexist(fields)
  local root = QuantumDungeonToolsDB
  if type(root) ~= "table" or type(root._checkLens) ~= "table" then return nil end
  local c = root._checkLens.coexist
  if not c then
    c = { foreign = 0, reapplied = 0, yielded = false, last = "" }
    root._checkLens.coexist = c
  end
  for k, v in pairs(fields) do c[k] = v end
  return c
end

-- What the lens should look like right now (see Lens.drift).
local function wanted(s)
  local w = { side = s.side, scale = s.scale }
  if GetTime() >= fadingUntil and fade then
    local okG, g = pcall(fade.goal.peek, fade.goal)
    if okG and type(g) == "number" then w.alpha = g end
  end
  if UI.moveHeld then w.pos = s.pos end
  return w
end

local function readBack()
  local _, w, h = call(Minimap, "GetSize")
  local _, scale = call(Minimap, "GetScale")
  local _, alpha = call(Minimap, "GetAlpha")
  local function num(v) return (not issecretvalue(v) and type(v) == "number") and v or nil end
  return { w = num(w), h = num(h), scale = num(scale), alpha = num(alpha), anchor = anchor() }
end

local function reassert(reason)
  local s = snap
  if not s or leaving or not settled or not referee then return end
  local fix = Lens.drift(wanted(s), readBack())
  if maskDirty and s.plan.mask then
    fix = fix or {}
    fix.mask = true
  end
  maskDirty = false
  if not fix then return end   -- they wrote, but the lens still stands
  local names = {}
  for k in pairs(fix) do names[#names + 1] = k end
  table.sort(names)
  local verdict = referee:call(GetTime())
  local c = coexist({ last = verdict .. " " .. table.concat(names, ",") .. " (" .. reason .. ")" })
  if verdict == "yield" then
    if c then c.yielded = true end
    UI:Warn("soft", s.owner)
    return
  end
  if verdict ~= "reapply" then return end
  if c then c.reapplied = c.reapplied + 1 end
  local p, w = s.pos, wanted(s)
  mine(function()
    if fix.scale then Minimap:SetScale(s.scale) end
    if fix.size then Minimap:SetSize(s.side, s.side) end
    if fix.anchor then
      Minimap:ClearAllPoints()
      Minimap:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    end
    if fix.alpha and w.alpha then Minimap:SetAlpha(w.alpha) end
    if fix.mask then Minimap:SetMaskTexture(Lens.MASK_SQUARE) end
  end)
  if fix.size then refreshIcons(s.plan) end
end

local function schedule(reason, delay)
  watchToken = watchToken + 1
  local my = watchToken
  C_Timer.After(delay or REAPPLY, function()
    if my == watchToken then reassert(reason) end
  end)
end

-- Every setter that can undo the lens (the zoom is left alone on purpose).
local WATCHED = { "SetSize", "SetWidth", "SetHeight", "SetPoint", "ClearAllPoints", "SetAllPoints",
  "SetScale", "SetAlpha", "SetMaskTexture" }
local hooked = false

local function hookSetters()
  if hooked then return end
  hooked = true
  for _, m in ipairs(WATCHED) do
    if type(Minimap[m]) == "function" then
      hooksecurefunc(Minimap, m, function()
        if writing or not snap or leaving or not settled then return end
        if m == "SetMaskTexture" then maskDirty = true end
        local c = coexist({})
        if c then c.foreign = c.foreign + 1 end
        schedule(m)
      end)
    end
  end
end

local function checkMove(my)
  local want = snap.pos
  local function done(held, retried)
    UI.moveHeld = held
    settled = true
    dump("move", { held = held, retried = retried })
    if not held then UI:Warn("pinned", snap.owner) end
  end
  C_Timer.After(MOVE_CHECK, function()
    if my ~= token or not snap then return end
    if Lens.held(want, anchor()) then return done(true, false) end
    -- Undone (EUI reanchors on resize): one more try past its window, then a frame to look.
    local p = want
    mine(function()
      Minimap:ClearAllPoints()
      Minimap:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    end)
    C_Timer.After(0, function()
      if my ~= token or not snap then return end
      done(Lens.held(want, anchor()), true)
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
  return mine(function()
    Minimap:SetSize(side, side)
    Minimap:ClearAllPoints()
    Minimap:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    if s.plan.mask then Minimap:SetMaskTexture(Lens.MASK_SQUARE) end
    -- Also over an addon that only says "ROUND" (owner "none"): restore puts its function back.
    if s.plan.shape then GetMinimapShape = squareShape end
    if s.backdrop and s.backdropShown then s.backdrop:Hide() end
    Minimap:SetZoom(s.lensZoom)
  end)
end

local function restore(s)
  settled = false
  local ok, e = mine(function()
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
  watchToken = watchToken + 1
  snap, UI.moveHeld = s, nil
  settled, maskDirty, referee = false, false, Lens.newReferee()
  local d = db()
  Lens.markApplied(d, s.zoom)
  mine(Minimap.SetAlpha, Minimap, 0)   -- grow unseen, then fade in (never tween the size)
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
  if type(QuantumDungeonToolsDB) == "table" and QuantumDungeonToolsDB._checkLens then
    QuantumDungeonToolsDB._checkLens.coexist = nil   -- F3 counts per lens
  end
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

-- Previews of the coexistence toast (/qdt lens notice <soft | pinned>): ignore the once rule.
function UI:PreviewNotice(kind)
  if kind ~= "soft" and kind ~= "pinned" then return false end
  warned[kind] = nil
  self:Warn(kind, self.owner())
  return true
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
    UI:Off(true)
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Safety net for a UI that writes through a cached setter (no hook sees it): look once
    -- after its post-combat pass. Only what drifted is put back, as with the hooks.
    if snap and settled and not leaving then schedule("combat", AFTER_COMBAT) end
  end
end)

function UI:Init()
  -- A crash or a disconnect with the lens on: put the original zoom back (gotcha 16).
  local z = Lens.takePendingZoom(db())
  if z then pcall(Minimap.SetZoom, Minimap, z) end
  hookSetters()
  events:RegisterEvent("PLAYER_LEAVING_WORLD")
  events:RegisterEvent("PLAYER_LOGOUT")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
end
