-- core/Format.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API): text formatting shared by modules.
local _, ns = ...

local Format = {}
ns.Format = Format

-- duration(65) -> "01:05"; duration(3725) -> "1:02:05". Negative/invalid -> "00:00".
function Format.duration(sec)
  if type(sec) ~= "number" or sec ~= sec or sec < 0 then sec = 0 end
  sec = math.floor(sec)
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%02d:%02d", m, s)
end

-- clock(238) -> "3:58"; clock(3725) -> "1:02:05". The widget's look: no leading zero on the
-- first field (duration() keeps "03:58" for the chat history).
function Format.clock(sec)
  if type(sec) ~= "number" or sec ~= sec or sec < 0 then sec = 0 end
  sec = math.floor(sec)
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

-- delta(-12) -> "-0:12"; delta(20) -> "+0:20"; delta(0) -> "0:00". ASCII minus on purpose:
-- the widget font may not carry U+2212.
function Format.delta(sec)
  if type(sec) ~= "number" or sec ~= sec then sec = 0 end
  local whole = math.floor(math.abs(sec) + 0.5)
  if whole == 0 then return "0:00" end
  return (sec < 0 and "-" or "+") .. Format.clock(whole)
end

-- thousands(1234567) -> "1,234,567". Plain Lua on purpose: never pass it a secret value.
function Format.thousands(n)
  n = math.floor(tonumber(n) or 0)
  local digits = tostring(math.abs(n))
  local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  grouped = (grouped:gsub("^,", ""))
  return (n < 0 and "-" or "") .. grouped
end

return Format
