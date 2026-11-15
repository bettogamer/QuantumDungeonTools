---@diagnostic disable: undefined-global
-- modules/MinimapLens/wow/Triggers.lua -- how the lens opens and closes (plan M2 F4).
--
-- Opens only by hand (owner, F0): the key binding (Key Bindings > AddOns > Quantum Dungeon
-- Tools, no key by default; Bindings.xml calls `/qdt lens bind`), the magnifier button on the
-- minimap and `/qdt lens`. Closes by itself on leaving the instance (a loading screen already
-- does it in Lens.lua; here a zone change without one), on opening Edit Mode and on logout.
--
-- Magnifier (artboards LensReposo / LensActiva): a 34 px round button, navy with a 2 px ring,
-- glued to the minimap's ring bottom right (to the square's corner when the minimap is square or
-- the lens is on). Off = ring tickIdle + zoom-in in muted; on = gold ring, gold halo, zoom-out.
-- It exists only inside an instance (owner, point 1), or while the lens is on so it can be
-- closed. Child of the Minimap: it moves, fades and hides with it. Shown and hidden with a fade.
local _, ns = ...
local L = ns.L
local Lens = ns.MinimapLens
local issecretvalue = ns.issecretvalue

local T = {}
ns.MinimapLensTriggers = T

BINDING_HEADER_QDT = "Quantum Dungeon Tools"
BINDING_NAME_QDT_LENS = L.LENS_BINDING

local BINDING = "QDT_LENS"
local SIZE, RING, HALO, ICON = 34, 2, 40, 18   -- artboard px
local FADE = 0.15                              -- Craft motionFast
local GUTTER = 2 / 64                          -- shape_circle.tga draws its disc inside 2 px of 64

local Weave = LibStub and LibStub("Weave-1.0", true)
local button, fade
local target = 0          -- alpha the button is heading to
local inside            -- last IsInInstance() read (nil = unknown)
local openedInside      -- the lens that is on was opened inside an instance

local function UI() return ns.MinimapLensUI end

