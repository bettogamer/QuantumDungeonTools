---@diagnostic disable: undefined-global
-- modules/InstanceTracker/wow/Alerts.lua -- the alerts of plan M1 F5 (artboard «Avisos»).
--
--   * Red 10/10 alert: on the entry that reaches the cap, on joining a group at the cap and when
--     the game refuses an entry ("You have entered too many instances recently.").
--   * Amber strip: on entering the 8th and 9th instance of the hour; gone after 8 s.
--   * End-of-run toast: time, delta and NEW RECORD, four stats and "Share with group".
--     "History" opens the History tab of the main window (F6d).
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
-- Motion (owner, 2026-11-14: every component animates). Same engine, time and easing as
-- Craft.Toast: one Weave tween per panel over { alpha, y }.
local MOTION = 0.4          -- sonner's transition, Craft.Toast TRANSITION
local LIFT = 16             -- panels drop in from / leave toward this many px above their slot
local Weave = LibStub("Weave-1.0")

local kit                   -- UI:Kit(), resolved on first use
local anchor                -- top-center holder: alert on top, toast under it
local cap, strip, toast     -- frames, built lazily
local board                 -- other modules' notices (Minimap Lens soft mode, plan M2 F3)
local lastFinished          -- the run the toast shows (Share sends it)

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------
local function text(parent, font, color)
  local fs = kit.newText(parent, font)
  fs:SetShadowOffset(0, 0)   -- solid panel: no shadow (and transparent: at offset 0 it still
  fs:SetShadowColor(0, 0, 0, 0)   -- darkened the glyph edges like a thin outline)
  fs:SetJustifyH("LEFT")
  if color then fs:SetTextColor(color.r, color.g, color.b, color.a or 1) end
  return fs
end

