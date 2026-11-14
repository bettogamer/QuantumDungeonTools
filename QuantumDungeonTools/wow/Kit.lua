---@diagnostic disable: undefined-global
-- wow/Kit.lua -- the addon's UI building blocks on Craft (plan M1 F6c): the Craft handle, OUR
-- theme context (own one, so Coffer & co. are untouched), BettoGeo text, pixel-perfect borders
-- and outline tags. Addon-level, so the main window works with every module turned off; each
-- module's UI builds on top of it (modules/InstanceTracker/wow/UI.lua adds the HUD shadow, bars
-- and coins). Colors and fonts come from core/Style.lua (or a module Style extending it).
--
-- Started by wow/Bootstrap.lua on PLAYER_LOGIN, BEFORE the modules. Kit:Get() is nil without Craft.
local _, ns = ...

local Kit = {}
ns.Kit = Kit

local THEME_NAME = "QuantumDungeonTools"

local Craft
local ctx
local fontOf = {}   -- FontString -> Style.FONT entry (re-applied on theme / font-metrics change)
local api           -- the table Kit:Get() hands out

local function setColor(tex, c) tex:SetColorTexture(c.r, c.g, c.b, c.a or 1) end

local function applyFont(fs)
  local f = fontOf[fs]
  local weight = f.weight ~= "regular" and f.weight or nil
  ctx:applyFont(fs, ctx:getFont(weight), f.size, f.flags)   -- nil flags: the theme's
end

-- One line of BettoGeo text, kept on our theme: no wrap, the palette's shadow color (offset is
-- the caller's: the HUD uses 1,-1, solid panels 0,0), LEFT unless the caller changes it.
local function newText(parent, font)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fontOf[fs] = font
  applyFont(fs)
  local sh = ns.Style.C.shadow
  fs:SetShadowColor(sh.r, sh.g, sh.b, sh.a)
  fs:SetWordWrap(false)
  return fs
end

local function setText(fs, text, color)
  fs:SetText(text or "")
  if color then fs:SetTextColor(color.r, color.g, color.b, color.a or 1) end
end

-- Re-points a kit FontString at another Style.FONT entry (kept on theme changes).
local function applyFontOf(fs, font)
  if fontOf[fs] ~= font then
    fontOf[fs] = font
    applyFont(fs)
  end
end

-- 1px border (Craft's corner-safe helper) in a given color.
local function newBorder(frame, layer)
  local b = {}
  for i = 1, 4 do b[i] = frame:CreateTexture(nil, layer or "BORDER") end
  Craft.Theme.AnchorBorder(frame, b[1], b[2], b[3], b[4])
  return b
end

local function colorBorder(b, c)
  for i = 1, 4 do setColor(b[i], c) end
end

-- Tag = text with a 1px border and no fill (design: "tags = only border"): a Craft.Badge
-- `outline` with per-instance font, padding and colors (FR-140, Craft 2.48.0). It sizes itself
-- (whole pixels, CSS-centered caps, re-measured next frame) and inherits our theme context.
-- Returns the Badge's frame (what the row chains/shows); the Badge object rides in `.badge`.
-- Padding counts the 1px border; Badge's padding sits inside it, hence the -1.
local function newTag(parent, font, padX, padY)
  local S = ns.Style.SIZE
  local badge = Craft.Badge:Create(parent, {
    variant    = "outline",
    fontSize   = font.size,
    fontWeight = font.weight,
    paddingX   = (padX or S.tagPadX) - 1,
    paddingY   = padY or S.tagPadY,
    fontFlags  = font.flags,   -- nil = the theme's outline (HUD); "" on solid panels (FR-102)
  })
  local frame = badge:GetFrame()
  frame.badge = badge
  return frame
end

local function setTag(tag, text, textColor, borderColor)
  tag.badge:SetColors({ text = textColor, border = borderColor })
  tag.badge:SetText(text)
end

-- nil before Init or without Craft. Callers may copy it and override pieces (module kits).
function Kit:Get() return api end

-- Theme or font-metrics change (first-ever BettoGeo load is async): `fn` runs AFTER every kit
-- FontString has been re-fonted.
function Kit:OnThemeChange(fn)
  if ctx then ctx:register(fn) end
end

-- For /qdt check f2: how many FontStrings the kit keeps on our theme.
function Kit:FontCount()
  local n = 0
  for _ in pairs(fontOf) do n = n + 1 end
  return n
end

function Kit:Init()
  if ctx then return api end
  Craft = LibStub and LibStub("Craft-2.0", true)
  if not Craft then return nil end
  local C = ns.Style.C
  ctx = Craft.Theme.context(THEME_NAME, {
    font = "bettogeo", headingFont = "bettogeo",
    overrides = {
      fontFlags = "OUTLINE, SLUG",   -- vector (Slug) outline: thinner and crisper than bitmap OUTLINE
      -- No regular weight anywhere (core/Style.lua): Craft overlays (tooltip) read `font`, so
      -- the body token is BettoGeo Medium too (owner, 2026-11-13).
      font = Craft.mediaPath .. "BettoGeo-Medium.ttf",
      primary = C.gold, primaryForeground = C.panel,             -- Forever gold on navy (9.7:1)
      sidebarPrimary = C.gold, sidebarPrimaryForeground = C.panel,
      -- Main window sidebar (F6b, artboard Inicio): darker navy, active row in gold.
      sidebar = C.sidebar, sidebarForeground = C.cream, sidebarBorder = C.hairline,
      sidebarAccent = C.sidebarActive, sidebarAccentForeground = C.gold,
      foreground = C.cream, mutedForeground = C.muted,
      popover = C.panel, popoverForeground = C.cream,
      border = C.hairline, destructive = C.red,
    },
  })
  -- Registered first, so module callbacks (Kit:OnThemeChange) see the new fonts.
  ctx:register(function()
    for fs in pairs(fontOf) do applyFont(fs) end
  end)
  api = {
    Craft = Craft, ctx = ctx, newText = newText, setText = setText, setColor = setColor,
    applyFontOf = applyFontOf, newBorder = newBorder, colorBorder = colorBorder,
    newTag = newTag, setTag = setTag,
  }
  return api
end

return Kit
