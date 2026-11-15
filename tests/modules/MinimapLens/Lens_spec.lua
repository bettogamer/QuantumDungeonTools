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
end)
