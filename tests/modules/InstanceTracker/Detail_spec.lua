-- tests/modules/InstanceTracker/Detail_spec.lua -- PURE hover detail (plan M1 F4b, artboard Detalle).
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
ns.Brand = { COLORS = { primary = "F5BF57", accent = "36C9E8", text = "F7EDDC", danger = "FF6B4F", sea = "0A8FB0" } }
for _, f in ipairs({ "core/Format.lua", "modules/InstanceTracker/core/Run.lua",
  "modules/InstanceTracker/core/Records.lua",
  "modules/InstanceTracker/core/DungeonData.lua", "modules/InstanceTracker/core/Dungeons.lua",
  "modules/InstanceTracker/core/Style.lua", "modules/InstanceTracker/core/View.lua",
  "modules/InstanceTracker/core/Detail.lua", "modules/InstanceTracker/core/Demo.lua" }) do
  helper.loadModule("QuantumDungeonTools/" .. f, "QuantumDungeonTools", ns)
end
local Detail, Demo, Run = ns.InstanceTrackerDetail, ns.InstanceTrackerDemo, ns.InstanceRun

local function section(sections, id)
  for _, s in ipairs(sections) do
    if s.id == id then return s end
  end
end

local function row(sec, id)
  for _, r in ipairs(sec and sec.rows or {}) do
    if r.id == id then return r end
  end
end

describe("InstanceTrackerDetail: groupKey", function()
  it("ordena los nombres y descarta vacíos", function()
    assert_eq(Detail.groupKey({ "Bob", "Ann", "" }), "Ann,Bob")
  end)
  it("solo = sin firma", function()
    assert_eq(Detail.groupKey({}), nil)
    assert_eq(Detail.groupKey(nil), nil)
  end)
end)

describe("InstanceTrackerDetail: artboard Detalle (demo live)", function()
  local run, opts = Demo.get("live")
  local s = Detail.build(run, opts)

  it("secciones en el orden del diseño", function()
    assert_eq(#s, 4)
    assert_eq(s[1].id, "pace")
    assert_eq(s[2].id, "rep")
    assert_eq(s[3].id, "records")
    assert_eq(s[4].id, "instances")
  end)

  it("ritmo: XP/h y oro/h sobre el tiempo de la run", function()
    local pace = section(s, "pace")
    -- 18450 XP in 16:22 (982 s) -> 67,637/h; 41200 copper -> 151,039/h
    assert_eq(row(pace, "xpHour").text, "67,637")
    assert_eq(row(pace, "xpHour").tone, "xp")
    assert_eq(row(pace, "goldHour").copper, 151039)
  end)

  it("runs para subir: media de las runs terminadas de esta mazmorra", function()
    local r = row(section(s, "pace"), "toLevel")
    assert_eq(r.level, 55)
    assert_eq(r.runs, 1)   -- 33440 XP left, 39800 per run
  end)

  it("reputación por facción", function()
    local r = row(section(s, "rep"), "faction")
    assert_eq(r.name, "Undercity")
    assert_eq(r.amount, 350)
  end)

  it("récords: personal y con este grupo (solo cuenta su firma)", function()
    local rec = section(s, "records")
    assert_eq(row(rec, "personal").text, "31:40")
    local g = row(rec, "group")
    assert_eq(g.text, "28:05")
    assert_eq(g.runs, 2)
    assert_eq(g.tone, "ahead")
  end)

  it("instancias: los dos próximos huecos", function()
    local inst = section(s, "instances")
    assert_eq(inst.count, 8)
    assert_eq(inst.limit, 10)
    assert_eq(row(inst, "nextSlot").text, "12:40")
    assert_eq(row(inst, "thenSlot").text, "21:15")
  end)
end)

describe("InstanceTrackerDetail: lo que falta se oculta", function()
  it("sin run: nada", function()
    assert_eq(#Detail.build(nil), 0)
  end)

  it("run recién empezada, sin grupo ni historial: nada", function()
    local t = 1000
    local run = Run.new({ instanceID = 1, name = "X", difficulty = "Normal" }, { now = function() return t end })
    t = 1030
    run:addXP(500)
    assert_eq(#Detail.build(run, { xp = { level = 20, xp = 100, max = 9000 } }), 0)
  end)

  it("nivel máximo: sin XP/h ni runs para subir", function()
    local run, opts = Demo.get("live")
    opts.xp.atMax = true
    local pace = section(Detail.build(run, opts), "pace")
    assert_eq(row(pace, "xpHour"), nil)
    assert_eq(row(pace, "toLevel"), nil)
    assert_true(row(pace, "goldHour") ~= nil)
  end)

  it("otro grupo: sin fila de grupo", function()
    local run, opts = Demo.get("live")
    opts.group = "Nobody"
    assert_eq(row(section(Detail.build(run, opts), "records"), "group"), nil)
  end)

  it("sin historial, la run terminada sirve para las runs que faltan", function()
    local run, opts = Demo.get("done")
    local r = row(section(Detail.build(run, opts), "pace"), "toLevel")
    assert_eq(r.level, 56)
    assert_eq(r.runs, 2)   -- 58080 left, 41220 per run
  end)
end)
