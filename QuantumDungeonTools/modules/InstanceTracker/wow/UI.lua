---@diagnostic disable: undefined-global
-- modules/InstanceTracker/wow/UI.lua -- the Instance Tracker widget (plan M1 F2), on Craft.
--
-- A transparent HUD (no background: legibility comes from OUTLINE + shadow), right-aligned,
-- following the design canvas: header (dungeon + difficulty tag), big clock with the record or
-- the FIRST TIME tag, info line, 14 px time bar (or boss segments without a record), XP bar,
-- contextual "Instances X/10" and the boss list with splits and deltas. Compact mode = one line
-- on a panel, with the boss list in a Craft.Tooltip on hover.
--
-- WHAT to paint comes from core/View.lua (pure, tested); colors and sizes ONLY from
-- core/Style.lua. Craft gives the theme context (own one, so Coffer & co. are untouched), the
-- BettoGeo fonts (applyFont arms the async font probes), the pixel-perfect border and the tooltip.
-- Only the header row (or the compact panel) takes the mouse: the rest is click-through.
local _, ns = ...
local L, T = ns.L, ns.InstanceTracker
local View, Style, Demo = ns.InstanceTrackerView, ns.InstanceTrackerStyle, ns.InstanceTrackerDemo
local Detail, Records = ns.InstanceTrackerDetail, ns.InstanceRecords
local S, C, FONT = Style.SIZE, Style.C, Style.FONT

local UI = {}
ns.InstanceTrackerUI = UI

local THEME_NAME = "QuantumDungeonTools"
local TICK = 0.5

local Craft            -- resolved in Init (LibStub)
local ctx              -- our Craft theme context
local root             -- position anchor, holds both layouts
local W = {}           -- widgets of the full layout
local K = {}           -- widgets of the compact layout
local fontOf = {}      -- FontString -> Style.FONT entry (re-applied on theme / font-metrics change)
local forced           -- nil (automatic) | "show" | "hide"; reset on every zone change
local demo             -- nil | scenario name of core/Demo.lua
local lastView         -- what was painted last (the tick repaints only when the clock moves)

local function db() return ns.db.instanceTracker end

-- BettoGeo: descender 192 of a 932 line box (hhea; the Win metrics give the same ~20 %), so
-- the baseline sits that fraction of the measured line height above the FontString's bottom.
local DESCENT = 192 / 932

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------
local function setColor(tex, c) tex:SetColorTexture(c.r, c.g, c.b, c.a or 1) end

local function applyFont(fs)
  local f = fontOf[fs]
  local weight = f.weight ~= "regular" and f.weight or nil
  ctx:applyFont(fs, ctx:getFont(weight), f.size, f.flags)   -- nil flags: the theme's
end

local function newText(parent, font)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fontOf[fs] = font
  applyFont(fs)
  fs:SetShadowColor(C.shadow.r, C.shadow.g, C.shadow.b, C.shadow.a)
  fs:SetShadowOffset(1, -1)
  fs:SetWordWrap(false)
  fs:SetJustifyH("RIGHT")
  return fs
end

local function setText(fs, text, color)
  fs:SetText(text or "")
  if color then fs:SetTextColor(color.r, color.g, color.b, color.a or 1) end
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
-- S.tagPad* count the 1px border; Badge's padding sits inside it, hence the -1.
local function newTag(parent, font, padX, padY)
  local badge = Craft.Badge:Create(parent, {
    variant    = "outline",
    fontSize   = font.size,
    fontWeight = font.weight,
    paddingX   = (padX or S.tagPadX) - 1,
    paddingY   = padY or S.tagPadY,
  })
  local frame = badge:GetFrame()
  frame.badge = badge
  return frame
end

local function setTag(tag, text, textColor, borderColor)
  tag.badge:SetColors({ text = textColor, border = borderColor })
  tag.badge:SetText(text)
end

