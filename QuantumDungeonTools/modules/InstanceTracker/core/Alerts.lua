-- modules/InstanceTracker/core/Alerts.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- What the alerts of plan M1 F5 show (artboard «Avisos»); wow/Alerts.lua paints it.
--   Alerts.hourNotice(snap, trigger) -> nil | { kind = "cap"|"near", count, limit, freeIn }
--     trigger "entry"   = we just walked into a new instance: cap at limit, near at limit-2..limit-1
--             "group"   = we joined a group: only the cap
--             "blocked" = the game refused the entry (too many instances): always the cap
--     (owner, 2026-11-14: three triggers for the cap; the amber strip only on entering the 8th/9th.)
--   Alerts.toast(run, opts) -> the end-of-run card (semantic: texts + tones, no colors)
--   Alerts.shareLine(run, opts, words) -> one plain chat line (no textures, ASCII minus)
--   Alerts.chunks(text, max) -> the line cut at " · " into pieces of at most `max` bytes
local _, ns = ...
local Format = ns.Format

local Alerts = {}
ns.InstanceAlerts = Alerts

Alerts.NEAR = 2   -- the amber strip shows from limit - NEAR (8/10)
Alerts.SEP = " \194\183 "   -- " · "

local function num(v) return type(v) == "number" and v == v end

function Alerts.hourNotice(snap, trigger)
  if type(snap) ~= "table" or not num(snap.count) or not num(snap.limit) then return nil end
  local n = { count = snap.count, limit = snap.limit, freeIn = snap.freeIn }
  if trigger == "blocked" then
    n.kind, n.count = "cap", math.max(n.count, n.limit)   -- the game knows better than our list
  elseif (trigger == "entry" or trigger == "group") and n.count >= n.limit then
    n.kind = "cap"
  elseif trigger == "entry" and n.count >= n.limit - Alerts.NEAR then
    n.kind = "near"
  else
    return nil
  end
  return n
end

local function pbOf(run, opts)
  local pb = (opts and opts.pb) or run.pb
  if type(pb) == "table" and num(pb.total) and pb.total > 0 then return pb end
end

local function repTotal(run)
  local sum = 0
  if type(run.rep) == "table" then
    for _, amount in pairs(run.rep) do
      if num(amount) then sum = sum + amount end
    end
  end
  return sum
end

local function deathsOf(run, opts)
  local d = (opts and opts.deaths) or run.deaths
  return num(d) and d or 0
end

-- { record, sub = { name, difficulty }, clock, clockTone, delta = { sec, text, tone } | nil,
--   stats = { { id = "deaths"|"xp"|"gold"|"rep", value, tone } } }
function Alerts.toast(run, opts)
  if not run then return nil end
  local elapsed = run:elapsed()
  local pb = pbOf(run, opts)
  local t = {
    sub = { name = run.name or "?", difficulty = run.difficulty ~= "" and run.difficulty or nil },
    clock = Format.clock(elapsed), clockTone = "text",
  }
  if pb then
    local d = elapsed - pb.total
    t.record = run.newRecord == true or d < 0
    t.delta = { sec = d, text = Format.delta(d), tone = d <= 0 and "ahead" or "behind" }
    if t.record then t.clockTone = "ahead" end
  end
  local deaths = deathsOf(run, opts)
  t.stats = {
    { id = "deaths", value = deaths, tone = deaths > 0 and "behind" or "text" },
    { id = "xp", value = num(run.xp) and run.xp or 0, tone = "xp" },
    { id = "gold", value = num(run.copper) and run.copper or 0, tone = "text" },
    { id = "rep", value = repTotal(run), tone = "text" },
  }
  return t
end

-- The toast's gold column fits two denominations (artboard: "+7 [g] 80 [s]"): with gold, the
-- copper is dropped (floored to the silver); below 1 gold it is kept.
function Alerts.dropCopper(copper)
  if not num(copper) or copper < 10000 then return copper end
  return copper - copper % 100
end

-- coins(78012) -> "7g 80s 12c" (chat cannot carry coin textures); zero denominations dropped.
function Alerts.coins(copper)
  if not num(copper) or copper <= 0 then return "0c" end
  copper = math.floor(copper)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = Format.thousands(g) .. "g" end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if c > 0 then parts[#parts + 1] = c .. "c" end
  return table.concat(parts, " ")
end

-- words = { record = "new record", deaths1 = "1 death", deathsN = "%d deaths", xp = "XP" }
-- -> "Ruins of Lordaeron (Normal) 29:51 · new record -1:49 · 3 deaths · +41,220 XP · +7g 80s"
function Alerts.shareLine(run, opts, words)
  local t = Alerts.toast(run, opts)
  if not t then return nil end
  words = words or {}
  local head = t.sub.name .. (t.sub.difficulty and (" (" .. t.sub.difficulty .. ")") or "") .. " " .. t.clock
  local parts = { head }
  if t.delta then
    local d = t.delta.sec < 0 and ("-" .. Format.clock(-t.delta.sec)) or Format.delta(t.delta.sec)
    parts[#parts + 1] = t.record and ((words.record or "new record") .. " " .. d) or d
  end
  for _, s in ipairs(t.stats) do
    if s.id == "deaths" and s.value > 0 then
      local many = (words.deathsN or "%d deaths"):format(s.value)
      parts[#parts + 1] = s.value == 1 and (words.deaths1 or "1 death") or many
    elseif s.id == "xp" and s.value > 0 then
      parts[#parts + 1] = "+" .. Format.thousands(s.value) .. " " .. (words.xp or "XP")
    elseif s.id == "gold" and s.value > 0 then
      parts[#parts + 1] = "+" .. Alerts.coins(s.value)
    end
  end
  return table.concat(parts, Alerts.SEP)
end

-- Cuts at the " · " separators so every piece fits in `max` bytes (chat limit 255). A single
-- part longer than `max` is cut hard.
function Alerts.chunks(text, max)
  max = max or 255
  if type(text) ~= "string" then return {} end
  if #text <= max then return { text } end
  local out, cur = {}, ""
  local sep = Alerts.SEP
  local pos = 1
  while pos <= #text do
    local s, e = text:find(sep, pos, true)
    local part = text:sub(pos, (s or #text + 1) - 1)
    pos = e and e + 1 or #text + 1
    local joined = cur == "" and part or (cur .. sep .. part)
    if #joined <= max then
      cur = joined
    else
      if cur ~= "" then out[#out + 1] = cur end
      while #part > max do
        out[#out + 1] = part:sub(1, max)
        part = part:sub(max + 1)
      end
      cur = part
    end
  end
  if cur ~= "" then out[#out + 1] = cur end
  return out
end

return Alerts
