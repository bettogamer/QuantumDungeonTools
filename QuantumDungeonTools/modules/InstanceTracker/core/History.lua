-- modules/InstanceTracker/core/History.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- What the History tab of the main window shows (plan M1 F6, artboard «Instance Tracker ·
-- Historial»): the account-wide list of the last runs (db.instanceTracker.history, newest
-- first, Run:toTable() rows), its filters (dungeon, difficulty, character) and one display
-- row per run. Runs saved before F6 have no `char`: they show "—" and only match "All".
--
-- Injected: `date` (os.date-compatible: date("*t", ts) -> { year, month, day, hour, min });
-- the wow/ layer passes the global `date`, the specs pass os.date.
local _, ns = ...
local Format = ns.Format
local Run = ns.InstanceRun

local History = {}
ns.InstanceHistory = History

History.MAX = 100   -- runs kept, account-wide (owner, 2026-11-12)
History.DASH = "\226\128\148"   -- U+2014, "no value" in a cell

local function num(v) return type(v) == "number" and v == v end
local function str(v) return type(v) == "string" and v ~= "" end

-- Dungeon key of a saved run: instanceID when known (locale-proof), else the name.
function History.dungeonKey(t)
  if type(t) ~= "table" then return nil end
  if t.instanceID ~= nil and t.instanceID ~= "" then return tostring(t.instanceID) end
  if str(t.name) then return t.name end
  return nil
end

-- "Kael-Realm" -> "Kael" (the realm only matters to tell characters apart).
function History.charName(char)
  if not str(char) then return nil end
  return (char:match("^([^%-]+)")) or char
end

------------------------------------------------------------------------------
-- Filters
------------------------------------------------------------------------------
-- Values the three selects offer, from what the history actually holds:
--   { dungeons = { { key, label } ... }, difficulties = { "Normal", ... }, chars = { { key, label } ... } }
-- sorted by label. "All" is not included: the UI adds it first.
function History.options(list)
  local out = { dungeons = {}, difficulties = {}, chars = {} }
  local seenD, seenF, seenC = {}, {}, {}
  for _, t in ipairs(type(list) == "table" and list or {}) do
    local key = History.dungeonKey(t)
    if key and not seenD[key] then
      seenD[key] = true
      out.dungeons[#out.dungeons + 1] = { key = key, label = str(t.name) and t.name or key }
    end
    if str(t.difficulty) and not seenF[t.difficulty] then
      seenF[t.difficulty] = true
      out.difficulties[#out.difficulties + 1] = t.difficulty
    end
    if str(t.char) and not seenC[t.char] then
      seenC[t.char] = true
      out.chars[#out.chars + 1] = { key = t.char, label = History.charName(t.char) }
    end
  end
  table.sort(out.dungeons, function(a, b) return a.label < b.label end)
  table.sort(out.difficulties)
  table.sort(out.chars, function(a, b) return a.label < b.label end)
  return out
end

-- f = { dungeon = key | nil, difficulty = string | nil, char = string | nil }; nil = all.
-- Keeps the history order (newest first).
function History.filter(list, f)
  f = f or {}
  local out = {}
  for _, t in ipairs(type(list) == "table" and list or {}) do
    if type(t) == "table"
      and (f.dungeon == nil or History.dungeonKey(t) == f.dungeon)
      and (f.difficulty == nil or t.difficulty == f.difficulty)
      and (f.char == nil or t.char == f.char) then
      out[#out + 1] = t
    end
  end
  return out
end

------------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------------
-- "Hoy 19:42" / "Ayer 22:10" / "10 nov 20:04". L = { today, yesterday, months = { "jan"... } }.
function History.dateLabel(ts, now, date, L)
  if not num(ts) or type(date) ~= "function" then return History.DASH end
  L = L or {}
  local d = date("*t", ts)
  local hm = string.format("%d:%02d", d.hour, d.min)
  if num(now) then
    local n = date("*t", now)
    local y = date("*t", now - 86400)
    if d.year == n.year and d.month == n.month and d.day == n.day then
      return (L.today or "Today") .. " " .. hm
    end
    if d.year == y.year and d.month == y.month and d.day == y.day then
      return (L.yesterday or "Yesterday") .. " " .. hm
    end
  end
  local month = (L.months or {})[d.month] or tostring(d.month)
  return string.format("%d %s %s", d.day, month, hm)
end

local function repTotal(rep)
  local n = 0
  for _, v in pairs(type(rep) == "table" and rep or {}) do
    if num(v) then n = n + v end
  end
  return n
end

-- "Ann,Bob-Realm" (Detail.groupKey) -> "Ann, Bob"; solo -> nil.
function History.groupLabel(key)
  if not str(key) then return nil end
  local names = {}
  for part in key:gmatch("[^,]+") do names[#names + 1] = History.charName(part) end
  if #names == 0 then return nil end
  return table.concat(names, ", ")
end

-- One display row for a saved run.
--   kind = "record" (it set the record) | "behind" | "ahead" (vs the record it raced against)
--        | "unfinished" | "first" (no record to compare with)
-- Text cells are ready to paint; `copper` stays a number (the UI draws coins).
function History.row(t, opts)
  opts = opts or {}
  local run = Run.fromTable(t)
  if not run then return nil end
  local done = run:isFinished()
  local elapsed = run:elapsed()
  local row = {
    date = History.dateLabel(run.finishedAt or run.endedAt or run.startedAt, opts.now, opts.date, opts.L),
    char = History.charName(t.char),
    dungeon = run.name,
    difficulty = run.difficulty,
    elapsed = done and elapsed or nil,
    time = done and Format.clock(elapsed) or History.DASH,
    deaths = num(run.deaths) and run.deaths or 0,
    xp = num(run.xp) and run.xp > 0 and ("+" .. Format.thousands(run.xp)) or History.DASH,
    copper = num(run.copper) and run.copper or 0,
    group = History.groupLabel(run.group),
  }
  local rep = repTotal(run.rep)
  row.rep = rep > 0 and ("+" .. Format.thousands(rep)) or History.DASH
  if not done then
    row.kind = "unfinished"
  elseif run.newRecord then
    row.kind = "record"
  elseif run.pb and num(run.pb.total) then
    local d = elapsed - run.pb.total
    row.kind = d > 0 and "behind" or "ahead"
    row.delta = Format.delta(d)
  else
    row.kind = "first"
  end
  return row
end

-- Footer of the table: { count, mean = sec | nil, best = sec | nil } over the finished runs.
function History.summary(list)
  local count, sum, n, best = 0, 0, 0, nil
  for _, t in ipairs(type(list) == "table" and list or {}) do
    count = count + 1
    local run = Run.fromTable(t)
    if run and run:isFinished() then
      local e = run:elapsed()
      sum, n = sum + e, n + 1
      if not best or e < best then best = e end
    end
  end
  return { count = count, mean = n > 0 and sum / n or nil, best = best }
end

-- Distinct dungeon + difficulty pairs with a record (the Summary tab: "récord en 9 mazmorras").
function History.recordCount(records)
  local n = 0
  for _, rec in pairs(type(records) == "table" and records or {}) do
    if type(rec) == "table" and num(rec.total) then n = n + 1 end
  end
  return n
end

return History
