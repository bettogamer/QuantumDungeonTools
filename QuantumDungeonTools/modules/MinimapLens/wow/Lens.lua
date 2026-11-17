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
-- Triggers (binding, magnifier button, auto-close) live in Triggers.lua (F4): they listen
-- through UI:OnChange. F5 (the module page): live size, opacity and position, the zoom step and
-- the herbs/ores tracking as options, dragging the lens itself unless «Lock position», and the
-- module switch (off = the lens cannot open). db.pos is in UIParent units.
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
local current           -- self-check entry of the lens that is on (_checkLens.history)
local listeners = {}    -- fn(on) after every on/off (the magnifier button, F4)

local function db() return ns.db and ns.db.minimapLens end

local function notify()
  local on = snap ~= nil and not leaving
  for _, fn in ipairs(listeners) do pcall(fn, on) end
end

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
  if snap and current then current.warned = current.warned .. kind .. " " end
  local body
  local title = L.LENS_SOFT_TITLE
  if kind == "pinned" then
    title = L.LENS_PINNED_TITLE
    body = owner == "eui" and L.LENS_PINNED_EUI or L.LENS_PINNED:format(ownerLabel(owner))
  else
    body = L.LENS_SOFT_BODY:format(ownerLabel(owner))
  end
  local alerts = ns.InstanceAlertsUI
  local ok, shown = false, false
  if alerts and alerts.ShowNotice then
    ok, shown = pcall(alerts.ShowNotice, alerts, { icon = "search", title = title, body = body,
      seconds = NOTICE_SECONDS, action = UI.settingsAction and UI.settingsAction() or nil })
  end
  if not ok or not shown then ns.say(body) end
end

-- Self-check of F3: one entry per lens in _checkLens.history (the last HISTORY), so a test of
-- several steps is still readable after them. coexist(fields) updates the current one.
local HISTORY = 10

