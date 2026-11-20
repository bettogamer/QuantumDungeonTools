-- tests/modules/InstanceTracker/Hourly_spec.lua -- PURE instances per hour (plan M1 F5).
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Hourly.lua", "QuantumDungeonTools", ns)
local Hourly = ns.InstanceHourly

local RFC = { instanceID = 389, name = "Ragefire Chasm", char = "Ann-Realm" }
local DM = { instanceID = 36, name = "Deadmines", char = "Bob-Realm" }

describe("InstanceHourly", function()
  it("cuenta las entradas de la última hora y ordena los huecos", function()
    local l = {}
    Hourly.note(l, 1000, RFC)
    Hourly.note(l, 1600, DM)
    local s = Hourly.snapshot(l, 2000)
    assert_eq(s.count, 2)
    assert_eq(s.limit, 10)
    assert_eq(s.slots[1], 2600)   -- 1000 + 3600 - 2000
    assert_eq(s.slots[2], 3200)
    assert_eq(s.freeIn, 2600)
  end)

  it("una entrada de hace una hora o más ya no cuenta y se poda", function()
    local l = {}
    Hourly.note(l, 1000, RFC)
    Hourly.note(l, 2000, DM)
    assert_eq(Hourly.snapshot(l, 4600).count, 1)
    Hourly.prune(l, 4600)
    assert_eq(#l, 1)
    assert_eq(l[1].instanceID, 36)
  end)

  it("suma personajes distintos (la cuenta es de la cuenta, no del personaje)", function()
    local l = {}
    Hourly.note(l, 1000, RFC)
    Hourly.note(l, 1100, { instanceID = 389, name = "Ragefire Chasm", char = "Bob-Realm" })
    assert_eq(Hourly.snapshot(l, 1200).count, 2)
  end)

  it("con copia ya contada en la hora no suma", function()
    local l = {}
    Hourly.note(l, 1000, { instanceID = 389, copy = 5 })
    assert_eq(Hourly.note(l, 1500, { instanceID = 389, copy = 5 }), nil)
    assert_eq(Hourly.snapshot(l, 1600).count, 1)
    assert_true(Hourly.note(l, 1500, { instanceID = 389, copy = 6 }) ~= nil)
    assert_eq(Hourly.snapshot(l, 1600).count, 2)
  end)

  it("bindCopy guarda la copia en la entrada más nueva de esa instancia", function()
    local l = {}
    Hourly.note(l, 1000, RFC)
    Hourly.note(l, 1100, DM)
    assert_eq(Hourly.bindCopy(l, 1200, 389, 7), "bound")
    assert_eq(l[1].copy, 7)
    assert_eq(Hourly.bindCopy(l, 1300, 389, 7), "known")
  end)

  it("bindCopy quita la entrada si esa copia ya estaba contada (volver a la misma copia)", function()
    local l = {}
    Hourly.note(l, 1000, RFC)
    Hourly.bindCopy(l, 1010, 389, 7)
    Hourly.note(l, 2000, RFC)             -- re-entry noted before knowing the copy
    assert_eq(Hourly.bindCopy(l, 2010, 389, 7), "dup")
    assert_eq(Hourly.snapshot(l, 2020).count, 1)
    assert_eq(l[1].at, 1000)              -- the first entry is the one that stays
  end)

  it("bindCopy sin entradas de esa instancia no hace nada", function()
    local l = {}
    Hourly.note(l, 1000, DM)
    assert_eq(Hourly.bindCopy(l, 1100, 389, 7), nil)
    assert_eq(Hourly.bindCopy(l, 1100, 36, nil), nil)
  end)

  it("ignora entradas mal formadas y argumentos inválidos", function()
    local l = { { at = "x" }, "basura", { at = 1000, instanceID = 389 } }
    assert_eq(Hourly.snapshot(l, 1100).count, 1)
    assert_eq(Hourly.note(l, 1100, {}), nil)
    assert_eq(Hourly.note(nil, 1100, RFC), nil)
    assert_eq(Hourly.snapshot(nil, 1100).count, 0)
  end)
  it("rebindCopy cambia la copia de las entradas de esa instancia (zoneUID nuevo tras /reload)", function()
    local l = {}
    Hourly.note(l, 1000, { instanceID = 2999, copy = "a" })
    Hourly.note(l, 1000, { instanceID = 90, copy = "a" })
    assert_eq(Hourly.rebindCopy(l, 1100, 2999, "a", "b"), 1)
    assert_eq(l[1].copy, "b")
    assert_eq(l[2].copy, "a", "otra instancia no se toca")
    assert_eq(Hourly.note(l, 1200, { instanceID = 2999, copy = "b" }), nil, "volver a la copia no cuenta")
    assert_eq(Hourly.rebindCopy(nil, 1100, 2999, "a", "b"), 0)
  end)
end)
