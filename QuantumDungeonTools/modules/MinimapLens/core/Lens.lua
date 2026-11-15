-- modules/MinimapLens/core/Lens.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- Minimap Lens core (plan M2 F2): the settings and their limits, the lens geometry (square side,
-- default position from the LensActiva artboard), what each minimap owner lets us touch, the
-- snapshot validation and the zoom kept in the DB so a crash or a disconnect with the lens on
-- does not leave the minimap one step closer (F1 gotcha 16: the client remembers the zoom).
-- The WoW side (modules/MinimapLens/wow/Lens.lua) reads the game and applies what this decides.
local _, ns = ...
local Style = ns.Style

local Lens = {}
ns.MinimapLens = Lens

-- Settings (db.minimapLens). size = factor over the original minimap side; opacity 0..1.
-- Defaults: LensActiva artboard (440 px over a 170 px minimap = 260 %), full opacity.
Lens.SIZE    = { default = 2.6, min = 1.5, max = 3.5, step = 0.1 }
Lens.OPACITY = { default = 1.0, min = 0.4, max = 1.0, step = 0.05 }
Lens.SCREEN_FIT = 0.85      -- the square never grows past this share of the screen height

-- Default spot (no saved position): the artboard's square centre on its 1280x720 frame, i.e.
-- 80 px right of and 30 px below the screen centre, scaled to the real UIParent height. Not the
-- minimap corner: there Blizzard's minimap grows off screen and the quest list covers it (gotcha 13).
Lens.DESIGN_H = 720
Lens.DEFAULT_POS = { point = "CENTER", x = 80, y = -30 }

-- Mask textures (F1 gotchas 8 and 12): square = what ElvUI/EUI use; round = Blizzard's look,
-- the one restored when nobody else owns the minimap (there is no getter for the mask).
Lens.MASK_SQUARE = 130937
Lens.MASK_ROUND  = 186178

-- QDT outline (artboard: 1 px dark edge, 2 px Secondary at 85 %, 1 px dark edge), inside out.
Lens.OUTLINE = {
  { size = 1, color = { r = 0, g = 0, b = 0, a = 0.75 } },
  { size = 2, color = Style.rgba(Style.HEX.muted, 0.85) },
  { size = 1, color = { r = 0, g = 0, b = 0, a = 0.6 } },
}

local function round(v) return math.floor(v + 0.5) end

-- Clamps to [min, max] and snaps to the step (sliders, F5). Non-numbers fall to the default.
function Lens.clamp(v, spec)
  if type(v) ~= "number" or v ~= v then return spec.default end
  if v < spec.min then v = spec.min elseif v > spec.max then v = spec.max end
  return round((v - spec.min) / spec.step) * spec.step + spec.min
end

-- Fills the missing fields (additive, no migration); `saved` and `pos` stay nil until used.
function Lens.applyDefaults(db)
  if type(db) ~= "table" then return end
  if db.size == nil then db.size = Lens.SIZE.default end
  if db.opacity == nil then db.opacity = Lens.OPACITY.default end
end

-- Side of the square lens: the original's larger side times the factor, capped to the screen
-- and never smaller than the original. Whole UI units.
function Lens.side(w, h, factor, screenH)
  local base = math.max(w, h)
  local s = base * Lens.clamp(factor, Lens.SIZE)
  if type(screenH) == "number" and screenH > 0 then s = math.min(s, screenH * Lens.SCREEN_FIT) end
  return round(math.max(s, base))
end

-- One zoom step closer (design decision 3), capped to the last level. `levels` = GetZoomLevels.
function Lens.zoomIn(zoom, levels)
  local top = (type(levels) == "number" and levels > 0) and levels - 1 or 5
  return math.min(zoom + 1, top)
end

-- Where the lens goes: the saved position if it is well formed, else the artboard default.
function Lens.position(pos, uiH)
  if type(pos) == "table" and type(pos.point) == "string" and type(pos.x) == "number"
      and type(pos.y) == "number" then
    return { point = pos.point, x = pos.x, y = pos.y }
  end
  local k = (type(uiH) == "number" and uiH > 0) and uiH / Lens.DESIGN_H or 1
  local d = Lens.DEFAULT_POS
  return { point = d.point, x = round(d.x * k), y = round(d.y * k) }
end

-- What the lens may touch given who owns the minimap ("none" | "eui" | "elvui" | "elvui+eui").
--   mask/shape: square mask + GetMinimapShape only on Blizzard's minimap (ElvUI and EUI are
--               square already and own their mask).
--   icons:      LibDBIcon Refresh, except with EllesmereUIMinimap, which hides those buttons in
--               its drawer and Refresh would force them visible for good (gotcha 4).
function Lens.plan(owner)
  local eui = type(owner) == "string" and owner:find("eui", 1, true) ~= nil
  return { mask = owner == "none", shape = owner == "none", icons = not eui }
end

-- A snapshot is usable only if every number came back readable (no secret, no nil) and the
-- minimap had at least one anchor. `isSecret` is injected (ns.issecretvalue on the WoW side).
local NUMBERS = { "w", "h", "scale", "alpha", "zoom" }
function Lens.validSnapshot(s, isSecret)
  if type(s) ~= "table" then return false, "no snapshot" end
  for _, k in ipairs(NUMBERS) do
    local v = s[k]
    if isSecret and isSecret(v) then return false, "secret " .. k end
    if type(v) ~= "number" then return false, "missing " .. k end
  end
  if type(s.points) ~= "table" or #s.points == 0 then return false, "no anchor" end
  return true
end

-- Did the move hold? (F1 gotchas 29-30: with EUI and the minimap snapped, our SetPoint is
-- undone.) `want` = the anchor we set { point, x, y }; `got` = the Minimap's only anchor, read
-- back, or nil when it has several or is not relative to UIParent (someone else anchored it).
function Lens.held(want, got, tol)
  if type(want) ~= "table" or type(got) ~= "table" then return false end
  if got.point ~= want.point or type(got.x) ~= "number" or type(got.y) ~= "number" then return false end
  tol = tol or 0.5
  return math.abs(want.x - got.x) <= tol and math.abs(want.y - got.y) <= tol
end

-- The original zoom, kept in the DB while the lens is on (gotcha 16). The normal exit restores
-- it before any reload; this covers a crash or a disconnect.
function Lens.markApplied(db, zoom)
  if type(db) == "table" then db.saved = { zoom = zoom } end
end

function Lens.markRestored(db)
  if type(db) == "table" then db.saved = nil end
end

-- Zoom to put back at login (nil = nothing pending). Clears the mark.
function Lens.takePendingZoom(db)
  if type(db) ~= "table" or type(db.saved) ~= "table" then return nil end
  local z = db.saved.zoom
  db.saved = nil
  return type(z) == "number" and z or nil
end
