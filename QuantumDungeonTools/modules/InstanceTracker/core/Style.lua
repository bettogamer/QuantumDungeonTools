-- modules/InstanceTracker/core/Style.lua -- PURE: the ONLY place with the colors and sizes of
-- the Instance Tracker widget (plan M1 F2). No hex anywhere else in the UI: it asks for a TONE
-- (semantic) or a token here. Palette roles, tones, rgba/code and the main window tokens are
-- addon-level (core/Style.lua): this file inherits them (Style.extend) and adds the widget's own.
local _, ns = ...
local Base = ns.Style
local rgba, HEX = Base.rgba, Base.HEX

-- Widget-only alpha variants of the palette roles (the roles themselves live in core/Style.lua).
local C = {
  goldSoft    = rgba(HEX.gold, 0.22),      -- difficulty tag border, compact separators
  goldHalf    = rgba(HEX.gold, 0.5),       -- "Instances" tag border
  xpLightHalf = rgba(HEX.xpLight, 0.5),    -- FIRST TIME tag border
  mutedHalf   = rgba(HEX.muted, 0.5),      -- RARE tag border
  rested      = rgba(HEX.turquoise, 0.22), -- rested XP extent
  panelBg     = rgba(HEX.panel, 0.82),     -- compact panel
  alertBg     = rgba(HEX.panel, 0.88),     -- 10/10 alert and 8/10 strip (artboard Avisos)
  goldBorder  = rgba(HEX.gold, 0.6),       -- 8/10 strip border
  recordWash  = rgba(HEX.turquoise, 0.08), -- History row that set the record
}

-- Sizes (canvas px; Style.extend scales them by Base.GEO, see core/Style.lua). tagPadX/Y are
-- inherited from the addon level.
local SIZE = {
  width     = 340,
  gap       = 6,    -- between stacked rows
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
  toastButtonGap = 8, -- "History" <- "Share with group" (design gap 8)
  toastHeadH  = 44,  -- header row "Run completada  [NUEVO RÉCORD]" (12 + 14 + ~6 + 12)
  toastStatGap = 8,  -- between the four stat columns
  toastStatKV = 2,   -- stat label <-> value
  toastClockGap = 10, -- big clock <-> delta
  -- Module page of the main window (F6c, artboard «Instance Tracker · Resumen»).
  pageTop     = 16,  -- tab bar -> first block label
  pageLabelGap = 10, -- block label -> its card
  pageBlockGap = 16, -- card -> next block label (gap 10 + margin-top 6)
  pagePadX    = 16,  -- inside cards and setting cells
  pageCardH   = 44,  -- MODULE card (padding 12 + 18 switch + 12)
  pageFoldH   = 40,  -- «Qué enseña» header (padding 11 + 14 title + 11)
  pageRowH    = 46,  -- a setting cell (padding 9 + 13 label + 1 + 11 hint + 9)
  pageFootH   = 30,  -- «N cambiados · Restablecer» footer
  pageRunH    = 48,  -- RUN rows (padding 10 + 28 button + 10)
  pageRunGap  = 10,  -- between the two RUN rows
  pageIcon    = 14,  -- chevrons
  pageIconGap = 10,
  pageDot     = 5,   -- the gold "changed" dot
  pageSelectW = 130,
  pageBottom  = 16,  -- room under the last block (scroll)
  -- History tab (F6d, artboard «Instance Tracker · Historial»).
  histBarH    = 52,  -- filter bar (padding 12 + 28 select + 12)
  histLabelGap = 8,  -- filter label -> its select (gap 8)
  histGroupGap = 16, -- select -> next filter label (gap 8 + margin-left 8)
  histDungeonW = 180,
  histDiffW   = 110,
  histCharW   = 120,
  histHeadH   = 30,  -- column header (padding 8 + 14 + 8)
  histRowH    = 32,  -- a run row (padding 9 + 14 + 9)
  histGap     = 8,   -- between columns
  histPadX    = 4,   -- row padding left and right
  histFootH   = 36,  -- "12 runs · mean · record" footer (padding 10 + 14 + 12)
}

-- `flags` overrides the theme outline ("OUTLINE, SLUG") for one element: the Slug outline is
-- vector and grows with the font size, so the big clock blurs with it; there the classic ~1 px
-- OUTLINE reads better (owner, 2026-11-13).

local FONT = {
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
  -- History tab of the main window (solid panel: no outline).
  histHead    = { size = 11, weight = "semibold", flags = "" }, -- column titles
  histCell    = { size = 12, weight = "medium", flags = "" },
  histHour    = { size = 12, weight = "bold", flags = "" },     -- "8/10"
}

local Style = Base.extend({ C = C, SIZE = SIZE, FONT = FONT })
ns.InstanceTrackerStyle = Style

return Style
