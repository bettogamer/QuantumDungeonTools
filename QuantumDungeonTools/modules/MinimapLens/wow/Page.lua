---@diagnostic disable: undefined-global
-- modules/MinimapLens/wow/Page.lua -- the module's page in the main window (plan M2 F5,
-- artboard AppLens «Minimap Lens · Resumen»).
--
-- Header + one Summary tab, in a scroll: MODULE (live switch, /qdt lens, «Move the lens» =
-- wow/Mover.lua, «Try the lens» = toggle), LENS «How it looks» (our own fold, as on the Instance
-- Tracker page: size and opacity sliders, then zoom step / hide herbs and minerals / lock
-- position switches, gold dot when off their default, «N changed · Reset the lens»), SHORTCUT
-- (the bound key or NOT SET, where to set it, «Open Keybindings») and COEXISTENCE (who owns the
-- minimap and what soft mode does with it).
--
-- Every change writes db.minimapLens and reaches the lens at once (UI:SetSize/SetOpacity live
-- while it is on; the switches apply on the next opening, except «lock» and «hide herbs», live).
local _, ns = ...
local L = ns.L
local Lens = ns.MinimapLens

local Page = {}
ns.MinimapLensPage = Page

local RAIL = 8              -- Craft.Scroll's rail (see the Instance Tracker page)
local DOT_MASK = [[Interface\CharacterFrame\TempPortraitAlphaMask]]
local SLIDER_W, VALUE_W = 150, 42   -- artboard

local Style, C, FONT, S
local kit, Craft, B, Weave
local P = {}
local cells = {}            -- key -> { dot, control, kind, value? }
local moduleListeners = {}
local silent = false

local function db() return ns.db.minimapLens end
local function UI() return ns.MinimapLensUI end
local function Mover() return ns.MinimapLensMover end

------------------------------------------------------------------------------
-- Module switch (shared with the Home card of the main window)
------------------------------------------------------------------------------
function Page:OnModuleChange(fn) moduleListeners[#moduleListeners + 1] = fn end

function Page:ModuleOn() return Lens.isOn(db()) end

function Page:SetModuleOn(on)
  if UI() then UI():SetModuleOn(on) else db().enabled = on and true or false end
  if not on and Mover() then Mover():Stop() end
  for _, fn in ipairs(moduleListeners) do fn(Lens.isOn(db())) end
end

local function setSwitch(sw, v)
  if sw:GetChecked() == v then return end
  silent = true
  sw:SetChecked(v)
  silent = false
end

------------------------------------------------------------------------------
-- Pieces
------------------------------------------------------------------------------
local function icon(parent, name, color)
  local t = parent:CreateTexture(nil, "ARTWORK")
  Craft.Icons.Apply(t, name, S.pageIcon)
  t:SetSize(S.pageIcon, S.pageIcon)
  local c = color or C.muted
  t:SetVertexColor(c.r, c.g, c.b, 1)
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

local function button(parent, textValue, primary, onClick)
  return Craft.Button:Create(parent, { text = textValue, variant = not primary and "outline" or nil,
    size = "sm", fontFlags = "", onClick = onClick })
end

------------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------------
local function summaryText()
  local d = db()
  return table.concat({
    L.LENS_P_SQUARE,
    Lens.percent(Lens.get(d, "size")) .. "%",
    L.LENS_P_OPACITY_N:format(Lens.percent(Lens.get(d, "opacity"))),
    Lens.get(d, "zoomStep") and L.LENS_P_ZOOM1 or L.LENS_P_ZOOM0,
    Lens.get(d, "hideGathering") and L.LENS_P_GATHER_OFF or L.LENS_P_GATHER_KEEP,
  }, " · ")
end

local function refreshSettings()
  if not P.summary then return end
  local d = db()
  for key, cell in pairs(cells) do
    cell.dot:SetShown(Lens.isChanged(d, key))
    if cell.kind == "switch" then
      setSwitch(cell.control, Lens.get(d, key))
    elseif cell.kind == "select" then
      if cell.control:GetValue() ~= Lens.get(d, key) then cell.control:SetValue(Lens.get(d, key)) end
    else
      local pct = Lens.percent(Lens.get(d, key))
      silent = true
      cell.control:SetValue(pct)
      silent = false
      cell.value:SetText(pct .. "%")
    end
  end
  P.summary:SetText(summaryText())
  local n = Lens.changedCount(d)
  P.footText:SetText(n == 0 and L.IT_P_DEFAULTS or (n == 1 and L.IT_P_CHANGED1 or L.IT_P_CHANGEDN:format(n)))
  P.reset:GetFrame():SetShown(n > 0)
end

local function refreshModule()
  if not P.moduleSwitch then return end
  local on = Lens.isOn(db())
  setSwitch(P.moduleSwitch, on)
  P.try:SetEnabled(on)
  P.move:SetEnabled(on)
  P.try:SetText(UI() and UI():IsOn() and L.LENS_P_CLOSE or L.LENS_P_TRY)
  P.move:SetText(Mover() and Mover():IsShown() and L.LENS_MOVER_DONE or L.LENS_P_MOVE)
end

local function refreshShortcut()
  if not P.keyTag then return end
  local T = ns.MinimapLensTriggers
  local key = T and T:BoundKey()
  if key then
    kit.setTag(P.keyTag, key, C.gold, C.goldTag)
  else
    kit.setTag(P.keyTag, L.LENS_P_NO_KEY, C.muted, C.mutedTag)
  end
end

local OWNER_HELP = { eui = "LENS_P_HELP_EUI", elvui = "LENS_P_HELP_ELVUI", ["elvui+eui"] = "LENS_P_HELP_ELVUI",
  other = "LENS_P_HELP_OTHER", none = "LENS_P_HELP_NONE" }

local function refreshCoexist()
  if not P.ownerTitle then return end
  local owner = UI() and UI().owner() or "none"
  if owner == "none" then
    kit.setTag(P.ownerTag, L.LENS_P_NORMAL, C.muted, C.mutedTag)
    P.ownerTitle:SetText(L.LENS_P_BLIZZARD)
  else
    kit.setTag(P.ownerTag, L.LENS_P_SOFT, C.gold, C.goldTag)
    P.ownerTitle:SetText(L.LENS_P_DETECTED:format(Lens.ownerName(owner) or L.LENS_OTHER_UI))
  end
  P.ownerHelp:SetText(L[OWNER_HELP[owner] or "LENS_P_HELP_OTHER"])
end

local function refreshAll()
  refreshModule()
  refreshSettings()
  refreshShortcut()
  refreshCoexist()
end

------------------------------------------------------------------------------
-- Blocks
------------------------------------------------------------------------------
local function card(parent, anchor, h)
  local f = B.box(parent, nil, C.hairline)
  f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -S.pageLabelGap)
  f:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  f:SetHeight(h)
  return f
