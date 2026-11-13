-- scripts/read-check-f1.lua -- REDUCER for QuantumDungeonToolsDB._checkF1 (plan M1, F1).
-- Prints a short summary of the probe dump instead of reading the SavedVariables by hand.
-- Usage (from the repo root):
--   lua scripts/read-check-f1.lua [path\to\SavedVariables\QuantumDungeonTools.lua]
-- Without a path it takes the first account under the Forever WTF folder.
local path = arg[1]
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
local chunk = assert(loadfile(path, "t", env))
chunk()
local db = env.QuantumDungeonToolsDB or {}
local c = db._checkF1
if not c then print("no _checkF1 in " .. path .. " (run /qdt check f1 and /reload)") return end

local function sorted(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end
local function row(list) return table.concat(list or {}, " | ") end

local st = c.static or {}
print("== static ==")
print("build: " .. row(st.build) .. "   real issecretvalue: " .. tostring(st.realIssecretvalue))
local missing = {}
for _, k in ipairs(sorted(st.globals or {})) do
  if st.globals[k] == "nil" then missing[#missing + 1] = k else print("  G " .. k .. " = " .. st.globals[k]) end
end
print("  missing globals: " .. table.concat(missing, ", "))
local badEv, badApi = {}, {}
for _, k in ipairs(sorted(st.events or {})) do if not st.events[k] then badEv[#badEv + 1] = k end end
for _, k in ipairs(sorted(st.apis or {})) do if st.apis[k] ~= "function" and st.apis[k] ~= "table" then badApi[#badApi + 1] = k end end
print("  invalid events: " .. table.concat(badEv, ", "))
print("  missing APIs: " .. table.concat(badApi, ", "))
local scan = sorted(st.scan or {})
print(("  _G scan: %d hits%s"):format(#scan, st.scanCapped and " (CAPPED)" or ""))
for _, k in ipairs(scan) do
  local known = st.globals and st.globals[k]
  if not known then print("    " .. k .. " = " .. st.scan[k]) end
end

print("== snapshots (" .. #(c.snapshots or {}) .. ") ==")
for i, s in ipairs(c.snapshots or {}) do
  local lock = s.lock or {}
  print(("#%d %s t=%s  inst: %s"):format(i, s.label, tostring(s.t), row(s.instance)))
  print(("   lock: %s   (killed %s / total %s)"):format(row(lock.raw), tostring(lock.killed), tostring(lock.total)))
  for j, e in ipairs(s.encounters or {}) do print(("   enc%d: %s"):format(j, row(e))) end
  local saved = s.saved or {}
  print("   saved count: " .. tostring(saved.count))
  for j, v in ipairs(saved) do print(("   saved%d: %s"):format(j, row(v))) end
  for _, u in ipairs(s.units or {}) do
    if u.exists ~= "nil" and u.exists ~= "boolean:false" then
      print(("   %s: %s guid=%s zoneUID=%s npc=%s"):format(u.unit, tostring(u.name), tostring(u.guid),
        tostring(u.zoneUID), tostring(u.npcID)))
    end
  end
end

print("== GUID sources inside instances (public / secret / no zoneUID) ==")
for _, k in ipairs(sorted(c.guidSources or {})) do
  local g = c.guidSources[k]
  print(("  %-12s %d / %d / %d  sample=%s"):format(k, g.public, g.secret, g.noZone, tostring(g.sample)))
end
print("== zoneUIDs seen (instanceID:zoneUID) ==")
for _, k in ipairs(sorted(c.zoneUIDs or {})) do
  local z = c.zoneUIDs[k]
  print(("  %s  count=%d first=%s last=%s npc=%s src=%s"):format(k, z.count or 0, tostring(z.first),
    tostring(z.last), tostring(z.npcID), tostring(z.source)))
end

print("== event counts ==")
for _, k in ipairs(sorted(c.counts or {})) do print("  " .. k .. " = " .. c.counts[k]) end
print("== log (last " .. #(c.log or {}) .. ") ==")
for _, e in ipairs(c.log or {}) do
  print(("  t=%s %s inst=%s: %s"):format(tostring(e.t), e.ev, tostring(e.inst), row(e.args)))
end
