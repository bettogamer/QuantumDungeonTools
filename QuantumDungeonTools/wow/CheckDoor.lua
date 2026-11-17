---@diagnostic disable: undefined-global
-- wow/CheckDoor.lua -- `/qdt check door`: research probe for the minimap map switch (outdoor <->
-- underground) at the Undercity gate (docs/LECCIONES.md, minimapa-grande-sin-terreno-bajo-tierra).
-- The lens needs a signal to flash on; zone texts, IsIndoors, GetBestMapForUnit and ZONE_CHANGED*
-- are already ruled out. This RECORDS, while you walk through the gate:
--   1. Every event (frame:RegisterAllEvents), name only: never touches the payload.
--   2. Every frame, the minimap readings that could flip with the map (zoom, zoom levels, view
--      radius, zoom CVars, indoors, ping position, minimap zone text), stored only on change.
--   `/qdt check door`       start (auto-stops after MAX s) / stop.
--   `/qdt check door mark`  stamp "I saw the minimap switch now" (bind it to a macro).
--   `/qdt check door reset` clear.
-- Dump: QuantumDungeonToolsDB._checkDoor.runs (last RUNS_MAX), read with scripts/read-check-door.lua
-- after a /reload. Every value through issecretvalue first, every call through pcall.
local _, ns = ...
local issecretvalue = ns.issecretvalue

local C = {}
ns.CheckDoor = C

local FORMAT = 1
local RUNS_MAX = 4
local MAX = 120
local TIMELINE_MAX = 3000
local CHANGES_MAX = 1500
-- Per-frame or per-tick spam: counted, never put on the timeline.
local NOISY = {
  COMBAT_LOG_EVENT_UNFILTERED = true, COMBAT_LOG_EVENT = true, CHAT_MSG_ADDON = true,
  CHAT_MSG_ADDON_LOGGED = true, UPDATE_MOUSEOVER_UNIT = true, CURSOR_CHANGED = true,
  CURSOR_UPDATE = true, MODIFIER_STATE_CHANGED = true, GLOBAL_MOUSE_DOWN = true,
  GLOBAL_MOUSE_UP = true,
}

local function say(s) print("|cff7dd3fcQDT check door|r " .. s) end

local function enc(v)
  if issecretvalue(v) then return "SECRET" end
  local t = type(v)
  if t == "number" then return tostring(math.floor(v * 1000 + 0.5) / 1000) end
  if t == "nil" then return "nil" end
  if t == "boolean" or t == "string" then return tostring(v) end
  return "<" .. t .. ">"
end

