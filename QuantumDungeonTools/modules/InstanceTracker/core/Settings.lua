-- modules/InstanceTracker/core/Settings.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- The Instance Tracker settings shown in the main window (plan M1 F6, artboard «Instance
-- Tracker · Resumen», group «Qué enseña»): their defaults, which ones differ from them (the
-- gold dot and the "N changed · Reset" footer) and the one-line summary of the group.
-- The values live in db.instanceTracker (additive fields: a missing one takes its default).
local _, ns = ...

local Settings = {}
ns.InstanceSettings = Settings

-- Widget group, in the order of the artboard (two columns, left to right).
-- kind = "switch" | "marker" (raid marker index 1..8). `line` = a widget line that can be off.
Settings.WIDGET = {
  { key = "autoShow",     default = true,  kind = "switch" },
  { key = "compact",      default = false, kind = "switch" },
  { key = "showBosses",   default = true,  kind = "switch", line = true },
  { key = "showTimeBar",  default = true,  kind = "switch", line = true },
  { key = "showXPBar",    default = true,  kind = "switch", line = true },
  { key = "showTotals",   default = true,  kind = "switch", line = true },
  { key = "pingMarker",   default = 8,     kind = "marker" },
  { key = "locked",       default = false, kind = "switch" },
}

local BY_KEY = {}
for _, s in ipairs(Settings.WIDGET) do BY_KEY[s.key] = s end

function Settings.spec(key) return BY_KEY[key] end

-- Fills the missing fields with their default (0 and false are valid values: compare to nil).
function Settings.applyDefaults(db)
  if type(db) ~= "table" then return end
  for _, s in ipairs(Settings.WIDGET) do
    if db[s.key] == nil then db[s.key] = s.default end
  end
end

function Settings.get(db, key)
  local s = BY_KEY[key]
  local v = nil
  if type(db) == "table" then v = db[key] end   -- not `and db[key] or nil`: false is a value
  if v == nil and s then return s.default end
  return v
end

function Settings.isChanged(db, key)
  local s = BY_KEY[key]
  return s ~= nil and Settings.get(db, key) ~= s.default
end

function Settings.changedCount(db)
  local n = 0
  for _, s in ipairs(Settings.WIDGET) do
    if Settings.isChanged(db, s.key) then n = n + 1 end
  end
  return n
end

-- Back to the defaults (only the widget group: history, records and position are untouched).
function Settings.reset(db)
  if type(db) ~= "table" then return end
  for _, s in ipairs(Settings.WIDGET) do db[s.key] = s.default end
end

-- Summary of the group, as parts the UI joins with " · " (artboard: "3 de 4 líneas · completo
-- · se abre al entrar"): { on = lines on, total = lines, compact = bool, autoShow = bool }.
function Settings.summary(db)
  local on, total = 0, 0
  for _, s in ipairs(Settings.WIDGET) do
    if s.line then
      total = total + 1
      if Settings.get(db, s.key) then on = on + 1 end
    end
  end
  return { on = on, total = total, compact = Settings.get(db, "compact") and true or false,
           autoShow = Settings.get(db, "autoShow") and true or false }
end

-- The widget lines that are on, as View.withLines takes them.
function Settings.lines(db)
  return {
    bosses = Settings.get(db, "showBosses") and true or false,
    timeBar = Settings.get(db, "showTimeBar") and true or false,
    xpBar = Settings.get(db, "showXPBar") and true or false,
    totals = Settings.get(db, "showTotals") and true or false,
  }
end

-- Module switch (artboard: MODULE card). Off = the module does not start on the next load
-- (its events, widget and alerts); the page and the history stay reachable. Field `enabled` of
-- db.instanceTracker (additive, default on). Applied by a reload: `loadedOn` is how it started.
function Settings.isOn(db)
  return not (type(db) == "table" and db.enabled == false)
end

function Settings.needsReload(loadedOn, db)
  return (loadedOn and true or false) ~= Settings.isOn(db)
end

return Settings
