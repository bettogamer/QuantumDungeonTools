---@diagnostic disable: undefined-global
-- wow/MainWindow.lua -- the addon's main window (plan M1 F6b, canvas page "Ventana principal").
--
-- One headless Craft.Window: a 220 px sidebar (brand, Home, DUNGEONS > Instance Tracker, Minimap
-- Lens as SOON, and General settings / What's new pinned at the bottom with the version) and,
-- to its right, a top bar with "Reload UI" and close, over one frame per page. Pages are built
-- once and switched with Show/Hide (no re-render per visit). F6b paints the Home page (NOW,
-- OPEN, MODULES); the module pages are placeholders that F6c/F6d fill.
--
-- Fonts, borders and the theme context come from the addon kit (wow/Kit.lua) and colors, fonts
-- and sizes from the addon Style (core/Style.lua): nothing here depends on a module being on.
-- Built lazily on the first Open. WHAT the NOW card says comes from the Instance Tracker view
-- model (View.now, pure and tested), only while that module runs.
local _, ns = ...
local L = ns.L

local MW = {}
ns.MainWindow = MW

local TICK = 0.5   -- NOW card clock, same cadence as the widget

local Style, View        -- resolved on build
local C, FONT, WIN
local kit, Craft
local win, side, foot
local pages = {}         -- id -> page frame
local current            -- id of the page on screen
local home = {}          -- widgets of the Home page
local previewStep = 0    -- "Try" cycles the alert previews

local FOOT_IDS = { general = true, news = true }
local PREVIEWS = { "cap", "near", "toast" }

local function wdb()
  ns.db.window = ns.db.window or {}   -- additive (position + size), no migration
  return ns.db.window
end

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------
local function text(parent, font, color, justify)
  local fs = kit.newText(parent, font)
  fs:SetShadowOffset(0, 0)            -- solid panel: no HUD shadow
  fs:SetJustifyH(justify or "LEFT")
  if color then fs:SetTextColor(color.r, color.g, color.b, color.a or 1) end
  return fs
end

local function box(parent, fill, line)
  local f = CreateFrame("Frame", nil, parent)
  if fill then
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    kit.setColor(bg, fill)
  end
  if line then kit.colorBorder(kit.newBorder(f), line) end
  return f
end

local function hline(parent, color)
  local t = parent:CreateTexture(nil, "BORDER")
  t:SetHeight(1)
  kit.setColor(t, color or C.hairline)
  return t
end

local function section(parent, label, anchor, gap)
  local fs = text(parent, FONT.winSection, C.muted)
  fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or WIN.gap))
  fs:SetText(label)
  return fs
end

-- Kicker, title, subtitle and the bottom rule. Returns the rule (the next block hangs from it).
local function pageHeader(page, title, sub)
  local kicker = text(page, FONT.winKicker, C.muted)
  kicker:SetPoint("TOPLEFT", WIN.padX, -WIN.padY)
  kicker:SetText(ns.Brand.TITLE)
  local h1 = text(page, FONT.winTitle, C.cream)
  h1:SetPoint("TOPLEFT", kicker, "BOTTOMLEFT", 0, -4)
  h1:SetText(title)
  local s = text(page, FONT.winSub, C.muted)
  s:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -4)
  s:SetText(sub or "")
  local rule = hline(page)
  rule:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -16)
  rule:SetPoint("RIGHT", page, "RIGHT", -WIN.padX, 0)
  return rule
end

------------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------------
local function newPage(container, id)
  local page = CreateFrame("Frame", nil, container)
  page:SetAllPoints(container)
  page:Hide()
  pages[id] = page
  return page
end

-- Module pages not built yet (F6c/F6d) and General / What's new: header + empty state.
local function placeholder(container, id, title, sub)
  local page = newPage(container, id)
  local rule = pageHeader(page, title, sub)
  local empty = Craft.Empty:Create(page, { title = L.MW_SOON_TITLE, description = L.MW_SOON_DESC,
    icon = "hourglass" })
  local f = empty:GetFrame()
  f:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -WIN.gap)
  f:SetPoint("RIGHT", page, "RIGHT", -WIN.padX, 0)
  return page
end

local function openRow(parent, key, sub, button, onClick, disabled)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(WIN.openRowH)
  local k = text(row, FONT.winRow, C.cream)
  k:SetPoint("TOPLEFT", 12, -8)
  k:SetText(key)
  local h = text(row, FONT.winRowSub, C.muted)
  h:SetPoint("TOPLEFT", k, "BOTTOMLEFT", 0, -2)
  h:SetText(sub)
  local btn = Craft.Button:Create(row, { text = button, variant = "outline", size = "sm",
    onClick = onClick, disabled = disabled, tooltip = disabled and L.MW_SOON_TIP or nil, fontFlags = "" })
  local bf = btn:GetFrame()
  bf:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  if bf:GetWidth() < 78 then bf:SetWidth(78) end
  local rule = hline(row, C.hairlineSoft)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")
  return row
