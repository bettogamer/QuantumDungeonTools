-- core/Brand.lua -- PURE: the addon's display name and brand colors (no WoW API).
-- Palette anchored on the WoW Forever logo (owner, 2026-11-12): gold is the PRIMARY color
-- (chat prefix, titles), turquoise the accent. F2 extends this into the UI token file.
local _, ns = ...

local Brand = {
  TITLE = "Quantum Dungeon Tools",   -- what the player reads; the folder name stays without spaces
  SHORT = "QDT",
  COLORS = {
    primary = "F2B84B",   -- Forever gold
    accent  = "3FD0D4",   -- Forever turquoise
    text    = "F8EEDB",   -- cream
    danger  = "FF5A4E",   -- red
  },
}
ns.Brand = Brand

-- Wraps text in a WoW color escape: Brand.paint("primary", "QDT") -> "|cffF2B84BQDT|r".
function Brand.paint(color, text)
  local hex = Brand.COLORS[color] or color
  return "|cff" .. hex .. tostring(text) .. "|r"
end

-- Chat prefix used by every message the addon prints.
function Brand.prefix() return Brand.paint("primary", Brand.SHORT) .. ": " end

return Brand
