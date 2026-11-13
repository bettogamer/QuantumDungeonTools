-- tests/run.lua -- test mini-runner, pure Lua (5.1-5.4), ZERO dependencies.
-- Born in Weave because busted does NOT install on the dev machine (no C compiler);
-- the API is busted-compatible: the specs move to busted (Linux CI) unchanged.
-- Usage (from the repo root):
--   lua tests/run.lua                       -> DISCOVERS every tests/**/*_spec.lua (the default)
--   lua tests/run.lua tests/core/x_spec.lua -> only those (to iterate on one spec)
-- Discovery replaces the hand-kept spec list: a list or glob in AGENTS.md / ci.yml goes stale
-- the day someone adds tests/data/, and the new specs then NEVER run while CI stays green
-- (Coffer: 30 specs that ran nowhere). The runner prints how many spec files it loaded.

-- The runner's report must NEVER depend on a global the code under test can replace:
-- `tests/wow_helper.lua` installs a silent `print`, which swallowed the summary AND THE
-- FAILURE LIST. A RED suite printed as little as a green one, with the right exit code, so it
-- passed for good. Capture the real print BEFORE loading any spec. (GearScope, 2026-08-15.)
local print = print

local passed, failures = 0, {}
local path = {}

function describe(name, fn)
  path[#path + 1] = name
  local ok, err = pcall(fn)
  if not ok then
    failures[#failures + 1] = { name = table.concat(path, " › "), err = "(describe) " .. tostring(err) }
  end
  path[#path] = nil
end

function it(name, fn)
  local full = table.concat(path, " › ") .. " › " .. name
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
    io.write(".")
  else
    failures[#failures + 1] = { name = full, err = err }
    io.write("F")
  end
end

function assert_eq(got, expected, msg)
  if got ~= expected then
    error(("%s\n  esperado: %s\n  obtenido: %s"):format(msg or "valores distintos",
      tostring(expected), tostring(got)), 2)
  end
end

function assert_true(v, msg)  assert_eq(not not v, true,  msg) end
function assert_false(v, msg) assert_eq(not not v, false, msg) end

function assert_error(fn, pattern, msg)
  local ok, err = pcall(fn)
  if ok then error((msg or "se esperaba un error") .. " (no hubo error)", 2) end
  if pattern and not tostring(err):find(pattern) then
    error(("%s\n  el error no contiene %q:\n  %s"):format(msg or "error inesperado", pattern, tostring(err)), 2)
  end
end

-- Spec discovery: no lfs, so ask the OS. `dir /b /s` on Windows, `find` elsewhere.
local function discover()
  local isWin = package.config:sub(1, 1) == "\\"
  local function lines(cmd)
    local p = io.popen(cmd)
    if not p then return nil end
    local out = {}
    for l in p:lines() do out[#out + 1] = l end
    p:close()
    return out
  end
  local cmd = isWin and "dir /b /s tests\\*_spec.lua 2>nul" or "find tests -name '*_spec.lua' 2>/dev/null"
  local found = lines(cmd)
  if not found or #found == 0 then return nil end
  local cwd = isWin and lines("cd") or nil
  cwd = cwd and cwd[1] and cwd[1]:gsub("\\", "/"):gsub("/$", "") or nil
  local specs = {}
  for _, l in ipairs(found) do
    l = l:gsub("\\", "/"):gsub("\r$", "")
    if cwd and l:sub(1, #cwd + 1) == cwd .. "/" then l = l:sub(#cwd + 2) end
    specs[#specs + 1] = l
  end
  table.sort(specs)
  return specs
end

-- Each spec runs in its OWN environment (reads fall through to _G), like busted: a spec that
-- writes `GetTime = ...` changes only its own environment, never the _G the modules under test
-- read. To stub a global FOR the code under test, write `_G.Name = ...` (and undo it). Without
-- this, specs pass or fail depending on the ORDER they run in, and the failure shows up in CI
-- (alphabetical) but never locally. (craft, 2026-10-18.)
local function loadIn(file, env)
  if setfenv then                              -- Lua 5.1 (CI)
    local chunk, err = loadfile(file)
    if not chunk then error(err, 0) end
    return setfenv(chunk, env)
  end
  local chunk, err = loadfile(file, "t", env)  -- Lua 5.2+ (dev machine)
  if not chunk then error(err, 0) end
  return chunk
end

local specs = { ... }
if #specs == 0 then
  specs = discover()
  if not specs then
    print("no specs found under tests/ (run from the repo root) -- or pass them: lua tests/run.lua <spec.lua> [...]")
    os.exit(2)
  end
end

for _, spec in ipairs(specs) do
  local env = setmetatable({}, { __index = _G })
  loadIn(spec, env)()
end

print(("\n%d spec files, %d ok, %d fallos"):format(#specs, passed, #failures))
for _, f in ipairs(failures) do
  print(("\nFALLO: %s\n%s"):format(f.name, f.err))
end
os.exit(#failures == 0 and 0 or 1)