-- Chains the shown regions right-to-left inside `row` (pieces[1] is the rightmost).
-- `point` = "" centers them vertically ("BOTTOM" aligns box bottoms: use chainBaseline for text).
local function chain(row, pieces, point, gap)
  local prev
  for _, r in ipairs(pieces) do
    if r:IsShown() then
      r:ClearAllPoints()
      if prev then
        r:SetPoint(point .. "RIGHT", prev, point .. "LEFT", -(gap or S.rowGap), 0)
      else
        r:SetPoint(point .. "RIGHT", row, point .. "RIGHT", 0, 0)
      end
      prev = r
    end
  end
end

local function heightOf(pieces)
  local h = 0
  for _, r in ipairs(pieces) do
    if r:IsShown() then
      local rh = r.GetStringHeight and r:GetStringHeight() or r:GetHeight()
      if rh > h then h = rh end
    end
  end
  return math.ceil(h)
end

-- Baseline alignment (design: align-items: baseline). Anchoring by BOTTOM is not enough: the
-- descender gap grows with the font size, so 12 px text beside the 42 px clock sat ~6 px low.
-- DESCENT (top of file) gives the baseline inside a FontString.
local function descentOf(r)
  if r.GetStringHeight then return r:GetStringHeight() * DESCENT end
  if r.badge then return r.badge:GetBaselineOffset() end   -- tag (Craft.Badge)
  return 0
end

local function heightRaw(r)
  return r.GetStringHeight and r:GetStringHeight() or r:GetHeight()
end

-- Chains the shown pieces right-to-left on a common baseline; returns the row height.
local function chainBaseline(row, pieces, gap)
  local shown, dmax = {}, 0
  for _, r in ipairs(pieces) do
    if r:IsShown() then
      shown[#shown + 1] = r
      local d = descentOf(r)
      if d > dmax then dmax = d end
    end
  end
  local h, prev, dprev = 0, nil, 0
  for _, r in ipairs(shown) do
    local d = descentOf(r)
    r:ClearAllPoints()
    if prev then
      r:SetPoint("BOTTOMRIGHT", prev, "BOTTOMLEFT", -(gap or S.rowGap), dprev - d)
    else
      r:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, dmax - d)
    end
    local top = heightRaw(r) - d + dmax
    if top > h then h = top end
    prev, dprev = r, d
  end
  return math.ceil(h)
end

-- "+4 [gold] 12 [silver]" with the game's coin icons at a fixed, measurable size. Pattern from
-- Coffer MoneyDisplay.Format: auto-sized icons (":0:0:") measure ~0 px and the last token of the
-- string is dropped from the measurement, hence the pinned size and the closing space.
local function moneyText(copper)
  local s = GetMoneyString and GetMoneyString(copper, true) or GetCoinTextureString(copper)
  s = s:gsub("|T([^|:]+):[^|]*|t", " |T%1:" .. S.coinSize .. "|t")
  return "+" .. s .. " "
end

-- "+350 Undercity": the amount in cream, the faction in the row's muted color.
local function repText(rep)
  local sign = rep.amount > 0 and "+" or ""
  return Style.code("text") .. sign .. rep.amount .. "|r " .. rep.name
end

local function newRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(S.width)
  return row
end

------------------------------------------------------------------------------
-- Position
------------------------------------------------------------------------------
local function savePosition()
  local right, top = root:GetRight(), root:GetTop()
  local pr, pt = UIParent:GetRight(), UIParent:GetTop()
  if right and top and pr and pt then
    db().pos = { "TOPRIGHT", "TOPRIGHT", right - pr, top - pt }
  end
end

local function restorePosition()
  root:ClearAllPoints()
  local p = db().pos
  if p then
    root:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    root:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -200)
  end
end

-- The header row / compact panel move the whole widget; right click hides it.
local function makeHandle(frame)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() root:StartMoving() end)
  frame:SetScript("OnDragStop", function()
    root:StopMovingOrSizing()
    savePosition()
  end)
  frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then UI:Hide() end
  end)
end

------------------------------------------------------------------------------
-- Hover detail (F4b, artboard «Detalle»)
------------------------------------------------------------------------------
-- The detail needs the history and the group: read only on hover, never on the clock tick.
local function detailSource()
  if demo then return Demo.get(demo) end
  local run = T.run
  if not run then return nil end
  return run, {
    xp = T:XPSnapshot(), history = T:History(), record = Records.get(db().records, run),
    group = T:GroupKey(),
  }
