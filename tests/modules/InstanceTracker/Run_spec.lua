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

  it("cuenta los niveles ganados en la run y los persiste", function()
    local r = Run.new(INFO, { now = clock().now })
    assert_eq(r.levels, 0)
    assert_true(r:addLevels(1))
    assert_false(r:addLevels(0))
    assert_false(r:addLevels("x"))
    assert_eq(r.levels, 1)
    assert_eq(Run.fromTable(r:toTable(), { now = clock().now }).levels, 1)
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

describe("InstanceRun con la tabla de mazmorras (resolver)", function()
  -- Fake table: route Witherfang(1) > The Butcher(2) > The Abandoned(3); Captain is a rare.
  local DATA = { Witherfang = { order = 1 }, ["The Butcher"] = { order = 2 }, ["The Abandoned"] = { order = 3 },
    ["Lordaeron Captain"] = { order = 4, rare = true } }
  local function resolve(instanceID, name)
    if instanceID ~= 2999 then return nil end
    return DATA[name]
  end
  local function names(r)
    local out = {}
    for i, b in ipairs(r.bosses) do out[i] = b.name end
    return table.concat(out, ",")
  end
  local LIST = { { name = "Lordaeron Captain", killed = false }, { name = "Witherfang", killed = false },
    { name = "Mystery Boss", killed = false }, { name = "The Abandoned", killed = false },
    { name = "The Butcher", killed = false } }

  it("ordena por la ruta: conocidos, luego desconocidos, rares al final", function()
    local r = Run.new(INFO, { now = clock().now, resolve = resolve })
    r:setBosses(LIST)
    assert_eq(names(r), "Witherfang,The Butcher,The Abandoned,Mystery Boss,Lordaeron Captain")
  end)

  it("el rare no cuenta para el total ni para el fin de la run", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now, resolve = resolve })
    r:setBosses(LIST)
    assert_eq(r:total(), 4)
    for _, n in ipairs({ "Witherfang", "The Butcher", "The Abandoned", "Mystery Boss" }) do
      c.t = c.t + 60
      r:markKilled(n)
    end
    assert_true(r:isFinished(), "termina con el rare vivo")
    assert_eq(r:killedCount(), 4)
  end)

  it("matar el rare no suma jefes", function()
    local r = Run.new(INFO, { now = clock().now, resolve = resolve })
    r:setBosses(LIST)
    r:markKilled("Lordaeron Captain")
    assert_eq(r:killedCount(), 0)
    assert_true(r.bosses[5].killed)
  end)

  it("reclassify recoloca un nombre que el resolver aprende después", function()
    local learned = {}
    local r = Run.new(INFO, { now = clock().now, resolve = function(id, n) return learned[n] or resolve(id, n) end })
    r:setBosses(LIST)
    learned["Mystery Boss"] = { order = 0 }
    assert_true(r:reclassify())
    assert_eq(names(r), "Mystery Boss,Witherfang,The Butcher,The Abandoned,Lordaeron Captain")
  end)

  it("un resolver que lanza no rompe la run", function()
    local r = Run.new(INFO, { now = clock().now, resolve = function() error("boom") end })
    r:setBosses(LIST)
    assert_eq(r:total(), 5)
  end)

  it("una run guardada sin tabla se clasifica al cargarla (y no se da por terminada)", function()
    local old = Run.new(INFO, { now = clock().now })
    old:setBosses(LIST)
    for _, n in ipairs({ "Witherfang", "The Butcher", "The Abandoned", "Mystery Boss" }) do old:markKilled(n) end
    assert_false(old:isFinished(), "sin tabla el rare bloquea el fin")
    local loaded = Run.fromTable(old:toTable(), { now = clock().now, resolve = resolve })
    assert_eq(loaded:total(), 4)
    assert_eq(loaded.bosses[5].name, "Lordaeron Captain")
    assert_false(loaded:isFinished())
    local again = Run.fromTable(loaded:toTable(), { now = clock().now })
    assert_true(again.bosses[5].rare, "order/rare se persisten")
  end)

  it("jefe de quest sin kill: la run termina igual y conserva su etiqueta", function()
    local res = function(_, name)
      if name == "Highland Horror" then return { order = 3, rare = true, kind = "quest" } end
      return ({ Saltspine = { order = 1 }, Shadetooth = { order = 2 }, ["Relic Guardian"] = { order = 4 } })[name]
    end
    local c = clock()
    local r = Run.new({ name = "Excavation Site: Wetlands", instanceID = 2998 }, { now = c.now, resolve = res })
    r:setBosses({ { name = "Saltspine", killed = false }, { name = "Shadetooth", killed = false },
      { name = "Highland Horror", killed = false }, { name = "Relic Guardian", killed = false } })
    for _, b in ipairs({ "Saltspine", "Shadetooth", "Relic Guardian" }) do
      c.t = c.t + 60
      r:markKilled(b)
    end
    assert_eq(r:total(), 3)
    assert_true(r:isFinished(), "Highland Horror vivo no bloquea el fin")
    local again = Run.fromTable(r:toTable(), { now = c.now })
    assert_eq(again.bosses[4].kind, "quest")
  end)
  it("copia: adopta la primera, reconoce la misma y avisa de otra", function()
    local r = Run.new(INFO, { now = clock().now })
    assert_eq(r:observeCopy("5"), "first")
    assert_eq(r:observeCopy("5"), "same")
    assert_eq(r:observeCopy("6"), "other")
    assert_eq(r.copy, "5", "otra copia no pisa la de la run")
    assert_eq(r:observeCopy(""), nil)
    assert_eq(r:observeCopy(nil), nil)
  end)

  it("copia: un zoneUID secreto se descarta y cuenta como degradado", function()
    local r = Run.new(INFO, { now = clock().now, isSecret = helper.isFakeSecret })
    assert_eq(r:observeCopy(helper.newFakeSecret()), nil)
    assert_eq(r.copy, nil)
    assert_eq(r.degraded, 1)
  end)

  it("copia: se persiste (al volver tras /reload sabe en qué copia estaba)", function()
    local r = Run.new(INFO, { now = clock().now })
    r:observeCopy("5")
    local loaded = Run.fromTable(r:toTable(), { now = clock().now })
    assert_eq(loaded:observeCopy("5"), "same")
    assert_eq(loaded:observeCopy("7"), "other")
  end)

  it("reset: saca el nombre de la mazmorra del mensaje de sistema", function()
    local fmt = "%s has been reset."
    assert_eq(Run.resetName(fmt, "Ruins of Lordaeron has been reset."), "Ruins of Lordaeron")
    assert_eq(Run.resetName(fmt, "Ruins of Lordaeron has been reset"), nil, "sin punto no casa")
    assert_eq(Run.resetName(fmt, "Cannot reset Ruins of Lordaeron."), nil)
    assert_eq(Run.resetName("%s (reset).", "The Deadmines (reset)."), "The Deadmines", "escapa los parentesis")
    assert_eq(Run.resetName(nil, "x has been reset."), nil)
    assert_eq(Run.resetName("sin hueco", "sin hueco"), nil)
  end)

  it("reset: un texto secreto no se opera", function()
    local secret = helper.newFakeSecret()
    assert_eq(Run.resetName("%s has been reset.", secret, helper.isFakeSecret), nil)
  end)

  it("pausa: el tiempo fuera no cuenta en el reloj ni en los splits", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:setBosses(lockout())
    c.t = c.t + 100
    assert_true(r:pause())
    assert_false(r:pause(), "idempotente")
    c.t = c.t + 600
    assert_eq(r:elapsed(), 100, "congelado mientras está en pausa")
    assert_true(r:resume())
    assert_eq(r:elapsed(), 100)
    c.t = c.t + 50
    assert_eq(r:elapsed(), 150)
    r:markKilled("Witherfang")
    assert_eq(r.bosses[1].killedAt, 150, "el split descuenta la pausa")
  end)

  it("pausa: sobrevive a toTable/fromTable (logout dentro de la mazmorra)", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    c.t = c.t + 40
    r:pause()
    c.t = c.t + 3600 * 17
    local loaded = Run.fromTable(r:toTable(), { now = c.now })
    assert_eq(loaded:elapsed(), 40, "17 h desconectado no cuentan")
    loaded:resume()
    c.t = c.t + 5
    assert_eq(loaded:elapsed(), 45)
  end)

  it("pausa: cerrar una run en pausa la congela donde se pausó", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    c.t = c.t + 30
    r:pause()
    c.t = c.t + 900
    r:close()
    assert_eq(r:elapsed(), 30)
  end)

  it("retomar: misma mazmorra y dificultad dentro de la ventana", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:pause()
    c.t = c.t + 29 * 60
    assert_true(r:canResume(INFO, 30 * 60))
    assert_false(r:canResume({ instanceID = 2999, difficulty = "Heroic" }, 30 * 60), "otra dificultad")
    assert_false(r:canResume({ instanceID = 1, difficulty = "Normal" }, 30 * 60), "otra mazmorra")
    c.t = c.t + 2 * 60
    assert_false(r:canResume(INFO, 30 * 60), "fuera más de 30 min: copia nueva")
    r:close()
    assert_false(r:canResume(INFO), "cerrada no se retoma")
  end)

  it("retomar: la dificultad vacía de la entrada no abre otra run tras /reload (Deadmines)", function()
    local c = clock()
    local r = Run.new({ instanceID = 36, name = "Deadmines", difficulty = "" }, { now = c.now })
    r:pause()
    assert_true(r:canResume({ instanceID = 36, difficulty = "Normal" }, 30 * 60))
    assert_true(r:fillDifficulty("Normal"))
    assert_eq(r.difficulty, "Normal")
    assert_false(r:fillDifficulty("Heroic"), "una dificultad conocida no cambia")
    assert_false(r:fillDifficulty(""))
    assert_true(r:canResume({ instanceID = 36, difficulty = "" }, 30 * 60), "y al revés")
    assert_false(r:canResume({ instanceID = 36, difficulty = "Heroic" }, 30 * 60))
  end)

  it("retomar: una run completada sigue como completada y su tiempo no cambia", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:setBosses(lockout())
    c.t = c.t + 200
    r:markKilled("Witherfang"); r:markKilled("The Abandoned"); r:markKilled("The Butcher")
    assert_true(r:isFinished())
    assert_true(r:pause(), "registra la salida")
    c.t = c.t + 300
    assert_true(r:canResume(INFO, 30 * 60))
    r:resume()
    assert_eq(r:elapsed(), 200)
    assert_eq(r.pausedTotal, 0)
  end)

  it("retomar: 90 min con la run abierta, 20 min si ya está completada (punto 8a)", function()
    local c = clock()
    local open = Run.new(INFO, { now = c.now })
    open:pause()
    c.t = c.t + 89 * 60
    assert_true(open:canResume(INFO, 90 * 60, 20 * 60), "abierta: 89 min aún retoma")
    c.t = c.t + 2 * 60
    assert_false(open:canResume(INFO, 90 * 60, 20 * 60), "abierta: más de 90 min, run nueva")

    local done = Run.new(INFO, { now = c.now })
    done:setBosses(lockout())
    done:markKilled("Witherfang"); done:markKilled("The Abandoned"); done:markKilled("The Butcher")
    assert_true(done:isFinished())
    done:pause()
    c.t = c.t + 19 * 60
    assert_true(done:canResume(INFO, 90 * 60, 20 * 60), "completada: 19 min aún retoma")
    c.t = c.t + 2 * 60
    assert_false(done:canResume(INFO, 90 * 60, 20 * 60), "completada: más de 20 min, run nueva")
  end)

  it("trash: cada PARTY_KILL suma; la kill del jefe (antes o después del evento) no", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:setBosses(lockout())
    assert_true(r:addKill()); assert_true(r:addKill())
    c.t = c.t + 30
    assert_true(r:addKill())               -- killing blow of Witherfang...
    c.t = c.t + 1
    r:noteBossDeath(); r:markKilled("Witherfang")   -- ...its event a second later
    assert_eq(r.trash, 2)
    c.t = c.t + 60
    r:noteBossDeath(); r:markKilled("The Abandoned")   -- event first...
    assert_false(r:addKill())              -- ...then its killing blow
    assert_true(r:addKill(), "la siguiente kill ya es trash")
    assert_eq(r.trash, 3)
  end)

  it("trash: ENCOUNTER_END y BOSS_KILL del mismo jefe descuentan una sola kill", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:addKill(); r:addKill()
    c.t = c.t + 1
    r:noteBossDeath(); r:noteBossDeath()
    assert_eq(r.trash, 1)
  end)

  it("trash: no cuenta en pausa ni con la run terminada, y se persiste", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    r:setBosses(lockout())
    r:addKill()
    r:pause()
    assert_false(r:addKill())
    r:resume()
    for _, n in ipairs({ "Witherfang", "The Abandoned", "The Butcher" }) do
      c.t = c.t + 10
      r:noteBossDeath(); r:markKilled(n)
    end
    c.t = c.t + 10
    assert_false(r:addKill(), "terminada")
    assert_eq(Run.fromTable(r:toTable()).trash, 1)
  end)

  it("tiempo fuera: pausas cerradas más la abierta", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    assert_eq(r:awayTime(), 0)
    r:pause(); c.t = c.t + 100; r:resume()
    r:pause(); c.t = c.t + 20
    assert_eq(r:awayTime(), 120)
  end)
