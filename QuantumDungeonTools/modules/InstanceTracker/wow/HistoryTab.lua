---@diagnostic disable: undefined-global
-- modules/InstanceTracker/wow/HistoryTab.lua -- the History tab of the module page (plan M1 F6d,
-- artboard «Instance Tracker · Historial»).
--
-- Filter bar (three Craft.Select: dungeon, difficulty, character; "Instances last hour" on the
-- right), the column header outside the scroll, the table inside a Craft.Scroll (row frames
-- made once and reused: at most History.MAX) and the footer (count, mean, record · how many are
-- kept). WHAT each cell says and its tone comes from core/History.lua (pure, tested); colors and
-- sizes from core/Style.lua. Works with the module switched off: it only reads the saved history.
-- Built by wow/Page.lua with the main window's building blocks.
local _, ns = ...
local L = ns.L

local Tab = {}
ns.InstanceHistoryTab = Tab

local RAIL = 8      -- Craft.Scroll's rail (Craft px): it goes into the page margin, as on Summary
local ALL = "*"     -- the "All" option of every filter

local History, Hourly = ns.InstanceHistory, ns.InstanceHourly
local Style, C, FONT, S
local Craft, B
local P = {}        -- widgets
local rows = {}     -- reused row frames
local filters = { dungeon = ALL, difficulty = ALL, char = ALL }
local optionSig = {}
local shown, lastSig = 0, nil

local function db() return ns.db.instanceTracker end
local function history() return db().history or {} end

local function tone(name) return Style.TONE[name] or C[name] or C.cream end

local function paint(fs, text, toneName)
  fs:SetText(text or History.DASH)
  local c = tone(toneName)
  fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
end

local DATE_L, FOOT_L, CELL_L