end

local function buildNowCard(page, anchor)
  local card = box(page, C.goldWash, C.goldCard)
  card:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
  card:SetPoint("RIGHT", page, "RIGHT", -WIN.padX, 0)
  card:SetHeight(WIN.nowH)
  home.card = card

  local hourLabel = text(card, FONT.winRowSub, C.muted)
  hourLabel:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -14)
  hourLabel:SetText(L.MW_HOUR)
  home.hour = text(card, FONT.winHourNum, C.gold)
  home.hour:SetPoint("TOPLEFT", hourLabel, "BOTTOMLEFT", 0, -2)

  local vline = card:CreateTexture(nil, "BORDER")
  vline:SetWidth(1)
  kit.setColor(vline, C.hairline)
  vline:SetPoint("TOP", card, "TOP", 0, -1)
  vline:SetPoint("BOTTOM", card, "BOTTOM", 0, 1)
  vline:SetPoint("RIGHT", hourLabel, "LEFT", -28, 0)

  home.clock = text(card, FONT.winClock, C.cream, "RIGHT")
  home.clock:SetPoint("TOPRIGHT", vline, "TOPLEFT", -28, -9)
  home.delta = text(card, FONT.winDelta, C.cream, "RIGHT")
  home.delta:SetPoint("TOPRIGHT", home.clock, "BOTTOMRIGHT", 0, -2)

  home.name = text(card, FONT.winNowName, C.cream)
  home.name:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -14)
  home.name:SetPoint("RIGHT", home.clock, "LEFT", -28, 0)
  home.line = text(card, FONT.winNowLine, C.muted)
  home.line:SetPoint("TOPLEFT", home.name, "BOTTOMLEFT", 0, -3)
  home.line:SetPoint("RIGHT", home.clock, "LEFT", -28, 0)
  return card
end

local function buildOpen(page, anchor)
  local area = CreateFrame("Frame", nil, page)
  area:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  area:SetPoint("RIGHT", page, "RIGHT", -WIN.padX, 0)
  area:SetHeight(2 * WIN.openRowH)
  local rows = {
    openRow(area, L.MW_OPEN_HISTORY, L.MW_OPEN_HISTORY_SUB, L.MW_BTN_OPEN, function() MW:Navigate("it") end),
    openRow(area, L.MW_OPEN_WIDGET, L.MW_OPEN_WIDGET_SUB, L.MW_BTN_SHOW,
      function() if ns.InstanceTrackerUI then ns.InstanceTrackerUI:Toggle() end end),
    openRow(area, L.MW_OPEN_ALERTS, L.MW_OPEN_ALERTS_SUB, L.MW_BTN_TRY, function()
      previewStep = previewStep % #PREVIEWS + 1
      if ns.InstanceAlertsUI then ns.InstanceAlertsUI:Preview(PREVIEWS[previewStep]) end
    end),
    openRow(area, L.MW_OPEN_MOVE, L.MW_OPEN_MOVE_SUB, L.MW_BTN_MOVE, nil, true),   -- edit mode: later
  }
  -- Two columns, row-major (as the artboard's grid), re-laid when the window is resized.
  local function layout()
    local w = math.floor((area:GetWidth() - WIN.openColGap) / 2)
    if w <= 0 then return end
    for i, row in ipairs(rows) do
      local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", area, "TOPLEFT", col * (w + WIN.openColGap), -line * WIN.openRowH)
      row:SetWidth(w)
    end
  end
  area:SetScript("OnSizeChanged", layout)
  layout()
  return area
end

local function buildModules(page, anchor)
  local it = box(page, nil, C.hairline)
  it:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
  it:SetPoint("RIGHT", page, "RIGHT", -WIN.padX, 0)
  it:SetHeight(WIN.moduleH)
  local name = text(it, FONT.winModule, C.cream)
  name:SetPoint("LEFT", 16, 0)
  name:SetText(L.IT_TITLE)
  -- The module switch (asks for a reload) is wired in F6c, with the module's own page.
  local sw = Craft.Switch:Create(it, { checked = true, disabled = true })
  sw:GetFrame():SetPoint("LEFT", name, "RIGHT", 14, 0)
  local cmd = text(it, FONT.winRowSub, C.tickIdle)
  cmd:SetPoint("LEFT", sw:GetFrame(), "RIGHT", 14, 0)
  cmd:SetText("/qdt it")
  local cfg = Craft.Button:Create(it, { text = L.MW_CONFIGURE, variant = "link", tone = "primary",
    size = "sm", fontFlags = "", onClick = function() MW:Navigate("it") end })
  cfg:GetFrame():SetPoint("RIGHT", it, "RIGHT", -10, 0)
  local desc = text(it, FONT.winSub, C.muted)
  desc:SetPoint("LEFT", cmd, "RIGHT", 14, 0)
  desc:SetPoint("RIGHT", cfg:GetFrame(), "LEFT", -14, 0)
  desc:SetText(L.MW_IT_DESC)

  local lens = box(page, nil, C.hairlineSoft)
  lens:SetPoint("TOPLEFT", it, "BOTTOMLEFT", 0, -WIN.moduleGap)
  lens:SetPoint("RIGHT", page, "RIGHT", -WIN.padX, 0)
  lens:SetHeight(WIN.moduleH)
  local lname = text(lens, FONT.winModule, C.tickIdle)
  lname:SetPoint("LEFT", 16, 0)
  lname:SetText(L.MW_LENS)
  local tag = kit.newTag(lens, FONT.winTag, 4, 1)
  kit.setTag(tag, L.MW_SOON, C.tickIdle, C.mutedTag)
  tag:SetPoint("LEFT", lname, "RIGHT", 14, 0)
  local ldesc = text(lens, FONT.winSub, C.tickIdle)
  ldesc:SetPoint("LEFT", tag, "RIGHT", 14, 0)
  ldesc:SetText(L.MW_LENS_DESC)
end

local function buildHome(container)
  local page = newPage(container, "home")
  local rule = pageHeader(page, L.MW_HOME, L.MW_HOME_SUB)
  local now = section(page, L.MW_NOW, rule)
  local card = buildNowCard(page, now)
  local open = buildOpen(page, section(page, L.MW_OPEN, card))
  buildModules(page, section(page, L.MW_MODULES, open))

  -- OnUpdate only runs while the page is on screen: the clock ticks there and nowhere else.
  local acc = 0
  page:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < TICK then return end
    acc = 0
    MW:RefreshHome()
  end)
  page:SetScript("OnShow", function() MW:RefreshHome() end)
