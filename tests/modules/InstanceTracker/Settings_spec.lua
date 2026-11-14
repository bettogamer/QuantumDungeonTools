-- tests/modules/InstanceTracker/Settings_spec.lua -- PURE widget settings (plan M1 F6).
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Settings.lua", "QuantumDungeonTools", ns)
local Settings = ns.InstanceSettings

describe("InstanceSettings", function()
  it("applyDefaults rellena lo que falta sin pisar false ni 0", function()
    local db = { autoShow = false, pingMarker = 0 }
    Settings.applyDefaults(db)
    assert_eq(db.autoShow, false)
    assert_eq(db.pingMarker, 0)
    assert_eq(db.compact, false)
    assert_eq(db.showBosses, true)
    assert_eq(db.locked, false)
  end)

  it("get cae al valor por defecto si falta el campo", function()
    assert_eq(Settings.get({}, "showTotals"), true)
    assert_eq(Settings.get({ showTotals = false }, "showTotals"), false)
    assert_eq(Settings.get(nil, "pingMarker"), 8)
  end)

  it("changedCount y reset: el pie «N cambiados · Restablecer»", function()
    local db = {}
    Settings.applyDefaults(db)
    assert_eq(Settings.changedCount(db), 0)
    db.showXPBar, db.pingMarker = false, 1
    assert_eq(Settings.changedCount(db), 2)
    assert_true(Settings.isChanged(db, "showXPBar"))
    assert_false(Settings.isChanged(db, "showBosses"))
    db.history = { 1 }
    Settings.reset(db)
    assert_eq(Settings.changedCount(db), 0)
    assert_eq(#db.history, 1)   -- only the widget group
  end)

  it("summary cuenta las 4 líneas desactivables", function()
    local s = Settings.summary({ showXPBar = false, compact = false, autoShow = true })
    assert_eq(s.total, 4)
    assert_eq(s.on, 3)
    assert_false(s.compact)
    assert_true(s.autoShow)
  end)

  it("lines traduce los 4 interruptores para View.withLines", function()
    local l = Settings.lines({ showBosses = false, showXPBar = false })
    assert_false(l.bosses)
    assert_true(l.timeBar)
    assert_false(l.xpBar)
    assert_true(l.totals)
  end)

  it("interruptor del módulo: encendido por defecto, se aplica al recargar", function()
    assert_true(Settings.isOn({}))
    assert_true(Settings.isOn(nil))
    assert_false(Settings.isOn({ enabled = false }))
    assert_false(Settings.needsReload(true, {}))
    assert_true(Settings.needsReload(true, { enabled = false }))
    assert_true(Settings.needsReload(false, { enabled = true }))
    assert_false(Settings.needsReload(false, { enabled = false }))
  end)

  it("reset no toca el interruptor del módulo", function()
    local db = { enabled = false }
    Settings.reset(db)
    assert_eq(db.enabled, false)
  end)
end)
