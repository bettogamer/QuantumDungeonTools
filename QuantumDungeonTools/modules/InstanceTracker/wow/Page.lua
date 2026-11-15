---@diagnostic disable: undefined-global
-- modules/InstanceTracker/wow/Page.lua -- the module's page in the main window (plan M1 F6c,
-- artboard «Instance Tracker · Resumen»).
--
-- Header + tabs Summary | History (wow/HistoryTab.lua, F6d). Summary: the MODULE card (module
-- switch, applied on reload), the WIDGET group «What it shows» (our own fold, animated with
-- Weave: Craft.Section has no summary slot and puts the chevron on the right): state tabs and a
-- preview box with the real widget (F6f), then the 8 settings of core/Settings.lua in two
-- columns, a gold dot on the ones off their default and the
-- "N changed · Reset" footer, and the RUN group (current run + "Reset the run", history line).
--
-- Every change writes db.instanceTracker and repaints the widget at once. Built by
-- wow/MainWindow.lua, which hands over its building blocks (text, box, hline, labels, header).
local _, ns = ...
local L = ns.L

local Page = {}
ns.InstanceTrackerPage = Page

local TICK = 0.5            -- the RUN line carries the clock
local RAIL = 8              -- Craft.Scroll's rail (Scroll.lua SCROLLBAR_W, Craft px: not GEO-scaled)
local CONFIRM_SECS = 4      -- "Reset the run" asks for a second click within this time
local DOT_MASK = [[Interface\CharacterFrame\TempPortraitAlphaMask]]
local MARKER_ICON = [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_%d:0|t %s]]

-- Pure modules load earlier in the .toc: resolved now (Home asks ModuleOn before Build).
local Settings, View, History = ns.InstanceSettings, ns.InstanceTrackerView, ns.InstanceHistory
local HistoryTab = ns.InstanceHistoryTab
local Style, C, FONT, S
local kit, Craft, B, Weave
local P = {}                -- widgets
local cells = {}            -- key -> { dot, control, kind }
local moduleListeners = {}
local silent = false        -- programmatic Switch:SetChecked (it fires onChange)

local function db() return ns.db.instanceTracker end