local function probe(fn, ...)
  if type(fn) ~= "function" then return "absent" end
  local r = { pcall(fn, ...) }
  if not r[1] then return "err" end
  local out = {}
  for i = 2, math.max(#r, 2) do out[#out + 1] = enc(r[i]) end
  return table.concat(out, ",")
end

local function method(obj, name, ...)
  if not obj or type(obj[name]) ~= "function" then return "absent" end
  return probe(obj[name], obj, ...)
end

local function cvar(name)
  local get = (C_CVar and C_CVar.GetCVar) or GetCVar
  return probe(get, name)
end

-- Fields of one reading, in order (the reducer prints them by name).
local FIELDS = { "zoom", "levels", "radius", "cvOut", "cvIn", "indoors", "outdoors", "ping",
  "mmZone", "alpha", "shown" }
local function read()
  return {
    method(Minimap, "GetZoom"),
    method(Minimap, "GetZoomLevels"),
    probe(C_Minimap and C_Minimap.GetViewRadius),
    cvar("minimapZoom"),
    cvar("minimapInsideZoom"),
    probe(IsIndoors),
    probe(IsOutdoors),
    method(Minimap, "GetPingPosition"),
    probe(GetMinimapZoneText),
    method(Minimap, "GetAlpha"),
    method(Minimap, "IsVisible"),
  }
end

local rec, f, t0, last

local function root(create)
  local db = QuantumDungeonToolsDB
  if type(db) ~= "table" then return nil end
  if create then db._checkDoor = db._checkDoor or { format = FORMAT, runs = {} } end
  return db._checkDoor
end

local function now() return GetTime() - t0 end

local function stamp(line)
  if #rec.timeline < TIMELINE_MAX then
    rec.timeline[#rec.timeline + 1] = ("%.3f|%s"):format(now(), line)
  else
    rec.dropped = rec.dropped + 1
  end
end

local function sample()
  local r = read()
  if last then
    local diff = {}
    for i, v in ipairs(r) do
      if v ~= last[i] then diff[#diff + 1] = FIELDS[i] .. "=" .. last[i] .. ">" .. v end
    end
    if #diff > 0 and #rec.changes < CHANGES_MAX then
      rec.changes[#rec.changes + 1] = ("%.3f|%s"):format(now(), table.concat(diff, " "))
      stamp("~" .. table.concat(diff, " "))
    end
  end
  last = r
end

local function stop(why)
  if not rec then return end
  rec.stopped = why
  rec.length = now()
  rec.final = read()
  if f then
    pcall(f.UnregisterAllEvents, f)
    f:SetScript("OnUpdate", nil)
    f:SetScript("OnEvent", nil)
  end
  say(("stopped (%s): %d events, %d changes, %d marks. /reload, then lua scripts/read-check-door.lua")
    :format(why, rec.total, #rec.changes, #rec.marks))
  rec, last = nil, nil
end

local function start()
  local r = root(true)
  if not r then return say("no SavedVariables yet") end
  t0 = GetTime()
  rec = { date = date("%Y-%m-%d %H:%M:%S"), fields = FIELDS, first = read(), counts = {},
    timeline = {}, changes = {}, marks = {}, total = 0, dropped = 0,
    zone = probe(GetRealZoneText) .. " / " .. probe(GetSubZoneText) }
  last = rec.first
  table.insert(r.runs, rec)
  while #r.runs > RUNS_MAX do table.remove(r.runs, 1) end
  f = f or CreateFrame("Frame")
  f:SetScript("OnEvent", function(_, ev)
    if not rec then return end
    rec.total = rec.total + 1
    rec.counts[ev] = (rec.counts[ev] or 0) + 1
    if not NOISY[ev] then stamp(ev) end
  end)
  local ok = pcall(f.RegisterAllEvents, f)
  rec.allEvents = ok
  if not ok then
    -- Fallback: the candidates we can name.
    for _, ev in ipairs({ "MINIMAP_UPDATE_ZOOM", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
      "ZONE_CHANGED_NEW_AREA", "AREA_POIS_UPDATED", "MINIMAP_UPDATE_TRACKING", "NEW_WMO_CHUNK",
      "UPDATE_UI_WIDGET", "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_DISABLED" }) do
      pcall(f.RegisterEvent, f, ev)
    end
  end
  f:SetScript("OnUpdate", function()
    if not rec then return end
    sample()
    if now() > MAX then stop("max") end
  end)
  say(("recording (%s). Walk through the gate, '/qdt check door mark' when the minimap switches, "
    .. "'/qdt check door' to stop (auto at %d s)."):format(ok and "all events" or "named events only", MAX))
end

function C:Run(arg)
  if arg == "reset" then
    stop("reset")
    if type(QuantumDungeonToolsDB) == "table" then QuantumDungeonToolsDB._checkDoor = nil end
    return say("data cleared.")
  elseif arg == "mark" then
    if not rec then return say("not recording: '/qdt check door' first") end
    rec.marks[#rec.marks + 1] = now()
    stamp("MARK")
    return say(("mark %d at %.1f s"):format(#rec.marks, now()))
  elseif arg ~= "" then
    return say("usage: check door [mark | reset]")
  end
  if rec then stop("manual") else start() end
end
