-- scripts/read-check-m2.lua -- REDUCER for QuantumDungeonToolsDB._checkM2 (plan M2, F1).
-- Prints a short summary per UI config (none / eui / elvui) instead of reading the SavedVariables.
-- Usage (from the repo root):
--   lua scripts/read-check-m2.lua [path\to\SavedVariables\QuantumDungeonTools.lua] [--log]
-- Without a path it takes the first account under the Forever WTF folder. --log prints every
-- non-QDT write and every event line (otherwise only the counts and the notable lines).
local path, full
for _, a in ipairs(arg) do
  if a == "--log" then full = true else path = a end
end
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
local c = (env.QuantumDungeonToolsDB or {})._checkM2
if not c then print("no _checkM2 in " .. path .. " (run /qdt check m2 and /reload)") return end

local function sorted(t)
  local keys = {}
  for k in pairs(t or {}) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end
local function list(t, indent)
  for _, line in ipairs(t or {}) do print((indent or "    ") .. tostring(line)) end
end
local function pts(p) return type(p) == "table" and table.concat(p, " ; ") or tostring(p) end

-- One compact line per state: what F2 cares about.
local function stateLine(s)
  local m = type(s.minimap) == "table" and s.minimap or {}
  local bd = type(s.backdrop) == "table" and s.backdrop or {}
  return ("%-22s size=%s scale=%s alpha=%s zoom=%s/%s radius=%s shape=%s ring=%s combat=%s pts=%s"):format(
    tostring(s.label), tostring(m.size), tostring(m.scale), tostring(m.alpha), tostring(s.zoom),
    tostring(s.zoomLevels), tostring(s.viewRadius), tostring(s.shape), tostring(bd.shown),
    tostring(s.combat), pts(m.points))
end

local function icons(s)
  if type(s.icons) ~= "table" then return tostring(s.icons) end
  local out = {}
  for _, k in ipairs(sorted(s.icons)) do out[#out + 1] = k .. "=" .. s.icons[k] end
  return table.concat(out, "\n      ")
end

for _, cfg in ipairs(sorted(c.runs)) do
  local r = c.runs[cfg]
  print(("==================== config: %s ===================="):format(cfg))
  local st = r.static or {}
  print("build: " .. tostring(st.build) .. "  GetMinimapShape: " .. tostring(st.getMinimapShape)
    .. "  ElvUI holder: " .. tostring(st.elvHolder) .. "  binding: " .. tostring(st.bindingKey)
    .. "  EventRegistry: " .. tostring(st.editModeRegistry))
  local loaded = {}
  for _, a in ipairs(sorted(st.addons)) do if st.addons[a] then loaded[#loaded + 1] = a end end
  print("addons loaded: " .. table.concat(loaded, ", "))
  local m = {}
  for _, k in ipairs(sorted(st.methods)) do m[#m + 1] = k .. "=" .. st.methods[k] end
  print("Minimap methods: " .. table.concat(m, " "))
  print("anchors:")
  for _, n in ipairs(sorted(st.anchors)) do
    local a = st.anchors[n]
    if type(a) == "table" then
      print(("  %-22s shown=%s parent=%s size=%s scale=%s pts=%s"):format(n, tostring(a.shown),
        tostring(a.parent), tostring(a.size), tostring(a.scale), pts(a.points)))
    else
      print(("  %-22s %s"):format(n, tostring(a)))
    end
  end
  print("tracking (" .. tostring(st.trackingCount) .. ", cvar " .. tostring(st.cvarTracked) .. "):")
  list(st.tracking)

  print("states:")
  for _, s in ipairs(r.states or {}) do print("  " .. stateLine(s)) end
  local last = r.states and r.states[#r.states]
  if last then print("  icons @" .. tostring(last.label) .. ":\n      " .. icons(last)) end
  local firstSize
  for _, s in ipairs(r.states or {}) do
    if s.label == "tour:size+0" then firstSize = s end
  end
  if firstSize then print("  icons @tour:size+0:\n      " .. icons(firstSize)) end

  if r.tour then
    print(("tour: restore diffs size=%d scale=%d"):format(#(r.tour.diff or {}), #(r.tour.diff2 or {})))
    list(r.tour.diff, "    size  ")
    list(r.tour.diff2, "    scale ")
  end
  if r.reload then
    print(("reload with lens on: %d fields differ from the baseline"):format(#(r.reload.diff or {})))
    list(r.reload.diff)
  end
  if r.offDiff then
    print(("off: %d fields differ from the baseline"):format(#r.offDiff))
    list(r.offDiff)
  end
  if r.combat then
    local cb = r.combat
    print(("combat: lockdown=%s apply=%s move=%s setTracking=%s setCVar=%s restore=%s lockdownAtRestore=%s"):format(
      tostring(cb.inLockdown), tostring(cb.apply), tostring(cb.move), tostring(cb.setTracking),
      tostring(cb.setCVar), tostring(cb.restore), tostring(cb.inLockdownAtRestore)))
    list(cb.diff, "    diff ")
  end

  print("writes by others (method | writer = count):")
  for _, k in ipairs(sorted(r.counts)) do
    if not k:find("| QDT$") then print("    " .. k .. " = " .. r.counts[k]) end
  end
  print("errors: " .. #(r.errors or {}))
  list(r.errors)
  print("notable log lines:")
  for _, line in ipairs(r.log or {}) do
    local notable = line:find("STOMPED") or line:find("ADDON_ACTION") or line:find("EditMode")
      or line:find("==") or line:find("EVENT PEW")
    local foreign = not line:find(" by QDT ") and not line:find("EVENT ")
    if notable or (full and (foreign or line:find("EVENT "))) then print("    " .. line) end
  end
end