end

------------------------------------------------------------------------------
-- Home: the NOW card
------------------------------------------------------------------------------
function MW:RefreshHome()
  if not home.card then return end
  local T = ns.InstanceTracker
  local run = T and T.run
  local v = run and View.build(run, { pb = run.pb, deaths = run.deaths, now = time() }) or nil
  local now = View.now(v, T and T:HourSnapshot(), ns.InstanceAlerts and ns.InstanceAlerts.NEAR)

  local r = now.run
  if r then
    home.name:SetText(r.difficulty and (r.name .. " · " .. r.difficulty) or r.name)
    local parts = { L.IT_BOSSES:format(Style.code("progress") .. r.bosses .. "|r") }
    if r.record then parts[#parts + 1] = L.MW_NOW_RECORD:format(r.record) end
    if r.deaths then parts[#parts + 1] = (r.deaths == 1 and L.IT_DEATH or L.IT_DEATHS):format(r.deaths) end
    home.line:SetText(table.concat(parts, " · "))
    kit.setText(home.clock, r.clock, Style.tone(r.clockTone))
    home.clock:Show()
    if r.delta then
      local fmt = r.delta.kind == "newRecord" and L.IT_NEW_RECORD or L.MW_VS_RECORD
      kit.setText(home.delta, fmt:format(r.delta.text), Style.tone(r.delta.tone))
      home.delta:Show()
    else
      home.delta:Hide()
    end
  else
    home.name:SetText(L.IT_NO_RUN)
    home.line:SetText(L.MW_NO_RUN_HINT)
    home.clock:Hide()
    home.delta:Hide()
  end
  if now.hour then
    kit.setText(home.hour, now.hour.text, Style.tone(now.hour.tone == "text" and "progress" or now.hour.tone))
  else
    home.hour:SetText("—")
  end
end

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------
local function buildSidebar(content)
  side = Craft.Sidebar:Create(content, {
    size = "default", activeItem = "home",
    items = {
      { id = "home", label = L.MW_HOME, icon = "house" },
      { id = "it", label = L.IT_TITLE, icon = "timer", section = L.MW_DUNGEONS },
      -- Craft rows take no badge: SOON goes in the tooltip here and as a tag on Home (FR-152).
      { id = "lens", label = L.MW_LENS, icon = "map", section = L.MW_DUNGEONS, disabled = true,
        tooltip = L.MW_SOON_TIP },
    },
    onSelect = function(id) MW:Navigate(id) end,
  })
  local sf = side:GetFrame()
  sf:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  sf:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
  sf:SetWidth(WIN.sidebar)

  local brand = side:GetHeader()
  brand:SetHeight(WIN.brandH)
  local q = text(brand, FONT.winBrand, C.cream)
  q:SetPoint("TOPLEFT", 16, -16)
  q:SetText((ns.Brand.TITLE:match("^(%S+)")))
  local sub = text(brand, FONT.winBrandSub, C.gold)
  sub:SetPoint("TOPLEFT", q, "BOTTOMLEFT", 0, -1)
  sub:SetText((ns.Brand.TITLE:match("^%S+ (.+)$") or ""):upper())
  win:EnableDragFrom(brand)

  -- Bottom block: a second Sidebar so the pinned rows look and select like the top ones.
  -- Craft rows are not GEO-scaled: 2 rows of 32 + its 8 px group padding above and below.
  local footH = 2 * 32 + 16
  local footer = side:GetFooter()
  footer:SetHeight(footH + WIN.versionH)
  foot = Craft.Sidebar:Create(footer, {
    size = "default",
    items = {
      { id = "general", label = L.MW_GENERAL, icon = "sliders-horizontal" },
      { id = "news", label = L.MW_NEWS, icon = "file-text" },
    },
    onSelect = function(id) MW:Navigate(id) end,
  })
  local ff = foot:GetFrame()
  ff:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
  ff:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
  ff:SetHeight(footH)
  home.version = text(footer, FONT.winVersion, C.tickIdle)
  home.version:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", 16, 8)
  side:RefreshLayout()
end

local function buildMain(content)
  local main = CreateFrame("Frame", nil, content)
  main:SetPoint("TOPLEFT", content, "TOPLEFT", WIN.sidebar, 0)
  main:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

  local bar = CreateFrame("Frame", nil, main)
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("TOPRIGHT")
  bar:SetHeight(WIN.topBar)
  win:EnableDragFrom(bar)
  local rule = hline(bar)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")
  local close = Craft.Button:Create(bar, { icon = "x", size = "icon-sm", variant = "outline",
    tooltip = L.MW_CLOSE, onClick = function() win:Hide() end })
  close:GetFrame():SetPoint("RIGHT", bar, "RIGHT", -14, 0)
  local reload = Craft.Button:Create(bar, { text = L.MW_RELOAD, variant = "outline", size = "sm",
    fontFlags = "", onClick = function() ReloadUI() end })
  reload:GetFrame():SetPoint("RIGHT", close:GetFrame(), "LEFT", -10, 0)

  local body = CreateFrame("Frame", nil, main)
  body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
  body:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
  buildHome(body)
  placeholder(body, "it", L.IT_TITLE, L.MW_IT_DESC)
  placeholder(body, "general", L.MW_GENERAL, L.MW_GENERAL_SUB)
  placeholder(body, "news", L.MW_NEWS, L.MW_NEWS_SUB)
end

local function build()
  kit = ns.Kit:Get()
  if not kit then return false end
  Craft, Style, View = kit.Craft, ns.Style, ns.InstanceTrackerView
  C, FONT, WIN = Style.C, Style.FONT, Style.WIN

  local saved = wdb()
  win = Craft.Window:Create(UIParent, {
    name = "QDTMainWindow", header = false, theme = kit.ctx,
    width = saved.w or WIN.width, height = saved.h or WIN.height,
    minWidth = WIN.minWidth, minHeight = WIN.minHeight,
    onMoved = function(w)
      local _, _, _, x, y = w:GetPosition()
      saved.x, saved.y = x, y
    end,
    onResized = function(_, w, h) saved.w, saved.h = w, h end,
  })
  if saved.x and saved.y then win:SetPosition("CENTER", UIParent, "CENTER", saved.x, saved.y) else win:Center() end

  local content = win:GetContent()
  local bg = content:CreateTexture(nil, "BACKGROUND", nil, -8)
  bg:SetAllPoints()
  kit.setColor(bg, C.panel)          -- the artboard's navy, under Craft's own surface
  buildSidebar(content)
  buildMain(content)

  if ns.InstanceTracker then
    ns.InstanceTracker:OnChange(function() if current == "home" and win:IsShown() then MW:RefreshHome() end end)
  end
  return true
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------
-- Shows page `id` (unknown ids fall back to Home) and marks it on the right sidebar.
function MW:Navigate(id)
  if not win then return end
  if not pages[id] then id = "home" end
  for pid, page in pairs(pages) do
    if pid == id then page:Show() else page:Hide() end
  end
  current = id
  side:SetActiveItem(not FOOT_IDS[id] and id or nil)
  foot:SetActiveItem(FOOT_IDS[id] and id or nil)
end

function MW:Open(id)
  if not win and not build() then
    ns.say(L.IT_NO_CRAFT)
    return
  end
  local ver = ns.version or "dev"
  home.version:SetText(ver == "dev" and ver or ("v" .. ver))
  win:Show()
  self:Navigate(id or current or "home")
end

function MW:Toggle(id)
  if win and win:IsShown() and (id == nil or id == current) then
    win:Hide()
  else
    self:Open(id)
  end
end

function MW:IsShown() return win ~= nil and win:IsShown() end

return MW
