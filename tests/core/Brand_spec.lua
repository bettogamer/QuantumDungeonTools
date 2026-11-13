-- tests/core/Brand_spec.lua -- PURE brand helpers, no WoW mock.
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/core/Brand.lua", "QuantumDungeonTools", ns)
local Brand = ns.Brand

describe("Brand", function()
  it("el nombre visible lleva espacios", function()
    assert_eq(Brand.TITLE, "Quantum Dungeon Tools")
  end)

  it("pinta con el color primario (oro de Forever)", function()
    assert_eq(Brand.paint("primary", "QDT"), "|cffF5BF57QDT|r")
  end)

  it("acepta un hex directo si no es un nombre de la paleta", function()
    assert_eq(Brand.paint("FFFFFF", "x"), "|cffFFFFFFx|r")
  end)

  it("el título del chat: Quantum en mar, Dungeon Tools en oro", function()
    assert_eq(Brand.title(), "|cff0A8FB0Quantum|r |cffF5BF57Dungeon Tools|r")
  end)

  it("el prefijo del chat es QDT en oro", function()
    assert_eq(Brand.prefix(), "|cffF5BF57QDT|r: ")
  end)
end)
