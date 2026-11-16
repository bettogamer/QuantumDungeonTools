---@diagnostic disable: undefined-global
-- wow/CheckPos.lua -- `/qdt check pos`: research probe for an own coordinate system inside a
-- dungeon (docs/27-coordenadas-propias.md). Forever gives addons no position in instances
-- (UnitPosition / GetPlayerFacing / GetBestMapForUnit = nil), so this MEASURES the side signals:
--   1. Snapshot: position APIs, minimap scale (zoom, C_Minimap.GetViewRadius) and, per group
--      member, UnitPosition / UnitDistanceSquared / CheckInteractDistance / UnitInRange / item
--      range buckets (LibRangeCheck Era items).
--   2. Ping tour (30 s): Minimap:PingLocation(0, 0) on yourself, then Minimap:GetPingPosition()
--      every 0.25 s while you walk (straight 10 s, turn right ~90 degrees, straight 10 s). If the
--      ping stays fixed in the world, its offset is a north-up odometer = own coordinates.
--      At +15 s it re-pings AT the ping (chain test: can the origin outlive the ripple?).
--      MINIMAP_PING payloads (SecretPayloads in the api-db) are logged too, also teammates' pings.
-- The ping is VISIBLE to the group (ripple on their minimap). Run it once in open world (truth:
-- UnitPosition) and once inside a dungeon. Dump: QuantumDungeonToolsDB._checkPos, read with
-- scripts/read-check-pos.lua. Every value goes through issecretvalue first, every call through pcall.
local _, ns = ...
local issecretvalue = ns.issecretvalue

local C = {}
ns.CheckPos = C

local FORMAT = 1
local RUNS_MAX = 8
local TOUR = 30
local STEP = 0.25
local CHAIN_AT = 15
local UNITS = { "party1", "party2", "party3", "party4", "target" }
-- One Era item per range bucket (LibRangeCheck-3.0 FriendItems, isEra list).
local ITEMS = { { 5, 8149 }, { 10, 17626 }, { 15, 1251 }, { 20, 12450 }, { 25, 13289 },
  { 30, 954 }, { 35, 18904 }, { 40, 1713 } }

local function say(s) print("|cff7dd3fcQDT check pos|r " .. s) end

local function enc(v)
  if issecretvalue(v) then return "SECRET" end
  local t = type(v)
  if t == "number" then return math.floor(v * 1000 + 0.5) / 1000 end
  if t == "nil" then return "nil" end
  if t == "boolean" or t == "string" then return v end
  return "<" .. t .. ">"
end