end

local SECTION_TITLE = { pace = "IT_D_PACE", rep = "IT_D_REP", records = "IT_D_RECORDS" }

local function detailRow(r)
  local left, right
  if r.id == "xpHour" then
    left, right = L.IT_D_XP_HOUR, r.text
  elseif r.id == "goldHour" then
    left, right = L.IT_D_GOLD_HOUR, moneyText(r.copper):sub(2)   -- a rate: no "+"
  elseif r.id == "toLevel" then
    left, right = L.IT_D_TO_LEVEL:format(r.level), (r.runs == 1 and L.IT_D_RUN or L.IT_D_RUNS):format(r.runs)
  elseif r.id == "faction" then
    left, right = r.name, (r.amount > 0 and "+" or "") .. r.amount
  elseif r.id == "personal" then
    left, right = L.IT_D_PERSONAL, r.text
  elseif r.id == "group" then
    left, right = L.IT_D_GROUP:format(r.runs), r.text
  elseif r.id == "nextSlot" or r.id == "thenSlot" then
    left = r.id == "nextSlot" and L.IT_D_NEXT_SLOT or L.IT_D_THEN_SLOT
    right = L.IT_D_IN:format(r.text)
  end
  return { left, right, leftColor = C.cream, rightColor = Style.tone(r.tone) }
end

