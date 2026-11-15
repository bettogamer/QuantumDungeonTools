-- core/Style.lua -- PURE: the addon-level design tokens (palette roles, tones, the main window's
-- sizes and fonts). Every module's own Style inherits from this one and only adds what is its
-- own (modules/InstanceTracker/core/Style.lua: widget sizes, fonts and alpha variants). Living
-- here, the main window does not depend on any module being enabled (plan M1 F6c).
--
-- Palette sampled from the WoW Forever key art (canvas artboard "Paleta", proposal B, 2026-11-13):
-- gold = progress, turquoise = ahead / record / XP, red = behind / deaths, cream = text.
local _, ns = ...
local Brand = ns.Brand

local Style = {}
ns.Style = Style

-- "F5BF57" (+ alpha) -> { r, g, b, a } in 0..1 (what SetColorTexture / SetTextColor take).
function Style.rgba(hex, a)
  local r, g, b = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
  assert(r, "Style.rgba: bad hex " .. tostring(hex))
  return { r = tonumber(r, 16) / 255, g = tonumber(g, 16) / 255, b = tonumber(b, 16) / 255, a = a or 1 }
end

-- `top` drawn at alpha `a` over the opaque `base`: the color the eye sees (for opaque-only sinks).
function Style.over(base, top, a)
  local function ch(k) return base[k] + (top[k] - base[k]) * a end
  return { r = ch("r"), g = ch("g"), b = ch("b"), a = 1 }
end

local HEX = {
  gold      = Brand.COLORS.primary,   -- F5BF57
  turquoise = Brand.COLORS.accent,    -- 36C9E8
  cream     = Brand.COLORS.text,      -- F7EDDC
  red       = Brand.COLORS.danger,    -- FF6B4F
  muted     = "93B6C2",               -- secondary text (foam toward sea)
  sand      = "E6D2A9",               -- difficulty tag text (parchment)
  xpLight   = "8FE3F5",               -- XP numbers, FIRST TIME tag
  xpBase    = Brand.COLORS.sea,       -- 0A8FB0, XP owned before the run
  track     = "06364A",               -- bar track (abyss)
  panel     = "042239",               -- solid panels (window, tooltip, compact panel)
  tickIdle  = "5A808E",               -- PB split not reached yet, SOON tag text
  white     = "FFFFFF",
}
Style.HEX = HEX

local C = {}
for k, v in pairs(HEX) do C[k] = Style.rgba(v) end
C.hairline    = Style.rgba(HEX.white, 0.1)      -- 1px borders (Craft `border` token)
C.shadow      = { r = 0, g = 0, b = 0, a = 0.9 }
-- Main window (plan M1 F6b, artboard "Ventana principal · Inicio"): same roles, other alphas.
C.goldCard    = Style.rgba(HEX.gold, 0.35)      -- NOW card border
C.goldWash    = Style.rgba(HEX.gold, 0.05)      -- NOW card fill
C.hairlineSoft = Style.rgba(HEX.white, 0.06)    -- OPEN row dividers, idle module card
C.mutedTag    = Style.rgba(HEX.muted, 0.35)     -- SOON tag border
-- Craft paints the sidebar fill and its active row OPAQUE (alpha forced to 1), so the canvas'
-- "navy + black 22 %" and "gold 8 % on it" are pre-composited here from the same roles.
C.sidebar       = Style.over(C.panel, { r = 0, g = 0, b = 0 }, 0.22)
C.sidebarActive = Style.over(C.sidebar, C.gold, 0.08)
Style.C = C

-- Semantic tones the view models speak -> color.
Style.TONE = {
  text     = C.cream,
  muted    = C.muted,
  progress = C.gold,
  ahead    = C.turquoise,
  behind   = C.red,
  pending  = C.tickIdle,
  cut      = C.panel,
  pre      = C.muted,
  idle     = C.track,
  xp       = C.xpLight,
}

function Style.tone(name) return Style.TONE[name] or C.cream end

-- "|cffRRGGBB" escape for inline runs of text inside one FontString.
function Style.code(name)
  local c = Style.TONE[name] or C[name] or C.cream
  return string.format("|cff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5),
    math.floor(c.b * 255 + 0.5))
end