end

local function buildModule(parent, anchor)
  local f = card(parent, anchor, S.pageCardH)
  local name = B.text(f, FONT.winModule, C.cream)
  name:SetPoint("LEFT", S.pagePadX, 0)
  name:SetText(L.MW_LENS)
  P.moduleSwitch = Craft.Switch:Create(f, { checked = Lens.isOn(db()),
    onChange = function(v) if not silent then Page:SetModuleOn(v) end end })
  local sf = P.moduleSwitch:GetFrame()
  sf:SetPoint("LEFT", name, "RIGHT", 14, 0)
  local cmd = B.text(f, FONT.winRowSub, C.tickIdle)
  cmd:SetPoint("LEFT", sf, "RIGHT", 14, 0)
  cmd:SetText("/qdt lens")
  P.try = button(f, L.LENS_P_TRY, true, function()
    if ns.MinimapLensTriggers then ns.MinimapLensTriggers:Toggle("page") end
  end)
  P.try:GetFrame():SetPoint("RIGHT", f, "RIGHT", -S.pagePadX, 0)
  P.move = button(f, L.LENS_P_MOVE, false, function()
    if Mover() then Mover():Toggle() end
  end)
  P.move:GetFrame():SetPoint("RIGHT", P.try:GetFrame(), "LEFT", -8, 0)
  return f
end

