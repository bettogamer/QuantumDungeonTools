-- tests/wow_helper.lua -- MINIMAL mock of the WoW API for wow/ specs.
-- Wraps helper.lua (inherits loadModule / newNS / the fake-secret kit) and adds just what
-- it takes to load the wow/ layer headless: CreateFrame with events, C_Timer with a
-- deterministic queue, C_AddOns, GetLocale and a silent print.
local helper = dofile("tests/helper.lua")
local W = setmetatable({}, { __index = helper })

-- Timer queue (module level: shared by C_Timer.After and drainTimers).
local timers = {}

-- What GetAddOnMetadata(ADDON, "Version") returns. Defaults to the packager's LITERAL TOKEN:
-- that is what an UNPACKAGED build sees, and it is the case the code must degrade to "dev"
-- (ns.resolveVersion). A mock returning "test" hides the bug -- which is how `or "dev"` got
-- into every generated addon. A spec may change it before installGlobals(). (Bis, 2026-08.)
W.addonVersion = "@project-version@"

-- Installs the WoW globals the wow/ layer needs. Call it at the start of every spec.
-- Returns the list of created frames (W._frames[1] is the first one).
function W.installGlobals()
  for i = #timers, 1, -1 do timers[i] = nil end  -- reset in-place (keeps the upvalue)
  local frames = {}

  _G.CreateFrame = function()
    local fr = { _events = {}, _handler = nil }
    function fr:RegisterEvent(e) self._events[e] = true end
    function fr:UnregisterEvent(e) self._events[e] = nil end
    function fr:SetScript(kind, fn) if kind == "OnEvent" then self._handler = fn end end
    function fr:GetScript(kind) if kind == "OnEvent" then return self._handler end end
    -- test helper: fires an event the way the game would.
    function fr:_fire(event, ...)
      if self._handler and self._events[event] then self._handler(self, event, ...) end
    end
    frames[#frames + 1] = fr
    return fr
  end

  _G.C_Timer = { After = function(seconds, fn) timers[#timers + 1] = { seconds = seconds, fn = fn } end }
  _G.C_AddOns = { GetAddOnMetadata = function(_, key)
    if key == "Version" then return W.addonVersion end
  end }
  _G.GetLocale = function() return "enUS" end

  -- Silent print, but CAPTURED: silencing without keeping anything leaves the load messages
  -- with no way to assert on them. W._printed[1] is the first line printed.
  W._printed = {}
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    W._printed[#W._printed + 1] = table.concat(parts, " ")
  end

  W._frames = frames
  return frames
end

-- Runs every pending timer once (anything they re-schedule stays queued).
function W.drainTimers()
  local pending = {}
  for i, t in ipairs(timers) do pending[i] = t end
  for i = #timers, 1, -1 do timers[i] = nil end
  for _, t in ipairs(pending) do t.fn() end
end

return W
