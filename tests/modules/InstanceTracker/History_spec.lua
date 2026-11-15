-- tests/modules/InstanceTracker/History_spec.lua -- PURE History tab model (plan M1 F6).
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/core/Format.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/Run.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/modules/InstanceTracker/core/History.lua", "QuantumDungeonTools", ns)
local History = ns.InstanceHistory

local L = { today = "Hoy", yesterday = "Ayer",
            months = { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic" } }

-- A saved run (Run:toTable shape) started at `at`, `len` seconds long (nil = unfinished).
local function saved(o)
  local at = o.at or 100000
  return { instanceID = o.id or 2999, name = o.name or "Ruins of Lordaeron", difficulty = o.diff or "Normal",
           startedAt = at, finishedAt = o.len and (at + o.len) or nil, endedAt = (not o.len) and (at + 600) or nil,
           pausedTotal = 0, deaths = o.deaths or 0, xp = o.xp or 0, copper = o.copper or 0,
           rep = o.rep, group = o.group, char = o.char, pb = o.pb, newRecord = o.newRecord, bosses = {} }
end

describe("InstanceHistory", function()
  it("guarda 100 runs", function() assert_eq(History.MAX, 100) end)

  it("charName quita el reino", function()
    assert_eq(History.charName("Kael-Stormrage"), "Kael")
    assert_eq(History.charName("Kael"), "Kael")
    assert_eq(History.charName(nil), nil)
  end)

  it("options lista mazmorras, dificultades y personajes sin repetir, ordenados", function()
    local list = { saved({ char = "Kael-R" }), saved({ id = 36, name = "Deadmines", char = "Brenna-R" }),
                   saved({ diff = "Heroic", char = "Kael-R" }), saved({}) }
    local o = History.options(list)
    assert_eq(#o.dungeons, 2)
    assert_eq(o.dungeons[1].label, "Deadmines")
    assert_eq(o.dungeons[1].key, "36")
    assert_eq(#o.difficulties, 2)
    assert_eq(o.difficulties[1], "Heroic")
    assert_eq(#o.chars, 2)
    assert_eq(o.chars[1].label, "Brenna")
    assert_eq(o.chars[2].key, "Kael-R")
  end)

  it("filter combina mazmorra, dificultad y personaje; nil = todas; las runs sin char solo con Todos", function()
    local list = { saved({ char = "Kael-R" }), saved({ id = 36, name = "Deadmines", char = "Kael-R" }),
                   saved({ diff = "Heroic", char = "Brenna-R" }), saved({}) }
    assert_eq(#History.filter(list, {}), 4)
    assert_eq(#History.filter(list, { dungeon = "2999" }), 3)
    assert_eq(#History.filter(list, { dungeon = "2999", difficulty = "Normal" }), 2)
    assert_eq(#History.filter(list, { char = "Kael-R" }), 2)
    assert_eq(#History.filter(list, { dungeon = "2999", char = "Kael-R" }), 1)
    assert_eq(History.filter(list, { char = "Kael-R" })[2].name, "Deadmines")   -- keeps the order
  end)

  it("dateLabel dice Hoy / Ayer / día y mes", function()
    local now = os.time({ year = 2026, month = 11, day = 14, hour = 20, min = 0 })
    local today = os.time({ year = 2026, month = 11, day = 14, hour = 19, min = 42 })
    local yest = os.time({ year = 2026, month = 11, day = 13, hour = 22, min = 10 })
    local old = os.time({ year = 2026, month = 11, day = 10, hour = 20, min = 4 })
    assert_eq(History.dateLabel(today, now, os.date, L), "Hoy 19:42")
    assert_eq(History.dateLabel(yest, now, os.date, L), "Ayer 22:10")
    assert_eq(History.dateLabel(old, now, os.date, L), "10 nov 20:04")
    assert_eq(History.dateLabel(nil, now, os.date, L), History.DASH)
  end)

  it("row: récord, atrasada contra el récord, sin terminar y primera vez", function()
    local rec = History.row(saved({ len = 1791, newRecord = true, pb = { total = 1900 } }))
    assert_eq(rec.kind, "record")
    assert_eq(rec.time, "29:51")
    local behind = History.row(saved({ len = 1900, pb = { total = 1791 } }))
    assert_eq(behind.kind, "behind")
    assert_eq(behind.delta, "+1:49")
    local ahead = History.row(saved({ len = 1780, pb = { total = 1791 } }))
    assert_eq(ahead.kind, "ahead")
    local open = History.row(saved({}))
    assert_eq(open.kind, "unfinished")
    assert_eq(open.time, History.DASH)
    assert_eq(History.row(saved({ len = 2000 })).kind, "first")
  end)

  it("row: XP, reputación sumada, grupo sin reinos y personaje", function()
    local r = History.row(saved({ len = 1800, xp = 41220, rep = { A = 400, B = 70 }, copper = 78000,
                                  group = "Jun,Mira-Other,Tor", char = "Kael-R", deaths = 3 }))
    assert_eq(r.xp, "+41,220")
    assert_eq(r.rep, "+470")
    assert_eq(r.copper, 78000)
    assert_eq(r.group, "Jun, Mira, Tor")
    assert_eq(r.char, "Kael")
    assert_eq(r.deaths, 3)
    local bare = History.row(saved({ len = 1800 }))
    assert_eq(bare.xp, History.DASH)
    assert_eq(bare.rep, History.DASH)
    assert_eq(bare.group, nil)
    assert_eq(bare.char, nil)
  end)

  it("summary: cuenta todas, media y mejor solo de las terminadas", function()
    local s = History.summary({ saved({ len = 1800 }), saved({ len = 2000 }), saved({}) })
    assert_eq(s.count, 3)
    assert_eq(s.mean, 1900)
    assert_eq(s.best, 1800)
    local empty = History.summary({})
    assert_eq(empty.count, 0)
    assert_eq(empty.mean, nil)
  end)

  it("columns reparte el ancho como la rejilla del artboard (9 columnas, fr, gap y padding)", function()
    local cols = History.columns(800, 8, 4)
    assert_eq(#cols, 9)
    assert_eq(cols[1].x, 4)
    local free = 800 - 8 - 8 * 8
    assert_eq(cols[1].w, math.floor(free * 1.1 / 8))
    assert_eq(cols[9].w, math.floor(free * 1.5 / 8))
    -- the last one ends at the right edge minus the padding (±1 px of rounding)
    local right = cols[9].x + cols[9].w
    assert_true(right >= 795 and right <= 796)
    -- nunca anchos negativos
    for _, c in ipairs(History.columns(10, 8, 4)) do assert_eq(c.w, 0) end
  end)

  it("cells pinta récord, atrasada, adelantada, sin terminar y primera con su tono", function()
    local L2 = { record = "récord", unfinished = "sin terminar" }
    local rec = History.cells(History.row(saved({ len = 1791, newRecord = true, char = "Kael-R", xp = 10 })), L2)
    assert_eq(rec.delta.text, "récord")
    assert_eq(rec.delta.tone, "ahead")
    assert_eq(rec.time.tone, "ahead")
    assert_eq(rec.record, true)
    assert_eq(rec.char.tone, "text")
    assert_eq(rec.xp.tone, "xp")
    local behind = History.cells(History.row(saved({ len = 1900, pb = { total = 1791 } })), L2)
    assert_eq(behind.delta.text, "+1:49")
    assert_eq(behind.delta.tone, "behind")
    assert_eq(behind.time.tone, "text")
    assert_eq(behind.char.text, History.DASH)
    assert_eq(behind.char.tone, "pending")
    assert_eq(behind.xp.tone, "pending")
    assert_eq(behind.group.text, History.DASH)
    local ahead = History.cells(History.row(saved({ len = 1700, pb = { total = 1791 } })), L2)
    assert_eq(ahead.delta.tone, "ahead")
    local open = History.cells(History.row(saved({ group = "Ann,Bob" })), L2)
    assert_eq(open.delta.text, "sin terminar")
    assert_eq(open.time.tone, "pending")
    assert_eq(open.group.text, "Ann, Bob")
    assert_eq(open.group.tone, "muted")
    local first = History.cells(History.row(saved({ len = 1800 })), L2)
    assert_eq(first.delta.text, History.DASH)
    assert_eq(first.date.tone, "sand")
  end)

  it("footer: runs, media y récord, sin las partes que no hay", function()
    local L3 = { run1 = "1 run", runs = "%d runs", mean = "media %s", best = "récord %s" }
    assert_eq(History.footer({ count = 12, mean = 1985.4, best = 1791 }, L3),
      "12 runs \194\183 media 33:05 \194\183 récord 29:51")
    assert_eq(History.footer({ count = 1 }, L3), "1 run")
    assert_eq(History.footer({ count = 0 }, L3), "0 runs")
  end)

  it("recordCount cuenta los récords válidos", function()
    assert_eq(History.recordCount({ a = { total = 1 }, b = { total = 2 }, c = {} }), 2)
    assert_eq(History.recordCount(nil), 0)
  end)
end)
