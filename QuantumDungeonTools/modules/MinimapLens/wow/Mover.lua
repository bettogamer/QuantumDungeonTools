---@diagnostic disable: undefined-global
-- modules/MinimapLens/wow/Mover.lua -- «Move the lens» (plan M2 F5, artboard LensMover).
--
-- A stand-in square where the lens goes (its real size), opened from the module page: gold
-- 1 px edge over a gold wash, an inner guide line, the move glyph, «Minimap Lens» and «Drag to
-- place it · 260%», a gold name tag over its top-left corner and, under it, «Reset position»
-- and «Done». Dragging it writes db.minimapLens.pos (UI:SetPosition, live when the lens is on).
-- Only «Done» and Esc close it (it is not tied to the page). The inner line is solid: the
-- artboard's dashed line has no native texture (no FR: the design bends to what exists).
local _, ns = ...
local L = ns.L
local Lens = ns.MinimapLens
local issecretvalue = ns.issecretvalue

local M = {}
ns.MinimapLensMover = M

local INSET = 10        -- artboard: 300 px square, 280 px guide inside
local GLYPH = 26
local TAG_GAP = 5       -- tag bottom over the square's top edge
local BUTTON_GAP = 12   -- square -> buttons
local FADE = 0.15

local frame, sub, kit
local listeners = {}

local function UI() return ns.MinimapLensUI end

local function notify()
  local shown = frame ~= nil and frame:IsShown()
  for _, fn in ipairs(listeners) do pcall(fn, shown) end
end

local function num(v) return (not issecretvalue(v) and type(v) == "number") and v or nil end

local function place()
  local g = UI():Geometry()
  if not g then return false end
  frame:SetSize(g.side, g.side)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", g.x, g.y)
  sub:SetText(L.LENS_MOVER_SUB:format(Lens.percent(Lens.get(ns.db.minimapLens, "size"))))
  return true
end

local function drop()
  frame:StopMovingOrSizing()
  pcall(frame.SetUserPlaced, frame, false)
  local cx, cy = frame:GetCenter()
  local uw, uh = UIParent:GetSize()
  local pos = Lens.centerOffset(num(cx), num(cy), num(uw), num(uh))
  if pos then UI():SetPosition(pos) end
  place()
end

local function text(parent, font, color)
  local fs = kit.newText(parent, font)
  fs:SetShadowOffset(0, 0)
  fs:SetTextColor(color.r, color.g, color.b, color.a or 1)
  return fs
end

local function build()
  kit = ns.Kit and ns.Kit:Get()
  if not kit then return false end
  local Craft = kit.Craft
  local Style = ns.Style
  local C, FONT = Style.C, Style.FONT

  local f = CreateFrame("Frame", "QDT_LensMover", UIParent)
  Craft.Theme.resolve(nil, { theme = kit.ctx }, f)   -- the buttons inherit our context
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", drop)
  f:Hide()

  local wash = f:CreateTexture(nil, "BACKGROUND")
  wash:SetAllPoints()
  kit.setColor(wash, C.goldHover)
  kit.colorBorder(kit.newBorder(f), C.gold)
  local guide = CreateFrame("Frame", nil, f)
  guide:SetPoint("TOPLEFT", INSET, -INSET)
  guide:SetPoint("BOTTOMRIGHT", -INSET, INSET)
  kit.colorBorder(kit.newBorder(guide), Style.rgba(Style.HEX.gold, 0.6))

  local title = text(f, FONT.winModule, C.cream)
  title:SetPoint("CENTER", 0, 0)
  title:SetText(L.MW_LENS)
  local glyph = f:CreateTexture(nil, "ARTWORK")
  Craft.Icons.Apply(glyph, "move", GLYPH)
  glyph:SetSize(GLYPH, GLYPH)
  glyph:SetVertexColor(C.gold.r, C.gold.g, C.gold.b, 1)
  glyph:SetPoint("BOTTOM", title, "TOP", 0, 6)
  sub = text(f, FONT.winRowSub, C.muted)
  sub:SetPoint("TOP", title, "BOTTOM", 0, -6)

  -- Name tag: solid gold, navy bold text (artboard), over the top-left corner.
  local tag = CreateFrame("Frame", nil, f)
  local tagBg = tag:CreateTexture(nil, "BACKGROUND")
  tagBg:SetAllPoints()
  kit.setColor(tagBg, C.gold)
  local tagText = text(tag, FONT.winSection, C.panel)
  tagText:SetPoint("CENTER")
  tagText:SetText(L.MW_LENS)
  tag:SetSize(math.ceil(tagText:GetStringWidth()) + 16, 18)
  tag:SetPoint("BOTTOMLEFT", f, "TOPLEFT", -1, TAG_GAP)

  local bar = CreateFrame("Frame", nil, f)
  bar:SetSize(1, 30)
  bar:SetPoint("TOP", f, "BOTTOM", 0, -BUTTON_GAP)
  local reset = Craft.Button:Create(bar, { text = L.LENS_MOVER_RESET, variant = "outline", size = "sm",
    fontFlags = "", onClick = function()
      UI():SetPosition(nil)
      place()
    end })
  local done = Craft.Button:Create(bar, { text = L.LENS_MOVER_DONE, size = "sm", fontFlags = "",
    onClick = function() M:Stop() end })
  local rf, df = reset:GetFrame(), done:GetFrame()
  rf:SetPoint("RIGHT", bar, "CENTER", -4, 0)
  df:SetPoint("LEFT", bar, "CENTER", 4, 0)

  f:SetScript("OnHide", notify)
  f:SetScript("OnShow", notify)
  tinsert(UISpecialFrames, "QDT_LensMover")   -- Esc closes it
  frame = f
  return true
end

local function fadeIn()
  local Weave = LibStub and LibStub("Weave-1.0", true)
  if not Weave then frame:SetAlpha(1) return end
  if not M.fx then
    M.goal = Weave.signal(1)
    M.tween = Weave.tween(M.goal, { duration = FADE, easing = Weave.easing.outQuad })
    M.fx = Weave.effect(function()
      local v = M.tween()
      if type(v) == "number" and frame then frame:SetAlpha(v) end
    end)
  end
  M.tween:snap(0)
  M.goal:set(1)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------
function M:Start()
  if not frame and not build() then return false end
  if not place() then return false end
  frame:Show()
  fadeIn()
  return true
end

function M:Stop()
  if frame then frame:Hide() end
end

function M:Toggle()
  if self:IsShown() then self:Stop() else self:Start() end
end

function M:IsShown() return frame ~= nil and frame:IsShown() end

-- The size slider moved: the square follows.
function M:Refresh()
  if self:IsShown() then place() end
end

-- fn(shown) after it opens or closes (the page's button label).
function M:OnChange(fn) listeners[#listeners + 1] = fn end

return M
