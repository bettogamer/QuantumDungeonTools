---@diagnostic disable: undefined-global
-- modules/InstanceTracker/wow/Alerts.lua -- the alerts of plan M1 F5 (artboard «Avisos»).
--
--   * Red 10/10 alert: on the entry that reaches the cap, on joining a group at the cap and when
--     the game refuses an entry ("You have entered too many instances recently.").
--   * Amber strip: on entering the 8th and 9th instance of the hour; gone after 8 s.
--   * End-of-run toast: time, delta and NEW RECORD, four stats and "Share with group".
--     The "History" button waits for the History window (F6).
-- WHAT to show comes from core/Alerts.lua (pure, tested); colors and sizes from core/Style.lua;
-- fonts, borders and tags from the widget's kit (UI:Kit), so a theme change re-fonts them too.
-- Every panel is solid (no HUD outline) and a click on its body closes it.
local _, ns = ...
local L, T = ns.L, ns.InstanceTracker
local Alerts, Style, Format = ns.InstanceAlerts, ns.InstanceTrackerStyle, ns.Format
local S, C, FONT = Style.SIZE, Style.C, Style.FONT
local issecretvalue = ns.issecretvalue

local A = {}
ns.InstanceAlertsUI = A

local CAP_SECONDS = 15
local NEAR_SECONDS = 8      -- owner, 2026-11-14
local TOAST_SECONDS = 30    -- paused while the mouse is over it

local kit                   -- UI:Kit(), resolved on first use
local anchor                -- top-center holder: alert on top, toast under it
local cap, strip, toast     -- frames, built lazily
local lastFinished          -- the run the toast shows (Share sends it)

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------
local function text(parent, font, color)
  local fs = kit.newText(parent, font)
  fs:SetShadowOffset(0, 0)   -- solid panel: no shadow, like the compact panel
  fs:SetJustifyH("LEFT")
  if color then fs:SetTextColor(color.r, color.g, color.b, color.a or 1) end
  return fs
end

local function panel(bg, border)
  local f = CreateFrame("Frame", nil, anchor)
  f:SetFrameStrata("HIGH")
  f:SetWidth(S.alertW)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  kit.setColor(f.bg, bg)
  f.border = kit.newBorder(f)
  kit.colorBorder(f.border, border)
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self) self:Hide() end)
  f:Hide()
  return f
end

-- Shows `f` for `seconds` (re-armed on every show; hover holds it open).
local function showFor(f, seconds)
  f.left = seconds
  f:Show()
  f:SetScript("OnUpdate", function(self, dt)
    if self:IsMouseOver() then return end
    self.left = self.left - dt
    if self.left <= 0 then self:Hide() end
  end)
end

-- The alert (or strip) on top, the toast below whatever is shown above it.
local function stack()
  local prev
  for _, f in ipairs({ cap, strip, toast }) do
    if f and f:IsShown() then
      f:ClearAllPoints()
      if prev then
        f:SetPoint("TOP", prev, "BOTTOM", 0, -S.alertStack)
      else
        f:SetPoint("TOP", anchor, "TOP", 0, 0)
      end
      prev = f
    end
  end
end

local function ensure()
  if anchor then return true end
  kit = ns.InstanceTrackerUI:Kit()
  if not kit then return false end
  anchor = CreateFrame("Frame", "QDTInstanceAlerts", UIParent)
  kit.Craft.Theme.resolve(nil, { theme = kit.ctx }, anchor)   -- Craft children inherit our context
  anchor:SetSize(S.alertW, 1)
  anchor:SetPoint("TOP", UIParent, "TOP", 0, -S.alertTop)
  return true
end

------------------------------------------------------------------------------
-- 10/10 alert and 8/10 strip
------------------------------------------------------------------------------
local function buildCap()
  cap = panel(C.alertBg, C.red)
  cap.icon = cap:CreateTexture(nil, "OVERLAY")
  kit.Craft.Icons.Apply(cap.icon, "triangle-alert", S.alertIcon)
  cap.icon:SetVertexColor(C.red.r, C.red.g, C.red.b, 1)
  cap.icon:SetPoint("TOPLEFT", cap, "TOPLEFT", S.alertPadX, -S.alertPadY)
  cap.title = text(cap, FONT.alertTitle, C.red)
  cap.title:SetPoint("LEFT", cap.icon, "RIGHT", S.alertIconGap, 0)
  cap.body = text(cap, FONT.alertBody, C.sand)
  cap.note = text(cap, FONT.alertSmall, C.muted)
  for _, fs in ipairs({ cap.body, cap.note }) do
    fs:SetWidth(S.alertW - 2 * S.alertPadX)
    fs:SetWordWrap(true)
  end
  cap.body:SetPoint("TOPLEFT", cap.icon, "BOTTOMLEFT", 0, -S.alertGap)
  cap.note:SetPoint("TOPLEFT", cap.body, "BOTTOMLEFT", 0, -S.alertGap)
  cap:HookScript("OnHide", stack)
end

