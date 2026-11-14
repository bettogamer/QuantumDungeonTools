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
C.alertBg     = Style.rgba(HEX.panel, 0.88)     -- 10/10 alert and 8/10 strip (artboard Avisos)
C.goldBorder  = Style.rgba(HEX.gold, 0.6)       -- 8/10 strip border
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
  -- Alerts (artboard Avisos, plan M1 F5): end-of-run toast and the 10/10 / 8/10 notices.
  alertW      = 360,
  alertPadX   = 14,
  alertPadY   = 12,
  alertGap    = 6,   -- between the lines of the 10/10 alert
  alertIconGap = 8,  -- warning icon <-> title
  alertIcon   = 16,
  stripPadY   = 10,  -- the 8/10 strip is one line: 10x14
  alertTop    = 140, -- from the top of the screen (no place in the design: owner may move it)
  alertStack  = 16,  -- between the alert and the toast when both are shown
  toastNameGap = 4,  -- dungeon name -> clock (ui-critic M1, docs/17)
  toastBlockGap = 14, -- clock -> stats -> buttons (ui-critic M1)
  toastDeltaBase = 3, -- lifts the delta onto the clock's baseline (34 vs 16 px)
  toastVsGap  = 6,   -- delta -> "vs record"
  toastHeadH  = 44,  -- header row "Run completada  [NUEVO RÉCORD]" (12 + 14 + ~6 + 12)
  toastStatGap = 8,  -- between the four stat columns
  toastStatKV = 2,   -- stat label <-> value
  toastClockGap = 10, -- big clock <-> delta
}

-- The numbers above and the font sizes below are the CSS px of the design canvas. WoW sizes
-- a font by its LINE box (BettoGeo: ascender + descender = 740 + 192 = 932 of 1000 units), so
-- the same font size draws glyphs 1000/932 bigger than the canvas. The owner keeps the font
-- sizes of the design (2026-11-13), so the GEOMETRY grows by that ratio instead: the widget
-- is ~7 % bigger than the canvas with the canvas proportions (text no longer outgrows bars).
Style.GEO = 1000 / 932
for k, v in pairs(Style.SIZE) do Style.SIZE[k] = math.floor(v * Style.GEO + 0.5) end

-- Main window layout (plan M1 F6b, artboard "Ventana principal · Inicio"), px at scale 1.
Style.WIN = {
  width = 980, height = 640, minWidth = 820, minHeight = 560,
  sidebar = 220, brandH = 64, versionH = 22,
  topBar = 52, padX = 28, padY = 22, gap = 18,
  headH = 74,          -- kicker + title + subtitle, plus its bottom rule
  nowH = 66, openRowH = 44, openColGap = 48, moduleH = 44, moduleGap = 8,
}
for k, v in pairs(Style.WIN) do Style.WIN[k] = math.floor(v * Style.GEO + 0.5) end   -- same ratio as SIZE

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
  -- Alerts and toast: solid panels, so no outline and no shadow (like the compact panel).
  alertTitle  = { size = 14, weight = "semibold", flags = "" },
  alertBody   = { size = 12, weight = "medium", flags = "" },
  alertBodyBold = { size = 12, weight = "bold", flags = "" },  -- the time inside the 10/10 alert
  alertSmall  = { size = 11, weight = "medium", flags = "" },
  toastClock  = { size = 34, weight = "bold", flags = "" },
  toastDelta  = { size = 16, weight = "semibold", flags = "" },   -- ui-critic A1
  toastName   = { size = 13, weight = "medium", flags = "" },     -- dungeon · difficulty (M2)
  toastStat   = { size = 13, weight = "semibold", flags = "" },
  toastTag    = { size = 10, weight = "bold", flags = "" },     -- NEW RECORD: gold block (Oro Forever)
  toastButton = { flags = "" },                                 -- Craft.Button keeps its own size
  panelTag    = { size = 10, weight = "medium", flags = "" },   -- RARE on the compact panel
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

return Style
