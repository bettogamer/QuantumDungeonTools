-- tests/modules/InstanceTracker/ChatParse_spec.lua -- PURE chat parsing of money and reputation (F4).
-- The globals are the enUS strings of the client (F1 confirmed they exist in WoW Forever).
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/ChatParse.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Run.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/core/Format.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/View.lua", "QuantumDungeonTools", ns)
local ChatParse, Run, View = ns.InstanceChatParse, ns.InstanceRun, ns.InstanceTrackerView

local G = {
  YOU_LOOT_MONEY = "You loot %s",
  YOU_LOOT_MONEY_GUILD = "You loot %s (%s deposited to guild bank)",
  LOOT_MONEY_SPLIT = "Your share of the loot is %s.",
  LOOT_MONEY_SPLIT_GUILD = "Your share of the loot is %s. (%s deposited to guild bank)",
  GOLD_AMOUNT = "%d Gold", SILVER_AMOUNT = "%d Silver", COPPER_AMOUNT = "%d Copper",
  GOLD_AMOUNT_TEXTURE = "%d|TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d:2:0|t",
  SILVER_AMOUNT_TEXTURE = "%d|TInterface\\MoneyFrame\\UI-SilverIcon:%d:%d:2:0|t",
  COPPER_AMOUNT_TEXTURE = "%d|TInterface\\MoneyFrame\\UI-CopperIcon:%d:%d:2:0|t",
  FACTION_STANDING_INCREASED = "Reputation with %s increased by %d.",
  FACTION_STANDING_INCREASED_BONUS = "Reputation with %s increased by %d. (+%.1f bonus)",
  FACTION_STANDING_INCREASED_ACCOUNT_WIDE = "Your Warband's reputation with %s increased by %d.",
  FACTION_STANDING_DECREASED = "Reputation with %s decreased by %d.",
  FACTION_STANDING_INCREASED_GENERIC = "Reputation with %s increased.",
}

describe("InstanceChatParse: dinero", function()
  it("lee el oro looteado en texto", function()
    assert_eq(ChatParse.money("You loot 4 Gold, 12 Silver, 3 Copper", G), 41203)
    assert_eq(ChatParse.money("You loot 15 Copper", G), 15)
  end)

  it("lee la parte del reparto en grupo", function()
    assert_eq(ChatParse.money("Your share of the loot is 1 Silver, 20 Copper.", G), 120)
  end)

  it("con banco de hermandad solo cuenta lo que recibe el jugador", function()
    assert_eq(ChatParse.money("You loot 2 Silver (5 Copper deposited to guild bank)", G), 200)
  end)

  it("lee la variante con iconos", function()
    local s = "You loot 3|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t "
      .. "7|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
    assert_eq(ChatParse.money(s, G), 307)
  end)

  it("ignora el botín de otros y las líneas sin monedas", function()
    assert_eq(ChatParse.money("Thrall loots 4 Gold.", G), nil)
    assert_eq(ChatParse.money("You loot nothing", G), nil)
  end)
end)

describe("InstanceChatParse: reputación", function()
  it("lee facción y cantidad, también con bonus y a nivel de cuenta", function()
    local f, n = ChatParse.rep("Reputation with Undercity increased by 25.", G)
    assert_eq(f, "Undercity")
    assert_eq(n, 25)
    f, n = ChatParse.rep("Reputation with The Forsaken increased by 30. (+5.0 bonus)", G)
    assert_eq(f, "The Forsaken")
    assert_eq(n, 30)
    f, n = ChatParse.rep("Your Warband's reputation with Darnassus increased by 1,250.", G)
    assert_eq(f, "Darnassus")
    assert_eq(n, 1250)
  end)

  it("una bajada es negativa y la línea sin cantidad se ignora", function()
    local f, n = ChatParse.rep("Reputation with Booty Bay decreased by 10.", G)
    assert_eq(f, "Booty Bay")
    assert_eq(n, -10)
    assert_eq(ChatParse.rep("Reputation with Undercity increased.", G), nil)
  end)

  it("respeta los argumentos posicionales de otros idiomas", function()
    local L = { FACTION_STANDING_INCREASED = "Ruf %2$d bei %1$s erhöht." }
    local f, n = ChatParse.rep("Ruf 40 bei Unterstadt erhöht.", L)
    assert_eq(f, "Unterstadt")
    assert_eq(n, 40)
  end)
end)

describe("InstanceRun + View: oro y reputación de la run", function()
  local function clock()
    local c = { t = 1000 }
    c.now = function() return c.t end
    return c
  end

  it("suma con la run viva, también tras el último jefe, y no en pausa", function()
    local r = Run.new({ name = "X", difficulty = "Normal" }, { now = clock().now })
    assert_true(r:addMoney(500))
    assert_true(r:addRep("Undercity", 25))
    assert_true(r:addRep("Undercity", 25))
    r:pause()
    assert_false(r:addMoney(100))
    r:resume()
    r.finishedAt = 2000   -- the last boss's loot arrives after the run ends
    assert_true(r:addMoney(100))
    r:close()
    assert_false(r:addRep("Undercity", 5))
    assert_eq(r.copper, 600)
    assert_eq(r.rep.Undercity, 50)
    assert_false(r:addMoney(nil))
  end)

  it("sobrevive a guardar y cargar", function()
    local r = Run.new({ name = "X" }, { now = clock().now })
    r:addMoney(41200)
    r:addRep("Undercity", 350)
    local back = Run.fromTable(r:toTable(), { now = clock().now })
    assert_eq(back.copper, 41200)
    assert_eq(back.rep.Undercity, 350)
  end)

  it("la vista da el oro y la facción que más subió", function()
    local r = Run.new({ name = "X" }, { now = clock().now })
    r:addMoney(41200)
    r:addRep("The Forsaken", 150)
    r:addRep("Undercity", 350)
    local v = View.build(r)
    assert_eq(v.copper, 41200)
    assert_eq(v.rep.name, "Undercity")
    assert_eq(#v.repAll, 2)
    local empty = View.build(Run.new({ name = "Y" }, { now = clock().now }))
    assert_eq(empty.copper, nil)
    assert_eq(empty.rep, nil)
  end)
end)