-- The sizes below are the CSS px of the design canvas. WoW sizes a font by its LINE box
-- (BettoGeo: ascender + descender = 740 + 192 = 932 of 1000 units), so the same font size draws
-- glyphs 1000/932 bigger than the canvas. The owner keeps the font sizes of the design
-- (2026-11-13), so the GEOMETRY grows by that ratio instead (canvas proportions, ~7 % bigger).
Style.GEO = 1000 / 932
local function scale(t)
  for k, v in pairs(t) do t[k] = math.floor(v * Style.GEO + 0.5) end
  return t
end
Style.scale = scale

-- Shared sizes (px at scale 1): what the addon-level building blocks (wow/Kit.lua) default to.
Style.SIZE = scale({
  tagPadX = 6,   -- tag = 1px border + text (design: "tags = only border")
  tagPadY = 2,
})

-- Main window layout (plan M1 F6b, artboard "Ventana principal · Inicio"), px at scale 1.
Style.WIN = scale({
  width = 980, height = 640, minWidth = 820, minHeight = 560,
  sidebar = 220, brandH = 64, versionH = 22,
  topBar = 52, padX = 28, padY = 22, gap = 18,
  headH = 74,          -- kicker + title + subtitle, plus its bottom rule
  nowH = 66, openRowH = 44, openColGap = 48, moduleH = 44, moduleGap = 8,
})

-- General settings page (F6e, artboard "Ajustes generales"): a card of one two-line setting.
Style.WIN.cardH = math.floor(56 * Style.GEO + 0.5)   -- padding 12 + 14 title + 2 + 11 hint + 12 (+ air)
Style.WIN.cardPadX = math.floor(16 * Style.GEO + 0.5)
Style.WIN.dot = 5                                     -- gold "changed from its default" dot

-- Minimap icon tooltip (F6e, artboard "Icono del minimapa", SMRT pattern): the button's OWN
-- GameTooltip with Inter (Craft media) and the icon off its left edge.
Style.TIP = {
  icon = [[Interface\Icons\INV_Misc_PocketWatch_01]],   -- provisional Blizzard icon (owner, 2026-11-14)
  logo = 48,
  titleFont = "Inter-Bold.ttf", titleSize = 14,
  lineFont = "Inter-Regular.ttf", lineSize = 12,
}

-- Font weights map BettoGeo files: 500/600 medium, 700 bold. No regular: with OUTLINE it reads
-- too thin over the game (owner, 2026-11-12). `flags` overrides the theme outline
-- ("OUTLINE, SLUG") for one element; "" = no outline (solid panels).
Style.FONT = {
  -- Main window (F6b): a solid panel, so no outline anywhere.
  winBrand    = { size = 17, weight = "bold", flags = "" },     -- "Quantum" on the sidebar
  winBrandSub = { size = 10, weight = "semibold", flags = "" }, -- "DUNGEON TOOLS"
  winVersion  = { size = 10, weight = "medium", flags = "" },
  winKicker   = { size = 11, weight = "medium", flags = "" },   -- addon name over the page title
  winTitle    = { size = 26, weight = "semibold", flags = "" },
  winSub      = { size = 12, weight = "medium", flags = "" },
  winSection  = { size = 11, weight = "semibold", flags = "" }, -- NOW / OPEN / MODULES
  winNowName  = { size = 15, weight = "semibold", flags = "" },
  winNowLine  = { size = 12, weight = "medium", flags = "" },
  winClock    = { size = 26, weight = "bold", flags = "" },
  winDelta    = { size = 11, weight = "medium", flags = "" },
  winHourNum  = { size = 18, weight = "bold", flags = "" },
  winRow      = { size = 13, weight = "medium", flags = "" },
  winRowSub   = { size = 11, weight = "medium", flags = "" },
  winModule   = { size = 14, weight = "semibold", flags = "" },
  winTag      = { size = 9, weight = "semibold", flags = "" },  -- SOON
}

-- A module's Style: inherits every function and token above, adds its own on top.
-- `own` = { C = {...}, SIZE = {...unscaled}, FONT = {...} }; any of them may be nil.
function Style.extend(own)
  own = own or {}
  local S = setmetatable({}, { __index = Style })
  S.C = setmetatable(own.C or {}, { __index = C })
  S.SIZE = setmetatable(scale(own.SIZE or {}), { __index = Style.SIZE })
  S.FONT = setmetatable(own.FONT or {}, { __index = Style.FONT })
  return S
end

return Style
