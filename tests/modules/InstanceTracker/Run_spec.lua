-- tests/modules/InstanceTracker/Run_spec.lua -- PURE run model, tested with NO WoW mock.
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Run.lua", "QuantumDungeonTools", ns)
local Run = ns.InstanceRun

-- Controllable clock.
local function clock(t0)
  local c = { t = t0 or 1000 }
  c.now = function() return c.t end
  return c
end

local INFO = { instanceID = 2999, name = "Ruins of Lordaeron", difficulty = "Normal" }

local function lockout(killedSet)
  local names = { "Witherfang", "The Abandoned", "The Butcher" }
  local list = {}
  for i, n in ipairs(names) do list[i] = { name = n, killed = killedSet and killedSet[n] or false } end
  return list
end

describe("InstanceRun", function()
  it("arranca con 0 jefes, sin terminar y con el reloj en marcha", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    assert_eq(r:total(), 0)
    assert_false(r:isFinished())
    c.t = c.t + 65
    assert_eq(r:elapsed(), 65)
  end)

  it("toma la lista del lockout y cuenta muertos", function()
    local r = Run.new(INFO, { now = clock().now })
    assert_true(r:setBosses(lockout()))
    assert_eq(r:total(), 3)
    assert_eq(r:killedCount(), 0)
  end)

  it("un jefe ya muerto en la PRIMERA lista es preKilled y sin tiempo", function()
    local r = Run.new(INFO, { now = clock().now })
    r:setBosses(lockout({ Witherfang = true }))
    local b = r.bosses[1]
    assert_true(b.killed)
    assert_true(b.preKilled)
    assert_eq(b.killedAt, nil)
  end)

  it("un jefe que muere después guarda su split", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:setBosses(lockout())
    c.t = c.t + 120
    assert_true(r:markKilled("The Abandoned"))
    assert_eq(r.bosses[2].killedAt, 120)
    assert_false(r:markKilled("The Abandoned"), "idempotente")
    c.t = c.t + 30
    r:setBosses(lockout({ ["The Abandoned"] = true }))
    assert_eq(r.bosses[2].killedAt, 120, "el lockout no pisa el split del evento")
  end)

  it("el lockout también registra muertes que el evento no vio", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:setBosses(lockout())
    c.t = c.t + 50
    r:setBosses(lockout({ Witherfang = true }))
    assert_eq(r.bosses[1].killedAt, 50)
  end)

  it("termina y congela el reloj al morir el último", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:setBosses(lockout())
    c.t = c.t + 10; r:markKilled("Witherfang")
    c.t = c.t + 10; r:markKilled("The Abandoned")
    assert_false(r:isFinished())
    c.t = c.t + 10; r:markKilled("The Butcher")
    assert_true(r:isFinished())
    c.t = c.t + 500
    assert_eq(r:elapsed(), 30, "reloj congelado")
  end)

  it("sin lista conocida, markKilled añade el jefe; con lista, ignora nombres ajenos", function()
    local r = Run.new(INFO, { now = clock().now })
    assert_true(r:markKilled("Witherfang"))
    assert_eq(r:total(), 1)
    assert_false(r:isFinished(), "no termina sin conocer la lista completa")
    r:setBosses(lockout({ Witherfang = true }))
    assert_eq(r:total(), 3, "se fusiona sin duplicar")
    assert_false(r:markKilled("Hogger"))
    assert_eq(r:total(), 3)
  end)

  it("ignora una lista de lockout ajena (sin nombres en común)", function()
    local r = Run.new(INFO, { now = clock().now })
    r:setBosses(lockout())
    assert_false(r:setBosses({ { name = "Hogger", killed = true } }))
    assert_eq(r:total(), 3)
  end)

  it("detecta el reset de la instancia (menos muertos en el lockout)", function()
    local r = Run.new(INFO, { now = clock().now })
    r:setBosses(lockout({ Witherfang = true, ["The Butcher"] = true }))
    assert_false(r:lockoutWasReset(lockout({ Witherfang = true, ["The Butcher"] = true })))
    assert_true(r:lockoutWasReset(lockout()))
    assert_false(r:lockoutWasReset({ { name = "Hogger", killed = false } }), "lista ajena no es reset")
  end)

  it("un jefe muerto por evento NO cuenta como reset si el lockout nunca marca muertos (Normal)", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:setBosses(lockout())
    c.t = c.t + 90
    assert_true(r:markKilled("Witherfang"))
    assert_false(r:lockoutWasReset(lockout()), "el lockout sigue en 0: no es reset")
    r:setBosses(lockout())
    assert_eq(r:killedCount(), 1)
  end)

  it("close() congela el reloj de una run abandonada sin marcarla terminada", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    c.t = c.t + 40
    r:close()
    c.t = c.t + 100
    assert_eq(r:elapsed(), 40)
    assert_false(r:isFinished())
  end)

  it("suma XP y descarta basura", function()
    local r = Run.new(INFO, { now = clock().now })
    assert_true(r:addXP(150))
    assert_false(r:addXP(0))
    assert_false(r:addXP(-5))
    assert_false(r:addXP("x"))
    assert_eq(r.xp, 150)
  end)

  it("xpDelta cruza una subida de nivel", function()
    assert_eq(Run.xpDelta({ xp = 100, max = 1000, level = 10 }, { xp = 250, max = 1000, level = 10 }), 150)
    assert_eq(Run.xpDelta({ xp = 900, max = 1000, level = 10 }, { xp = 50, max = 1200, level = 11 }), 150)
    assert_eq(Run.xpDelta({ xp = 900, max = 1000, level = 10 }, { xp = 50, max = 1200, level = 13 }), 0)
    assert_eq(Run.xpDelta(nil, { xp = 1, max = 2, level = 1 }), 0)
  end)

  it("un secret value no se opera: se descarta y cuenta como degradado", function()
    local secret = helper.newFakeSecret()
    local r = Run.new(INFO, { now = clock().now, isSecret = helper.isFakeSecret })
    assert_false(r:addXP(secret))
    assert_false(r:markKilled(secret))
    r:setBosses({ { name = secret, killed = true }, { name = "Witherfang", killed = false } })
    assert_eq(r:total(), 1)
    assert_eq(r.degraded, 3)
  end)

  it("sobrevive a toTable/fromTable (SavedVariables)", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:setBosses(lockout())
    c.t = c.t + 75; r:markKilled("The Butcher")
    r:addXP(321)
    local copy = Run.fromTable(r:toTable(), { now = c.now })
    assert_eq(copy.name, "Ruins of Lordaeron")
    assert_eq(copy.instanceID, 2999)
    assert_eq(copy:total(), 3)
    assert_eq(copy:killedCount(), 1)
    assert_eq(copy.bosses[3].killedAt, 75)
    assert_eq(copy.xp, 321)
    assert_eq(copy:elapsed(), 75)
    copy.bosses[1].killed = true
    assert_false(r.bosses[1].killed, "la copia no comparte tablas")
  end)
end)
