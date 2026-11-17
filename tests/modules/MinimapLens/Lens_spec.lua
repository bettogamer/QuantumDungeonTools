-- tests/modules/MinimapLens/Lens_spec.lua -- PURE lens core (plan M2 F2).
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/core/Brand.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/core/Style.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/modules/MinimapLens/core/Lens.lua", "QuantumDungeonTools", ns)
local Lens = ns.MinimapLens

describe("MinimapLens core", function()
  it("clamp respeta límites y paso, y cae al valor por defecto si no es número", function()
    assert_eq(Lens.clamp(9, Lens.SIZE), 3.5)
    assert_eq(Lens.clamp(0, Lens.SIZE), 1.5)
    assert_true(math.abs(Lens.clamp(2.04, Lens.SIZE) - 2.0) < 1e-9)
    assert_eq(Lens.clamp("x", Lens.OPACITY), 1.0)
    assert_eq(Lens.clamp(0 / 0, Lens.SIZE), 2.6)
  end)

  it("applyDefaults rellena sin pisar lo guardado", function()
    local db = { opacity = 0.5 }
    Lens.applyDefaults(db)
    assert_eq(db.size, 2.6)
    assert_eq(db.opacity, 0.5)
    assert_eq(db.pos, nil)
  end)

  it("side: lado mayor por el factor, tope de pantalla y nunca menor que el original", function()
    assert_eq(Lens.side(170, 170, 2.6, 2000), 442)
    assert_eq(Lens.side(175, 180, 2, 2000), 360)
    assert_eq(Lens.side(198, 198, 3.5, 768), 653)   -- 768 * 0.85
    assert_eq(Lens.side(700, 700, 1.5, 768), 700)   -- cap below the original: keep the original
  end)

  it("zoomIn sube un paso con tope en el último nivel", function()
    assert_eq(Lens.zoomIn(0, 6), 1)
    assert_eq(Lens.zoomIn(5, 6), 5)
    assert_eq(Lens.zoomIn(2, nil), 3)
  end)

  it("position: la guardada si está bien formada; si no, la del artboard escalada", function()
    local p = Lens.position({ point = "TOPLEFT", x = 10, y = -20 }, 768)
    assert_eq(p.point, "TOPLEFT")
    assert_eq(p.x, 10)
    local d = Lens.position({ point = "CENTER" }, 768)
    assert_eq(d.point, "CENTER")
    assert_eq(d.x, 85)    -- 80 * 768 / 720
    assert_eq(d.y, -32)
    assert_eq(Lens.position(nil, nil).x, 80)
  end)

  it("plan: máscara solo con Blizzard, iconos salvo con EllesmereUI", function()
    local none, elv, eui, both = Lens.plan("none"), Lens.plan("elvui"), Lens.plan("eui"), Lens.plan("elvui+eui")
    assert_true(none.mask and none.shape and none.icons)
    assert_false(elv.mask)
    assert_true(elv.icons)
    assert_false(eui.icons)
    assert_false(both.icons)
    assert_false(both.mask)
  end)

  it("validSnapshot rechaza secretos sin operarlos, huecos y sin anclaje", function()
    local isSecret = helper.isFakeSecret
    local good = { w = 198, h = 198, scale = 1, alpha = 1, zoom = 0, points = { { "CENTER" } } }
    assert_true(Lens.validSnapshot(good, isSecret))
    local s = { w = helper.newFakeSecret(), h = 198, scale = 1, alpha = 1, zoom = 0, points = { {} } }
    local ok, why = Lens.validSnapshot(s, isSecret)
    assert_false(ok)
    assert_eq(why, "secret w")
    assert_false((Lens.validSnapshot({ w = 1, h = 1, scale = 1, alpha = 1, points = { {} } })))
    assert_false((Lens.validSnapshot({ w = 1, h = 1, scale = 1, alpha = 1, zoom = 0, points = {} })))
  end)

  it("held compara el ancla puesta con la leída", function()
    local want = { point = "CENTER", x = 85, y = -32 }
    assert_true(Lens.held(want, { point = "CENTER", x = 85.2, y = -32 }))
    assert_false(Lens.held(want, { point = "TOPRIGHT", x = 85, y = -32 }))
    assert_false(Lens.held(want, { point = "CENTER", x = -12, y = -32 }))
    assert_false(Lens.held(want, nil))
  end)

  it("el zoom guardado se repone una sola vez", function()
    local db = {}
    assert_eq(Lens.takePendingZoom(db), nil)
    Lens.markApplied(db, 2)
    assert_eq(Lens.takePendingZoom(db), 2)
    assert_eq(Lens.takePendingZoom(db), nil)
    Lens.markApplied(db, 0)
    Lens.markRestored(db)
    assert_eq(Lens.takePendingZoom(db), nil)
  end)

  -- F3: convivencia
  it("plan con un addon desconocido que define su forma: no toca la máscara, sí los iconos", function()
    local p = Lens.plan("other")
    assert_false(p.mask)
    assert_false(p.shape)
    assert_true(p.icons)
  end)

  it("ownerName: nombre de los UI conocidos y nil para el resto", function()
    assert_eq(Lens.ownerName("eui"), "EllesmereUI")
    assert_eq(Lens.ownerName("elvui"), "ElvUI")
    assert_eq(Lens.ownerName("other"), nil)
    assert_eq(Lens.ownerName("none"), nil)
  end)

  it("árbitro: corrige hasta el máximo en la ventana, cede una vez y luego se queda quieto", function()
    local r = Lens.newReferee({ max = 3, window = 10 })
    assert_eq(r:call(0), "reapply")
    assert_eq(r:call(1), "reapply")
    assert_eq(r:call(2), "reapply")
    assert_eq(r:call(3), "yield")
    assert_eq(r:call(4), "idle")
    assert_eq(r:call(100), "idle")
  end)

  it("árbitro: las pisadas viejas salen de la ventana y no cuentan", function()
    local r = Lens.newReferee({ max = 3, window = 10 })
    assert_eq(r:call(0), "reapply")
    assert_eq(r:call(1), "reapply")
    assert_eq(r:call(12), "reapply")   -- 0 y 1 ya caducaron
    assert_eq(r:call(13), "reapply")
    assert_eq(r:call(14), "reapply")
    assert_eq(r:call(15), "yield")      -- 12, 13 y 14 vivas
  end)

  it("árbitro: cede con max correcciones vivas en la ventana", function()
    local r = Lens.newReferee({ max = 2, window = 10 })
    assert_eq(r:call(0), "reapply")
    assert_eq(r:call(11), "reapply")    -- la de 0 caducó
    assert_eq(r:call(12), "reapply")
    assert_eq(r:call(13), "yield")
  end)

  it("drift: marca solo lo que se movió, con tolerancia", function()
    local want = { side = 442, scale = 1, alpha = 1, pos = { point = "CENTER", x = 80, y = -30 } }
    local fine = { w = 442.3, h = 442, scale = 1, alpha = 1, anchor = { point = "CENTER", x = 80.2, y = -30 } }
    assert_eq(Lens.drift(want, fine), nil)
    local f = Lens.drift(want, { w = 198, h = 198, scale = 1, alpha = 1,
      anchor = { point = "TOPRIGHT", x = -10, y = -10 } })
    assert_true(f.size)
    assert_true(f.anchor)
    assert_eq(f.scale, nil)
    assert_eq(f.alpha, nil)
    f = Lens.drift(want, { w = 442, h = 442, scale = 1, alpha = 0.5, anchor = nil })
    assert_true(f.alpha)
    assert_true(f.anchor)   -- varios puntos o relativo a otro marco
  end)

  it("drift: sin alpha (fundido en curso) ni pos (ancla cedida) no los vigila; ilegible no es deriva", function()
    local want = { side = 442, scale = 1 }
    assert_eq(Lens.drift(want, { w = 442, h = 442, scale = 1, alpha = 0.1, anchor = nil }), nil)
    assert_eq(Lens.drift(want, { w = nil, h = 442, scale = "x" }), nil)
    assert_eq(Lens.drift(nil, {}), nil)
  end)
  it("lupa: en el aro si es redondo, en la esquina si es cuadrado; por defecto abajo a la izquierda", function()
    local x, y = Lens.buttonOffset(170, 170, false, "BR")
    assert_eq(x, 80); assert_eq(y, -54)
    x, y = Lens.buttonOffset(170, 170, false)
    assert_eq(x, -80); assert_eq(y, -54)
    x, y = Lens.buttonOffset(442, 442, true, "BR")
    assert_eq(x, 221); assert_eq(y, -221)
    x, y = Lens.buttonOffset(442, 442, true, "TL")
    assert_eq(x, -221); assert_eq(y, 221)
    x, y = Lens.buttonOffset(442, 442, true, "basura")
    assert_eq(x, -221); assert_eq(y, -221)
    x, y = Lens.buttonOffset(nil, 170, true)
    assert_eq(x, 0); assert_eq(y, 0)
  end)

  it("esquina de la lupa: por defecto BL, cuenta como cambiada y se restablece", function()
    local db = {}
    assert_eq(Lens.get(db, "corner"), "BL")
    assert_eq(Lens.changedCount(db), 0)
    db.corner = "TR"
    assert_eq(Lens.get(db, "corner"), "TR")
    assert_true(Lens.isChanged(db, "corner"))
    assert_eq(Lens.changedCount(db), 1)
    Lens.reset(db)
    assert_eq(db.corner, nil)
  end)

  it("salir de la instancia: solo cierra la lente abierta dentro", function()
    assert_true(Lens.leftInstance(true, false))
    assert_eq(Lens.leftInstance(false, false), false)
    assert_eq(Lens.leftInstance(true, true), false)
    assert_eq(Lens.leftInstance(true, nil), false)
  end)

  it("ajustes de la página: valores por defecto, cambiados y restablecer", function()
    local db = {}
    Lens.applyDefaults(db)
    assert_eq(Lens.get(db, "zoomStep"), true)
    assert_eq(Lens.get(db, "hideGathering"), false)
    assert_eq(Lens.get(db, "locked"), false)
    assert_eq(Lens.changedCount(db), 0)
    db.size, db.opacity, db.hideGathering, db.zoomStep = 3.0, 0.85, true, false
    assert_eq(Lens.changedCount(db), 4)
    assert_true(Lens.isChanged(db, "size"))
    assert_eq(Lens.isChanged(db, "locked"), false)
    db.pos, db.enabled = { point = "CENTER", x = 1, y = 2 }, false
    Lens.reset(db)
    assert_eq(Lens.changedCount(db), 0)
    assert_eq(db.pos.x, 1)            -- la posición tiene su propio restablecer
    assert_eq(db.enabled, false)      -- el interruptor del módulo no es un ajuste de la lente
  end)

  it("isOn: el módulo está encendido salvo que se apague a mano", function()
    assert_true(Lens.isOn({}))
    assert_true(Lens.isOn(nil))
    assert_eq(Lens.isOn({ enabled = false }), false)
  end)

  it("percent redondea a entero", function()
    assert_eq(Lens.percent(2.6), 260)
    assert_eq(Lens.percent(0.85), 85)
  end)

  it("gatherToHide: solo hierbas y minerales que estén activos", function()
    local ids = Lens.gatherToHide({
      { spellID = 2580, active = true }, { spellID = 2383, active = false },
      { spellID = 5502, active = true }, { spellID = nil, active = true },
    })
    assert_eq(#ids, 1)
    assert_eq(ids[1], 2580)
    assert_eq(#Lens.gatherToHide(nil), 0)
  end)

  it("rastreo pendiente: se guarda con el zoom y se toma antes que él", function()
    local db = {}
    Lens.markTracking(db, { 2580 })   -- sin marca de zoom no hay dónde guardarlo
    assert_eq(db.saved, nil)
    Lens.markApplied(db, 1)
    Lens.markTracking(db, { 2580 })
    local t = Lens.takePendingTracking(db)
    assert_eq(t[1], 2580)
    assert_eq(Lens.takePendingTracking(db), nil)
    assert_eq(Lens.takePendingZoom(db), 1)
  end)

  it("centerOffset: desplazamiento desde el centro de UIParent", function()
    local p = Lens.centerOffset(1000, 300, 1600, 900)
    assert_eq(p.point, "CENTER"); assert_eq(p.x, 200); assert_eq(p.y, -150)
    assert_eq(Lens.centerOffset(nil, 1, 1, 1), nil)
  end)
end)