-- One cell: dot, label + hint, and the control on the right (a slider with its % or a switch).
local function buildCell(parent, key, kind)
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
  local entry = { dot = d, kind = kind }
  local ctrl
  if kind == "slider" then
    local spec = key == "size" and Lens.SIZE or Lens.OPACITY
    entry.value = B.text(cell, FONT.winRowSub, C.cream, "RIGHT")
    entry.value:SetWidth(VALUE_W)
    entry.value:SetPoint("RIGHT", cell, "RIGHT", -S.pagePadX, 0)
    local last
    entry.control = Craft.Slider:Create(cell, { min = Lens.percent(spec.min), max = Lens.percent(spec.max),
      step = Lens.percent(spec.step), value = Lens.percent(Lens.get(db(), key)), width = SLIDER_W,
      onChange = function(v)
        if silent or v == last then return end
        last = v
        if key == "size" then
          UI():SetSize(v / 100)
          if Mover() then Mover():Refresh() end
        else
          UI():SetOpacity(v / 100)
        end
        refreshSettings()
      end })
    ctrl = entry.control:GetFrame()
    ctrl:SetPoint("RIGHT", entry.value, "LEFT", -S.pageIconGap, 0)
  elseif kind == "select" then
    local options = {}
    for i, c in ipairs(Lens.CORNERS) do options[i] = { value = c, label = L.LENS_CORNER[c] or c } end
    entry.control = Craft.Select:Create(cell, { options = options, value = Lens.get(db(), key),
      size = "sm", width = SLIDER_W, onSelect = function(v)
        if v == Lens.get(db(), key) then return end
        db()[key] = v ~= Lens.CORNER_DEFAULT and v or nil
        if ns.MinimapLensTriggers then ns.MinimapLensTriggers:Replace() end
        refreshSettings()
      end })
    ctrl = entry.control:GetFrame()
    ctrl:SetPoint("RIGHT", cell, "RIGHT", -S.pagePadX, 0)
  else
    entry.control = Craft.Switch:Create(cell, { checked = Lens.get(db(), key),
      onChange = function(v)
        if silent then return end
        db()[key] = v
        if key == "locked" then UI():RefreshDrag() end
        if key == "hideGathering" then UI():RefreshGathering() end
        if key == "hoverOnly" and ns.MinimapLensTriggers then ns.MinimapLensTriggers:Refresh() end
        refreshSettings()
      end })
    ctrl = entry.control:GetFrame()
    ctrl:SetPoint("RIGHT", cell, "RIGHT", -S.pagePadX, 0)
  end

  local texts = L.LENS_SET[key] or { key, "" }
  local k = B.text(cell, FONT.winRow, C.cream)
  k:SetPoint("BOTTOMLEFT", cell, "LEFT", S.pagePadX + S.pageDot + S.pageIconGap, 1)
  k:SetPoint("RIGHT", ctrl, "LEFT", -S.pageIconGap, 0)
  k:SetText(texts[1])
  local h = B.text(cell, FONT.winRowSub, C.muted)
  h:SetPoint("TOPLEFT", k, "BOTTOMLEFT", 0, -2)
  h:SetPoint("RIGHT", ctrl, "LEFT", -S.pageIconGap, 0)
  h:SetText(texts[2])
  cells[key] = entry
  return cell
end

local CELLS = { { "size", "slider" }, { "opacity", "slider" }, { "zoomStep", "switch" },
  { "hideGathering", "switch" }, { "locked", "switch" }, { "corner", "select" }, { "hoverOnly", "switch" } }

