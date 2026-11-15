-- scripts/read-check-lens.lua -- summary of QuantumDungeonToolsDB._checkLens (plan M2 F2-F3).
--   lua scripts/read-check-lens.lua [path\to\SavedVariables\QuantumDungeonTools.lua]
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
local db = env.QuantumDungeonToolsDB or {}
local c = db._checkLens
if not c then print("no _checkLens (use /qdt lens and /reload)") return end
for _, k in ipairs({ "on", "move", "coexist", "off" }) do
  local t = c[k]
  if t then
    local keys = {}
    for key in pairs(t) do keys[#keys + 1] = key end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. tostring(t[key]) end
    print(k .. ": " .. table.concat(parts, " "))
  else
    print(k .. ": -")
  end
end
local ml = db.minimapLens or {}
print(("minimapLens: size=%s opacity=%s saved=%s"):format(tostring(ml.size), tostring(ml.opacity),
  ml.saved and tostring(ml.saved.zoom) or "nil"))