------------------------------------------------------------------------------
-- Self-check: _checkLens.triggers = { inside, shown, key, opens = {..}, closes = {..} }
------------------------------------------------------------------------------
local LOG = 10
local function log(list, what)
  local root = QuantumDungeonToolsDB
  if type(root) ~= "table" then return end
  root._checkLens = root._checkLens or {}
  local t = root._checkLens.triggers or {}
  root._checkLens.triggers = t
  t[list] = t[list] or {}
  local l = t[list]
  l[#l + 1] = what
  while #l > LOG do table.remove(l, 1) end
  t.inside, t.shown = inside, button and button:IsShown() or false
end

------------------------------------------------------------------------------
-- Reads
------------------------------------------------------------------------------
local function readInside()
  local ok, v = pcall(IsInInstance)
  if not ok or issecretvalue(v) or type(v) ~= "boolean" then return nil end
  return v
end

-- The key bound to the lens, as the client spells it ("Shift-M"), or nil.
local function boundKey()
  local ok, key = pcall(GetBindingKey, BINDING)
  if not ok or issecretvalue(key) or type(key) ~= "string" or key == "" then return nil end
  local okT, text = pcall(GetBindingText, key)
  if okT and not issecretvalue(text) and type(text) == "string" and text ~= "" then return text end
  return key
end

local function squareMinimap()
  local fn = GetMinimapShape
  if type(fn) ~= "function" then return false end
  local ok, shape = pcall(fn)
  return ok and not issecretvalue(shape) and type(shape) == "string" and shape ~= "ROUND"
end

------------------------------------------------------------------------------
-- The magnifier
------------------------------------------------------------------------------
local function circle(parent, layer, size, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  t:SetSize(size, size)
  t:SetPoint("CENTER")
  local Craft = LibStub and LibStub("Craft-2.0", true)
  local file = Craft and Craft.Shapes and Craft.Shapes.Get("circle")
  if file then
    t:SetTexture(Craft.mediaPath .. file)
    t:SetTexCoord(GUTTER, 1 - GUTTER, GUTTER, 1 - GUTTER)
  else
    t:SetTexture("Interface\\Buttons\\WHITE8x8")   -- no Craft: a square button, same colors
  end
  return t
end

local function paint()
  if not button then return end
  local C = ns.Style.C
  local on = UI():IsOn()
  local ring = on and C.gold or C.tickIdle
  local glyph = on and C.gold or C.muted
  button.ring:SetVertexColor(ring.r, ring.g, ring.b, 1)
  button.halo:SetShown(on)
  local Craft = LibStub and LibStub("Craft-2.0", true)
  if Craft and Craft.Icons then Craft.Icons.Apply(button.icon, on and "zoom-out" or "zoom-in", ICON) end
  button.icon:SetVertexColor(glyph.r, glyph.g, glyph.b, 1)
end

-- Glued to the ring (round) or to the corner (square / lens on), from the Minimap's centre.
local function place()
  if not button then return end
  local okS, w, h = pcall(Minimap.GetSize, Minimap)
  if not okS or issecretvalue(w) or issecretvalue(h) then return end
  local x, y = Lens.buttonOffset(w, h, UI():IsOn() or squareMinimap())
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function showTip(owner)
  local key = boundKey()
  local pairs_ = {
    { L.LENS_TIP_CLICK, UI():IsOn() and L.LENS_TIP_OFF or L.LENS_TIP_ON },
    { L.LENS_TIP_KEY, key and ("|cff" .. ns.Style.HEX.cream .. key .. "|r") or L.LENS_TIP_NO_KEY },
  }
  ns.Minimap:ShowTip(owner, L.MW_LENS, pairs_, { logo = false, titleColor = ns.Style.C.gold,
    foot = not key and L.LENS_TIP_HINT or nil })
end

local function fadeTo(to)
  target = to
  if not Weave then
    button:SetAlpha(to)
    button:SetShown(to > 0)
    return
  end
  if not fade then
    fade = { goal = Weave.signal(0) }
    fade.tween = Weave.tween(fade.goal, { duration = FADE, easing = Weave.easing.outQuad })
    fade.effect = Weave.effect(function()
      local v = fade.tween()
      if type(v) ~= "number" then return end
      button:SetAlpha(v)
      if v <= 0.001 and target == 0 then button:Hide() end
    end)
  end
  local from = button:IsShown() and button:GetAlpha() or 0
  if to > 0 then button:Show() end
  fade.goal:set(to)
  fade.tween:snap(from)
end

-- In an instance, or while the lens is on (so the button can close it).
local function update()
  if not button then return end
  local want = inside == true or UI():IsOn()
  if want then place() end
  paint()
  if want and target ~= 1 then fadeTo(1) elseif not want and target ~= 0 then fadeTo(0) end
end

local function build()
  if button or not Minimap then return end
  local C = ns.Style.C
  local b = CreateFrame("Button", "QDT_LensButton", Minimap)
  b:SetSize(SIZE, SIZE)
  b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 10)
  b:RegisterForClicks("LeftButtonUp")
  b.halo = circle(b, "BACKGROUND", HALO, 0)
  b.halo:SetVertexColor(C.gold.r, C.gold.g, C.gold.b, 0.22)
  b.ring = circle(b, "BORDER", SIZE, 0)
  b.fill = circle(b, "ARTWORK", SIZE - 2 * RING, 0)
  b.fill:SetVertexColor(C.panel.r, C.panel.g, C.panel.b, 1)
  b.icon = b:CreateTexture(nil, "OVERLAY")
  b.icon:SetPoint("CENTER")
  b:SetScript("OnClick", function(self)
    ns.Minimap:HideTip()
    T:Toggle("button")
    if self:IsMouseOver() then showTip(self) end
  end)
  b:SetScript("OnEnter", showTip)
  b:SetScript("OnLeave", function() ns.Minimap:HideTip() end)
  b:SetAlpha(0)
  b:Hide()
  button = b
  paint()
  -- The minimap changes size (the lens, EUI's own resize): stay glued to the ring.
  Minimap:HookScript("OnSizeChanged", function() if button:IsShown() then place() end end)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------
-- source: "button", "bind", "slash" (only for the self-check).
function T:Toggle(source)
  local wasOn = UI():IsOn()
  UI():Toggle()
  log(wasOn and "closes" or "opens", source or "?")
end

local function close(reason)
  if not UI():IsOn() then return end
  UI():Off()
  log("closes", reason)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    local now = readInside()
    if now ~= nil then inside = now end
    if Lens.leftInstance(openedInside, inside) then close("left") end
    update()
  end
end)

function T:Init()
  build()
  inside = readInside()
  UI():OnChange(function(on)
    if on then openedInside = inside == true end
    update()
  end)
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  -- Edit Mode does not move the lens (gotcha 17), but the design closes it there.
  if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Enter", function() close("editmode") end, T)
  end
  update()
end

return T
