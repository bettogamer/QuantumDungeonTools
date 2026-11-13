-- tests/modules/InstanceTracker/Dungeons_spec.lua -- PURE lookups over the generated data.
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/DungeonData.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Dungeons.lua", "QuantumDungeonTools", ns)
local Dungeons = ns.InstanceDungeons

describe("InstanceDungeons (datos generados)", function()
  it("Ruins of Lordaeron sigue el orden de la ruta medido en la run del owner", function()
    local expected = { [3353] = 1, [3355] = 2, [3411] = 3, [3357] = 4, [3412] = 5, [3354] = 6 }
    for id, order in pairs(expected) do
      local info = Dungeons.forEncounter(id)
      assert_eq(info.dungeon, "RuinsOfLordaeron")
      assert_eq(info.order, order)
      assert_eq(info.rare, false)
    end
  end)

  it("marca a Lordaeron Captain como rare", function()
    assert_eq(Dungeons.forEncounter(3408).rare, true)
    assert_eq(Dungeons.find(2999, "Lordaeron Captain").rare, true)
  end)

  it("encuentra por el nombre medido en el juego (The Butcher, no The Baron)", function()
    assert_eq(Dungeons.find(2999, "The Butcher").order, 2)
    assert_eq(Dungeons.find(2999, "The Baron").order, 2)
  end)

  it("un nombre aprendido de ENCOUNTER_END gana (otros idiomas)", function()
    local info = Dungeons.find(2999, "El Carnicero", { ["El Carnicero"] = 3355 })
    assert_eq(info.order, 2)
  end)

  it("devuelve nil para nombres o instancias desconocidas", function()
    assert_eq(Dungeons.find(2999, "Nadie"), nil)
    assert_eq(Dungeons.find(1, "Witherfang"), nil)
    assert_eq(Dungeons.find(2999, nil), nil)
    assert_eq(Dungeons.forEncounter("3353"), nil)
  end)

  it("un jefe con dos encounterIDs (variantes) resuelve igual por ambos", function()
    assert_eq(Dungeons.forEncounter(2916), Dungeons.forEncounter(2761))
  end)
end)
