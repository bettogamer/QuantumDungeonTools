-- tests/wow/Tracker_spec.lua -- Instance Tracker (wow/) copy detection against a minimal mock.
-- Origin: CurseForge report 2026-11-20 on Excavation Site: Wetlands (2998): "it keeps resetting",
-- 481/10 instances per hour. Every cast with a different castGUID zoneUID started a new run and
-- counted one entry. The copy can only change across a loading screen (PLAYER_ENTERING_WORLD).
local wow = dofile("tests/wow_helper.lua")

local ADDON = "QuantumDungeonTools"
local IT = "QuantumDungeonTools/modules/InstanceTracker/"

local function setup()
  wow.installGlobals()
  local env = { clock = 1000000, inst = nil }
  _G.time = function() return env.clock end
  _G.GetInstanceInfo = function()
    local i = env.inst
    if not i then return "Wetlands", "none", 0, "", 5, 0, false, 0 end
    return i.name, "party", 1, i.diff or "Normal", 5, 0, false, i.id
  end
  _G.UnitXP = function() return 100 end
  _G.UnitXPMax = function() return 1000 end
  _G.UnitLevel = function() return 24 end
  _G.UnitFullName = function() return "Tester", "Realm" end
  _G.UnitExists = function() return false end
  _G.geterrorhandler = function() return function(e) error(e, 0) end end

  local ns = wow.newNS()
  ns.issecretvalue = function() return false end
  for _, f in ipairs({ "QuantumDungeonTools/core/Format.lua", IT .. "core/Run.lua", IT .. "core/Records.lua",
    IT .. "core/History.lua", IT .. "core/Hourly.lua", IT .. "core/ChatParse.lua", IT .. "core/Guid.lua",
    IT .. "core/DungeonData.lua", IT .. "core/Dungeons.lua", IT .. "core/Detail.lua", IT .. "wow/Tracker.lua" }) do
    wow.loadModule(f, ADDON, ns)
  end
  ns.db = { instanceTracker = { history = {}, records = {}, trash = {}, hourly = {}, unstableCopy = {} } }
  local T = ns.InstanceTracker
  T:Init()
  local frame = wow._frames[#wow._frames]

  function env.enter(id, name) env.inst = { id = id, name = name }; frame:_fire("PLAYER_ENTERING_WORLD") end
  function env.leave() env.inst = nil; frame:_fire("PLAYER_ENTERING_WORLD") end
  function env.reload() frame:_fire("PLAYER_ENTERING_WORLD", false, true) end
  function env.cast(zoneUID)
    local guid = "Cast-3-6831-" .. env.inst.id .. "-" .. zoneUID .. "-1026-F53E335783"
    frame:_fire("UNIT_SPELLCAST_SENT", "player", nil, guid)
  end
  function env.hourCount() return T:HourSnapshot().count end
  env.T, env.ns, env.frame = T, ns, frame
  return env
end

describe("Tracker: copia por castGUID (wow/)", function()
  it("Excavation Site: un zoneUID distinto en cada cast no reinicia la run ni cuenta entradas", function()
    local env = setup()
    env.enter(2998, "Excavation Site: Wetlands")
    local run = env.T.run
    for z = 1, 20 do env.cast(tostring(z)) end
    assert_true(env.T.run == run, "la run es la misma: no se reinicia en cada cast")
    assert_eq(env.hourCount(), 1, "una sola entrada en la hora")
    assert_eq(env.ns.db.instanceTracker.unstableCopy[2998], true, "la mazmorra queda marcada")
  end)

  it("mazmorra marcada: al volver a entrar, otro zoneUID no abre run nueva", function()
    local env = setup()
    env.ns.db.instanceTracker.unstableCopy[2998] = true
    env.enter(2998, "Excavation Site: Wetlands")
    env.cast("1")
    local run = env.T.run
    env.leave()
    env.clock = env.clock + 60
    env.enter(2998, "Excavation Site: Wetlands")
    env.cast("2")
    env.cast("3")
    assert_true(env.T.run == run, "se reanuda la misma run")
    assert_eq(env.hourCount(), 1)
  end)

  it("mazmorra normal: tras una pantalla de carga, otro zoneUID sí es otra copia", function()
    local env = setup()
    env.enter(2999, "Ruins of Lordaeron")
    env.cast("5"); env.cast("5")
    local run = env.T.run
    assert_eq(env.hourCount(), 1)
    env.leave()
    env.clock = env.clock + 60
    env.enter(2999, "Ruins of Lordaeron")
    env.cast("6")
    assert_true(env.T.run ~= run, "copia del líder o reset: run nueva")
    assert_eq(env.T.run.copy, "6")
    assert_eq(env.hourCount(), 2)
    assert_eq(env.ns.db.instanceTracker.unstableCopy[2999], nil, "no se marca como inestable")
  end)

  it("mazmorra normal: volver a la misma copia no cuenta otra entrada", function()
    local env = setup()
    env.enter(2999, "Ruins of Lordaeron")
    env.cast("5")
    local run = env.T.run
    env.leave()
    env.clock = env.clock + 60
    env.enter(2999, "Ruins of Lordaeron")
    env.cast("5")
    assert_true(env.T.run == run)
    assert_eq(env.hourCount(), 1)
  end)

  -- Measured 2026-11-20 in Ruins of Lordaeron: zoneUID 5045554 before /reload, 2556610 after.
  it("un /reload dentro cambia el zoneUID: se adopta, sin run nueva ni entrada", function()
    local env = setup()
    env.enter(2999, "Ruins of Lordaeron")
    env.cast("5045554")
    local run = env.T.run
    env.reload()
    env.cast("2556610")
    env.cast("2556610")
    assert_true(env.T.run == run, "la run sigue tras el reload")
    assert_eq(env.T.run.copy, "2556610", "la copia adopta el zoneUID nuevo")
    assert_eq(env.hourCount(), 1)
    assert_eq(env.ns.db.instanceTracker.hourly[1].copy, "2556610", "la entrada también")
    assert_eq(env.ns.db.instanceTracker.unstableCopy[2999], nil)
    -- out and back into the same copy (new zoneUID kept): still one entry
    env.leave()
    env.clock = env.clock + 60
    env.enter(2999, "Ruins of Lordaeron")
    env.cast("2556610")
    assert_true(env.T.run == run)
    assert_eq(env.hourCount(), 1)
  end)

  it("tras el reload, otro zoneUID a mitad de estancia sí marca la mazmorra", function()
    local env = setup()
    env.enter(2998, "Excavation Site: Wetlands")
    env.cast("1")
    env.reload()
    env.cast("2")
    env.cast("3")
    assert_eq(env.ns.db.instanceTracker.unstableCopy[2998], true)
    assert_eq(env.hourCount(), 1)
  end)

  it("ZONE_CHANGED_NEW_AREA dentro no abre run ni cuenta entrada aunque cambie el instanceID", function()
    local env = setup()
    env.enter(2998, "Excavation Site: Wetlands")
    local run = env.T.run
    for i = 1, 10 do
      env.inst = { id = (i % 2 == 0) and 2998 or 4000, name = "Excavation Site: Wetlands" }
      env.frame:_fire("ZONE_CHANGED_NEW_AREA")
    end
    assert_true(env.T.run == run, "la run no se reinicia al cruzar subzonas")
    assert_eq(env.hourCount(), 1)
  end)
end)