-- pcall(fn, ...) -> list of encoded returns, or { "ERR:<msg>" } / { "absent" }.
local function probe(fn, ...)
  if type(fn) ~= "function" then return { "absent" } end
  local r = { n = 0 }
  local function pack(...) r.n = select("#", ...) for i = 1, r.n do r[i] = (select(i, ...)) end end
  pack(pcall(fn, ...))
  if not r[1] then return { "ERR:" .. tostring(r[2]):sub(1, 120) } end
  local out = {}
  for i = 2, math.max(r.n, 2) do out[#out + 1] = tostring(enc(r[i])) end
  return out
end

local function joined(list) return table.concat(list, ",") end

local function mm(method, ...)
  local fn = Minimap and Minimap[method]
  if type(fn) ~= "function" then return { "absent" } end
  return probe(fn, Minimap, ...)
end

local function pingPos()
  local fn = Minimap and Minimap.GetPingPosition
  if type(fn) ~= "function" then return "absent", "absent" end
  local ok, x, y = pcall(fn, Minimap)
  if not ok then return "ERR", "ERR" end
  return x, y   -- raw: may be secret, the caller encodes / tests
end

---------------------------------------------------------------------------------------------
-- Snapshot
---------------------------------------------------------------------------------------------
local function snapshot()
  local s = {
    instance = joined(probe(GetInstanceInfo)),
    inInstance = joined(probe(IsInInstance)),
    combat = enc(InCombatLockdown()),
    indoors = joined(probe(IsIndoors)),
    zone = joined(probe(GetMinimapZoneText)),
    unitPosition = joined(probe(UnitPosition, "player")),
    facing = joined(probe(GetPlayerFacing)),
    bestMap = joined(probe(C_Map and C_Map.GetBestMapForUnit, "player")),
    speed = joined(probe(GetUnitSpeed, "player")),
    zoom = joined(mm("GetZoom")),
    zoomLevels = joined(mm("GetZoomLevels")),
    viewRadius = joined(probe(C_Minimap and C_Minimap.GetViewRadius)),
    mmSize = joined(mm("GetSize")),
    mmScale = joined(mm("GetEffectiveScale")),
    rotate = joined(probe(GetCVar, "rotateMinimap")),
    pingPos = joined({ enc((pingPos())), enc(select(2, pingPos())) }),
    units = {},
  }
  for _, u in ipairs(UNITS) do
    if UnitExists(u) then
      local e = {
        connected = joined(probe(UnitIsConnected, u)),
        visible = joined(probe(UnitIsVisible, u)),
        position = joined(probe(UnitPosition, u)),
        distSq = joined(probe(UnitDistanceSquared, u)),
        inRange = joined(probe(UnitInRange, u)),
        interact = {},
        items = {},
      }
      for i = 1, 4 do e.interact[i] = joined(probe(CheckInteractDistance, u, i)) end
      local isIn = C_Item and C_Item.IsItemInRange or IsItemInRange
      for _, it in ipairs(ITEMS) do
        e.items[#e.items + 1] = it[1] .. "y=" .. joined(probe(isIn, it[2], u))
      end
      s.units[u] = e
    end
  end
  return s
end

---------------------------------------------------------------------------------------------
-- Ping tour
---------------------------------------------------------------------------------------------
local active, ticker, current
local evFrame = CreateFrame("Frame")
local sink

evFrame:SetScript("OnEvent", function(_, _, unit, x, y)
  if not current then return end
  local isMe = "?"
  if not issecretvalue(unit) then
    local ok, me = pcall(UnitIsUnit, unit, "player")
    isMe = ok and enc(me) or "ERR"
  end
  local px, py = pingPos()
  current.events[#current.events + 1] = ("%.2f|%s|%s|%s|%s|me=%s|pp=%s,%s"):format(
    GetTime() - current.t0, tostring(enc(unit)), tostring(enc(x)), tostring(enc(y)),
    issecretvalue(x) and "secretX" or "pubX", tostring(isMe), tostring(enc(px)), tostring(enc(py)))
end)

local function sample(t)
  local px, py = pingPos()
  local up = probe(UnitPosition, "player")
  local ds = UnitExists("party1") and joined(probe(UnitDistanceSquared, "party1")) or "-"
  current.samples[#current.samples + 1] = table.concat({
    ("%.2f"):format(t), tostring(enc(px)), tostring(enc(py)), tostring(up[1]), tostring(up[2]),
    joined(probe(GetPlayerFacing)), joined(probe(GetUnitSpeed, "player")), joined(mm("GetZoom")), ds,
  }, "|")
end

-- If the ping offset is secret, can it still drive an anchor (sink pattern, like StatusBar)?
local function sinkTest(px, py)
  if not issecretvalue(px) then return "public" end
  sink = sink or Minimap:CreateTexture(nil, "OVERLAY")
  local ok, err = pcall(sink.SetPoint, sink, "CENTER", Minimap, "CENTER", px, py)
  return ok and "SetPoint accepts secret" or ("SetPoint ERR:" .. tostring(err):sub(1, 80))
end

local function finish()
  if ticker then ticker:Cancel() ticker = nil end
  evFrame:UnregisterAllEvents()
  current.after = snapshot()
  local r = QuantumDungeonToolsDB._checkPos
  table.insert(r.runs, current)
  while #r.runs > RUNS_MAX do table.remove(r.runs, 1) end
  say(("done: %d samples, %d ping events -> run %d. /reload and run scripts/read-check-pos.lua")
    :format(#current.samples, #current.events, #r.runs))
  active, current = false, nil
end

local function tour(duration)
  local r = QuantumDungeonToolsDB._checkPos
  if not r or r.format ~= FORMAT then
    r = { format = FORMAT, runs = {} }
    QuantumDungeonToolsDB._checkPos = r
  end
  active = true
  current = { t0 = GetTime(), date = date("%Y-%m-%d %H:%M"), before = snapshot(),
    samples = {}, events = {}, notes = {} }
  -- Forever 1.60.1: "unknown event MINIMAP_PING" (listed in the api-db, absent in the client).
  local evOk, evErr = pcall(evFrame.RegisterEvent, evFrame, "MINIMAP_PING")
  current.notes[#current.notes + 1] = "MINIMAP_PING "
    .. (evOk and "registered" or ("ERR:" .. tostring(evErr):sub(1, 80)))
  local ping = mm("PingLocation", 0, 0)
  current.notes[#current.notes + 1] = "ping(0,0)=" .. joined(ping)
  say("pinged your spot. WALK straight now ~10 s, then turn right ~90 degrees and walk ~10 s, then stop.")
  -- Run 1 (open world): PingLocation(0.144, 0.054) put the new ping on the PLAYER, so its args are
  -- not GetPingPosition's units (fraction of the minimap diameter). Hypothesis: minimap pixels
  -- from the centre -> re-ping at (px * width, py * height) should land on the OLD ping.
  local chained, chainCheck = duration ~= TOUR, nil
  ticker = C_Timer.NewTicker(STEP, function()
    local t = GetTime() - current.t0
    sample(t)
    if chainCheck then
      local nx, ny = pingPos()
      current.notes[#current.notes + 1] = ("chain: before %s,%s -> after %s,%s (same = origin kept)")
        :format(tostring(enc(chainCheck[1])), tostring(enc(chainCheck[2])), tostring(enc(nx)), tostring(enc(ny)))
      chainCheck = nil
    end
    if not chained and t >= CHAIN_AT then
      chained = true
      local px, py = pingPos()
      current.notes[#current.notes + 1] = "sink=" .. sinkTest(px, py)
      if type(px) == "number" and not issecretvalue(px) then
        local w, h = Minimap:GetSize()
        current.notes[#current.notes + 1] = ("chain ping(%s,%s) [pos x size %s,%s]=%s"):format(
          tostring(enc(px * w)), tostring(enc(py * h)), tostring(enc(w)), tostring(enc(h)),
          joined(mm("PingLocation", px * w, py * h)))
        chainCheck = { px, py }
      else
        current.notes[#current.notes + 1] = "chain skipped: ping pos " .. tostring(enc(px))
      end
    end
    if t >= duration then finish() end
  end)
end

---------------------------------------------------------------------------------------------
-- `/qdt check pos sys`: the 10.1 ping system (C_Ping, `/ping [@player] warning`). Its receive
-- callbacks are C_PingSecure (Blizzard only), so the most an addon could see is the PIN FRAME on
-- screen: list frames that appear after the ping, try to measure them, re-read GetPingPosition.
---------------------------------------------------------------------------------------------
local function frameSet()
  local set, f = {}, EnumerateFrames()
  while f do set[f] = true f = EnumerateFrames(f) end
  return set
end

local function describe(f)
  local ok, name = pcall(f.GetName, f)
  local _, otype = pcall(f.GetObjectType, f)
  local _, shown = pcall(f.IsShown, f)
  local parent = "?"
  local okP, p = pcall(f.GetParent, f)
  if okP and p then local okN, n = pcall(p.GetName, p) parent = okN and tostring(n) or "?" end
  local center = joined(probe(f.GetCenter, f))
  return ("%s [%s] shown=%s parent=%s center=%s forbidden=%s"):format(tostring(ok and name), tostring(otype),
    tostring(enc(shown)), parent, center, joined(probe(f.IsForbidden, f)))
end

local function pingSystem()
  local r = QuantumDungeonToolsDB._checkPos
  if not r or r.format ~= FORMAT then
    r = { format = FORMAT, runs = {} }
    QuantumDungeonToolsDB._checkPos = r
  end
  active = true
  local sys = { date = date("%Y-%m-%d %H:%M"), kind = "sys", lines = {} }
  local function add(s) sys.lines[#sys.lines + 1] = s end
  add("instance=" .. joined(probe(GetInstanceInfo)))
  add("C_Ping=" .. type(C_Ping) .. " enabled=" .. joined(probe(C_Ping and C_Ping.IsPingSystemEnabled)))
  add("pingPos before=" .. joined({ tostring(enc((pingPos()))), tostring(enc(select(2, pingPos()))) }))
  local before = frameSet()
  local warning = Enum and Enum.PingSubjectType and Enum.PingSubjectType.Warning
  add("SendMacroPing(warning,@player)=" .. joined(probe(C_Ping and C_Ping.SendMacroPing,
    { type = warning, targetToken = "player" })))
  say("pinged @player with the ping system. You can also press your /ping macro now. Reading in 2 and 6 s.")
  local function scan(label)
    local n = 0
    for f in pairs(frameSet()) do
      if not before[f] then
        n = n + 1
        if n <= 15 then add(label .. " new: " .. describe(f)) end
      end
    end
    add(("%s: %d new frames; pingPos=%s,%s"):format(label, n, tostring(enc((pingPos()))),
      tostring(enc(select(2, pingPos())))))
  end
  C_Timer.After(2, function() scan("+2s") end)
  C_Timer.After(6, function()
    scan("+6s")
    table.insert(r.runs, sys)
    while #r.runs > RUNS_MAX do table.remove(r.runs, 1) end
    active = false
    say("done -> run " .. #r.runs .. ". /reload and run scripts/read-check-pos.lua")
  end)
end

function C:Run(arg)
  if arg == "sys" then
    if active then say("already running.") return end
    pingSystem()
  elseif arg == "reset" then
    QuantumDungeonToolsDB._checkPos = nil
    say("dumps cleared.")
  elseif arg == "" or tonumber(arg) then
    -- `/qdt check pos 180`: long tour WITHOUT the chain ping, to see how long the ping lives.
    if active then say("already running.") return end
    tour(math.max(10, math.min(600, tonumber(arg) or TOUR)))
  else
    say("usage: /qdt check pos [seconds]  |  /qdt check pos reset")
  end
end