end)

-- The clock starts at the first combat, not at the door (owner 2026-11-20).
describe("InstanceRun: reloj desde el primer combate", function()
  local WAIT = { instanceID = 2999, name = "Ruins of Lordaeron", difficulty = "Normal", waitCombat = true }

  it("en espera el reloj marca 0 y arranca con startClock", function()
    local c = clock()
    local r = Run.new(WAIT, { now = c.now })
    c.t = c.t + 300                      -- waiting for the group
    assert_true(r:isWaiting())
    assert_eq(r:elapsed(), 0)
    assert_eq(r:startClock(), true)
    assert_eq(r:startClock(), false, "solo arranca una vez")
    c.t = c.t + 90
    assert_eq(r:elapsed(), 90)
    assert_eq(r.startedAt, 1000, "la fecha de la run sigue siendo la entrada")
  end)

  it("las pausas antes del primer combate no cuentan ni como tiempo fuera", function()
    local c = clock()
    local r = Run.new(WAIT, { now = c.now })
    r:pause(); c.t = c.t + 200; r:resume()
    assert_eq(r:awayTime(), 0)
    assert_eq(r:startClock(), true)
    c.t = c.t + 60
    assert_eq(r:elapsed(), 60)
    assert_eq(r:awayTime(), 0)
  end)

  it("en pausa no arranca (el combate es dentro)", function()
    local c = clock()
    local r = Run.new(WAIT, { now = c.now })
    r:pause()
    assert_eq(r:startClock(), false)
  end)

  it("el split de un jefe cuenta desde el combate", function()
    local c = clock()
    local r = Run.new(WAIT, { now = c.now })
    r:setBosses({ { name = "Witherfang", killed = false }, { name = "The Butcher", killed = false } })
    c.t = c.t + 400
    r:startClock()
    c.t = c.t + 120
    r:markKilled("Witherfang")
    assert_eq(r.bosses[1].killedAt, 120)
  end)

  it("toTable/fromTable conserva la espera y el arranque", function()
    local c = clock()
    local r = Run.new(WAIT, { now = c.now })
    local w = Run.fromTable(r:toTable(), { now = c.now })
    assert_true(w:isWaiting(), "guardada en espera, carga en espera")
    r:startClock(); c.t = c.t + 50
    local s = Run.fromTable(r:toTable(), { now = c.now })
    assert_true(not s:isWaiting())
    assert_eq(s:elapsed(), 50)
  end)

  it("una run guardada antes del cambio (sin waiting ni clockAt) cuenta desde startedAt", function()
    local c = clock(5000)
    local r = Run.fromTable({ instanceID = 2999, name = "Ruins", startedAt = 4000, pausedTotal = 100, bosses = {} },
      { now = c.now })
    assert_true(not r:isWaiting())
    assert_eq(r:elapsed(), 900)
  end)
end)