local function newEntry(owner)
  local root = QuantumDungeonToolsDB
  if type(root) ~= "table" or type(root._checkLens) ~= "table" then current = nil; return end
  local h = root._checkLens.history or {}
  root._checkLens.history = h
  root._checkLens.coexist = nil   -- F3 first cut kept only the last lens
  current = { owner = owner, foreign = 0, reapplied = 0, yielded = false, warned = "", last = "" }
  h[#h + 1] = current
  while #h > HISTORY do table.remove(h, 1) end
end

local function coexist(fields)
  if not current then return nil end
  for k, v in pairs(fields) do current[k] = v end
  return current
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

-- Underground / WMO areas (caves, Undercity): the engine paints only the blips on the grown
-- minimap until a LATER zoom change lands back on the level (measured 2026-11-16: size, mask,
-- position, alpha, tracking and our child frames ruled out one by one; a zoom +1 then -1 after
-- the lens settled brought the ground back). So once settled, and on every subzone change while
-- on, step the zoom out of the level and back a moment later.
local NUDGE_BACK = 0.2
local nudgeToken = 0
local function nudgeZoom()
  if not snap or leaving then return end
  local ok, z = call(Minimap, "GetZoom")
  local levels = maxZoomLevels()
  if not ok or type(z) ~= "number" or issecretvalue(z) or not levels then return end
  nudgeToken = nudgeToken + 1
  local my = nudgeToken
  mine(Minimap.SetZoom, Minimap, z + 1 < levels and z + 1 or z - 1)
  C_Timer.After(NUDGE_BACK, function()
    if my ~= nudgeToken or not snap then return end
    mine(Minimap.SetZoom, Minimap, z)
  end)
end

local function checkMove(my)
  local want = snap.pos
  local function done(held, retried)
    UI.moveHeld = held
    settled = true
    nudgeZoom()
    dump("move", { held = held, retried = retried })
    coexist({ held = held })
    UI:RefreshDrag()
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

------------------------------------------------------------------------------
-- Geometry (F5). The lens position lives in UIParent units (db.pos, the mover); the Minimap
-- gets it divided by its scale relative to UIParent (1 on Blizzard's, EUI/ElvUI may differ).
------------------------------------------------------------------------------
local function num(v) return (not issecretvalue(v) and type(v) == "number") and v or nil end

local function relScale()
  local _, m = call(Minimap, "GetEffectiveScale")
  local _, u = call(UIParent, "GetEffectiveScale")
  m, u = num(m), num(u)
  if not m or not u or u <= 0 or m <= 0 then return 1 end
  return m / u
end

local function uiSize()
  local _, w, h = call(UIParent, "GetSize")
  return num(w), num(h)
end

-- Lens side (Minimap units) and anchor (Minimap units) for the original size w x h.
local function geometry(w, h, d, k)
  local _, uiH = uiSize()
  local side = Lens.side(w, h, Lens.get(d, "size"), uiH and uiH / k)
  local p = Lens.position(d.pos, uiH)
  return side, { point = p.point, x = p.x / k, y = p.y / k }
end

------------------------------------------------------------------------------
-- Gathering tracking (F5): Find Herbs / Find Minerals off while the lens is on.
------------------------------------------------------------------------------
local function trackingRows()
  local rows = {}
  local M = C_Minimap
  if not (M and M.GetNumTrackingTypes and M.GetTrackingInfo) then return rows end
  local ok, n = pcall(M.GetNumTrackingTypes)
  if not ok or issecretvalue(n) or type(n) ~= "number" then return rows end
  for i = 1, math.min(n, 60) do
    local okI, info = pcall(M.GetTrackingInfo, i)
    if okI and type(info) == "table" and not ns.issecrettable(info) then
      local id, active = info.spellID, info.active
      if not issecretvalue(id) and not issecretvalue(active) then
        rows[#rows + 1] = { index = i, spellID = id, active = active == true }
      end
    end
  end
  return rows
end

-- Turns the tracking of these spellIDs on or off (by spell, the indexes may move).
local function setTracking(ids, on)
  if type(ids) ~= "table" or #ids == 0 or not (C_Minimap and C_Minimap.SetTracking) then return end
  local want = {}
  for _, id in ipairs(ids) do want[id] = true end
  for _, r in ipairs(trackingRows()) do
    if want[r.spellID] and r.active ~= on then pcall(C_Minimap.SetTracking, r.index, on) end
  end
end

------------------------------------------------------------------------------
-- Dragging the lens itself (F5, «Lock position» off). Only when the move held (EUI with the
-- minimap pinned would undo it). The engine moves the frame; the drop is written as ours.
------------------------------------------------------------------------------
local drag          -- { movable } while the Minimap is draggable; nil otherwise
local dragging = false
local dragHooked = false

local function dropAt()
  local s = snap
  if not s then return end
  local _, cx, cy = call(Minimap, "GetCenter")
  local k = relScale()
  local uiW, uiH = uiSize()
  cx, cy = num(cx), num(cy)
  local pos = cx and cy and Lens.centerOffset(cx * k, cy * k, uiW, uiH)
  if not pos then return end
  db().pos = pos
  s.pos = { point = pos.point, x = pos.x / k, y = pos.y / k }
  local p = s.pos
  mine(function()
    Minimap:ClearAllPoints()
    Minimap:SetPoint(p.point, UIParent, p.point, p.x, p.y)
  end)
end

local function hookDrag()
  if dragHooked then return end
  dragHooked = true
  Minimap:HookScript("OnDragStart", function()
    if not drag or dragging or not snap or leaving then return end
    dragging = true
    mine(Minimap.StartMoving, Minimap)
  end)
  Minimap:HookScript("OnDragStop", function()
    if not dragging then return end
    dragging = false
    mine(Minimap.StopMovingOrSizing, Minimap)
    -- Never into layout-local.txt: the lens spot is ours (db.pos), the minimap's is not.
    if drag then call(Minimap, "SetUserPlaced", drag.userPlaced) end
    dropAt()
  end)
end

local function setDrag(on)
  if on and not drag then
    local okM, movable = call(Minimap, "IsMovable")
    local okU, placed = call(Minimap, "IsUserPlaced")
    drag = { movable = okM and not issecretvalue(movable) and movable == true,
      userPlaced = okU and not issecretvalue(placed) and placed == true }
    hookDrag()
    call(Minimap, "SetMovable", true)
    call(Minimap, "RegisterForDrag", "LeftButton")
  elseif not on and drag then
    if dragging then
      dragging = false
      mine(Minimap.StopMovingOrSizing, Minimap)
    end
    call(Minimap, "RegisterForDrag")          -- no button: Blizzard's minimap has no drag
    call(Minimap, "SetUserPlaced", drag.userPlaced)
    call(Minimap, "SetMovable", drag.movable)
    drag = nil
  end
end

local function refreshDrag()
  setDrag(snap ~= nil and not leaving and settled and UI.moveHeld == true and not Lens.get(db(), "locked"))
end

local function apply(s, d)
  local k = relScale()
  local side
  side, s.pos = geometry(s.w, s.h, d, k)
  s.side = side
  s.lensZoom = Lens.get(d, "zoomStep") and Lens.zoomIn(s.zoom, maxZoomLevels()) or s.zoom
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
  setDrag(false)
  setTracking(s.tracking, true)
  s.tracking = nil
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
  if not Lens.isOn(db()) then
    ns.say(L.LENS_MODULE_OFF)
    return false
  end
  if leaving then   -- reopened while fading out: just fade back in
    leaving = false
    token = token + 1
    fadeTo(Lens.clamp(db().opacity, Lens.OPACITY))
    notify()
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
  if Lens.get(d, "hideGathering") then
    local rows = trackingRows()
    s.tracking = Lens.gatherToHide(rows)
    Lens.markTracking(d, s.tracking)
    setTracking(s.tracking, false)
  end
  dump("on", { owner = s.owner, w = s.w, h = s.h, side = s.side, zoom = s.zoom, lensZoom = s.lensZoom,
    point = s.pos.point, x = s.pos.x, y = s.pos.y, mask = s.plan.mask, icons = s.plan.icons,
    ring = s.backdropShown, size = Lens.percent(Lens.get(d, "size")), gather = s.tracking and #s.tracking or 0,
    k = relScale(),
    shape = type(GetMinimapShape) == "function" and select(2, pcall(GetMinimapShape)) or "nil" })
  newEntry(s.owner)
  fadeTo(Lens.clamp(d.opacity, Lens.OPACITY))
  checkMove(token)
  notify()
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
    notify()
  end
  if instant or not Weave then return finish() end
  if leaving then return true end
  leaving = true
  token = token + 1
  fadeTo(0, finish)
  notify()   -- the button turns off as the fade starts
  return true
end

function UI:Toggle()
  if self:IsOn() then return self:Off() end
  return self:On()
end

-- fn(on) runs after every change of state (on, starting to fade out, off).
function UI:OnChange(fn) listeners[#listeners + 1] = fn end

-- The lens's square right now (side, or nil when off): where the magnifier goes.
function UI:Side() return snap and not leaving and snap.side or nil end

-- Opacity slider (F5): live while on.
function UI:SetOpacity(v)
  local d = db()
  d.opacity = Lens.clamp(v, Lens.OPACITY)
  if self:IsOn() then fadeTo(d.opacity) end
end

-- Notice action (F5): the toast's «Lens settings» button opens the module page.
local function settingsAction()
  local MW = ns.MainWindow
  if not MW then return nil end
  return { text = L.LENS_SETTINGS, onClick = function() MW:Open("lens") end }
end
UI.settingsAction = settingsAction

-- Size slider (F5): live while on (a new square, icons re-laid; never tweened, doc 22).
function UI:SetSize(v)
  local d = db()
  d.size = Lens.clamp(v, Lens.SIZE)
  local s = snap
  if not s or leaving then return end
  local side = geometry(s.w, s.h, d, relScale())
  if side == s.side then return end
  s.side = side
  mine(Minimap.SetSize, Minimap, side, side)
  refreshIcons(s.plan)
end

-- Where the lens goes (UIParent units, CENTER offset; nil = the artboard default). Live while on,
-- unless another UI holds the minimap (the move did not hold).
function UI:SetPosition(pos)
  local d = db()
  d.pos = pos
  local s = snap
  if not s or leaving or UI.moveHeld ~= true then return end
  local _, p = geometry(s.w, s.h, d, relScale())
  s.pos = p
  mine(function()
    Minimap:ClearAllPoints()
    Minimap:SetPoint(p.point, UIParent, p.point, p.x, p.y)
  end)
end

-- The lens square in UIParent units: { side, x, y } (CENTER offset), on or off. For the mover.
function UI:Geometry()
  local k = relScale()
  local w, h
  if snap then
    w, h = snap.w, snap.h
  else
    local _, mw, mh = call(Minimap, "GetSize")
    w, h = num(mw), num(mh)
  end
  if not w or not h then return nil end
  local side, p = geometry(w, h, db(), k)
  return { side = side * k, x = p.x * k, y = p.y * k }
end

-- «Lock position» changed, or the lens settled: the Minimap is draggable only while it may move.
function UI:RefreshDrag() refreshDrag() end

-- «Hide herbs and ores» changed: live while on (turns them off now, or back on).
function UI:RefreshGathering()
  local s, d = snap, db()
  if not s or leaving then return end
  if Lens.get(d, "hideGathering") then
    if s.tracking and #s.tracking > 0 then return end
    s.tracking = Lens.gatherToHide(trackingRows())
    Lens.markTracking(d, s.tracking)
    setTracking(s.tracking, false)
  else
    setTracking(s.tracking, true)
    s.tracking = nil
    Lens.markTracking(d, nil)
  end
end

-- Module switch (F5, live): off closes the lens; the magnifier hides through OnChange.
function UI:SetModuleOn(on)
  db().enabled = on and true or false
  if not on then self:Off() end
  notify()
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
  elseif event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
    if snap and settled and not leaving then nudgeZoom() end   -- walked into a cave / city
  end
end)

function UI:Init()
  -- A crash or a disconnect with the lens on: put the original zoom back (gotcha 16), and the
  -- gathering tracking it had turned off (F5).
  setTracking(Lens.takePendingTracking(db()), true)
  local z = Lens.takePendingZoom(db())
  if z then pcall(Minimap.SetZoom, Minimap, z) end
  hookSetters()
  events:RegisterEvent("PLAYER_LEAVING_WORLD")
  events:RegisterEvent("PLAYER_LOGOUT")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  events:RegisterEvent("ZONE_CHANGED_INDOORS")
  events:RegisterEvent("ZONE_CHANGED")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end