------------------------------------------------------------------------------
-- Module switch (shared with the Home card of the main window)
------------------------------------------------------------------------------
function Page:OnModuleChange(fn) moduleListeners[#moduleListeners + 1] = fn end

function Page:SetModuleOn(on)
  db().enabled = on and true or false
  for _, fn in ipairs(moduleListeners) do fn(Settings.isOn(db())) end
end

function Page:ModuleOn() return Settings.isOn(db()) end

-- Turns a Switch without running its onChange.
local function setSwitch(sw, v)
  if sw:GetChecked() == v then return end
  silent = true
  sw:SetChecked(v)
  silent = false
end
Page.setSwitch = setSwitch

------------------------------------------------------------------------------
-- Pieces
------------------------------------------------------------------------------
local function icon(parent, name)
  local t = parent:CreateTexture(nil, "ARTWORK")
  Craft.Icons.Apply(t, name, S.pageIcon)
  t:SetSize(S.pageIcon, S.pageIcon)
  t:SetVertexColor(C.muted.r, C.muted.g, C.muted.b, 1)
  return t
end

local function dot(parent)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(S.pageDot, S.pageDot)
  kit.setColor(t, C.gold)
  local m = parent:CreateMaskTexture()
  m:SetTexture(DOT_MASK, "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
  m:SetAllPoints(t)
  t:AddMaskTexture(m)
  return t
end

local function markerOptions()
  local out = {}
  for i = 1, 8 do
    out[i] = { value = i, label = MARKER_ICON:format(i, L.IT_MARKER_NAMES[i] or tostring(i)) }
  end
  return out
end

------------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------------
local function summaryText()
  local s = Settings.summary(db())
  return table.concat({ L.IT_P_LINES:format(s.on, s.total), s.compact and L.IT_P_COMPACT or L.IT_P_FULL,
    s.autoShow and L.IT_P_AUTO or L.IT_P_MANUAL }, " · ")
end

local function refreshSettings()
  if not P.summary then return end
  local d = db()
  for key, cell in pairs(cells) do
    cell.dot:SetShown(Settings.isChanged(d, key))
    if cell.kind == "switch" then
      setSwitch(cell.control, Settings.get(d, key) and true or false)
    else
      cell.control:SetValue(Settings.get(d, key))
    end
  end
  P.summary:SetText(summaryText())
  if P.previewNote then P.previewNote:SetText(d.compact and L.IT_P_PREVIEW_CMP or L.IT_P_PREVIEW) end
  local n = Settings.changedCount(d)
  P.footText:SetText(n == 0 and L.IT_P_DEFAULTS or (n == 1 and L.IT_P_CHANGED1 or L.IT_P_CHANGEDN:format(n)))
  P.reset:GetFrame():SetShown(n > 0)
end

-- The widget follows every setting at once (Update re-renders; the marker needs the secure
-- ping buttons re-armed, out of combat or when it ends).
local function applyToWidget(key)
  local UI = ns.InstanceTrackerUI
  if not (ns.itLoaded and UI) then return end
  UI:Update()
  if key == nil or key == "pingMarker" then UI:SyncPings() end
end

local function changed(key)
  refreshSettings()
  applyToWidget(key)
end

local function refreshModule()
  if not P.moduleSwitch then return end
  setSwitch(P.moduleSwitch, Settings.isOn(db()))
  P.reloadHint:SetShown(Settings.needsReload(ns.itLoaded, db()))
end

local function disarm()
  P.armed = nil
  if P.resetRun then P.resetRun:SetText(L.IT_P_RESET_RUN) end
end

function Page:RefreshRun()
  if not P.runLine then return end
  local T = ns.InstanceTracker
  local run = ns.itLoaded and T and T.run
  if run then
    local v = View.build(run, { pb = run.pb, deaths = run.deaths, now = time() })
    local r = View.now(v).run
    local parts = { r.name }
    if r.difficulty then parts[#parts + 1] = r.difficulty end
    parts[#parts + 1] = L.IT_BOSSES:format(r.bosses)
    parts[#parts + 1] = r.clock
    P.runLine:SetText(table.concat(parts, " · "))
  else
    P.runLine:SetText(ns.itLoaded and L.IT_P_NO_RUN or L.IT_MODULE_OFF)
    disarm()
  end
  P.resetRun:SetEnabled(run ~= nil)
  local list = T and T:History() or {}
  P.histLine:SetText(L.IT_P_HIST_LINE:format(#list, History.MAX, History.recordCount(db().records)))
end

------------------------------------------------------------------------------
-- Blocks
------------------------------------------------------------------------------
local function buildModule(parent, anchor)
  local card = B.box(parent, nil, C.hairline)
  card:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -S.pageLabelGap)
  card:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  card:SetHeight(S.pageCardH)
  local name = B.text(card, FONT.winModule, C.cream)
  name:SetPoint("LEFT", S.pagePadX, 0)
  name:SetText(L.IT_TITLE)
  P.moduleSwitch = Craft.Switch:Create(card, { checked = Settings.isOn(db()),
    onChange = function(v) if not silent then Page:SetModuleOn(v) end end })
  local sf = P.moduleSwitch:GetFrame()
  sf:SetPoint("LEFT", name, "RIGHT", 14, 0)
  local cmd = B.text(card, FONT.winRowSub, C.tickIdle)
  cmd:SetPoint("LEFT", sf, "RIGHT", 14, 0)
  cmd:SetText("/qdt it")
  P.reloadHint = B.text(card, FONT.winRowSub, C.gold)
  P.reloadHint:SetPoint("LEFT", cmd, "RIGHT", 14, 0)
  P.reloadHint:SetText(L.IT_P_RELOAD_HINT)
  return card
end

-- One setting cell: dot, label + hint, and its control on the right.
local function buildCell(parent, spec)
  local cell = CreateFrame("Frame", nil, parent)
  cell:SetHeight(S.pageRowH)
  local rule = B.hline(cell, C.hairlineSoft)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")
  cell.vrule = cell:CreateTexture(nil, "BORDER")
  cell.vrule:SetWidth(1)
  kit.setColor(cell.vrule, C.hairlineSoft)
  cell.vrule:SetPoint("TOPRIGHT")
  cell.vrule:SetPoint("BOTTOMRIGHT")

  local d = dot(cell)
  d:SetPoint("LEFT", S.pagePadX, 0)
  local control, ctrlFrame
  local key = spec.key
  if spec.kind == "marker" then
    control = Craft.Select:Create(cell, { options = markerOptions(), value = Settings.get(db(), key),
      size = "sm", width = S.pageSelectW,
      onSelect = function(v) db()[key] = v; changed(key) end })
  else
    control = Craft.Switch:Create(cell, { checked = Settings.get(db(), key) and true or false,
      onChange = function(v)
        if silent then return end
        db()[key] = v
        changed(key)
      end })
  end
  ctrlFrame = control:GetFrame()
  ctrlFrame:SetPoint("RIGHT", cell, "RIGHT", -S.pagePadX, 0)

  local texts = L.IT_SET[key] or { key, "" }
  local k = B.text(cell, FONT.winRow, C.cream)
  k:SetPoint("BOTTOMLEFT", cell, "LEFT", S.pagePadX + S.pageDot + S.pageIconGap, 1)
  k:SetPoint("RIGHT", ctrlFrame, "LEFT", -S.pageIconGap, 0)
  k:SetText(texts[1])
  local h = B.text(cell, FONT.winRowSub, C.muted)
  h:SetPoint("TOPLEFT", k, "BOTTOMLEFT", 0, -2)
  h:SetPoint("RIGHT", ctrlFrame, "LEFT", -S.pageIconGap, 0)
  h:SetText(texts[2])
  cells[key] = { dot = d, control = control, kind = spec.kind }
  return cell
end

-- Preview (F6f): state tabs on the right and, under them, a box that borrows the real widget
-- (UI:Preview) while it is visible: every setting changed below shows on it at once. Folding the
-- group, switching to History or closing the window hides the box and gives the widget back.
local PREVIEW_STATES = { "live", "done", "first" }

local function startPreview()
  local UI = ns.InstanceTrackerUI
  if not (ns.itLoaded and UI and P.previewBox and P.previewBox:IsVisible()) then return end
  UI:Preview(P.previewBox, P.previewState)
end

local function stopPreview()
  local UI = ns.InstanceTrackerUI
  if ns.itLoaded and UI then UI:Preview(nil) end
end

-- Returns the height it takes in the fold's body (from its top rule).
local function buildPreview(body)
  local tabs = {}
  for i, id in ipairs(PREVIEW_STATES) do tabs[i] = { id = id, label = L.IT_P_STATES[id] } end
  P.previewState = PREVIEW_STATES[1]
  local bar = Craft.Tabs:Create(body, { variant = "default", fill = true, defaultTab = P.previewState,
    tabs = tabs, onTabChange = function(id)
      P.previewState = id
      startPreview()
    end })
  local bf = bar:GetFrame()
  bf:SetPoint("TOPRIGHT", body, "TOPRIGHT", -S.pagePadX, -(1 + S.previewTop))
  bf:SetSize(S.previewTabsW, S.previewTabsH)
  P.previewTabs = bar

  local box = B.box(body, C.sidebar, C.hairline)
  box:SetPoint("TOPLEFT", body, "TOPLEFT", S.pagePadX, -(1 + S.previewTop + S.previewTabsH + S.previewGap))
  box:SetPoint("RIGHT", body, "RIGHT", -S.pagePadX, 0)
  box:SetHeight(S.previewH)
  box:SetClipsChildren(true)
  P.previewBox = box
  P.previewNote = B.text(box, FONT.winRowSub, C.muted)
  P.previewNote:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", S.previewNote + 2, S.previewNote)
  if not ns.itLoaded then   -- module off: no widget to borrow
    local off = B.text(box, FONT.winRow, C.muted)
    off:SetPoint("CENTER")
    off:SetText(L.IT_MODULE_OFF)
  end
  box:SetScript("OnShow", startPreview)
  box:SetScript("OnHide", stopPreview)
  return S.previewTop + S.previewTabsH + S.previewGap + S.previewH + S.previewBottom
end

-- «What it shows»: header (chevron, title, summary) over a body that folds with a Weave tween
-- (height and alpha; the chevron turns from down to right), as every component animates.
local function buildFold(parent, anchor, onHeight)
  local f = B.box(parent, nil, C.hairline)
  f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -S.pageLabelGap)
  f:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  f:SetClipsChildren(true)

  local head = CreateFrame("Button", nil, f)
  head:SetPoint("TOPLEFT")
  head:SetPoint("TOPRIGHT")
  head:SetHeight(S.pageFoldH)
  local chev = icon(head, "chevron-down")
  chev:SetPoint("LEFT", S.pagePadX, 0)
  local title = B.text(head, FONT.winModule, C.cream)
  title:SetPoint("LEFT", chev, "RIGHT", S.pageIconGap, 0)
  title:SetText(L.IT_P_WHAT)
  P.summary = B.text(head, FONT.winRowSub, C.muted)
  P.summary:SetPoint("LEFT", title, "RIGHT", S.pageIconGap, 0)

  local rows = math.ceil(#Settings.WIDGET / 2)
  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
  body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
  local top = B.hline(body, C.hairlineSoft)
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  local previewH = buildPreview(body)
  local gridTop = B.hline(body, C.hairlineSoft)
  gridTop:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(1 + previewH))
  gridTop:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -(1 + previewH))
  local bodyH = 1 + previewH + 1 + rows * S.pageRowH + S.pageFootH
  body:SetHeight(bodyH)

  local list = {}
  for i, spec in ipairs(Settings.WIDGET) do list[i] = buildCell(body, spec) end
  -- Two columns, row-major as the artboard's grid; re-laid when the window is resized.
  local function layout()
    local w = math.floor(body:GetWidth() / 2)
    if w <= 0 then return end
    for i, cell in ipairs(list) do
      local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", body, "TOPLEFT", col * w, -(2 + previewH + line * S.pageRowH))
      cell:SetWidth(col == 0 and w or body:GetWidth() - w)
      cell.vrule:SetShown(col == 0)
    end
  end
  body:SetScript("OnSizeChanged", layout)
  layout()

  local foot = CreateFrame("Frame", nil, body)
  foot:SetPoint("BOTTOMLEFT")
  foot:SetPoint("BOTTOMRIGHT")
  foot:SetHeight(S.pageFootH)
  P.footText = B.text(foot, FONT.winRowSub, C.muted)
  P.footText:SetPoint("LEFT", S.pagePadX, 0)
  P.reset = Craft.Button:Create(foot, { text = L.IT_P_RESET, variant = "link", tone = "primary",
    size = "sm", fontFlags = "", onClick = function()
      Settings.reset(db())
      changed(nil)
    end })
  P.reset:GetFrame():SetPoint("RIGHT", foot, "RIGHT", -S.pagePadX, 0)

  local m = kit.ctx:get()
  local open = Weave.signal(true)
  local prog = Weave.tween(Weave.computed(function() return open() and 1 or 0 end),
    { duration = m.motionBase or 0.2, easing = Weave.easing[m.motionEasing] or Weave.easing.outQuad })
  P.foldFx = Weave.effect(function()
    local p = prog()
    if type(p) ~= "number" then return end
    f:SetHeight(S.pageFoldH + p * bodyH)
    body:SetAlpha(p)
    body:SetShown(p > 0)
    chev:SetRotation((1 - p) * math.pi / 2)   -- down when open, right when folded
    onHeight()
  end)
  P.foldProg = prog
  head:SetScript("OnClick", function() open:set(not open:peek()) end)
  return f
end

local function runRow(parent, anchor, gap, title)
  local row = B.box(parent, nil, C.hairline)
  row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
  row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  row:SetHeight(S.pageRunH)
  local chev = icon(row, "chevron-right")
  chev:SetPoint("LEFT", S.pagePadX, 0)
  local name = B.text(row, FONT.winModule, C.cream)
  name:SetPoint("LEFT", chev, "RIGHT", S.pageIconGap, 0)
  name:SetText(title)
  local line = B.text(row, FONT.winRowSub, C.muted)
  line:SetPoint("LEFT", name, "RIGHT", S.pageIconGap, 0)
  return row, line
end

local function buildRun(parent, anchor, onHistory)
  local run, runLine = runRow(parent, anchor, S.pageLabelGap, L.IT_P_CURRENT)
  P.runLine = runLine
  P.resetRun = Craft.Button:Create(run, { text = L.IT_P_RESET_RUN, variant = "outline", tone = "destructive",
    size = "sm", fontFlags = "", onClick = function()
      if not P.armed then           -- first click arms, the second one resets
        P.armed = true
        P.resetRun:SetText(L.IT_P_CONFIRM)
        C_Timer.After(CONFIRM_SECS, function() if P.armed then disarm() end end)
        return
      end
      disarm()
      local T = ns.InstanceTracker
      T:NewRun()
      ns.say(T.run and L.IT_NEW_RUN or L.IT_RUN_CLOSED)
      Page:RefreshRun()
    end })
  P.resetRun:GetFrame():SetPoint("RIGHT", run, "RIGHT", -S.pagePadX, 0)
  runLine:SetPoint("RIGHT", P.resetRun:GetFrame(), "LEFT", -S.pageIconGap, 0)

  local hist, histLine = runRow(parent, run, S.pageRunGap, L.IT_P_HISTORY)
  P.histLine = histLine
  local see = Craft.Button:Create(hist, { text = L.IT_P_SEE_HISTORY, variant = "link", tone = "primary",
    size = "sm", fontFlags = "", onClick = onHistory })
  see:GetFrame():SetPoint("RIGHT", hist, "RIGHT", -S.pagePadX, 0)
  histLine:SetPoint("RIGHT", see:GetFrame(), "LEFT", -S.pageIconGap, 0)
  return hist
end

local function buildSummary(frame, onHistory)
  local scroll = Craft.Scroll:Create(frame, {})
  -- Craft reserves an 8 px rail on the right, always: it goes into the page margin, so the cards
  -- end where the tab bar line ends.
  local sf = scroll:GetFrame()
  sf:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  sf:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", RAIL, 0)
  -- Hover: Craft paints the thumb with `accent` (grey, shared by menus and selects); ours gets
  -- the palette's muted teal. At rest `secondary` (Kit) and gold while dragging stay.
  local thumb, thumbTex = scroll._scrollThumb, scroll._thumbTex   -- Craft's back-compat aliases
  if thumb and thumbTex then
    thumb:HookScript("OnEnter", function() thumbTex:SetColorTexture(C.muted.r, C.muted.g, C.muted.b, 1) end)
  end
  local child = scroll:GetScrollChild()
  child:SetHeight(1)
  P.scroll, P.child = scroll, child

  local last
  -- The scroll child's height follows the fold while it animates (measured, not summed: the
  -- labels' height depends on the font).
  local function fit()
    local top, bottom = child:GetTop(), last and last:GetBottom()
    if top and bottom then child:SetHeight(math.max(1, top - bottom + S.pageBottom)) end
  end

  local label = B.label(child, L.IT_P_MODULE)
  label:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -S.pageTop)
  P.firstLabel = label
  local card = buildModule(child, label)
  P.card = card
  label = B.label(child, L.IT_P_WIDGET)
  label:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -S.pageBlockGap)
  local fold = buildFold(child, label, fit)
  P.fold = fold
  label = B.label(child, L.IT_P_RUN)
  label:SetPoint("TOPLEFT", fold, "BOTTOMLEFT", 0, -S.pageBlockGap)
  last = buildRun(child, label, onHistory)
  P.last = last
  child:SetScript("OnShow", fit)
  child:SetScript("OnSizeChanged", fit)
  fit()
end

------------------------------------------------------------------------------
-- Build (called once by wow/MainWindow.lua)
------------------------------------------------------------------------------
-- page: the empty page frame. blocks: { text, box, hline, label, header } of the main window.
function Page:Build(page, blocks)
  kit = ns.Kit:Get()
  Craft, B = kit.Craft, blocks
  Weave = LibStub("Weave-1.0")
  Style = ns.InstanceTrackerStyle
  C, FONT, S = Style.C, Style.FONT, Style.SIZE

  local head = B.header(page, L.IT_TITLE, L.IT_P_SUB, L.IT_P_KICKER:format(L.IT_P_SUMMARY))
  head.rule:Hide()   -- the tab bar draws the line here

  local tabs = Craft.Tabs:Create(page, {
    variant = "line", defaultTab = "summary",
    tabs = { { id = "summary", label = L.IT_P_SUMMARY }, { id = "history", label = L.IT_P_HISTORY } },
    onTabChange = function(id)
      P.tab = id
      head.kicker:SetText(L.IT_P_KICKER:format(id == "history" and L.IT_P_HISTORY or L.IT_P_SUMMARY))
      if id == "history" then HistoryTab:Refresh() end
    end,
  })
  local tf = tabs:GetFrame()
  tf:SetPoint("TOPLEFT", head.sub, "BOTTOMLEFT", 0, -12)
  tf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -B.padX, 0)
  P.tabs, P.tab = tabs, "summary"
  -- Built hidden: the content frames keep their rect since Craft 2.51.0 (FR-153).
  local panes = { summary = tabs:GetContentFrame("summary"), history = tabs:GetContentFrame("history") }
  P.panes = panes

  buildSummary(panes.summary, function() tabs:SetActiveTab("history") end)

  HistoryTab:Build(panes.history, B)

  self:OnModuleChange(refreshModule)
  refreshModule()
  refreshSettings()

  local acc = 0
  page:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < TICK then return end
    acc = 0
    Page:RefreshRun()
    HistoryTab:Tick()
  end)
  page:SetScript("OnShow", function()
    refreshModule()
    refreshSettings()   -- /qdt auto, /qdt it compact and /qdt it mark change them too
    Page:RefreshRun()
    if P.tab == "history" then HistoryTab:Refresh() end
  end)
  if ns.itLoaded and ns.InstanceTracker then
    ns.InstanceTracker:OnChange(function() if page:IsVisible() then Page:RefreshRun() end end)
  end
