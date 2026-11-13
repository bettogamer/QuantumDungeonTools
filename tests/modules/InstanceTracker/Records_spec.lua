-- tests/modules/InstanceTracker/Records_spec.lua -- PURE personal records (plan M1 F3).
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Run.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Records.lua", "QuantumDungeonTools", ns)
local Run, Records = ns.InstanceRun, ns.InstanceRecords

local INFO = { instanceID = 2999, name = "Ruins of Lordaeron", difficulty = "Normal" }
local NAMES = { "Witherfang", "The Abandoned", "The Butcher" }

local function clock(t0)
  local c = { t = t0 or 1000 }
  c.now = function() return c.t end
  return c
end

local function list(killed)
  local l = {}
  for i, n in ipairs(NAMES) do l[i] = { name = n, killed = killed or false } end
  return l
end

-- A clean run: lockout first (nothing dead), then one kill every `step` seconds.
local function cleanRun(step, c)
  c = c or clock()
  local r = Run.new(INFO, { now = c.now })
  r:setBosses(list())
  for _, n in ipairs(NAMES) do
    c.t = c.t + step
    r:markKilled(n)
  end
  return r, c
end

describe("InstanceRecords", function()
  it("la clave es instanceID + dificultad (o el nombre si no hay ID)", function()
    assert_eq(Records.key(Run.new(INFO)), "2999|Normal")
    assert_eq(Records.key(Run.new({ name = "X", difficulty = "Heroic" })), "X|Heroic")
  end)

  it("la primera run limpia terminada pasa a ser el récord, con sus splits", function()
    local store = {}
    local r = cleanRun(100)
    assert_true(Records.consider(store, r))
    local pb = Records.get(store, r)
    assert_eq(pb.total, 300)
    assert_eq(pb.splits["Witherfang"], 100)
    assert_eq(pb.splits["The Butcher"], 300)
  end)

  it("solo la reemplaza una run más rápida", function()
    local store = {}
    Records.consider(store, cleanRun(100))
    assert_false(Records.consider(store, cleanRun(120)))
    assert_eq(Records.get(store, Run.new(INFO)).total, 300)
    assert_true(Records.consider(store, cleanRun(80)))
    assert_eq(Records.get(store, Run.new(INFO)).total, 240)
  end)

  it("no cuenta una run sin terminar ni una con jefes ya muertos al entrar", function()
    local store = {}
    local r = Run.new(INFO, { now = clock().now })
    r:setBosses(list())
    r:markKilled("Witherfang")
    assert_false(Records.consider(store, r))

    local pre = Run.new(INFO, { now = clock().now })
    pre:setBosses({ { name = "Witherfang", killed = true }, { name = "The Abandoned", killed = false },
      { name = "The Butcher", killed = false } })
    pre:markKilled("The Abandoned")
    pre:markKilled("The Butcher")
    assert_true(pre:isFinished())
    assert_false(Records.consider(store, pre))
    assert_eq(next(store), nil)
  end)

  it("get devuelve una copia: tocarla no cambia el récord guardado", function()
    local store = {}
    local r = cleanRun(100)
    Records.consider(store, r)
    local pb = Records.get(store, r)
    pb.total, pb.splits["Witherfang"] = 1, 1
    assert_eq(Records.get(store, r).total, 300)
    assert_eq(Records.get(store, r).splits["Witherfang"], 100)
  end)
end)

describe("InstanceRun: muertes y récord de referencia", function()
  it("cuenta muertes solo con la run viva", function()
    local c = clock()
    local r = Run.new(INFO, { now = c.now })
    assert_true(r:addDeath())
    r:pause()
    assert_false(r:addDeath())
    r:resume()
    assert_true(r:addDeath())
    assert_eq(r.deaths, 2)
    r:close()
    assert_false(r:addDeath())
    assert_eq(r.deaths, 2)
  end)

  it("muertes y récord de referencia sobreviven a guardar y cargar", function()
    local r = Run.new(INFO, { now = clock().now })
    r.pb = { total = 300, splits = { Witherfang = 100 } }
    r:addDeath()
    local t = r:toTable()
    r.pb.splits.Witherfang = 1   -- the saved table is a copy
    local back = Run.fromTable(t, { now = clock().now })
    assert_eq(back.deaths, 1)
    assert_eq(back.pb.total, 300)
    assert_eq(back.pb.splits.Witherfang, 100)
  end)
end)
