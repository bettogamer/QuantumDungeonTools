-- scripts/read-check-f2.lua -- REDUCER for QuantumDungeonToolsDB._checkF2 (plan M1, F2).
-- Usage (from the repo root):
--   lua scripts/read-check-f2.lua [path\to\SavedVariables\QuantumDungeonTools.lua]
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
assert(loadfile(path, "t", env))()
local c = (env.QuantumDungeonToolsDB or {})._checkF2
if not c then print("no _checkF2 in " .. path .. " (run /qdt check f2 and /reload)") return end

print("build: " .. table.concat(c.build or {}, " | ") .. "   at " .. tostring(c.at))
local ok, total = 0, 0
for _, r in ipairs(c.results or {}) do
  total = total + 1
  if r.ok then ok = ok + 1 end
  print(("  %s %-28s %s"):format(r.ok and "ok  " or "FAIL", r.name, tostring(r.detail)))
end
print(("== %d/%d ok =="):format(ok, total))
local keys = {}
for k in pairs(c.apis or {}) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do print("  api " .. k .. " = " .. tostring(c.apis[k])) end