------------------------------------------------------------------------------
-- Motion: enter = fade in dropping LIFT px into its slot; leave = fade out rising back, then
-- hide; the panels left behind slide to their new slots instead of jumping.
------------------------------------------------------------------------------
local function place(f, v)   -- v = { alpha, y below the anchor's top }
  f:SetAlpha(v[1])
  f:ClearAllPoints()
  f:SetPoint("TOP", anchor, "TOP", 0, -v[2])
end

local function motion(f)
  local m = kit.ctx:get()
  f.goal = Weave.signal({ 0, 0 })
  f.tween = Weave.tween(f.goal, { duration = MOTION,
    easing = Weave.easing[m.motionEasing] or Weave.easing.outQuad })
  f.effect = Weave.effect(function()
    local v = f.tween()
    if type(v) == "table" then place(f, v) end
  end)
end

-- Gives every shown panel its slot (alert on top, toast below) and slides it there.
local function stack()
  local y = 0
  for _, f in ipairs({ cap or false, strip or false, toast or false, board or false }) do   -- no nil holes
    if f and f:IsShown() and not f.leaving then
      f.slot = y
      f.goal:set({ 1, y })
      if f.entering then
        f.entering = false
        f.tween:snap({ 0, y - LIFT })   -- start above, transparent, and drop in
      end
      y = y + f:GetHeight() + S.alertStack
    end
  end
end

local function dismiss(f)
  if not f or not f:IsShown() or f.leaving then return end
  f.leaving = true
  f.leaveLeft = MOTION
  f.goal:set({ 0, (f.slot or 0) - LIFT })
  stack()
end

-- Shows `f` for `seconds` (re-armed on every show; hover holds it open). The caller fills it
-- and then calls stack(), which starts the entry.
local function showFor(f, seconds)
  f.left = seconds
  if not f:IsShown() or f.leaving then
    f.leaving = false
    f.entering = true
    f:SetAlpha(0)
    f:Show()
  end
end

local function tick(f, dt)
  if f.leaving then
    f.leaveLeft = f.leaveLeft - dt
    if f.leaveLeft <= 0 then
      f.leaving = false
      f:Hide()
    end
    return
  end
  if f:IsMouseOver() then return end
  f.left = (f.left or 0) - dt
  if f.left <= 0 then dismiss(f) end
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
  f:SetScript("OnMouseUp", dismiss)
  f:SetScript("OnUpdate", tick)
  f:Hide()
  motion(f)
  return f
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
------------------------------------------------------------------------------
-- Rich text: one wrapped paragraph whose pieces may differ in font and color (a FontString
-- has a single weight; the design's "<b>12:40</b>" needs its own). Wraps word by word,
-- measuring each word in its own font, into one FontString per run of a line.
--   rich:Set({ { text, font, color }, ... }) -> height
------------------------------------------------------------------------------
local function newRich(parent, width)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(width, 1)
  local pool, probes = {}, {}

  local function probe(font)
    local p = probes[font]
    if not p then
      p = text(box, font)
      p:Hide()
      probes[font] = p
    end
    return p
  end

  local function measure(font, s)
    local p = probe(font)
    p:SetText(s)
    return p:GetStringWidth()
  end

  local function spaceOf(font)   -- trailing spaces are not measured: "x x" - "xx"
    return measure(font, "x x") - measure(font, "xx")
  end

  function box:Set(segments)
    local lines, line, x = {}, {}, 0
    lines[1] = line
    for _, seg in ipairs(segments) do
      local sp = spaceOf(seg[2])
      for word, gap in seg[1]:gmatch("(%S+)(%s*)") do
        local w = measure(seg[2], word)
        if x > 0 and x + w > width then
          line = {}
          lines[#lines + 1] = line
          x = 0
        end
        local run = line[#line]
        if not run or run.seg ~= seg then
          run = { seg = seg, x = x, text = "" }
          line[#line + 1] = run
        end
        run.text = run.text .. word
        x = x + w
        if gap ~= "" then
          run.text = run.text .. " "
          x = x + sp
        end
      end
    end
    local lineH = 0
    for _, seg in ipairs(segments) do
      local p = probe(seg[2])
      p:SetText("Xg")
      lineH = math.max(lineH, p:GetStringHeight())
    end
    local n = 0
    for li, l in ipairs(lines) do
      for _, run in ipairs(l) do
        n = n + 1
        local fs = pool[n]
        if not fs then
          fs = text(box, FONT.alertBody)
          pool[n] = fs
        end
        kit.applyFontOf(fs, run.seg[2])
        kit.setText(fs, run.text, run.seg[3])
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", box, "TOPLEFT", run.x, -(li - 1) * lineH)
        fs:Show()
      end
    end
    for i = n + 1, #pool do pool[i]:Hide() end
    local h = #lines * lineH
    box:SetHeight(math.max(1, h))
    return h
  end

  return box
end

-- Splits a localized "...%s..." around its %s: the time goes in bold, the rest stays as is.
local function around(fmt)
  local pre, post = fmt:match("^(.-)%%s(.*)$")
  return pre or fmt, post or ""
end

local function buildCap()
  cap = panel(C.alertBg, C.red)
  cap.icon = cap:CreateTexture(nil, "OVERLAY")
  kit.Craft.Icons.Apply(cap.icon, "triangle-alert", S.alertIcon)
  cap.icon:SetVertexColor(C.red.r, C.red.g, C.red.b, 1)
  cap.icon:SetPoint("TOPLEFT", cap, "TOPLEFT", S.alertPadX, -S.alertPadY)
  cap.title = text(cap, FONT.alertTitle, C.red)
  cap.title:SetPoint("LEFT", cap.icon, "RIGHT", S.alertIconGap, 0)
  cap.body = newRich(cap, S.alertW - 2 * S.alertPadX)
  cap.note = text(cap, FONT.alertSmall, C.muted)
  cap.note:SetWidth(S.alertW - 2 * S.alertPadX)
  cap.note:SetWordWrap(true)
  cap.body:SetPoint("TOPLEFT", cap.icon, "BOTTOMLEFT", 0, -S.alertGap)
  cap.note:SetPoint("TOPLEFT", cap.body, "BOTTOMLEFT", 0, -S.alertGap)
end

local function buildStrip()
  strip = panel(C.alertBg, C.goldBorder)
  strip.text = text(strip, FONT.alertBody, C.gold)
  strip.text:SetWidth(S.alertW - 2 * S.alertPadX)
  strip.text:SetWordWrap(true)
  strip.text:SetPoint("TOPLEFT", strip, "TOPLEFT", S.alertPadX, -S.stripPadY)
end

-- notice = Alerts.hourNotice(...) (plain numbers: they come from our own list or the game's text)
function A:ShowHour(notice)
  if not notice or not ensure() then return end
  if notice.kind == "cap" then
    if not cap then buildCap() end
    dismiss(strip)
    kit.setText(cap.title, L.IT_A_CAP_TITLE:format(notice.count, notice.limit))
    local bodyH
    if notice.freeIn and notice.freeIn > 0 then
      local pre, post = around(L.IT_A_CAP_BODY)   -- design: the time in bold cream
      bodyH = cap.body:Set({ { pre, FONT.alertBody, C.sand },
        { Format.clock(notice.freeIn), FONT.alertBodyBold, C.cream }, { post, FONT.alertBody, C.sand } })
    else
      bodyH = cap.body:Set({ { L.IT_A_CAP_BODY_NOW, FONT.alertBody, C.sand } })
    end
    kit.setText(cap.note, L.IT_A_CAP_NOTE)
    cap:SetHeight(S.alertPadY * 2 + math.max(S.alertIcon, cap.title:GetStringHeight()) + S.alertGap
      + bodyH + S.alertGap + cap.note:GetStringHeight())
    showFor(cap, CAP_SECONDS)
  else
    if not strip then buildStrip() end
    if cap and cap:IsShown() and not cap.leaving then return end   -- the red one says more
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
  if s.id == "gold" then return kit.moneyText(Alerts.dropCopper(s.value)) end
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

-- Stat columns 1fr 1fr 1.5fr 1fr (ui-critic A2): gold + silver with icons needs the room.
local COL_FR = { 1, 1, 1.5, 1 }
local function colWidth(inner, i)
  return (inner - 3 * S.toastStatGap) * COL_FR[i] / 4.5
end

local function colX(inner, i)
  local x = 0
  for j = 1, i - 1 do x = x + colWidth(inner, j) + S.toastStatGap end
  return x
end

local function buildToast()
  toast = panel(C.panel, C.hairline)
  local inner = S.alertW - 2 * S.alertPadX
  toast.title = text(toast, FONT.alertTitle, C.cream)
  toast.title:SetPoint("TOPLEFT", toast, "TOPLEFT", S.alertPadX, -S.alertPadY)
  toast.tag = kit.newTag(toast, FONT.toastTag)
  toast.tag:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -S.alertPadX, -S.alertPadY)
  toast.line = toast:CreateTexture(nil, "ARTWORK")
  kit.setColor(toast.line, C.hairline)
  toast.line:SetHeight(1)
  toast.sub = text(toast, FONT.toastName, C.cream)
  toast.clock = text(toast, FONT.toastClock)
  toast.delta = text(toast, FONT.toastDelta)
  toast.delta:SetPoint("BOTTOMLEFT", toast.clock, "BOTTOMRIGHT", S.toastClockGap, S.toastDeltaBase)
  toast.vs = text(toast, FONT.alertSmall, C.muted)
  toast.vs:SetPoint("BOTTOMLEFT", toast.delta, "BOTTOMRIGHT", S.toastVsGap, 1)
  toast.stats = {}
  for i = 1, 4 do
    local k = text(toast, FONT.alertSmall, C.muted)
    local v = text(toast, FONT.toastStat)
    k:SetWidth(colWidth(inner, i))
    v:SetWidth(colWidth(inner, i))
    v:SetPoint("TOPLEFT", k, "BOTTOMLEFT", 0, -S.toastStatKV)
    toast.stats[i] = { k = k, v = v }
  end
  toast.share = kit.Craft.Button:Create(toast, { text = L.IT_A_SHARE, size = "sm", onClick = share,
    -- default = the theme's primary: gold with navy text (artboard «Oro Forever»)
    fontFlags = FONT.toastButton.flags })
  toast.history = kit.Craft.Button:Create(toast, { text = L.IT_A_HISTORY, size = "sm", variant = "outline",
    fontFlags = FONT.toastButton.flags, onClick = function() ns.InstanceTrackerPage:OpenHistory() end })
end

local function layoutToast()
  local head = S.alertPadY * 2 + math.max(toast.title:GetStringHeight(), toast.tag:GetHeight())
  toast.line:ClearAllPoints()
  toast.line:SetPoint("TOPLEFT", toast, "TOPLEFT", 0, -head)
  toast.line:SetPoint("TOPRIGHT", toast, "TOPRIGHT", 0, -head)
  local y = head + S.alertPadY
  toast.sub:SetPoint("TOPLEFT", toast, "TOPLEFT", S.alertPadX, -y)
  y = y + toast.sub:GetStringHeight() + S.toastNameGap
  toast.clock:SetPoint("TOPLEFT", toast, "TOPLEFT", S.alertPadX, -y)
  y = y + toast.clock:GetStringHeight() + S.toastBlockGap
  local inner = S.alertW - 2 * S.alertPadX
  local statH = 0
  for i, st in ipairs(toast.stats) do
    st.k:SetPoint("TOPLEFT", toast, "TOPLEFT", S.alertPadX + colX(inner, i), -y)
    statH = math.max(statH, st.k:GetStringHeight() + S.toastStatKV + st.v:GetStringHeight())
  end
  y = y + statH + S.toastBlockGap
  local btn = toast.share:GetFrame()
  btn:ClearAllPoints()
  btn:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -S.alertPadX, -y)
  local hist = toast.history:GetFrame()
  hist:ClearAllPoints()
  hist:SetPoint("RIGHT", btn, "LEFT", -S.toastButtonGap, 0)
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
    -- Gold block with navy text, as the badge of «Oro Forever» (owner, 2026-11-14).
    toast.tag.badge:SetColors({ text = C.panel, border = C.gold, fill = C.gold })
    toast.tag.badge:SetText(L.IT_A_RECORD)
    toast.tag:Show()
  else
    toast.tag:Hide()
  end
  local sub = t.sub.name .. (t.sub.difficulty and (Alerts.SEP .. t.sub.difficulty) or "")
  kit.setText(toast.sub, sub)
  kit.setText(toast.clock, t.clock, Style.tone(t.clockTone))
  if t.delta then
    kit.setText(toast.delta, t.delta.text, Style.tone(t.delta.tone))
    kit.setText(toast.vs, L.IT_A_VS_RECORD)
    toast.delta:Show()
    toast.vs:Show()
  else
    toast.delta:Hide()
    toast.vs:Hide()
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
-- Notice (artboard LensAviso, variant A): gold icon + title, sand body, "Got it" (outline) and
-- an optional primary action. Same panel, motion and stack as the alerts; one at a time.
--   A:ShowNotice({ icon, title, body, seconds, action = { text, onClick }? }) -> true if shown
------------------------------------------------------------------------------
local function buildNotice()
  board = panel(C.alertBg, C.goldBorder)
  board.icon = board:CreateTexture(nil, "OVERLAY")
  board.icon:SetPoint("TOPLEFT", board, "TOPLEFT", S.alertPadX, -S.alertPadY)
  board.title = text(board, FONT.alertTitle, C.gold)
  board.title:SetPoint("LEFT", board.icon, "RIGHT", S.alertIconGap, 0)
  board.body = text(board, FONT.alertBody, C.sand)
  board.body:SetWidth(S.alertW - 2 * S.alertPadX)
  board.body:SetWordWrap(true)
  board.body:SetPoint("TOPLEFT", board.icon, "BOTTOMLEFT", 0, -S.alertGap)
  board.action = kit.Craft.Button:Create(board, { text = "", size = "sm", fontFlags = FONT.toastButton.flags,
    onClick = function()
      if board.onAction then board.onAction() end
      dismiss(board)
    end })
  board.close = kit.Craft.Button:Create(board, { text = L.LENS_GOT_IT, size = "sm", variant = "outline",
    fontFlags = FONT.toastButton.flags, onClick = function() dismiss(board) end })
end

function A:ShowNotice(n)
  if type(n) ~= "table" or not ensure() then return false end
  if not board then buildNotice() end
  kit.Craft.Icons.Apply(board.icon, n.icon or "search", S.alertIcon)
  board.icon:SetVertexColor(C.gold.r, C.gold.g, C.gold.b, 1)
  kit.setText(board.title, n.title or "")
  kit.setText(board.body, n.body or "")
  local y = S.alertPadY + math.max(S.alertIcon, board.title:GetStringHeight()) + S.alertGap
    + board.body:GetStringHeight() + S.alertGap
  local close, action = board.close:GetFrame(), board.action:GetFrame()
  action:ClearAllPoints()
  close:ClearAllPoints()
  if n.action then
    board.action:SetText(n.action.text)
    board.onAction = n.action.onClick
    action:SetPoint("TOPRIGHT", board, "TOPRIGHT", -S.alertPadX, -y)
    close:SetPoint("RIGHT", action, "LEFT", -S.toastButtonGap, 0)
    action:Show()
  else
    board.onAction = nil
    close:SetPoint("TOPRIGHT", board, "TOPRIGHT", -S.alertPadX, -y)
    action:Hide()
  end
  board:SetHeight(y + close:GetHeight() + S.alertPadY)
  showFor(board, n.seconds or NEAR_SECONDS)
  stack()
  return true
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