local function buildStrip()
  strip = panel(C.alertBg, C.goldBorder)
  strip.text = text(strip, FONT.alertBody, C.gold)
  strip.text:SetWidth(S.alertW - 2 * S.alertPadX)
  strip.text:SetWordWrap(true)
  strip.text:SetPoint("TOPLEFT", strip, "TOPLEFT", S.alertPadX, -S.stripPadY)
  strip:HookScript("OnHide", stack)
end

-- notice = Alerts.hourNotice(...) (plain numbers: they come from our own list or the game's text)
function A:ShowHour(notice)
  if not notice or not ensure() then return end
  if notice.kind == "cap" then
    if not cap then buildCap() end
    if strip then strip:Hide() end
    kit.setText(cap.title, L.IT_A_CAP_TITLE:format(notice.count, notice.limit))
    if notice.freeIn and notice.freeIn > 0 then
      kit.setText(cap.body, L.IT_A_CAP_BODY:format(Style.code("text") .. Format.clock(notice.freeIn) .. "|r"))
    else
      kit.setText(cap.body, L.IT_A_CAP_BODY_NOW)
    end
    kit.setText(cap.note, L.IT_A_CAP_NOTE)
    cap:SetHeight(S.alertPadY * 2 + math.max(S.alertIcon, cap.title:GetStringHeight()) + S.alertGap
      + cap.body:GetStringHeight() + S.alertGap + cap.note:GetStringHeight())
    showFor(cap, CAP_SECONDS)
  else
    if not strip then buildStrip() end
    if cap and cap:IsShown() then return end   -- the red one says more
    kit.setText(strip.text, L.IT_A_NEAR:format(notice.count, notice.limit, Format.clock(notice.freeIn or 0)))
    strip:SetHeight(S.stripPadY * 2 + strip.text:GetStringHeight())
    showFor(strip, NEAR_SECONDS)
  end
  stack()
end

------------------------------------------------------------------------------
-- End-of-run toast
------------------------------------------------------------------------------
local STAT_LABEL = { deaths = "IT_A_DEATHS", xp = "IT_A_XP", gold = "IT_A_GOLD", rep = "IT_A_REP" }

local function statValue(s)
  if s.id == "deaths" then return tostring(s.value) end
  if s.id == "gold" then return kit.moneyText(s.value) end
  return (s.value > 0 and "+" or "") .. Format.thousands(s.value)
end

local function channel()
  local ok, inst = pcall(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)
  if ok and not issecretvalue(inst) and inst then return "INSTANCE_CHAT" end
  local okR, raid = pcall(IsInRaid)
  if okR and not issecretvalue(raid) and raid then return "RAID" end
  local okP, party = pcall(IsInGroup)
  if okP and not issecretvalue(party) and party then return "PARTY" end
end

-- Chat lines go out under pcall, one per chunk of 255 bytes (pattern of NF's SendLine).
local function share()
  if not lastFinished then return end
  local run, opts = lastFinished.run, lastFinished.opts
  local line = Alerts.shareLine(run, opts, { record = L.IT_A_W_RECORD, deaths1 = L.IT_A_W_DEATH1,
    deathsN = L.IT_A_W_DEATHN, xp = L.IT_A_XP })
  local ch = channel()
  if not ch then
    ns.say(L.IT_A_NO_GROUP)
    return
  end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  for _, part in ipairs(Alerts.chunks(ns.Brand.SHORT .. ": " .. line, 255)) do
    local ok = send and pcall(send, part, ch)
    if not ok then
      ns.say(L.IT_A_SEND_FAIL)
      return
    end
  end
end

local function buildToast()
  toast = panel(C.panel, C.hairline)
  local inner = S.alertW - 2 * S.alertPadX
  toast.title = text(toast, FONT.alertTitle, C.cream)
  toast.title:SetPoint("TOPLEFT", toast, "TOPLEFT", S.alertPadX, -S.alertPadY)
  toast.tag = kit.newTag(toast, FONT.tagStrong)
  toast.tag:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -S.alertPadX, -S.alertPadY)
  toast.line = toast:CreateTexture(nil, "ARTWORK")
  kit.setColor(toast.line, C.hairline)
  toast.line:SetHeight(1)
  toast.sub = text(toast, FONT.alertBody, C.muted)
  toast.clock = text(toast, FONT.toastClock)
  toast.delta = text(toast, FONT.toastDelta)
  toast.delta:SetPoint("BOTTOMLEFT", toast.clock, "BOTTOMRIGHT", S.toastClockGap, 3)
  toast.stats = {}
  local colW = (inner - 3 * S.toastStatGap) / 4
  for i = 1, 4 do
    local k = text(toast, FONT.alertSmall, C.muted)
    local v = text(toast, FONT.toastStat)
    k:SetWidth(colW)
    v:SetWidth(colW)
    v:SetPoint("TOPLEFT", k, "BOTTOMLEFT", 0, -S.toastStatKV)
    toast.stats[i] = { k = k, v = v }
  end
  toast.share = kit.Craft.Button:Create(toast, { text = L.IT_A_SHARE, size = "sm", onClick = share })
  toast:HookScript("OnHide", stack)
end

local function layoutToast()
  local head = S.alertPadY * 2 + math.max(toast.title:GetStringHeight(), toast.tag:GetHeight())
  toast.line:ClearAllPoints()
  toast.line:SetPoint("TOPLEFT", toast, "TOPLEFT", 0, -head)
  toast.line:SetPoint("TOPRIGHT", toast, "TOPRIGHT", 0, -head)
  local y = head + S.alertPadY
  toast.sub:SetPoint("TOPLEFT", toast, "TOPLEFT", S.alertPadX, -y)
  y = y + toast.sub:GetStringHeight() + S.toastGap
  toast.clock:SetPoint("TOPLEFT", toast, "TOPLEFT", S.alertPadX, -y)
  y = y + toast.clock:GetStringHeight() + S.toastGap
  local colW = (S.alertW - 2 * S.alertPadX - 3 * S.toastStatGap) / 4
  local statH = 0
  for i, st in ipairs(toast.stats) do
    st.k:SetPoint("TOPLEFT", toast, "TOPLEFT", S.alertPadX + (i - 1) * (colW + S.toastStatGap), -y)
    statH = math.max(statH, st.k:GetStringHeight() + S.toastStatKV + st.v:GetStringHeight())
  end
  y = y + statH + S.toastGap + S.toastBtnTop
  local btn = toast.share:GetFrame()
  btn:ClearAllPoints()
  btn:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -S.alertPadX, -y)
  toast:SetHeight(y + btn:GetHeight() + S.alertPadY)
