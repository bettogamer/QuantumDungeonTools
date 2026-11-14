-- modules/InstanceTracker/core/Style.lua -- PURE: the ONLY place with colors and sizes of the
-- Instance Tracker widget (plan M1 F2). No hex anywhere else in the UI: it asks for a TONE
-- (semantic) or a token here.
--
-- Palette sampled from the WoW Forever key art (canvas artboard "Paleta", proposal B, 2026-11-13):
-- gold = progress, turquoise = ahead / record / XP, red = behind / deaths, cream = text.
local _, ns = ...
local Brand = ns.Brand

local Style = {}
ns.InstanceTrackerStyle = Style

-- "F5BF57" (+ alpha) -> { r, g, b, a } in 0..1 (what SetColorTexture / SetTextColor take).
function Style.rgba(hex, a)
  local r, g, b = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
  assert(r, "Style.rgba: bad hex " .. tostring(hex))
  return { r = tonumber(r, 16) / 255, g = tonumber(g, 16) / 255, b = tonumber(b, 16) / 255, a = a or 1 }
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
  panel     = "042239",               -- tooltip / compact panel, cut ticks of a finished run
  tickIdle  = "5A808E",               -- PB split not reached yet
  white     = "FFFFFF",
}
Style.HEX = HEX

local C = {}
for k, v in pairs(HEX) do C[k] = Style.rgba(v) end
C.goldSoft    = Style.rgba(HEX.gold, 0.22)      -- difficulty tag border, compact separators
C.goldHalf    = Style.rgba(HEX.gold, 0.5)       -- "Instances" tag border
C.xpLightHalf = Style.rgba(HEX.xpLight, 0.5)    -- FIRST TIME tag border
C.mutedHalf   = Style.rgba(HEX.muted, 0.5)      -- RARE tag border
C.rested      = Style.rgba(HEX.turquoise, 0.22) -- rested XP extent
C.hairline    = Style.rgba(HEX.white, 0.1)      -- 1px bar borders
C.panelBg     = Style.rgba(HEX.panel, 0.82)     -- compact panel
C.shadow      = { r = 0, g = 0, b = 0, a = 0.9 }
Style.C = C

-- Semantic tones the view model (core/View.lua) speaks -> color.
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

-- Sizes (px at scale 1). Font weights map BettoGeo files: 500/600 medium, 700 bold. No regular:
-- with OUTLINE it reads too thin over the game (owner, 2026-11-12).
Style.SIZE = {
  width     = 340,
  gap       = 6,    -- between stacked rows
  tagPadX   = 6,
  tagPadY   = 2,
  barH      = 14,   -- time bar (owner: 14 px)
  tickW     = 2,
  tickOut   = 3,    -- the tick sticks out of the bar this much, top and bottom
  segH      = 12,   -- first-time boss segments
  segGap    = 3,
  xpBarH    = 8,
  xpTop     = 2,    -- extra space above the XP bar
  xpLabelGap = 3,   -- XP bar -> its two labels (design gap 3)
  clockGap  = 10,   -- between deaths, clock and "/ record" (design gap 10)
  totalsTop = 2,    -- extra space above the totals row
  bossGap   = 3,
  bossTop   = 10,   -- extra space before the boss list (design value; owner 2026-11-13)
  rareTop   = 4,    -- extra space before each rare (design: margin-top 4 on every rare row)
  rareTagPadX = 4,
  rareTagPadY = 1,
  rowGap    = 8,    -- between the pieces of a right-aligned row
  extrasGap = 20,   -- between money and reputation in the totals row (design option B: 20)
  repMinW   = 60,   -- totals row: below this room the faction is hidden instead of cut
  coinSize  = 10,   -- inline coin icons in the totals row (design: 10)
  coinBefore = 2,   -- design: margin 0 5px 0 2px around each coin icon
  coinAfter  = 5,
  compactPadX = 10,
  compactPadY = 6,
  compactSep  = 14, -- height of the compact separators
  compactGap  = 10, -- between every piece of the compact bar (design)
  panelW      = 260, -- compact hover panel (artboard Compacto): fixed width
  panelTop    = 10,  -- panel below the compact bar, right edges aligned
  panelPadX   = 12,
  panelPadY   = 10,
  panelGap    = 6,   -- between the panel's lines (separators included)
  panelColGap = 8,   -- left text <-> right column
  panelTagGap = 6,   -- rare name <-> its RARE badge
  detailW     = 300, -- hover detail tooltip (artboard Detalle, Craft.Tooltip FR-150)
  detailPad   = 12,
  detailRowGap = 4,  -- between the lines of a section
  detailSecGap = 10, -- between sections (no hairline)
  infoSep     = 10, -- each side of the "·" in the info row (design gap 10)
  pingIcon    = 13, -- crosshair left of a live boss name on hover (artboard Ping, variant B)
  pingPadX    = 12, -- its small tooltip: padding 8x12, 4 px between the two lines
  pingPadY    = 8,
  pingGap     = 4,
}

-- The numbers above and the font sizes below are the CSS px of the design canvas. WoW sizes
-- a font by its LINE box (BettoGeo: ascender + descender = 740 + 192 = 932 of 1000 units), so
-- the same font size draws glyphs 1000/932 bigger than the canvas. The owner keeps the font
-- sizes of the design (2026-11-13), so the GEOMETRY grows by that ratio instead: the widget
-- is ~7 % bigger than the canvas with the canvas proportions (text no longer outgrows bars).
Style.GEO = 1000 / 932
for k, v in pairs(Style.SIZE) do Style.SIZE[k] = math.floor(v * Style.GEO + 0.5) end

-- `flags` overrides the theme outline ("OUTLINE, SLUG") for one element: the Slug outline is
-- vector and grows with the font size, so the big clock blurs with it; there the classic ~1 px
-- OUTLINE reads better (owner, 2026-11-13).

Style.FONT = {
  head      = { size = 12, weight = "medium" },
  tag       = { size = 11, weight = "medium" },
  tagStrong = { size = 11, weight = "bold" },
  deaths    = { size = 12, weight = "medium" },
  clock     = { size = 42, weight = "bold", flags = "OUTLINE" },
  ref       = { size = 16, weight = "medium" },
  info      = { size = 12, weight = "medium" },
  small     = { size = 11, weight = "medium" },
  bossName  = { size = 15, weight = "medium" },
  bossTime  = { size = 13, weight = "medium" },
  bossDelta = { size = 11, weight = "medium" },
  rareName  = { size = 13, weight = "medium" },
  rareTime  = { size = 12, weight = "medium" },
  rareTag   = { size = 10, weight = "medium" },
  compact   = { size = 13, weight = "medium" },
  compactSm = { size = 11, weight = "medium" },
  -- Compact hover panel: solid background, so no outline (flags "") and no shadow.
  panel     = { size = 12, weight = "medium", flags = "" },
  panelSm   = { size = 11, weight = "medium", flags = "" },
  detail      = { size = 12, weight = "medium" },     -- detail tooltip rows
  detailTitle = { size = 11, weight = "semibold" },   -- its section titles (Craft: the medium file)
  pingName    = { size = 12, weight = "medium" },     -- ping tooltip: boss name (cream)
  pingHint    = { size = 11, weight = "medium" },     -- ping tooltip: "Click: attack ping" (muted)
}

return Style
