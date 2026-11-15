---@diagnostic disable: undefined-global
-- wow/Minimap.lua -- the minimap icon (plan M1 F6e, artboard "Icono del minimapa").
--
-- A LibDataBroker launcher shown by LibDBIcon (drag along the minimap edge, position and `hide`
-- saved in ns.db.minimap). Clicks follow SMRT's button (docs/19-smrt-menu-minimapa.md): left =
-- main window Home, shift+left = Instance Tracker History, right = a Craft.Menu. The tooltip is
-- the button's OWN GameTooltip, not the shared one: restyling GameTooltip's lines (Inter) would
-- leak into every item and unit tooltip. Being ours, it also carries the icon off its left edge.
local ADDON, ns = ...
local L = ns.L

local Minimap = {}
ns.Minimap = Minimap

local NAME = ADDON                     -- LibDBIcon / LDB object name
local TOOLTIP_NAME = "QDT_MinimapTooltip"

local listeners = {}
local tooltip, menu

local function db()
  ns.db.minimap = ns.db.minimap or {}  -- additive: { hide, minimapPos } (LibDBIcon's own keys)
  return ns.db.minimap
end

local function dbicon() return LibStub and LibStub("LibDBIcon-1.0", true) end

------------------------------------------------------------------------------
-- Tooltip
------------------------------------------------------------------------------
local function getTooltip()
  if tooltip then return tooltip end
  local TIP, C = ns.Style.TIP, ns.Style.C
  tooltip = CreateFrame("GameTooltip", TOOLTIP_NAME, UIParent, "GameTooltipTemplate")
  -- Navy panel + hairline like the window; older templates without NineSlice keep the default.
  if tooltip.NineSlice then
    pcall(function()
      tooltip.NineSlice:SetCenterColor(C.panel.r, C.panel.g, C.panel.b, 0.96)
      tooltip.NineSlice:SetBorderColor(1, 1, 1, 0.18)
    end)
  end
  local logo = CreateFrame("Frame", nil, tooltip)
  tooltip.logo = logo
  logo:SetSize(TIP.logo, TIP.logo)
  logo:SetPoint("RIGHT", tooltip, "LEFT", 0, 0)
  local tex = logo:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture(TIP.icon)
  tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- trim the icon's baked-in border
  return tooltip
end

-- Same place LibDBIcon puts every other button's tooltip: below the button in the top half of
-- the screen (above otherwise), flush with its right/left edge in the right/left third.
local function tooltipAnchor(owner)
  local x, y = owner:GetCenter()
  if not x or not y then return "BOTTOM", owner, "TOP" end
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  local hside = (x > w * 2 / 3) and "RIGHT" or (x < w / 3) and "LEFT" or ""
  local vside = (y > h / 2) and "TOP" or "BOTTOM"
  return vside .. hside, owner, (vside == "TOP" and "BOTTOM" or "TOP") .. hside
end

-- Lines are created lazily by AddLine, so the fonts go on afterwards. Without Craft the
-- tooltip keeps the client's font.
-- `foot`: index of a last, smaller line (the hint under the lens's lines).
local function applyFonts(tip, foot)
  local Craft = LibStub and LibStub("Craft-2.0", true)
  local media = Craft and Craft.mediaPath
  if not media then return end
  local TIP = ns.Style.TIP
  for i = 1, tip:NumLines() do
    local line = _G[TOOLTIP_NAME .. "TextLeft" .. i]
    if line then
      if i == 1 then line:SetFont(media .. TIP.titleFont, TIP.titleSize, "")
      elseif i == foot then line:SetFont(media .. TIP.lineFont, TIP.footSize, "")
      else line:SetFont(media .. TIP.lineFont, TIP.lineSize, "") end
    end
  end
end

-- title: text with its own color codes; pairs: { { key, value } }; opts = { logo = bool,
-- titleColor = rgb, foot = muted hint line }.
local function showTip(owner, title, pairs_, opts)
  opts = opts or {}
  local tip = getTooltip()
  local point, rel, relPoint = tooltipAnchor(owner)
  tip:SetOwner(owner, "ANCHOR_NONE")
  tip:ClearAllPoints()
  tip:SetPoint(point, rel, relPoint)
  tip.logo:SetShown(opts.logo ~= false)
  local tc = opts.titleColor
  if tc then tip:AddLine(title, tc.r, tc.g, tc.b) else tip:AddLine(title) end
  local key, cream = ns.Style.code("muted"), ns.Style.C.cream
  for _, pair in ipairs(pairs_) do
    tip:AddLine(key .. pair[1] .. "|r · " .. pair[2], cream.r, cream.g, cream.b)
  end
  local foot
  if opts.foot then
    local m = ns.Style.C.muted
    tip:AddLine(opts.foot, m.r, m.g, m.b, true)
    foot = tip:NumLines()
  end
  applyFonts(tip, foot)
  tip:Show()
end

local function showTooltip(owner) showTip(owner, ns.Brand.title(), L.MM_TIP_LINES) end

------------------------------------------------------------------------------
-- Right-click menu (Craft.Menu, rebuilt on every open)
------------------------------------------------------------------------------
local function openTab(tab)
  local Page = ns.InstanceTrackerPage
  if tab == "history" then Page:OpenHistory() return end
  ns.MainWindow:Open("it")
  Page:ShowTab("summary")
end

local function menuItems()
  return {
    { label = L.IT_TITLE, icon = "timer", onClick = function() openTab("summary") end },
    { label = L.MM_HISTORY, icon = "history", onClick = function() openTab("history") end },
    { type = "separator" },
    { label = L.MW_GENERAL, icon = "sliders-horizontal",
      onClick = function() ns.MainWindow:Open("general") end },
    { label = L.MM_HIDE, icon = "eye-off", onClick = function() Minimap:SetShown(false) end },
  }
end

local function openMenu(anchor)
  local kit = ns.Kit:Get()
  if not (kit and kit.Craft and kit.Craft.Menu) then
    ns.MainWindow:Toggle("home")   -- no Craft menu: the left click's action
    return
  end
  menu = menu or kit.Craft.Menu:Create({ width = 180, theme = kit.menuCtx or kit.ctx, fontFlags = "" })
  menu:SetItems(menuItems())
  menu:Open(anchor, { point = "TOPRIGHT", relativePoint = "BOTTOMLEFT", x = 8, y = 8 })
end

local function onClick(button, mouse)
  if tooltip then tooltip:Hide() end
  if mouse == "RightButton" then
    openMenu(button)
  elseif IsShiftKeyDown() then
    openTab("history")
  else
    ns.MainWindow:Toggle("home")
  end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------
function Minimap:IsShown() return not db().hide end

-- The same tooltip for other QDT buttons on the minimap (the Minimap Lens magnifier, plan M2 F4).
function Minimap:ShowTip(owner, title, pairs_, opts) showTip(owner, title, pairs_, opts) end
function Minimap:HideTip() if tooltip then tooltip:Hide() end end

-- `fn(shown)` runs after every change (the General page switch follows /qdt minimap and the menu).
function Minimap:OnChange(fn) listeners[#listeners + 1] = fn end

function Minimap:SetShown(shown)
  db().hide = not shown
  local icon = dbicon()
  if icon then
    if shown then icon:Show(NAME) else icon:Hide(NAME) end
  end
  for _, fn in ipairs(listeners) do fn(shown) end
end

function Minimap:Init()
  local ldb, icon = LibStub and LibStub("LibDataBroker-1.1", true), dbicon()
  if not (ldb and icon) then return end
  local obj = ldb:NewDataObject(NAME, {
    type = "launcher", label = ns.Brand.TITLE, icon = ns.Style.TIP.icon,
    OnClick = onClick,
    OnEnter = function(owner) showTooltip(owner) end,
    OnLeave = function() if tooltip then tooltip:Hide() end end,
  })
  icon:Register(NAME, obj, db())
end

return Minimap
