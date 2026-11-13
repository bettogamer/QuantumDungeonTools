-- modules/InstanceTracker/core/Guid.lua -- PURE parser of unit GUIDs (no WoW API).
--
-- Creature-style GUIDs: "<type>-0-<serverID>-<instanceID>-<zoneUID>-<npcID>-<spawnUID>".
-- Player GUIDs ("Player-<serverID>-<hex>") carry no zoneUID. The zoneUID identifies the
-- instance COPY: F3 uses it to pause/resume a run (plan M1); F1 measures whether it is stable.
local _, ns = ...

local Guid = {}
ns.InstanceGuid = Guid

-- GUID kinds that carry the zoneUID field (Cast: the castGUID of UNIT_SPELLCAST_*, where npcID
-- holds the spellID).
local ZONED = { Creature = true, Vehicle = true, GameObject = true, Pet = true, Cast = true }

local function split(s)
  local parts = {}
  for p in (s .. "-"):gmatch("([^-]*)-") do parts[#parts + 1] = p end
  return parts
end

-- Returns { type, serverID, instanceID, zoneUID, npcID, spawnUID } (numbers where they are
-- numbers; zoneUID/spawnUID stay strings) or nil when `guid` is not a parsable string.
function Guid.parse(guid)
  if type(guid) ~= "string" or guid == "" then return nil end
  local p = split(guid)
  local kind = p[1]
  if not ZONED[kind] then
    return { type = kind, serverID = tonumber(p[2]) }
  end
  if #p < 7 then return nil end
  return {
    type = kind,
    serverID = tonumber(p[3]),
    instanceID = tonumber(p[4]),
    zoneUID = p[5] ~= "" and p[5] or nil,
    npcID = tonumber(p[6]),
    spawnUID = p[7] ~= "" and p[7] or nil,
  }
end

return Guid
