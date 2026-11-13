-- core/Brand.lua -- PURE: the addon's display name and brand colors (no WoW API).
-- Palette sampled from the WoW Forever key art, saturated for the HUD (owner, 2026-11-13,
-- canvas artboard "Paleta", proposal B): gold (bronze hue) is the PRIMARY color (chat prefix,
-- titles, Craft primary), sea cyan the accent. F2 extends this into the UI token file.
local _, ns = ...

local Brand = {
  TITLE = "Quantum Dungeon Tools",   -- what the player reads; the folder name stays without spaces
  SHORT = "QDT",
  COLORS = {
    primary = "F5BF57",   -- Forever gold (bronze frame hue, saturated)
    accent  = "36C9E8",   -- Forever sea cyan (background hue, saturated)
    text    = "F7EDDC",   -- cream (FOREVER letters)
    danger  = "FF6B4F",   -- coral (complement of the sea)
  },
}
ns.Brand = Brand

-- Wraps text in a WoW color escape: Brand.paint("primary", "QDT") -> "|cffF5BF57QDT|r".
function Brand.paint(color, text)
  local hex = Brand.COLORS[color] or color
  return "|cff" .. hex .. tostring(text) .. "|r"
end

-- Chat prefix used by every message the addon prints.
function Brand.prefix() return Brand.paint("primary", Brand.SHORT) .. ": " end

return Brand
