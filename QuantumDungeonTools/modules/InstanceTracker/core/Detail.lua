-- modules/InstanceTracker/core/Detail.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- The hover detail of the widget (plan M1 F4b, artboard «Detalle»): pace (XP/h, gold/h, runs
-- to the next level), reputation per faction, records (personal and with this group) and the
-- instance slots of the last hour. It returns SEMANTIC rows (ids, numbers, tones); wow/UI.lua
-- turns them into localized Craft.Tooltip lines.
--
-- Detail.build(run, opts) -> { { id, rows = { { id, ... } } } }   (empty sections are dropped)
--   opts.xp        = nil | { level, xp, max, atMax }   plain numbers (wow/ scrubs them)
--   opts.history   = nil | list of Run:toTable() entries, newest first (db.instanceTracker.history)
--   opts.record    = nil | the CURRENT record of this dungeon (Records.get), else opts.pb / run.pb
--   opts.group     = nil | Detail.groupKey of the current group (nil = solo)
--   opts.instances = nil | { count, limit, slots = { sec until each slot frees, ... } }  (F5)
--   opts.trashTotal = nil | trash this dungeon has, learned from clean runs (Records.learnTrash, F4c)
local _, ns = ...
local Format = ns.Format
local Records = ns.InstanceRecords
local Run = ns.InstanceRun

local Detail = {}
ns.InstanceTrackerDetail = Detail

Detail.MIN_PACE = 60     -- seconds of run before XP/h and gold/h mean anything
Detail.PER_RUN_FROM = 5  -- "runs to level" averages the XP of the last N finished runs here

local function num(v) return type(v) == "number" and v == v end

-- groupKey({ "Bob", "Ann" }) -> "Ann,Bob" (order-proof signature); nil when solo.
function Detail.groupKey(names)
  if type(names) ~= "table" then return nil end
  local list = {}
  for _, n in ipairs(names) do
    if type(n) == "string" and n ~= "" then list[#list + 1] = n end
  end
  if #list == 0 then return nil end
  table.sort(list)
  return table.concat(list, ",")
end

-- Finished runs of this dungeon + difficulty in the history, as Run objects.
local function sameDungeon(run, history)
  local key, out = Records.key(run), {}
  if type(history) ~= "table" or not key then return out end
  for _, t in ipairs(history) do
    if type(t) == "table" and t.finishedAt then
      local r = Run.fromTable(t)
      if r and Records.key(r) == key then out[#out + 1] = r end
    end
  end
  return out
end

-- XP one run of this dungeon gives: the average of the last finished runs, else this run
-- once it is finished (a live run has not given all its XP yet).
local function xpPerRun(run, past)
  local sum, n = 0, 0
  for _, r in ipairs(past) do
    if n >= Detail.PER_RUN_FROM then break end
    if num(r.xp) and r.xp > 0 then sum, n = sum + r.xp, n + 1 end
  end
  if n > 0 then return sum / n end
  if run:isFinished() and num(run.xp) and run.xp > 0 then return run.xp end
  return nil
end

local function pace(run, opts, past)
  local rows = {}
  local elapsed = run:elapsed()
  local xp = opts.xp
  local leveling = type(xp) == "table" and not xp.atMax
  if elapsed >= Detail.MIN_PACE then
    local hours = elapsed / 3600
    if leveling and num(run.xp) and run.xp > 0 then
      rows[#rows + 1] = { id = "xpHour", text = Format.thousands(math.floor(run.xp / hours + 0.5)), tone = "xp" }
    end
    if num(run.copper) and run.copper > 0 then
      rows[#rows + 1] = { id = "goldHour", copper = math.floor(run.copper / hours + 0.5), tone = "text" }
    end
  end
  if leveling and num(xp.xp) and num(xp.max) and num(xp.level) and xp.max > xp.xp then
    local per = xpPerRun(run, past)
    if per then
      local runs = math.ceil((xp.max - xp.xp) / per)
      rows[#rows + 1] = { id = "toLevel", level = xp.level + 1, runs = runs, tone = "text" }
    end
  end
  -- F4c: trash with its % once the dungeon's total is known; time outside, only if any.
  if num(run.trash) and run.trash > 0 then
    local total = num(opts.trashTotal) and opts.trashTotal > 0 and opts.trashTotal or nil
    local pct = total and math.min(100, math.floor(run.trash / total * 100 + 0.5)) or nil
    rows[#rows + 1] = { id = "trash", kills = run.trash, total = total, pct = pct, tone = "text" }
  end
  local away = run.awayTime and run:awayTime() or 0
  if num(away) and away >= 1 then
    rows[#rows + 1] = { id = "away", text = Format.clock(away), tone = "muted" }
  end
  return rows
end

local function reputation(run)
  local rows = {}
  for _, r in ipairs(run.repList and run:repList() or {}) do
    rows[#rows + 1] = { id = "faction", name = r.name, amount = r.amount, tone = "text" }
  end
  return rows
end

-- Best clean run of this dungeon with the same group signature, and how many runs it had.
local function groupBest(past, group)
  local best, count = nil, 0
  for _, r in ipairs(past) do
    if r.group == group then
      count = count + 1
      if Records.eligible(r) then
        local e = r:elapsed()
        if not best or e < best then best = e end
      end
    end
  end
  return best, count
end

local function records(run, opts, past)
  local rows = {}
  local rec = opts.record or opts.pb or run.pb
  if type(rec) == "table" and num(rec.total) and rec.total > 0 then
    rows[#rows + 1] = { id = "personal", text = Format.clock(rec.total), tone = "text" }
  end
  if opts.group then
    local best, count = groupBest(past, opts.group)
    if best then
      local tone = (not num(rec and rec.total) or best <= rec.total) and "ahead" or "text"
      rows[#rows + 1] = { id = "group", runs = count, text = Format.clock(best), tone = tone }
    end
  end
  return rows
end

local function instances(inst)
  if type(inst) ~= "table" or not (num(inst.count) and num(inst.limit)) then return nil end
  local rows = {}
  for i, sec in ipairs(inst.slots or {}) do
    if i > 2 then break end
    if num(sec) and sec > 0 then
      rows[#rows + 1] = { id = i == 1 and "nextSlot" or "thenSlot", text = Format.clock(sec),
        tone = i == 1 and "progress" or "muted" }
    end
  end
  return { id = "instances", count = inst.count, limit = inst.limit, rows = rows }
end

function Detail.build(run, opts)
  if not run then return {} end
  opts = opts or {}
  local past = sameDungeon(run, opts.history)
  local out = {}
  local function add(id, rows)
    if #rows > 0 then out[#out + 1] = { id = id, rows = rows } end
  end
  add("pace", pace(run, opts, past))
  add("rep", reputation(run))
  add("records", records(run, opts, past))
  local inst = instances(opts.instances)
  if inst then out[#out + 1] = inst end
  return out
end

return Detail