local function detailLines()
  local run, opts = detailSource()
  local sections = Detail.build(run, opts)
  if #sections == 0 then return { { L.IT_D_EMPTY, leftColor = C.muted } } end
  local lines = {}
  for i, sec in ipairs(sections) do
    local title = sec.id == "instances" and L.IT_D_INSTANCES:format(sec.count, sec.limit) or L[SECTION_TITLE[sec.id]]
    lines[#lines + 1] = { title, leftColor = C.muted, separator = i > 1 or nil }
    for _, r in ipairs(sec.rows) do lines[#lines + 1] = detailRow(r) end
  end
  return lines
end

-- Hover without eating clicks: the HUD is transparent and must not block the world under it.
local function attachDetail(frame, catchHover)
  if catchHover then
    if frame.SetMouseMotionEnabled then
      frame:SetMouseMotionEnabled(true)
      if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
    else
      frame:EnableMouse(true)
    end
  end
  Craft.Tooltip.Attach(frame, { lines = detailLines, fontFlags = "", side = "left", delay = 150 })
end

------------------------------------------------------------------------------
-- Full layout
------------------------------------------------------------------------------
local function buildFull()
  local full = CreateFrame("Frame", nil, root)
  full:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
  full:SetWidth(S.width)
  W.frame = full

  -- Header: dungeon + difficulty tag (the drag handle)
  W.head = newRow(full)
  makeHandle(W.head)
  W.name = newText(W.head, FONT.head)
  W.diff = newTag(W.head, FONT.tag)

  -- Clock row: deaths, clock, "/ record" or FIRST TIME
  W.clockRow = newRow(full)
  W.deaths = newText(W.clockRow, FONT.deaths)
  W.clock = newText(W.clockRow, FONT.clock)
  W.ref = newText(W.clockRow, FONT.ref)
  W.strike = W.clockRow:CreateTexture(nil, "OVERLAY", nil, 7)
  W.strike:SetPoint("LEFT", W.ref, "LEFT", -1, 0)
  W.strike:SetPoint("RIGHT", W.ref, "RIGHT", 1, 0)
  W.strike:SetHeight(2)
  W.first = newTag(W.clockRow, FONT.tagStrong)

  -- Info row: "Bosses 3/7 · vs. record -0:17" (+ NEW RECORD tag)
  W.infoRow = newRow(full)
  W.info = newText(W.infoRow, FONT.info)
  W.record = newTag(W.infoRow, FONT.tagStrong)

  -- Time bar (with record) / boss segments (first time)
  W.bar = newRow(full)
  W.bar:SetHeight(S.barH)
  W.barTrack = W.bar:CreateTexture(nil, "BACKGROUND")
  W.barTrack:SetAllPoints()
  W.barBorder = newBorder(W.bar)
  W.barFill = W.bar:CreateTexture(nil, "ARTWORK")
  W.barFill:SetPoint("TOPLEFT", W.bar, "TOPLEFT", 0, 0)
  W.barFill:SetPoint("BOTTOMLEFT", W.bar, "BOTTOMLEFT", 0, 0)
  W.ticks = {}
  W.segRow = newRow(full)
  W.segRow:SetHeight(S.segH)
  W.segs = {}

  -- XP: bar (before the run / gained / rested) + two labels
  W.xp = newRow(full)
  W.xpBar = CreateFrame("Frame", nil, W.xp)
  W.xpBar:SetPoint("TOPLEFT", W.xp, "TOPLEFT", 0, 0)
  W.xpBar:SetPoint("TOPRIGHT", W.xp, "TOPRIGHT", 0, 0)
  W.xpBar:SetHeight(S.xpBarH)
  W.xpTrack = W.xpBar:CreateTexture(nil, "BACKGROUND")
  W.xpTrack:SetAllPoints()
  W.xpBorder = newBorder(W.xpBar)
  W.xpRested = W.xpBar:CreateTexture(nil, "ARTWORK", nil, 1)
  W.xpCur = W.xpBar:CreateTexture(nil, "ARTWORK", nil, 2)
  W.xpBase = W.xpBar:CreateTexture(nil, "ARTWORK", nil, 3)
  for _, tex in ipairs({ W.xpRested, W.xpCur, W.xpBase }) do
    tex:SetPoint("TOPLEFT", W.xpBar, "TOPLEFT", 0, 0)
    tex:SetPoint("BOTTOMLEFT", W.xpBar, "BOTTOMLEFT", 0, 0)
  end
  W.xpLeft = newText(W.xp, FONT.small)
  W.xpLeft:SetJustifyH("LEFT")
  W.xpLeft:SetPoint("TOPLEFT", W.xpBar, "BOTTOMLEFT", 0, -3)
  W.xpRight = newText(W.xp, FONT.small)
  W.xpRight:SetPoint("TOPRIGHT", W.xpBar, "BOTTOMRIGHT", 0, -3)

  -- Extras: "+4g 12s   +350 Undercity   [Instances 8/10 · free in 12:40]"
  W.extras = newRow(full)
  W.instances = newTag(W.extras, FONT.small)
  W.money = newText(W.extras, FONT.small)
  W.rep = newText(W.extras, FONT.small)

  W.bosses = {}
  W.rares = {}

  attachDetail(full, true)
  attachDetail(W.head, false)   -- the header grabs the mouse (drag): it shows the detail too
end

local function bossRow(i)
  local r = W.bosses[i]
  if r then return r end
  r = newRow(W.frame)
  r.name = newText(r, FONT.bossName)
  r.time = newText(r, FONT.bossTime)
  r.delta = newText(r, FONT.bossDelta)
  W.bosses[i] = r
  return r
end

-- Rare row (owner, 2026-11-13): "RARE [6:10] Name", smaller, the tag before the time so the
-- "[time] name" pair reads like a boss row.
local function rareRow(i)
  local r = W.rares[i]
  if r then return r end
  r = newRow(W.frame)
  r.name = newText(r, FONT.rareName)
  r.time = newText(r, FONT.rareTime)
  r.tag = newTag(r, FONT.rareTag, S.rareTagPadX, S.rareTagPadY)
  W.rares[i] = r
  return r
end

local function tick(i)
  local t = W.ticks[i]
  if t then return t end
  t = W.bar:CreateTexture(nil, "OVERLAY")
  t:SetWidth(S.tickW)
  t:SetHeight(S.barH + 2 * S.tickOut)
  W.ticks[i] = t
  return t
end

local function segment(i)
  local s = W.segs[i]
  if s then return s end
  s = CreateFrame("Frame", nil, W.segRow)
  s.fill = s:CreateTexture(nil, "BACKGROUND")
  s.fill:SetAllPoints()
  s.border = newBorder(s)
  colorBorder(s.border, C.hairline)
  W.segs[i] = s
  return s
end

local function paintTimeBar(bar)
  setColor(W.barTrack, C.track)
  colorBorder(W.barBorder, C.hairline)
  local width = S.width
  if bar.fill > 0 then
    W.barFill:SetWidth(width * bar.fill)
    setColor(W.barFill, C.gold)
    W.barFill:Show()
  else
    W.barFill:Hide()
  end
  for i, t in ipairs(bar.ticks) do
    local tx = tick(i)
    tx:ClearAllPoints()
    tx:SetPoint("CENTER", W.bar, "LEFT", width * t.pos, 0)
    setColor(tx, Style.tone(t.tone))
    tx:Show()
  end
  for i = #bar.ticks + 1, #W.ticks do W.ticks[i]:Hide() end
end

local function paintSegments(bar)
  local n = #bar.segs
  local w = (S.width - (n - 1) * S.segGap) / n
  for i, tone in ipairs(bar.segs) do
    local s = segment(i)
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", W.segRow, "TOPLEFT", (i - 1) * (w + S.segGap), 0)
    s:SetSize(w, S.segH)
    setColor(s.fill, Style.tone(tone))
    s:Show()
  end
  for i = n + 1, #W.segs do W.segs[i]:Hide() end
end

local function paintXP(xp)
  local width = S.width
  setColor(W.xpTrack, C.track)
  colorBorder(W.xpBorder, C.hairline)
  local function seg(tex, frac, color)
    if frac and frac > 0 then
      tex:SetWidth(width * frac)
      setColor(tex, color)
      tex:Show()
    else
      tex:Hide()
    end
  end
  seg(W.xpRested, xp.rested, C.rested)
  seg(W.xpCur, xp.cur, C.turquoise)
  seg(W.xpBase, xp.base, C.xpBase)
  setText(W.xpLeft, L.IT_XP_RUN:format(Style.code("xpLight") .. "+" .. xp.gained .. "|r"), C.muted)
  setText(W.xpRight, L.IT_XP_LEVEL:format(xp.level, xp.pct)
    .. (xp.restedPct and L.IT_XP_RESTED:format(xp.restedPct) or ""), C.muted)
  W.xp:SetHeight(S.xpBarH + 3 + math.ceil(W.xpLeft:GetStringHeight()))
end

local SEP = "  ·  "

local function infoText(v)
  local total = v.totalKnown and tostring(v.total) or "?"
  local text = L.IT_BOSSES:format(Style.code(v.bossesTone) .. v.killed .. "/" .. total .. "|r")
  local note = v.note
  if not v.totalKnown and #v.bosses == 0 then
    text = text .. SEP .. L.IT_WAITING
  elseif note and note.kind == "vsPB" then
    text = text .. SEP .. L.IT_VS_PB:format(Style.code(note.tone) .. note.text .. "|r")
  elseif note and note.kind == "firstHint" then
    text = text .. SEP .. L.IT_FIRST_HINT
  elseif note and note.kind == "newRecord" then
    text = text .. SEP
  end
  return text
end

local function renderFull(v)
  local y = 0
  local function place(frame, h, extra)
    y = y + (extra or 0)
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", 0, -y)
    frame:SetHeight(h)
    frame:Show()
    y = y + h + S.gap
  end

  -- Header
  setText(W.name, v.name, C.muted)
  if v.difficulty then
    setTag(W.diff, v.difficulty, C.sand, C.goldSoft)
    W.diff:Show()
  else
    W.diff:Hide()
  end
  local head = { W.diff, W.name }
  chain(W.head, head, "", S.rowGap)
  place(W.head, heightOf(head))

  -- Clock row
  setText(W.clock, v.clock, Style.tone(v.clockTone))
  W.deaths:SetShown(v.deaths ~= nil)
  if v.deaths then
    setText(W.deaths, (v.deaths == 1 and L.IT_DEATH or L.IT_DEATHS):format(v.deaths), C.red)
  end
  local right
  if v.ref.kind == "pb" then
    setText(W.ref, v.ref.struck and v.ref.text or ("/ " .. v.ref.text), C.muted)
    W.ref:Show()
    W.first:Hide()
    W.strike:SetShown(v.ref.struck)
    setColor(W.strike, C.muted)
    right = W.ref
  else
    setTag(W.first, L.IT_FIRST_TAG, C.xpLight, C.xpLightHalf)
    W.first:Show()
    W.ref:Hide()
    W.strike:Hide()
    right = W.first
  end
  local clockRow = { right, W.clock, W.deaths }
  place(W.clockRow, chainBaseline(W.clockRow, clockRow, 10))

  -- Info row
  setText(W.info, infoText(v), C.muted)
  if v.note and v.note.kind == "newRecord" then
    setTag(W.record, L.IT_NEW_RECORD:format(v.note.text), C.turquoise, C.turquoise)
    W.record:Show()
  else
    W.record:Hide()
  end
  local infoRow = { W.record, W.info }
  chain(W.infoRow, infoRow, "", 0)
  place(W.infoRow, heightOf(infoRow))

  -- Bar
  W.bar:Hide()
  W.segRow:Hide()
  if v.bar and v.bar.mode == "time" then
    paintTimeBar(v.bar)
    place(W.bar, S.barH, S.gap)
  elseif v.bar and v.bar.mode == "segments" and #v.bar.segs > 0 then
    paintSegments(v.bar)
    place(W.segRow, S.segH, S.gap)
  end

  -- XP
  if v.xp then
    paintXP(v.xp)
    place(W.xp, W.xp:GetHeight(), 2)
  else
    W.xp:Hide()
  end

  -- Extras (level 2, contextual): money, top reputation, instances per hour
  if v.instances then
    local i = v.instances
    local text = L.IT_INSTANCES:format(i.count, i.limit) .. (i.freeIn and L.IT_INSTANCES_FREE:format(i.freeIn) or "")
    local color = i.full and C.red or C.gold
    setTag(W.instances, text, color, i.full and C.red or C.goldHalf)
  end
  W.instances:SetShown(v.instances ~= nil)
  if v.copper then setText(W.money, moneyText(v.copper), C.cream) end
  W.money:SetShown(v.copper ~= nil)
  if v.rep then setText(W.rep, repText(v.rep), C.muted) end
  W.rep:SetShown(v.rep ~= nil)
  if v.instances or v.copper or v.rep then
    chain(W.extras, { W.instances, W.rep, W.money }, "", S.extrasGap)
    place(W.extras, heightOf({ W.instances, W.rep, W.money }), 2)
  else
    W.extras:Hide()
  end

  -- Bosses
  y = y + S.bossTop - S.gap
  local nb, nr = 0, 0
  for _, b in ipairs(v.bosses) do
    local r, pieces
    local tone = Style.tone(b.tone)
    if b.rare then
      nr = nr + 1
      if nr == 1 then y = y + S.rareTop end
      r = rareRow(nr)
      setText(r.name, b.name, tone)
      setText(r.time, b.time, tone)
      r.time:SetShown(b.time ~= "")
      setTag(r.tag, L.IT_RARE, C.muted, C.mutedHalf)
      pieces = { r.name, r.time, r.tag }
      chain(r, pieces, "", 8)
      r.h = nil
    else
      nb = nb + 1
      r = bossRow(nb)
      setText(r.name, b.name, tone)
      setText(r.time, b.time, tone)
      r.time:SetShown(b.time ~= "")
      r.delta:SetShown(b.delta ~= nil)
      if b.delta then setText(r.delta, b.delta, Style.tone(b.deltaTone)) end
      pieces = { r.name, r.time, r.delta }
      r.h = chainBaseline(r, pieces, 8)
    end
    r:ClearAllPoints()
    r:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", 0, -y)
    r:SetHeight(r.h or heightOf(pieces))
    r:Show()
    y = y + r:GetHeight() + S.bossGap
  end
  for i = nb + 1, #W.bosses do W.bosses[i]:Hide() end
  for i = nr + 1, #W.rares do W.rares[i]:Hide() end

  W.frame:SetHeight(math.max(1, y))
  return S.width, y
end

------------------------------------------------------------------------------
-- Compact layout
------------------------------------------------------------------------------
local function compactLines()
  local v = lastView
  if not v then return {} end
  local title = v.name .. (v.difficulty and (" · " .. v.difficulty) or "")
  local deaths = v.deaths and (v.deaths == 1 and L.IT_DEATH or L.IT_DEATHS):format(v.deaths) or nil
  local lines = { { title, deaths, leftColor = C.muted, rightColor = C.red } }
  lines[#lines + 1] = { separator = true }
  for _, b in ipairs(v.bosses) do
    local tone = Style.tone(b.tone)
    local time = b.time ~= "" and (b.time:gsub("[%[%]]", "")) or "--"
    local left = b.rare and (b.name .. "  " .. Style.code("muted") .. L.IT_RARE .. "|r") or b.name
    lines[#lines + 1] = { left, time, leftColor = tone, rightColor = tone }
  end
  if v.ref.kind == "pb" then
    lines[#lines + 1] = { separator = true }
    lines[#lines + 1] = { L.IT_RECORD, v.ref.text, leftColor = C.muted, rightColor = C.muted }
  end
  return lines
end

local function buildCompact()
  local f = CreateFrame("Frame", nil, root)
  f:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
  K.frame = f
  K.bg = f:CreateTexture(nil, "BACKGROUND")
  K.bg:SetAllPoints()
  K.border = newBorder(f)
  makeHandle(f)
  K.bosses = newText(f, FONT.compact)
  K.sep1 = f:CreateTexture(nil, "ARTWORK")
  K.clock = newText(f, FONT.compact)
  K.delta = newText(f, FONT.compactSm)
  K.sep2 = f:CreateTexture(nil, "ARTWORK")
  K.xp = newText(f, FONT.compact)
  for _, s in ipairs({ K.sep1, K.sep2 }) do s:SetSize(1, S.compactSep) end
  Craft.Tooltip.Attach(f, { lines = compactLines, fontFlags = "", side = "bottom", delay = 150 })
end

local function renderCompact(v)
  setColor(K.bg, C.panelBg)
  colorBorder(K.border, C.hairline)
  setColor(K.sep1, C.goldSoft)
  setColor(K.sep2, C.goldSoft)
  local total = v.totalKnown and tostring(v.total) or "?"
  setText(K.bosses, L.IT_BOSSES:format(v.killed .. "/" .. total), Style.tone(v.bossesTone))
  setText(K.clock, v.clock, Style.tone(v.clockTone))
  K.delta:SetShown(v.compactDelta ~= nil)
  if v.compactDelta then setText(K.delta, v.compactDelta.text, Style.tone(v.compactDelta.tone)) end
  K.sep2:SetShown(v.xp ~= nil)
  K.xp:SetShown(v.xp ~= nil)
  if v.xp then setText(K.xp, L.IT_XP_SHORT:format("+" .. v.xp.gained), C.xpLight) end

  -- Left to right, from the panel's left padding.
  local x = S.compactPadX
  for _, r in ipairs({ K.bosses, K.sep1, K.clock, K.delta, K.sep2, K.xp }) do
    if r:IsShown() then
      r:ClearAllPoints()
      r:SetPoint("LEFT", K.frame, "LEFT", x, 0)
      local w = r.GetStringWidth and math.ceil(r:GetStringWidth()) or r:GetWidth()
      x = x + w + (r == K.clock and 4 or S.rowGap + 2)
    end
  end
  local h = heightOf({ K.bosses, K.clock }) + 2 * S.compactPadY
  K.frame:SetSize(x - S.rowGap - 2 + S.compactPadX, h)
  return K.frame:GetWidth(), h
end

------------------------------------------------------------------------------
-- Render / visibility
------------------------------------------------------------------------------
local function source()
  if demo then
    local run, opts, compact = Demo.get(demo)
    return run, opts, compact
  end
  local run = T.run
  return run, { xp = T:XPSnapshot(), pb = run and run.pb, deaths = run and run.deaths }, db().compact
end

local function build()
  root = CreateFrame("Frame", "QDTInstanceTrackerFrame", UIParent)
  Craft.Theme.resolve(nil, { theme = ctx }, root)   -- marks the frame: Craft overlays inherit our context
  root:SetFrameStrata("MEDIUM")
  root:SetClampedToScreen(true)
  root:SetMovable(true)
  root:SetSize(S.width, 1)
  restorePosition()
  buildFull()
  buildCompact()

  local acc = 0
  root:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < TICK then return end
    acc = 0
    local run, opts = source()
    local v = View.build(run, opts)
    if v and (not lastView or v.clock ~= lastView.clock) then UI:Render() end
  end)

  -- Theme or font metrics changed (first-ever BettoGeo load is async): re-font and repaint.
  ctx:register(function()
    for fs in pairs(fontOf) do applyFont(fs) end
    if root:IsShown() then UI:Render() end
  end)
end

function UI:Render()
  if not root then return end
  local run, opts, compact = source()
  local v = View.build(run, opts)
  lastView = v
  if not v then
    W.frame:Hide()
    K.frame:Hide()
    return
  end
  local w, h
  if compact then
    W.frame:Hide()
    K.frame:Show()
    w, h = renderCompact(v)
  else
    K.frame:Hide()
    W.frame:Show()
    w, h = renderFull(v)
  end
  root:SetSize(w, math.max(1, h))
end

function UI:Update(reason)
  if not ctx then return end
  if reason == "zone" then forced = nil end
  local want
  if demo or forced == "show" then
    want = true
  elseif forced == "hide" then
    want = false
  else
    want = db().autoShow and T.inInstance and T.run ~= nil
  end
  if want and not root then build() end
  if not root then return end
  if want then
    self:Render()
    root:Show()
  else
    root:Hide()
  end
end

function UI:Hide()
  forced = "hide"
  demo = nil
  self:Update()
end

function UI:Toggle()
  forced = (root and root:IsShown()) and "hide" or "show"
  self:Update()
end

function UI:ToggleCompact()
  local it = db()
  it.compact = not it.compact
  self:Update()
  return it.compact
end

-- name: a Demo scenario, or "off". Returns true when the name was valid.
function UI:Demo(name)
  if name == "off" then
    demo = nil
    self:Update()
    return true
  end
  if not Demo.get(name) then return false end
  demo = name
  self:Update()
  return true
end

-- For /qdt check f2: what was built and painted (plain values only).
function UI:Snapshot()
  return {
    craft = Craft ~= nil, context = ctx and ctx.name or nil,
    built = root ~= nil, shown = root and root:IsShown() or false,
    compact = db().compact == true, demo = demo,
    width = root and root:GetWidth() or nil, height = root and root:GetHeight() or nil,
    fonts = (function() local n = 0 for _ in pairs(fontOf) do n = n + 1 end return n end)(),
  }
end

function UI:Init()
  Craft = LibStub and LibStub("Craft-2.0", true)
  if not Craft then
    ns.say(L.IT_NO_CRAFT)
    return
  end
  ctx = Craft.Theme.context(THEME_NAME, {
    font = "bettogeo", headingFont = "bettogeo",
    overrides = {
      fontFlags = "OUTLINE, SLUG",   -- vector (Slug) outline: thinner and crisper than bitmap OUTLINE
      -- No regular weight anywhere (Style.lua): Craft overlays (tooltip) read `font`, so the
      -- body token is BettoGeo Medium too (owner, 2026-11-13).
      font = Craft.mediaPath .. "BettoGeo-Medium.ttf",
      primary = C.gold, primaryForeground = C.panel,             -- Forever gold on navy (9.7:1)
      sidebarPrimary = C.gold, sidebarPrimaryForeground = C.panel,
      foreground = C.cream, mutedForeground = C.muted,
      popover = C.panel, popoverForeground = C.cream,
      border = C.hairline, destructive = C.red,
    },
  })
  T:OnChange(function(reason) UI:Update(reason) end)
end

return UI
