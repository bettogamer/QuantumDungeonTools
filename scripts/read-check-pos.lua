-- scripts/read-check-pos.lua -- REDUCER for QuantumDungeonToolsDB._checkPos (docs/27).
-- Usage (from the repo root):
--   lua scripts/read-check-pos.lua [path\to\SavedVariables\QuantumDungeonTools.lua] [run#]
-- Without a path it takes the first account under the Forever WTF folder; without run#, all runs.
local path, only = arg[1], tonumber(arg[2])
if path and tonumber(path) then path, only = nil, tonumber(path) end
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
local c = (env.QuantumDungeonToolsDB or {})._checkPos
if not c then print("no _checkPos in " .. path .. " (run /qdt check pos and /reload)") return end

local function split(s)
  local out = {}
  for f in (s .. "|"):gmatch("([^|]*)|") do out[#out + 1] = f end
  return out
end

local function snap(label, s)
  print(("  [%s] instance=%s  inInstance=%s  combat=%s  indoors=%s  zone=%s"):format(
    label, s.instance, s.inInstance, tostring(s.combat), s.indoors, s.zone))
  print(("    UnitPosition=%s  facing=%s  bestMap=%s  speed=%s"):format(
    s.unitPosition, s.facing, s.bestMap, s.speed))
  print(("    minimap zoom=%s/%s  viewRadius=%s yd  size=%s  scale=%s  rotate=%s  pingPos=%s"):format(
    s.zoom, s.zoomLevels, s.viewRadius, s.mmSize, s.mmScale, s.rotate, s.pingPos))
  for u, e in pairs(s.units or {}) do
    print(("    %-7s conn=%s vis=%s pos=%s distSq=%s inRange=%s"):format(
      u, e.connected, e.visible, e.position, e.distSq, e.inRange))
    print(("            interact[1..4]=%s  items: %s"):format(
      table.concat(e.interact, " / "), table.concat(e.items, " ")))
  end
end

for i, r in ipairs(c.runs) do
  if r.kind == "sys" and (not only or only == i) then
    print(("== run %d  %s  (ping system) =="):format(i, r.date or "?"))
    for _, l in ipairs(r.lines) do print("  " .. l) end
  elseif not only or only == i then
    print(("== run %d  %s =="):format(i, r.date or "?"))
    snap("before", r.before)
    for _, n in ipairs(r.notes) do print("  note: " .. n) end
    print(("  MINIMAP_PING events (%d): t|unit|x|y|xKind|me|pingPos"):format(#r.events))
    for _, e in ipairs(r.events) do print("    " .. e) end
    -- Samples: t|px|py|ux|uy|facing|speed|zoom|distSq(party1)
    local first, distinct, lastPx = nil, 0, nil
    print("  samples every ~2 s: t | ping x,y | UnitPosition x,y | facing | speed | zoom | distSq p1")
    for k, line in ipairs(r.samples) do
      local f = split(line)
      if f[2] ~= lastPx then distinct, lastPx = distinct + 1, f[2] end
      if k == 1 or k % 8 == 0 or k == #r.samples then
        print(("    %6s | %s,%s | %s,%s | %s | %s | %s | %s"):format(
          f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9]))
      end
      -- Ping-vs-truth ratio (only where both are public numbers: open world).
      local px, py, ux, uy = tonumber(f[2]), tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
      if px and ux then
        if not first then first = { px, py, ux, uy }
        elseif k % 20 == 0 then
          local dp = math.sqrt((px - first[1]) ^ 2 + (py - first[2]) ^ 2)
          local du = math.sqrt((ux - first[3]) ^ 2 + (uy - first[4]) ^ 2)
          if du > 1 then
            print(("      ratio ping/yard at t=%s: %.3f  (dPing %.2f, dYards %.2f)  dPing=(%.2f,%.2f) dUnit=(%.2f,%.2f)")
              :format(f[1], dp / du, dp, du, px - first[1], py - first[2], ux - first[3], uy - first[4]))
          end
        end
      end
    end
    print(("  distinct ping-x values over the tour: %d (1 = static / dead)"):format(distinct))
    snap("after", r.after)
  end
end
