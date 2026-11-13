-- scripts/check-upvalues.lua -- fails when any function has too many upvalues for Lua 5.1.
--
-- WoW runs Lua 5.1, where a function can capture at most 60 upvalues; past that the client
-- refuses to load THE WHOLE FILE ("function at line N has more than 60 upvalues"). The local
-- `luac -p` is 5.4 (limit 255) and luacheck does not count them, so nothing on the dev machine
-- warns: the first symptom is BugSack in-game. Typical culprit: a big builder function that
-- forward-declares dozens of locals and closes over them (SMRT Timeline.lua build(): 62).
--
-- Usage (explicit files, like luacheck -- no lfs, no folder scan):
--   lua scripts/check-upvalues.lua QuantumDungeonTools/Core.lua QuantumDungeonTools/Config.lua [--max 55]
-- Default threshold is 55: leaves headroom so the next local does not tip a function over.
-- Fix by splitting the function into helpers that receive a context table, not by hiding locals.
-- Needs `luac` on the PATH (any version >= 5.2: its listing reports upvalue counts).

local max, files = 55, {}
local args = { ... }
local i = 1
while i <= #args do
  if args[i] == "--max" then max = tonumber(args[i + 1]); i = i + 2
  else files[#files + 1] = args[i]; i = i + 1 end
end
if #files == 0 then print("usage: lua scripts/check-upvalues.lua <file.lua> [...] [--max N]") os.exit(2) end

local isWin = package.config:sub(1, 1) == "\\"
local bad = 0
for _, file in ipairs(files) do
  -- `-l -l` prints the full listing including an `upvalues (N)` line per function. Quote the
  -- path; send stderr to the void so a syntax error shows up as "no output", reported below.
  local p = io.popen(('luac -l -l -p "%s"%s'):format(file, isWin and " 2>nul" or " 2>/dev/null"))
  local current, seen = "?", false
  for line in p:lines() do
    local hdr = line:match("^function <(.-)>") or line:match("^main <(.-)>")
    if hdr then current = hdr; seen = true end
    local n = line:match("^upvalues %((%d+)%)")
    if n and tonumber(n) > max then
      bad = bad + 1
      print(("%s: %d upvalues (limit 60, threshold %d) in function <%s>"):format(file, tonumber(n), max, current))
    end
  end
  p:close()
  if not seen then print(file .. ": luac produced no listing (syntax error, or luac not on PATH)") bad = bad + 1 end
end
if bad > 0 then os.exit(1) end
print(("check-upvalues: %d file(s) ok (max %d)"):format(#files, max))
