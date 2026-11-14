-- tests/wow/Bootstrap_spec.lua -- the wow/ layer against the minimal WoW mock.
-- Checks the integration contract: on load, wow/ must INJECT the real game deps into the
-- core and start the lifecycle.
local wow = dofile("tests/wow_helper.lua")

local function loadAddon()
  wow.installGlobals()
  _G.QuantumDungeonToolsDB = nil                       -- clean SavedVariables per spec
  local ns = wow.newNS()
  wow.loadModule("QuantumDungeonTools/core/Brand.lua", "QuantumDungeonTools", ns)   -- before wow/, as in the .toc
  wow.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Settings.lua", "QuantumDungeonTools", ns)
  wow.loadModule("QuantumDungeonTools/wow/Bootstrap.lua", "QuantumDungeonTools", ns)
  return ns, wow._frames[1]
end

describe("Bootstrap (capa wow/)", function()
  it("crea la DB con los defaults del Instance Tracker al recibir ADDON_LOADED", function()
    local ns, frame = loadAddon()
    frame:_fire("ADDON_LOADED", "QuantumDungeonTools")
    assert_eq(ns.db.enabled, true, "default enabled=true")
    assert_eq(ns.db.instanceTracker.autoShow, true, "default autoShow=true")
    assert_eq(#ns.db.instanceTracker.history, 0, "historial vacío")
  end)

  it("no pisa los ajustes guardados del usuario", function()
    local ns, frame = loadAddon()
    _G.QuantumDungeonToolsDB = { instanceTracker = { autoShow = false, history = { {} } } }
    frame:_fire("ADDON_LOADED", "QuantumDungeonTools")
    assert_eq(ns.db.instanceTracker.autoShow, false)
    assert_eq(#ns.db.instanceTracker.history, 1)
  end)

  it("ignora ADDON_LOADED de otros addons", function()
    local ns, frame = loadAddon()
    frame:_fire("ADDON_LOADED", "OtroAddon")
    assert_true(ns.db == nil, "no debe inicializarse por otro addon")
  end)

  -- The .toc's `@project-version@` token is only substituted by the packager when publishing:
  -- outside a published build it arrives LITERAL, and it is not nil. `or "dev"` misses it.
  it("degrada la versión a 'dev' cuando llega el token del packager", function()
    wow.addonVersion = "@project-version@"
    local ns, frame = loadAddon()
    frame:_fire("ADDON_LOADED", "QuantumDungeonTools")
    frame:_fire("PLAYER_LOGIN")
    assert_eq(ns.version, "dev", "el token literal debe degradarse a dev")
    assert_true(not wow._printed[1]:find("@", 1, true),
      "el mensaje de carga no puede contener la arroba del token")
  end)

  it("usa la versión tal cual en un build publicado", function()
    wow.addonVersion = "1.2.3"
    local ns, frame = loadAddon()
    frame:_fire("ADDON_LOADED", "QuantumDungeonTools")
    frame:_fire("PLAYER_LOGIN")
    assert_eq(ns.version, "1.2.3", "una versión real pasa sin tocar")
    wow.addonVersion = "@project-version@"   -- restore the default for the other specs
  end)
end)
