-- tests/core/Style_spec.lua -- PURE addon-level tokens (plan M1 F6c): the main window must not
-- depend on a module's Style, and a module Style inherits the addon one and only adds its own.
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
for _, f in ipairs({ "core/Brand.lua", "core/Style.lua", "modules/InstanceTracker/core/Style.lua" }) do
  helper.loadModule("QuantumDungeonTools/" .. f, "QuantumDungeonTools", ns)
end
local Base, IT = ns.Style, ns.InstanceTrackerStyle

describe("Style (nivel addon)", function()
  it("trae los roles de la paleta y los tokens de la ventana", function()
    for _, k in ipairs({ "gold", "turquoise", "cream", "red", "muted", "panel", "tickIdle",
      "hairline", "shadow", "goldCard", "goldWash", "hairlineSoft", "mutedTag", "sidebar", "sidebarActive" }) do
      assert_true(Base.C[k] ~= nil, "missing color " .. k)
    end
    assert_true(Base.FONT.winTitle ~= nil)
    assert_eq(Base.WIN.sidebar, math.floor(220 * Base.GEO + 0.5))
    assert_eq(Base.SIZE.tagPadX, math.floor(6 * Base.GEO + 0.5))
  end)

  it("no lleva nada propio del widget del Instance Tracker", function()
    assert_eq(rawget(Base.C, "goldSoft"), nil)
    assert_eq(rawget(Base.FONT, "clock"), nil)
    assert_eq(rawget(Base.SIZE, "barH"), nil)
  end)
end)

describe("Style.extend (Style de un módulo)", function()
  it("hereda funciones, tonos, colores, fuentes y medidas del addon", function()
    assert_eq(IT.code("progress"), Base.code("progress"))
    assert_true(IT.C.gold == Base.C.gold)
    assert_true(IT.FONT.winTitle == Base.FONT.winTitle)
    assert_eq(IT.SIZE.tagPadX, Base.SIZE.tagPadX)
    assert_true(IT.WIN == Base.WIN)
  end)

  it("añade lo suyo escalado sin tocar el del addon", function()
    assert_true(IT.C.goldSoft ~= nil)
    assert_eq(IT.SIZE.barH, math.floor(14 * Base.GEO + 0.5))
    assert_eq(IT.FONT.clock.size, 42)
    assert_eq(rawget(Base.SIZE, "width"), nil)
  end)
end)
