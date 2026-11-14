-- tests/modules/InstanceTracker/View_spec.lua -- PURE view model of the widget (plan M1 F2).
-- The scenarios are the design artboards (core/Demo.lua): each assertion is a number you can
-- read on the canvas.
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
ns.Brand = { COLORS = { primary = "F5BF57", accent = "36C9E8", text = "F7EDDC", danger = "FF6B4F", sea = "0A8FB0" } }
for _, f in ipairs({ "core/Format.lua", "modules/InstanceTracker/core/Run.lua",
  "modules/InstanceTracker/core/DungeonData.lua", "modules/InstanceTracker/core/Dungeons.lua",
  "modules/InstanceTracker/core/Style.lua", "modules/InstanceTracker/core/View.lua",
  "modules/InstanceTracker/core/Demo.lua" }) do
  helper.loadModule("QuantumDungeonTools/" .. f, "QuantumDungeonTools", ns)
end
local View, Demo, Run, Style = ns.InstanceTrackerView, ns.InstanceTrackerDemo, ns.InstanceRun, ns.InstanceTrackerStyle

local function near(a, b) return math.abs(a - b) < 0.005 end

describe("InstanceTrackerView: en curso con récord (Main)", function()
  local v = View.build(Demo.get("live"))

  it("reloj, récord y jefes", function()
    assert_eq(v.clock, "16:22")
    assert_eq(v.ref.kind, "pb")
    assert_eq(v.ref.text, "31:40")
    assert_false(v.ref.struck)
    assert_eq(v.killed, 3)
    assert_eq(v.total, 6)   -- the rare is listed but never counts
    assert_true(v.totalKnown)
    assert_eq(v.deaths, 2)
  end)

  it("vas por delante del último split: reloj y nota en turquesa", function()
    assert_eq(v.clockTone, "ahead")
    assert_eq(v.note.kind, "vsPB")
    assert_eq(v.note.text, "\226\136\1460:17")
    assert_eq(v.note.tone, "ahead")
    assert_eq(v.compactDelta.text, "\226\136\1460:17")
  end)

  it("deltas por jefe con su color", function()
    assert_eq(v.bosses[1].time, "[3:58]")
    assert_eq(v.bosses[1].delta, "\226\136\1460:12")
    assert_eq(v.bosses[1].deltaTone, "ahead")
    assert_eq(v.bosses[2].delta, "+0:20")
    assert_eq(v.bosses[2].deltaTone, "behind")
    assert_eq(v.bosses[2].tone, "progress")
    assert_eq(v.bosses[4].tone, "text")
    assert_eq(v.bosses[4].time, "")
    assert_eq(v.bosses[4].delta, nil)
  end)

  it("orden de la ruta (tabla de mazmorras) y el rare al final, atenuado y sin delta", function()
    local names = {}
    for i, b in ipairs(v.bosses) do names[i] = b.name end
    assert_eq(table.concat(names, ","),
      "Witherfang,The Butcher,Viktor the Vile,The Abandoned,Bjork,Rath'mael,Lordaeron Captain")
    local rare = v.bosses[7]
    assert_true(rare.rare)
    assert_eq(rare.tone, "muted")
    assert_eq(rare.time, "")
    assert_eq(rare.delta, nil)
    assert_eq(v.bosses[1].rare, nil)
  end)

  it("barra de tiempo: relleno 51.7 % y 6 marcas (el split del rare no), las 3 pasadas en oro", function()
    assert_eq(v.bar.mode, "time")
    assert_true(near(v.bar.fill, 982 / 1900))
    assert_eq(#v.bar.ticks, 6)
    assert_eq(v.bar.ticks[3].tone, "progress")
    assert_eq(v.bar.ticks[4].tone, "pending")
    assert_true(near(v.bar.ticks[1].pos, 250 / 1900))
  end)

  it("XP: 41 % antes de la run, 62 % ahora, descanso hasta el 80 %", function()
    assert_eq(v.xp.gained, "18,450")
    assert_eq(v.xp.level, 54)
    assert_eq(v.xp.pct, 62)
    assert_eq(v.xp.restedPct, 18)
    assert_true(near(v.xp.base, 0.41))
    assert_true(near(v.xp.cur, 0.62))
    assert_true(near(v.xp.rested, 0.80))
  end)

  it("las instancias por hora no van en el widget (solo en el tooltip Detalle)", function()
    assert_eq(v.instances, nil)
  end)
end)

describe("InstanceTrackerView: completada (Completada)", function()
  local v = View.build(Demo.get("done"))

  it("nuevo récord: reloj turquesa, récord tachado, jefes en oro", function()
    assert_true(v.finished)
    assert_eq(v.clock, "29:51")
    assert_eq(v.clockTone, "ahead")
    assert_true(v.ref.struck)
    assert_eq(v.note.kind, "newRecord")
    assert_eq(v.note.text, "\226\136\1461:49")
    assert_eq(v.bossesTone, "progress")
  end)

  it("la barra pierde la marca del 100 % y las demás salen cortadas", function()
    assert_eq(#v.bar.ticks, 5)
    assert_eq(v.bar.ticks[1].tone, "cut")
    assert_true(near(v.bar.fill, 1791 / 1900))
  end)

  it("una run que cruzó de nivel tiene toda la barra de XP como ganada", function()
    assert_eq(v.xp.base, 0)
    assert_eq(v.xp.pct, 34)
    assert_eq(v.xp.restedPct, nil)
    assert_eq(v.xp.levels, 1)   -- "· 1 nivel"
  end)

  it("antigüedad del récord en días (pie del panel compacto)", function()
    assert_eq(v.ref.age, 3)
    local run, opts = Demo.get("done")
    opts.now = nil
    assert_eq(View.build(run, opts).ref.age, nil)
  end)

  it("más lenta que el récord: reloj en rojo y delta positivo", function()
    local run, opts = Demo.get("done")
    opts.pb = { total = 1700, splits = {} }
    local slow = View.build(run, opts)
    assert_eq(slow.clockTone, "behind")
    assert_eq(slow.note.kind, "vsPB")
    assert_eq(slow.note.text, "+1:31")
    assert_false(slow.ref.struck)
  end)
end)

describe("InstanceTrackerView: primera vez (PrimeraVez)", function()
  local v = View.build(Demo.get("first"))

  it("sin récord: etiqueta, pista y barra por segmentos", function()
    assert_eq(v.ref.kind, "first")
    assert_eq(v.note.kind, "firstHint")
    assert_eq(v.clockTone, "text")
    assert_eq(v.bar.mode, "segments")
    assert_eq(#v.bar.segs, 6)
    assert_eq(v.bar.segs[3], "progress")
    assert_eq(v.bar.segs[4], "idle")
    assert_eq(v.bosses[1].delta, nil)
  end)

  it("rare muerto: conserva su tiempo en oro pero no cuenta ni tiene segmento", function()
    assert_eq(v.killed, 3)
    local rare = v.bosses[7]
    assert_true(rare.rare)
    assert_eq(rare.time, "[6:10]")
    assert_eq(rare.tone, "progress")
  end)


  it("con un jefe ya muerto al entrar no promete récord y lo pinta apagado", function()
    local run = Run.fromTable({ name = "X", listKnown = true, startedAt = 0, xp = 0,
      bosses = { { name = "A", killed = true, preKilled = true }, { name = "B", killed = false } } },
      { now = function() return 60 end })
    local w = View.build(run, {})
    assert_eq(w.note, nil)
    assert_eq(w.bosses[1].tone, "pre")
    assert_eq(w.bosses[1].time, "--")
    assert_eq(w.bar.segs[1], "pre")
  end)
end)

describe("InstanceTrackerView: bordes", function()
  it("sin run no hay vista", function()
    assert_eq(View.build(nil, {}), nil)
  end)

  it("al nivel máximo no hay barra de XP", function()
    local run, opts = Demo.get("live")
    opts.xp.atMax = true
    assert_eq(View.build(run, opts).xp, nil)
  end)

  it("sin lista de jefes todavía: total desconocido y sin barra", function()
    local run = Run.new({ name = "X" }, { now = function() return 0 end })
    local w = View.build(run, {})
    assert_false(w.totalKnown)
    assert_eq(w.bar, nil)
    assert_eq(w.difficulty, nil)
    assert_eq(w.deaths, nil)
  end)

  it("pasado el tiempo del récord sin terminar: en rojo", function()
    local run = Run.fromTable({ name = "X", listKnown = true, startedAt = 0, xp = 0,
      bosses = { { name = "A", killed = false } } }, { now = function() return 2000 end })
    local w = View.build(run, { pb = { total = 1900, splits = { A = 1900 } } })
    assert_eq(w.clockTone, "behind")
    assert_eq(w.note.text, "+1:40")
    assert_eq(w.bar.fill, 1)
  end)
end)

describe("InstanceTrackerStyle", function()
  it("convierte hex a rgba y da códigos de color por tono", function()
    local c = Style.rgba("F5BF57")
    assert_true(near(c.r, 245 / 255))
    assert_eq(Style.code("progress"), "|cfff5bf57")
    assert_eq(Style.code("ahead"), "|cff36c9e8")
  end)

  it("todos los tonos que usa la vista existen", function()
    for _, tone in ipairs({ "text", "muted", "progress", "ahead", "behind", "pending", "cut", "pre", "idle" }) do
      assert_true(Style.TONE[tone] ~= nil, "missing tone " .. tone)
    end
  end)
end)
