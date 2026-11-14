-- tests/modules/InstanceTracker/Alerts_spec.lua -- PURE alerts of plan M1 F5 (artboard «Avisos»).
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/core/Format.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Run.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Alerts.lua", "QuantumDungeonTools", ns)
local Run, Alerts = ns.InstanceRun, ns.InstanceAlerts

local MINUS = "\226\136\146"
local SEP = " \194\183 "

local function snap(count, freeIn) return { count = count, limit = 10, freeIn = freeIn } end

-- A finished run of `elapsed` seconds, with loot.
local function finished(elapsed, extra)
  local c = { t = 1000 }
  local r = Run.new({ instanceID = 2999, name = "Ruins of Lordaeron", difficulty = "Normal" },
    { now = function() return c.t end })
  r:setBosses({ { name = "A", killed = false } })
  c.t = c.t + elapsed
  r:markKilled("A")
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end

describe("InstanceAlerts.hourNotice", function()
  it("al entrar: rojo en 10/10, ámbar en 8 y 9, nada por debajo", function()
    assert_eq(Alerts.hourNotice(snap(10, 760), "entry").kind, "cap")
    assert_eq(Alerts.hourNotice(snap(10, 760), "entry").freeIn, 760)
    assert_eq(Alerts.hourNotice(snap(9), "entry").kind, "near")
    assert_eq(Alerts.hourNotice(snap(8), "entry").kind, "near")
    assert_eq(Alerts.hourNotice(snap(7), "entry"), nil)
  end)

  it("al unirse a un grupo solo sale el rojo", function()
    assert_eq(Alerts.hourNotice(snap(10), "group").kind, "cap")
    assert_eq(Alerts.hourNotice(snap(9), "group"), nil)
  end)

  it("si el juego rechaza la entrada es 10/10 aunque nuestra lista diga menos", function()
    local n = Alerts.hourNotice(snap(6), "blocked")
    assert_eq(n.kind, "cap")
    assert_eq(n.count, 10)
  end)

  it("sin datos o con disparo desconocido no avisa", function()
    assert_eq(Alerts.hourNotice(nil, "entry"), nil)
    assert_eq(Alerts.hourNotice(snap(10), "tick"), nil)
  end)
end)

describe("InstanceAlerts.toast", function()
  it("récord nuevo: reloj y delta en turquesa", function()
    local t = Alerts.toast(finished(1791, { deaths = 3, xp = 41220, copper = 78012 }), { pb = { total = 1900 } })
    assert_true(t.record)
    assert_eq(t.clock, "29:51")
    assert_eq(t.clockTone, "ahead")
    assert_eq(t.delta.text, MINUS .. "1:49")
    assert_eq(t.sub.name, "Ruins of Lordaeron")
    assert_eq(t.stats[1].value, 3)
    assert_eq(t.stats[1].tone, "behind")
  end)

  it("más lenta que el récord: sin etiqueta, delta en rojo", function()
    local t = Alerts.toast(finished(2000), { pb = { total = 1900 } })
    assert_false(t.record)
    assert_eq(t.clockTone, "text")
    assert_eq(t.delta.tone, "behind")
    assert_eq(t.stats[1].tone, "text")
  end)

  it("sin récord previo no hay delta", function()
    local t = Alerts.toast(finished(600))
    assert_eq(t.delta, nil)
    assert_false(t.record)
  end)

  it("la reputación suma todas las facciones", function()
    local t = Alerts.toast(finished(600, { rep = { Undercity = 725, ["The Forsaken"] = 150 } }))
    assert_eq(t.stats[4].value, 875)
  end)
end)

describe("InstanceAlerts.shareLine", function()
  it("una línea con récord, muertes, XP y oro (menos ASCII, sin texturas)", function()
    local line = Alerts.shareLine(finished(1791, { deaths = 3, xp = 41220, copper = 78012 }), { pb = { total = 1900 } },
      { record = "nuevo récord", deaths1 = "1 muerte", deathsN = "%d muertes", xp = "XP" })
    assert_eq(line, "Ruins of Lordaeron (Normal) 29:51" .. SEP .. "nuevo récord -1:49" .. SEP .. "3 muertes"
      .. SEP .. "+41,220 XP" .. SEP .. "+7g 80s 12c")
  end)

  it("omite lo que vale cero", function()
    assert_eq(Alerts.shareLine(finished(600)), "Ruins of Lordaeron (Normal) 10:00")
  end)

  it("más lenta que el récord lleva el delta con +", function()
    assert_eq(Alerts.shareLine(finished(2000, { deaths = 1 }), { pb = { total = 1900 } }),
      "Ruins of Lordaeron (Normal) 33:20" .. SEP .. "+1:40" .. SEP .. "1 death")
  end)
end)

describe("InstanceAlerts.coins / chunks", function()
  it("monedas en texto", function()
    assert_eq(Alerts.coins(78012), "7g 80s 12c")
    assert_eq(Alerts.coins(120000000), "12,000g")
    assert_eq(Alerts.coins(0), "0c")
  end)

  it("trocea por los separadores sin pasar del máximo", function()
    local text = "aaaa" .. SEP .. "bbbb" .. SEP .. "cccc"
    assert_eq(#Alerts.chunks(text, 255), 1)
    local parts = Alerts.chunks(text, 12)
    assert_eq(parts[1], "aaaa" .. SEP .. "bbbb")
    assert_eq(parts[2], "cccc")
    local hard = Alerts.chunks(string.rep("x", 30), 12)
    assert_eq(#hard, 3)
    assert_eq(hard[3], "xxxxxx")
  end)
end)

describe("InstanceAlerts.dropCopper", function()
  it("con oro quita el cobre; sin oro lo deja", function()
    assert_eq(Alerts.dropCopper(87512), 87500)
    assert_eq(Alerts.dropCopper(9999), 9999)
  end)
end)