end

-- Shows a tab of the page ("summary" | "history").
function Page:ShowTab(id)
  if P.tabs then P.tabs:SetActiveTab(id) end
end

-- Opens the main window on the History tab: /qdt history, the toast button, Home › OPEN.
function Page:OpenHistory()
  ns.MainWindow:Open("it")
  self:ShowTab("history")
end

function Page:ActiveTab() return P.tab end

-- For /qdt check f2: what was built (plain values only).
function Page:Snapshot()
  local n = 0
  for _ in pairs(cells) do n = n + 1 end
  local function rect(f)
    if not f then return "nil" end
    local l, b, w, h = f:GetRect()
    return ("%s shown=%s vis=%s a=%.2f rect=%s,%s %sx%s"):format(f.GetObjectType and f:GetObjectType() or "?",
      tostring(f:IsShown()), tostring(f:IsVisible()), f:GetAlpha() or -1, tostring(l and math.floor(l)),
      tostring(b and math.floor(b)), tostring(w and math.floor(w)), tostring(h and math.floor(h)))
  end
  return { built = P.tabs ~= nil, cells = n, preview = P.previewState, previewBox = rect(P.previewBox),
    painted = P.last ~= nil and P.last:GetRect() ~= nil, folded = P.foldProg and P.foldProg:peek() == 0 or false,
    probe = P.tabs and {   -- why the Summary tab paints nothing (F6c in-game, 2026-11-14)
      tabs = rect(P.tabs:GetFrame()), content = rect(P.panes and P.panes.summary),
      scroll = rect(P.scroll and P.scroll:GetFrame()), child = rect(P.child), label = rect(P.firstLabel),
      card = rect(P.card), fold = rect(P.fold), last = rect(P.last),
    } or nil }
end

return Page