-- «How it looks»: header (chevron, title, summary) over a body that folds with a Weave tween.
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
  title:SetText(L.LENS_P_LOOK)
  P.summary = B.text(head, FONT.winRowSub, C.muted)
  P.summary:SetPoint("LEFT", title, "RIGHT", S.pageIconGap, 0)

  local rows = math.ceil(#CELLS / 2)
  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
  body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
  local top = B.hline(body, C.hairlineSoft)
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  local bodyH = 1 + rows * S.pageRowH + S.pageFootH
  body:SetHeight(bodyH)

  local list = {}
  for i, spec in ipairs(CELLS) do list[i] = buildCell(body, spec[1], spec[2]) end
  local function layout()
    local w = math.floor(body:GetWidth() / 2)
    if w <= 0 then return end
    for i, cell in ipairs(list) do
      local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", body, "TOPLEFT", col * w, -(1 + line * S.pageRowH))
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
  P.reset = Craft.Button:Create(foot, { text = L.LENS_P_RESET, variant = "link", tone = "primary",
    size = "sm", fontFlags = "", onClick = function()
      Lens.reset(db())
      UI():SetSize(Lens.get(db(), "size"))
      UI():SetOpacity(Lens.get(db(), "opacity"))
      UI():RefreshDrag()
      UI():RefreshGathering()
      if ns.MinimapLensTriggers then
        ns.MinimapLensTriggers:Replace()
        ns.MinimapLensTriggers:Refresh()
      end
      if Mover() then Mover():Refresh() end
      refreshSettings()
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
    chev:SetRotation((1 - p) * math.pi / 2)
    onHeight()
  end)
  head:SetScript("OnClick", function() open:set(not open:peek()) end)
  return f
end

local function openBindings()
  local ok = false
  if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
    ok = pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID)
  end
  if not ok then ns.say(L.LENS_TIP_HINT) end
end

local function buildShortcut(parent, anchor)
  local f = card(parent, anchor, S.pageRunH)
  local kb = icon(f, "keyboard")
  kb:SetSize(16, 16)
  kb:SetPoint("LEFT", S.pagePadX, 0)
  local name = B.text(f, FONT.winModule, C.cream)
  name:SetPoint("LEFT", kb, "RIGHT", 12, 0)
  name:SetText(L.LENS_P_TOGGLE)
  P.keyTag = kit.newTag(f, FONT.winSection, 8, 2)
  P.keyTag:SetPoint("LEFT", name, "RIGHT", 12, 0)
  local open = button(f, L.LENS_P_OPEN_KEYS, false, openBindings)
  open:GetFrame():SetPoint("RIGHT", f, "RIGHT", -S.pagePadX, 0)
  local path = B.text(f, FONT.winRowSub, C.muted)
  path:SetPoint("LEFT", P.keyTag, "RIGHT", 12, 0)
  path:SetPoint("RIGHT", open:GetFrame(), "LEFT", -12, 0)
  path:SetText(L.LENS_P_KEYS_PATH)
  return f
end

local function buildCoexist(parent, anchor)
  local f = card(parent, anchor, S.pageRunH + 6)
  P.ownerTag = kit.newTag(f, FONT.winSection, 8, 2)
  P.ownerTag:SetPoint("LEFT", S.pagePadX, 0)
  P.ownerTitle = B.text(f, FONT.winRow, C.cream)
  P.ownerTitle:SetPoint("BOTTOMLEFT", P.ownerTag, "RIGHT", 12, 1)
  P.ownerTitle:SetPoint("RIGHT", f, "RIGHT", -S.pagePadX, 0)
  P.ownerHelp = B.text(f, FONT.winRowSub, C.muted)
  P.ownerHelp:SetPoint("TOPLEFT", P.ownerTitle, "BOTTOMLEFT", 0, -2)
  P.ownerHelp:SetPoint("RIGHT", f, "RIGHT", -S.pagePadX, 0)
  return f
end

local function buildSummary(frame)
  local scroll = Craft.Scroll:Create(frame, {})
  local sf = scroll:GetFrame()
  sf:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  sf:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", RAIL, 0)
  local thumb, thumbTex = scroll._scrollThumb, scroll._thumbTex
  if thumb and thumbTex then
    thumb:HookScript("OnEnter", function() thumbTex:SetColorTexture(C.muted.r, C.muted.g, C.muted.b, 1) end)
  end
  local child = scroll:GetScrollChild()
  child:SetHeight(1)

  local last
  local function fit()
    local top, bottom = child:GetTop(), last and last:GetBottom()
    if top and bottom then child:SetHeight(math.max(1, top - bottom + S.pageBottom)) end
  end

  local label = B.label(child, L.IT_P_MODULE)
  label:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -S.pageTop)
  local block = buildModule(child, label)
  label = B.label(child, L.LENS_P_LENS)
  label:SetPoint("TOPLEFT", block, "BOTTOMLEFT", 0, -S.pageBlockGap)
  block = buildFold(child, label, fit)
  label = B.label(child, L.LENS_P_SHORTCUT)
  label:SetPoint("TOPLEFT", block, "BOTTOMLEFT", 0, -S.pageBlockGap)
  block = buildShortcut(child, label)
  label = B.label(child, L.LENS_P_COEXIST)
  label:SetPoint("TOPLEFT", block, "BOTTOMLEFT", 0, -S.pageBlockGap)
  last = buildCoexist(child, label)
  child:SetScript("OnShow", fit)
  child:SetScript("OnSizeChanged", fit)
  fit()
end

------------------------------------------------------------------------------
-- Build (called once by wow/MainWindow.lua)
------------------------------------------------------------------------------
function Page:Build(page, blocks)
  kit = ns.Kit:Get()
  Craft, B = kit.Craft, blocks
  Weave = LibStub("Weave-1.0")
  Style = ns.InstanceTrackerStyle   -- the page tokens (pageRowH...) are shared by both module pages
  C, FONT, S = Style.C, Style.FONT, Style.SIZE

  local head = B.header(page, L.MW_LENS, L.LENS_P_SUB, L.LENS_P_KICKER)
  head.rule:Hide()
  local tabs = Craft.Tabs:Create(page, { variant = "line", defaultTab = "summary",
    tabs = { { id = "summary", label = L.IT_P_SUMMARY } } })
  local tf = tabs:GetFrame()
  tf:SetPoint("TOPLEFT", head.sub, "BOTTOMLEFT", 0, -12)
  tf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -B.padX, 0)
  buildSummary(tabs:GetContentFrame("summary"))

  if UI() then UI():OnChange(function() if page:IsVisible() then refreshModule() end end) end
  if Mover() then Mover():OnChange(function() if page:IsVisible() then refreshModule() end end) end
  page:SetScript("OnShow", refreshAll)   -- the key, the owner and /qdt lens change outside the page
  self:OnModuleChange(refreshModule)
  refreshAll()
end

return Page
