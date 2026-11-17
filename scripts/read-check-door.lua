-- scripts/read-check-door.lua -- REDUCER for QuantumDungeonToolsDB._checkDoor (wow/CheckDoor.lua).
-- Usage (from the repo root):
--   lua scripts/read-check-door.lua [path\to\SavedVariables\QuantumDungeonTools.lua] [run#] [window]
-- Prints, per run: the reading changes, the events that fired ONLY near a change or a mark (within
-- `window` s, default 1.5; events that also fire away from them are background noise), and counts.
local path, only, window = arg[1], tonumber(arg[2]), tonumber(arg[3]) or 1.5
if path and tonumber(path) then path, only, window = nil, tonumber(path), tonumber(arg[2]) or 1.5 end
if not path then
  local wtf = "F:/Games/World of Warcraft/_forever_/WTF/Account/"
  local p = io.popen('dir /b /ad "' .. wtf:gsub("/", "\\") .. '" 2>nul')
  for name in p:lines() do
    if name ~= "SavedVariables" then
      path = wtf .. name .. "/SavedVariables/QuantumDungeonTools.lua"
      break
    end
  end
  p:close()
end
assert(path, "no account folder found: pass the path")
local env = {}
assert(loadfile(path, "t", env))()
local c = (env.QuantumDungeonToolsDB or {})._checkDoor
if not c then print("no _checkDoor in " .. path .. " (run /qdt check door and /reload)") return end

local function parse(line)
  local t, rest = line:match("^([%d%.%-]+)|(.*)$")
  return tonumber(t), rest
end

for i, r in ipairs(c.runs) do
  if not only or only == i then
    print(("== run %d  %s  zone=%s  %.1f s  stop=%s  allEvents=%s  events=%d dropped=%d =="):format(
      i, r.date or "?", r.zone or "?", r.length or -1, tostring(r.stopped), tostring(r.allEvents),
      r.total or 0, r.dropped or 0))
    local fields = r.fields or {}
    local first = {}
    for k, v in ipairs(r.first or {}) do first[#first + 1] = (fields[k] or k) .. "=" .. v end
    print("  start: " .. table.concat(first, "  "))
    local fin = {}
    for k, v in ipairs(r.final or {}) do fin[#fin + 1] = (fields[k] or k) .. "=" .. v end
    print("  final: " .. table.concat(fin, "  "))

    -- Changes, skipping ping-only ones (the ping drifts while you walk) after the first 40.
    local anchors = {}
    print(("  changes (%d):"):format(#r.changes))
    local shown, pingOnly = 0, 0
    for _, line in ipairs(r.changes) do
      local t, rest = parse(line)
      local onlyPing = not rest:gsub("ping=%S+", ""):find("%S")
      if onlyPing then pingOnly = pingOnly + 1 else anchors[#anchors + 1] = { t = t, what = rest } end
      if not onlyPing or shown < 40 then
        shown = shown + 1
        if shown <= 200 then print(("    %8.3f  %s"):format(t, rest)) end
      end
    end
    if pingOnly > 0 then print(("    (%d ping-only changes)"):format(pingOnly)) end
    for _, m in ipairs(r.marks or {}) do anchors[#anchors + 1] = { t = m, what = "MARK" } end
    table.sort(anchors, function(a, b) return a.t < b.t end)

    -- Events near vs away from the anchors.
    local near, away = {}, {}
    for _, line in ipairs(r.timeline) do
      local t, ev = parse(line)
      if ev ~= "MARK" and ev:sub(1, 1) ~= "~" then
        local close = false
        for _, a in ipairs(anchors) do
          if math.abs(t - a.t) <= window then close = true break end
        end
        local bucket = close and near or away
        bucket[ev] = (bucket[ev] or 0) + 1
      end
    end
    print(("  events ONLY within %.1f s of a change/mark (candidates):"):format(window))
    local cands = {}
    for ev, n in pairs(near) do if not away[ev] then cands[#cands + 1] = ev end end
    table.sort(cands)
    for _, ev in ipairs(cands) do
      local times = {}
      for _, line in ipairs(r.timeline) do
        local t, e = parse(line)
        if e == ev and #times < 8 then times[#times + 1] = ("%.2f"):format(t) end
      end
      print(("    %-45s x%d  at %s"):format(ev, near[ev], table.concat(times, " ")))
    end
    if #cands == 0 then print("    (none)") end
    print("  anchors: ")
    for _, a in ipairs(anchors) do print(("    %8.3f  %s"):format(a.t, a.what)) end

    local list = {}
    for ev, n in pairs(r.counts or {}) do list[#list + 1] = { ev = ev, n = n } end
    table.sort(list, function(a, b) return a.n > b.n end)
    local parts = {}
    for k = 1, math.min(#list, 25) do parts[#parts + 1] = list[k].ev .. "=" .. list[k].n end
    print(("  top counts (%d distinct): %s"):format(#list, table.concat(parts, "  ")))
  end
end