end

-- run: a finished Run; opts: { pb, deaths } (only the demo passes them).
function A:ShowToast(run, opts)
  local t = Alerts.toast(run, opts)
  if not t or not ensure() then return end
  if not toast then buildToast() end
  lastFinished = { run = run, opts = opts }
  kit.setText(toast.title, L.IT_A_DONE)
  if t.record then
    kit.setTag(toast.tag, L.IT_A_RECORD, C.turquoise, C.turquoise)
    toast.tag:Show()
  else
    toast.tag:Hide()
  end
  local sub = t.sub.name .. (t.sub.difficulty and (Alerts.SEP .. t.sub.difficulty) or "")
  kit.setText(toast.sub, sub)
  kit.setText(toast.clock, t.clock, Style.tone(t.clockTone))
  if t.delta then
    kit.setText(toast.delta, t.delta.text, Style.tone(t.delta.tone))
    toast.delta:Show()
  else
    toast.delta:Hide()
  end
  for i, s in ipairs(t.stats) do
    local st = toast.stats[i]
    kit.setText(st.k, L[STAT_LABEL[s.id]])
    kit.setText(st.v, statValue(s), Style.tone(s.tone))
  end
  layoutToast()
  showFor(toast, TOAST_SECONDS)
  stack()
end

------------------------------------------------------------------------------
-- Previews (/qdt it alert <toast | cap | near>)
------------------------------------------------------------------------------
function A:Preview(name)
  if name == "toast" then
    local run, opts = ns.InstanceTrackerDemo.get("done")
    run.newRecord = true
    self:ShowToast(run, opts)
  elseif name == "cap" then
    self:ShowHour({ kind = "cap", count = 10, limit = 10, freeIn = 760 })
  elseif name == "near" then
    self:ShowHour({ kind = "near", count = 8, limit = 10, freeIn = 760 })
  else
    return false
  end
  return true
end

------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------
-- The game's refusal: a system line or a UI error with one of these globals (compared as
-- plain text; a secret line is skipped).
local function isTooMany(msg)
  if issecretvalue(msg) or type(msg) ~= "string" then return false end
  for _, g in ipairs({ TRANSFER_ABORT_TOO_MANY_INSTANCES or false, ERR_TOO_MANY_INSTANCES or false }) do
    if g and msg == g then return true end
  end
  return false
end

local function blocked()
  A:ShowHour(Alerts.hourNotice(T:HourSnapshot(), "blocked"))
end

local frame
function A:Init()
  T:OnHourEntry(function(snap) A:ShowHour(Alerts.hourNotice(snap, "entry")) end)
  T:OnFinish(function(run) A:ShowToast(run) end)
  frame = frame or CreateFrame("Frame")
  for _, ev in ipairs({ "GROUP_JOINED", "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE" }) do
    pcall(frame.RegisterEvent, frame, ev)
  end
  frame:SetScript("OnEvent", function(_, event, a1, a2)
    local ok, err = pcall(function()
      if event == "GROUP_JOINED" then
        A:ShowHour(Alerts.hourNotice(T:HourSnapshot(), "group"))
      elseif event == "CHAT_MSG_SYSTEM" then
        if isTooMany(a1) then blocked() end
      elseif event == "UI_ERROR_MESSAGE" then   -- errorType, message
        if isTooMany(a2) then blocked() end
      end
    end)
    if not ok then geterrorhandler()(err) end
  end)
end

return A