------------------------------------------------------------------------------
-- Filters
------------------------------------------------------------------------------
local function withAll(label, list)
  local out = { { value = ALL, label = label } }
  for _, o in ipairs(list) do out[#out + 1] = o end
  return out
end

-- Rebuilds a Select's options only when they changed; a value that is gone falls back to All.
local function syncOptions(key, sel, options)
  local parts = {}
  for i, o in ipairs(options) do parts[i] = tostring(o.value) end
  local sig = table.concat(parts, "\0")
  if optionSig[key] ~= sig then
    optionSig[key] = sig
    sel:SetOptions(options)
  end
  local found = false
  for _, o in ipairs(options) do if o.value == filters[key] then found = true end end
  if not found then filters[key] = ALL end
  sel:SetValue(filters[key])
end

local function syncFilters(list)
  local o = History.options(list)
  local dungeons, diffs, chars = {}, {}, {}
  for i, d in ipairs(o.dungeons) do dungeons[i] = { value = d.key, label = d.label } end
  for i, d in ipairs(o.difficulties) do diffs[i] = { value = d, label = d } end
  for i, c in ipairs(o.chars) do chars[i] = { value = c.key, label = c.label } end
  syncOptions("dungeon", P.dungeon, withAll(L.IT_H_ALL_F, dungeons))
  syncOptions("difficulty", P.difficulty, withAll(L.IT_H_ALL_F, diffs))
  syncOptions("char", P.char, withAll(L.IT_H_ALL_M, chars))
end

local function activeFilter()
  local f = {}
  for k, v in pairs(filters) do if v ~= ALL then f[k] = v end end
  return f
end

------------------------------------------------------------------------------
-- Table
------------------------------------------------------------------------------
local function newCell(parent, font)
  local fs = B.text(parent, font)
  fs:SetWordWrap(false)
  fs:SetNonSpaceWrap(false)
  return fs
end

local function layoutCells(cells, width)
  local cols = History.columns(width, S.histGap, S.histPadX)
  for i, col in ipairs(History.COLUMNS) do
    local fs, c = cells[col.key], cols[i]
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", fs:GetParent(), "LEFT", c.x, 0)
    fs:SetWidth(math.max(1, c.w))
  end
end

local function getRow(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, P.child)
  r:SetHeight(S.histRowH)
  r:SetPoint("TOPLEFT", P.child, "TOPLEFT", 0, -(i - 1) * S.histRowH)
  r:SetPoint("TOPRIGHT", P.child, "TOPRIGHT", 0, -(i - 1) * S.histRowH)
  r.wash = r:CreateTexture(nil, "BACKGROUND")
  r.wash:SetAllPoints()
  r.wash:SetColorTexture(C.recordWash.r, C.recordWash.g, C.recordWash.b, C.recordWash.a)
  local rule = B.hline(r, C.hairlineSoft)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")
  r.cells = {}
  for _, col in ipairs(History.COLUMNS) do r.cells[col.key] = newCell(r, FONT.histCell) end
  layoutCells(r.cells, P.child:GetWidth())
  rows[i] = r
  return r
end

local function fillRow(r, row)
  local cells = History.cells(row, CELL_L)
  for _, col in ipairs(History.COLUMNS) do
    local k = col.key
    if k == "gold" then
      if row.copper > 0 then
        paint(r.cells.gold, ns.InstanceTrackerUI.coinText(row.copper), "text")
      else
        paint(r.cells.gold, History.DASH, "pending")
      end
    else
      paint(r.cells[k], cells[k].text, cells[k].tone)
    end
  end
  r.wash:SetShown(cells.record)
  r:Show()
end

local function relayout()
  if P.head then layoutCells(P.headCells, P.head:GetWidth()) end
  local w = P.child and P.child:GetWidth() or 0
  if w <= 0 then return end
  for _, r in ipairs(rows) do layoutCells(r.cells, w) end
end

------------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------------
function Tab:RefreshHour()
  if not P.hourNum then return end
  local h = Hourly.snapshot(db().hourly, time())
  local s = ("%d/%d"):format(h.count, h.limit)
  P.hourNum:SetText(s)
  P.footHourNum:SetText(s)
end

-- The bar at the window's minimum width does not hold the three filters and the hour count:
-- the selects shrink (dungeon first) down to their minimum, then the hour count moves to the
-- footer. Measured, so it follows the font.
local function layoutBar()
  local w = P.bar and P.bar:GetWidth() or 0
  if w <= 0 then return end
  local labels = 0
  for _, fs in ipairs(P.filterLabels) do labels = labels + fs:GetStringWidth() end
  local fixed = labels + 3 * S.histLabelGap + 2 * S.histGroupGap
  local hourW = S.histGroupGap + P.hourLabel:GetStringWidth() + 4 + P.hourNum:GetStringWidth()
  local want = { S.histDungeonW, S.histDiffW, S.histCharW }
  local min = { S.histDungeonMin, S.histDiffMin, S.histCharMin }
  local function fit(room)
    local widths, sum = {}, 0
    for i = 1, 3 do widths[i] = want[i]; sum = sum + want[i] end
    for i = 1, 3 do   -- shrink in order until it fits
      if sum <= room then break end
      local cut = math.min(widths[i] - min[i], sum - room)
      widths[i], sum = widths[i] - cut, sum - cut
    end
    return widths, sum <= room
  end
  local widths, ok = fit(w - fixed - hourW)
  local inBar = ok
  if not ok then widths = fit(w - fixed) end
  for i, sel in ipairs(P.selects) do sel:GetFrame():SetWidth(widths[i]) end
  P.hourLabel:SetShown(inBar)
  P.hourNum:SetShown(inBar)
  P.footHour:SetShown(not inBar)
  P.footHourNum:SetShown(not inBar)
end

local function signature(list)
  local first = list[1]
  return #list .. ":" .. tostring(type(first) == "table" and first.startedAt or "")
end

function Tab:Refresh()
  if not P.child then return end
  local list = history()
  lastSig = signature(list)
  syncFilters(list)
  local f = History.filter(list, activeFilter())
  local now = time()
  local n = 0
  for _, t in ipairs(f) do
    local row = History.row(t, { now = now, date = date, L = DATE_L })
    if row then
      n = n + 1
      fillRow(getRow(n), row)
    end
  end
  for i = n + 1, #rows do rows[i]:Hide() end
  shown = n
  P.child:SetHeight(math.max(1, n * S.histRowH))
  P.empty:SetText(#list == 0 and L.IT_H_EMPTY or L.IT_H_NO_MATCH)
  P.empty:SetShown(n == 0)
  P.footLeft:SetText(History.footer(History.summary(f), FOOT_L))
  self:RefreshHour()
  layoutBar()
end

-- Clock tick of the page (only while the tab is on screen): the hour count moves with time,
-- and a run that lands in the history repaints the table.
function Tab:Tick()
  if not (P.pane and P.pane:IsVisible()) then return end
  if signature(history()) ~= lastSig then self:Refresh() else self:RefreshHour() end
end

------------------------------------------------------------------------------
-- Build (called once by wow/Page.lua)
------------------------------------------------------------------------------
local function filter(bar, anchor, key, labelText, width)
  local lbl = B.text(bar, FONT.winSub, C.muted)
  if anchor then
    lbl:SetPoint("LEFT", anchor, "RIGHT", S.histGroupGap, 0)
  else
    lbl:SetPoint("LEFT", bar, "LEFT", 0, 0)
  end
  lbl:SetText(labelText)
  P.filterLabels[#P.filterLabels + 1] = lbl
  local sel = Craft.Select:Create(bar, { options = { { value = ALL, label = labelText } }, value = ALL,
    size = "sm", width = width, onSelect = function(v)
      filters[key] = v
      Tab:Refresh()
      if P.scroll then P.scroll:ScrollToTop() end
    end })
  sel:GetFrame():SetPoint("LEFT", lbl, "RIGHT", S.histLabelGap, 0)
  P.selects[#P.selects + 1] = sel
  return sel
end

function Tab:Build(pane, blocks)
  local kit = ns.Kit:Get()
  Craft, B = kit.Craft, blocks
  Style = ns.InstanceTrackerStyle
  C, FONT, S = Style.C, Style.FONT, Style.SIZE
  DATE_L = { today = L.IT_H_TODAY, yesterday = L.IT_H_YESTERDAY, months = L.IT_H_MONTHS }
  FOOT_L = { run1 = L.IT_H_RUN1, runs = L.IT_H_RUNS, mean = L.IT_H_MEAN, best = L.IT_H_BEST }
  CELL_L = { record = L.IT_H_RECORD, unfinished = L.IT_H_UNFINISHED }
  P.pane = pane

  -- Filter bar
  local bar = CreateFrame("Frame", nil, pane)
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("TOPRIGHT")
  bar:SetHeight(S.histBarH)
  P.bar, P.filterLabels, P.selects = bar, {}, {}
  local rule = B.hline(bar)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")
  P.dungeon = filter(bar, nil, "dungeon", L.IT_H_DUNGEON, S.histDungeonW)
  P.difficulty = filter(bar, P.dungeon:GetFrame(), "difficulty", L.IT_H_DIFFICULTY, S.histDiffW)
  P.char = filter(bar, P.difficulty:GetFrame(), "char", L.IT_H_CHAR, S.histCharW)
  P.hourNum = B.text(bar, FONT.histHour, C.gold)
  P.hourNum:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
  local hour = B.text(bar, FONT.winSub, C.muted)
  hour:SetPoint("RIGHT", P.hourNum, "LEFT", -4, 0)
  hour:SetText(L.IT_H_HOUR)
  P.hourLabel = hour
  bar:SetScript("OnSizeChanged", layoutBar)

  -- Column header (outside the scroll: it stays put)
  local head = CreateFrame("Frame", nil, pane)
  head:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
  head:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
  head:SetHeight(S.histHeadH)
  rule = B.hline(head)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")
  P.head, P.headCells = head, {}
  for _, col in ipairs(History.COLUMNS) do
    local fs = newCell(head, FONT.histHead)
    paint(fs, L.IT_H_COLS[col.key], "muted")
    P.headCells[col.key] = fs
  end
  head:SetScript("OnSizeChanged", relayout)

  -- Footer
  local foot = CreateFrame("Frame", nil, pane)
  foot:SetPoint("BOTTOMLEFT")
  foot:SetPoint("BOTTOMRIGHT")
  foot:SetHeight(S.histFootH)
  rule = B.hline(foot)
  rule:SetPoint("TOPLEFT")
  rule:SetPoint("TOPRIGHT")
  P.footLeft = B.text(foot, FONT.winRowSub, C.muted)
  P.footLeft:SetPoint("LEFT", foot, "LEFT", S.histPadX, 0)
  local kept = B.text(foot, FONT.winRowSub, C.muted, "RIGHT")
  kept:SetPoint("RIGHT", foot, "RIGHT", -S.histPadX, 0)
  kept:SetText(L.IT_H_KEPT:format(History.MAX))
  -- The hour count when the bar has no room for it (layoutBar), centered between both texts.
  P.footHour = B.text(foot, FONT.winRowSub, C.muted)
  P.footHour:SetPoint("RIGHT", foot, "CENTER", -2, 0)
  P.footHour:SetText(L.IT_H_HOUR)
  P.footHourNum = B.text(foot, FONT.histHead, C.gold)
  P.footHourNum:SetPoint("LEFT", foot, "CENTER", 2, 0)
  P.footHour:Hide()
  P.footHourNum:Hide()

  -- Table
  local scroll = Craft.Scroll:Create(pane, {})
  local sf = scroll:GetFrame()
  sf:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
  sf:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", RAIL, 0)
  local thumb, thumbTex = scroll._scrollThumb, scroll._thumbTex   -- same hover as Summary
  if thumb and thumbTex then
    thumb:HookScript("OnEnter", function() thumbTex:SetColorTexture(C.muted.r, C.muted.g, C.muted.b, 1) end)
  end
  local child = scroll:GetScrollChild()
  child:SetHeight(1)
  child:SetScript("OnSizeChanged", relayout)
  P.scroll, P.child = scroll, child
  P.empty = B.text(child, FONT.winSub, C.muted)
  P.empty:SetPoint("TOPLEFT", child, "TOPLEFT", S.histPadX, -S.histPadX * 3)
  P.empty:SetPoint("RIGHT", child, "RIGHT", -S.histPadX, 0)

  relayout()
end

-- For /qdt check f2 (plain values only).
function Tab:Snapshot()
  local n = 0
  for _ in pairs(P.headCells or {}) do n = n + 1 end
  return { built = P.child ~= nil, cols = n, shown = shown, pool = #rows,
    saved = #history(), filtered = #History.filter(history(), activeFilter()) }
end

return Tab
