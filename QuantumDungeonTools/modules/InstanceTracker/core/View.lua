-- modules/InstanceTracker/core/View.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- Turns a Run (core/Run.lua) plus what surrounds it (personal record, XP snapshot, deaths)
-- into WHAT the widget paints: texts already formatted and semantic TONES
-- (core/Style.lua maps them to colors). wow/UI.lua only lays it out, so every state of the
-- design (live with record, completed, first time, compact) is testable headless.
--
-- View.build(run, opts) -> view | nil
--   opts.pb        = nil | { total = sec, splits = { [bossName] = sec since start } }   (F3)
--   opts.xp        = nil | { level, xp, max, rested, atMax }   plain numbers (wow/ scrubs them)
--   opts.deaths    = nil | number                                                        (F3)
--   opts.now       = nil | epoch seconds (time()): gives the record's age (v.ref.age, in days)
-- Every opts field may be missing: the widget simply hides what it does not get.
local _, ns = ...
local Format = ns.Format

local View = {}
ns.InstanceTrackerView = View

local function num(v) return type(v) == "number" and v == v end

-- PB splits sorted by time: { { name, at } }.
local function sortedSplits(pb)
  local out = {}
  for name, at in pairs(pb.splits or {}) do
    if num(at) then out[#out + 1] = { name = name, at = at } end
  end
  table.sort(out, function(a, b) return a.at < b.at end)
  return out
end

-- The last boss killed (largest split) that also has a PB split -> its delta, or nil.
local function lastDelta(bosses)
  local best
  for _, b in ipairs(bosses) do
    if b.deltaSec and (not best or b.at > best.at) then best = b end
  end
  return best and best.deltaSec or nil
end

local function bossRows(run, pb)
  local rows = {}
  for i, b in ipairs(run.bosses) do
    -- Rares: listed (owner, doc 11) but muted while alive, gold when killed, never a delta.
    local row = { name = b.name, tone = b.rare and "muted" or "text", time = "", rare = b.rare or nil,
      kind = b.rare and b.kind or nil,   -- badge: nil RARE, "optional", "quest" (docs/16)
      alive = not b.killed }   -- alive rows answer the mouse with the ping (plan M1 point 7)
    if b.killed then
      if b.preKilled or not num(b.killedAt) then
        row.tone, row.time = "pre", "--"
      else
        row.tone = "progress"
        row.time = "[" .. Format.clock(b.killedAt) .. "]"
        row.at = not b.rare and b.killedAt or nil
        local ref = not b.rare and pb and pb.splits and pb.splits[b.name]
        if num(ref) then
          row.deltaSec = b.killedAt - ref
          row.delta = Format.delta(row.deltaSec)
          row.deltaTone = row.deltaSec <= 0 and "ahead" or "behind"
        end
      end
    end
    rows[i] = row
  end
  return rows
end

local function hasPreKilled(run)
  for _, b in ipairs(run.bosses) do
    if b.preKilled then return true end
  end
  return false
end

local function timeBar(run, pb, finished, elapsed)
  local splits = sortedSplits(pb)
  local killed, rare = {}, {}
  for _, b in ipairs(run.bosses) do
    if b.rare then rare[b.name] = true end
    if b.killed and not b.preKilled then killed[b.name] = true end
  end
  local ticks = {}
  for _, s in ipairs(splits) do
    local pos = s.at / pb.total
    if pos > 1 then pos = 1 end
    -- A finished run drops the 100 % tick (it is the bar's end) and cuts the rest dark.
    -- Rares never get a tick (a record may still carry their split).
    if not (finished and pos >= 1) and not rare[s.name] then
      local tone = finished and "cut" or (killed[s.name] and "progress" or "pending")
      ticks[#ticks + 1] = { pos = pos, tone = tone }
    end
  end
  local fill = elapsed / pb.total
  if fill > 1 then fill = 1 end
  if fill < 0 then fill = 0 end
  return { mode = "time", fill = fill, ticks = ticks }
end

local function segmentBar(run)
  local segs = {}
  for _, b in ipairs(run.bosses) do
    if not b.rare then
      if b.killed then
        segs[#segs + 1] = b.preKilled and "pre" or "progress"
      else
        segs[#segs + 1] = "idle"
      end
    end
  end
  return { mode = "segments", segs = segs }
end

local function xpView(run, xp)
  if type(xp) ~= "table" or xp.atMax then return nil end
  if not (num(xp.xp) and num(xp.max) and num(xp.level)) or xp.max <= 0 then return nil end
  local gained = num(run.xp) and run.xp or 0
  local cur = xp.xp / xp.max
  -- Before-the-run part of the bar; a run that crossed a level owns the whole bar.
  local base = gained <= xp.xp and (xp.xp - gained) / xp.max or 0
  local rested = num(xp.rested) and xp.rested > 0 and xp.rested or 0
  local restedEnd = (xp.xp + rested) / xp.max
  if restedEnd > 1 then restedEnd = 1 end
  if cur > 1 then cur = 1 end
  return {
    gained = Format.thousands(gained),
    level = xp.level,
    pct = math.floor(cur * 100),
    restedPct = rested > 0 and math.floor(rested / xp.max * 100) or nil,
    levels = num(run.levels) and run.levels > 0 and run.levels or nil,
    base = base, cur = cur, rested = restedEnd,
  }
end

function View.build(run, opts)
  if not run then return nil end
  opts = opts or {}
  local pb = opts.pb
  if type(pb) ~= "table" or not num(pb.total) or pb.total <= 0 then pb = nil end

  local finished = run:isFinished()
  local elapsed = run:elapsed()
  local total = run:total()
  local v = {
    name = run.name,
    difficulty = run.difficulty ~= "" and run.difficulty or nil,
    killed = run:killedCount(),
    total = total,
    totalKnown = run.listKnown and total > 0,
    finished = finished,
    clock = Format.clock(elapsed),
    clockTone = "text",
    bossesTone = finished and "progress" or "text",
    deaths = num(opts.deaths) and opts.deaths > 0 and opts.deaths or nil,
    bosses = bossRows(run, pb),
    xp = xpView(run, opts.xp),
  }
  -- Totals row (F4): money looted and the faction with the biggest gain; the rest go to the
  -- hover detail.
  if num(run.copper) and run.copper > 0 then v.copper = run.copper end
  local rep = run.repList and run:repList() or {}
  if #rep > 0 then v.rep, v.repAll = rep[1], rep end

  if pb then
    v.ref = { kind = "pb", text = Format.clock(pb.total), struck = finished and elapsed < pb.total }
    if num(pb.at) and num(opts.now) and opts.now >= pb.at then
      v.ref.age = math.floor((opts.now - pb.at) / 86400)   -- days since the record was set
    end
    if finished then
      local d = elapsed - pb.total
      if d < 0 then
        v.note = { kind = "newRecord", text = Format.delta(d) }
        v.clockTone = "ahead"
      else
        v.note = { kind = "vsPB", text = Format.delta(d), tone = "behind" }
        v.clockTone = "behind"
      end
    else
      local d = lastDelta(v.bosses)
      if elapsed > pb.total then
        v.clockTone = "behind"
        v.note = { kind = "vsPB", text = Format.delta(elapsed - pb.total), tone = "behind" }
      elseif d then
        v.clockTone = d <= 0 and "ahead" or "behind"
        v.note = { kind = "vsPB", text = Format.delta(d), tone = v.clockTone }
      end
    end
    v.bar = timeBar(run, pb, finished, elapsed)
    v.compactDelta = v.note and { text = v.note.text, tone = v.note.kind == "newRecord" and "ahead" or v.note.tone }
  else
    v.ref = { kind = "first" }
    if finished then
      v.clockTone = "progress"
    elseif not hasPreKilled(run) then
      v.note = { kind = "firstHint" }   -- only a clean run can become the record (F3)
    end
    v.bar = total > 0 and segmentBar(run) or nil
  end
  return v
end

-- Macro of the boss ping (plan M1 point 7): target the boss by name, attack ping on it, give
-- the previous target back. /cleartarget first: when the boss is out of sight /target fails and
-- would leave the OLD target, which got the ping (owner, in-game 2026-11-13). /targetexact so a
-- partial name never picks another unit; the ping only on a live hostile target. The cleared
-- target is the "last target", so /targetlasttarget gives it back in both cases.
-- nil when the name cannot go into a macro line (empty, or a line break would split it).
local function onBoss(name, action)
  if type(name) ~= "string" or name == "" or name:find("[\r\n]") then return nil end
  return "/cleartarget\n/targetexact " .. name .. "\n" .. action .. "\n/targetlasttarget"
end

function View.pingMacro(name)
  return onBoss(name, "/ping [@target,exists,harm,nodead] attack")
end

-- Right click (owner, 2026-11-13): the configured raid marker (8 = skull) on the boss, same
-- target dance. /tm toggles: on a boss that already wears that marker it takes it off.
function View.markMacro(name, marker)
  marker = tonumber(marker)
  if not marker or marker < 1 or marker > 8 or marker % 1 ~= 0 then return nil end
  return onBoss(name, "/tm [@target,exists,harm,nodead] " .. marker)
end

-- Raid markers by game index (1 star .. 8 skull), English and Spanish names for /qdt it mark.
View.MARKERS = {
  { "star", "estrella" }, { "circle", "circulo" }, { "diamond", "diamante" }, { "triangle", "triangulo" },
  { "moon", "luna" }, { "square", "cuadrado" }, { "cross", "cruz" }, { "skull", "calavera" },
}

-- "8", "skull", "calavera", "círculo"... -> 1..8, or nil.
function View.markerIndex(text)
  if type(text) ~= "string" then return nil end
  text = text:lower():gsub("\195\173", "i")   -- "í" (círculo, triángulo)
  local n = tonumber(text)
  if n then return (n >= 1 and n <= 8 and n % 1 == 0) and n or nil end
  for i, names in ipairs(View.MARKERS) do
    if text == names[1] or text == names[2] then return i end
  end
  return nil
end

return View
