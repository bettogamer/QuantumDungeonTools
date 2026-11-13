-- tests/helper.lua -- helpers for core/ specs (pure Lua, NO WoW).
-- Used by the core/ specs and, wrapped, by the wow/ ones through wow_helper.lua.
local M = {}

-- Loads an addon module passing it the (ADDON, ns) vararg, just like WoW does with `...`.
-- Paths are relative to the repo root (where `lua tests/run.lua` is run from).
function M.loadModule(path, addon, ns)
  local chunk = assert(loadfile(path))
  return chunk(addon, ns)
end

-- Fresh ns with an L returning "" for any key (specs do not assert on user-facing text).
function M.newNS()
  return { L = setmetatable({}, { __index = function() return "" end }) }
end

------------------------------------------------------------------------------
-- Fake "secret value" kit (Weave pattern: newFakeSecret / isFakeSecret)
--
-- A real secret value (WoW 12.0+) throws when operated on: arithmetic, comparison,
-- concatenation. We reproduce THAT behaviour with a metatable that throws the same way,
-- so the core's taint-safe degradation can be tested headless, without the client.
-- If the code under test operated on the secret by mistake, the test fails with the same
-- message the user would see in game.
------------------------------------------------------------------------------
local function boom() error("attempt to operate on a secret value", 2) end
local SECRET_MT = {
  __add = boom, __sub = boom, __mul = boom, __div = boom,
  __lt = boom, __le = boom, __concat = boom, __tostring = boom,
}

-- Identity registry (not by ==, which would throw): weak keys so nothing leaks.
local registry = setmetatable({}, { __mode = "k" })

function M.newFakeSecret()
  local s = setmetatable({}, SECRET_MT)
  registry[s] = true
  return s
end

-- Detector with the issecretvalue signature. The table lookup uses primitive equality
-- (rawequal on the reference), so it does NOT fire the secret's __eq/__lt.
function M.isFakeSecret(v)
  return registry[v] == true
end

-- Reads a .toc: returns the `## Key: value` fields and the list of files it loads, in order.
-- Specs read the version and the file list FROM THE .toc instead of hardcoding them: a hardcoded
-- version in a smoke spec is one more place to bump at every release (Loom touched 5 sites).
function M.readToc(path)
  local fh = assert(io.open(path, "rb"))
  local text = fh:read("*a")
  fh:close()
  local fields, files = {}, {}
  for line in text:gmatch("[^\r\n]+") do
    local k, v = line:match("^##%s*([%w%-]+)%s*:%s*(.-)%s*$")
    if k then
      fields[k] = v
    elseif not line:match("^%s*#") and line:match("%S") then
      files[#files + 1] = (line:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/"))
    end
  end
  return fields, files
end

return M
