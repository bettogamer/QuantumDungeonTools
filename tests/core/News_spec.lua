-- tests/core/News_spec.lua -- PURE "What's new" model: hand-written notes, split and header.
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/core/News.lua", "QuantumDungeonTools", ns)
helper.loadModule("QuantumDungeonTools/core/NewsData.lua", "QuantumDungeonTools", ns)
local News = ns.News

describe("News.split", function()
  it("Título: detalle", function()
    local t, tag, b = News.split("Pausa: el reloj se para.")
    assert_eq(t, "Pausa")
    assert_eq(tag, nil)
    assert_eq(b, "el reloj se para.")
  end)

  it("Título (etiqueta): detalle", function()
    local t, tag, b = News.split("Ventana principal (/qdt): Inicio y ajustes.")
    assert_eq(t, "Ventana principal")
    assert_eq(tag, "/qdt")
    assert_eq(b, "Inicio y ajustes.")
  end)

  it("un paréntesis que no va pegado a los dos puntos es parte del detalle", function()
    local t, tag, b = News.split("Avisos: al llegar (10/10): espera.")
    assert_eq(t, "Avisos")
    assert_eq(tag, nil)
    assert_eq(b, "al llegar (10/10): espera.")
  end)

  it("sin dos puntos: todo es título", function()
    local t, tag, b = News.split("Solo título")
    assert_eq(t, "Solo título")
    assert_eq(tag, nil)
    assert_eq(b, "")
  end)
end)

describe("News.lang / lines", function()
  it("español para esES y esMX, inglés para el resto", function()
    assert_eq(News.lang("esES"), "es")
    assert_eq(News.lang("esMX"), "es")
    assert_eq(News.lang("enUS"), "en")
    assert_eq(News.lang("deDE"), "en")
    assert_eq(News.lang(nil), "en")
  end)

  it("si falta un idioma sale el otro", function()
    assert_eq(News.lines({ es = { "a" } }, "en")[1], "a")
    assert_eq(News.lines({ en = { "b" }, es = {} }, "es")[1], "b")
    assert_eq(#News.lines({}, "es"), 0)
  end)
end)

describe("News.header", function()
  local L = { dev = "En desarrollo", unreleased = "SIN PUBLICAR", changes = "%d cambios", one = "1 cambio",
    months = { [11] = "nov" } }

  it("sin publicar: En desarrollo + etiqueta + cuenta", function()
    local t, tag, meta = News.header({ unreleased = true }, 10, L)
    assert_eq(t, "En desarrollo")
    assert_eq(tag, "SIN PUBLICAR")
    assert_eq(meta, "10 cambios")
  end)

  it("publicada: vN, sin etiqueta, fecha · cuenta", function()
    local t, tag, meta = News.header({ version = "1.0.0", date = "2026-11-03" }, 1, L)
    assert_eq(t, "v1.0.0")
    assert_eq(tag, nil)
    assert_eq(meta, "3 nov 2026 · 1 cambio")
    assert_eq(select(3, News.header({ version = "1.0.0" }, 2, L)), "2 cambios")
  end)
end)

describe("News helpers", function()
  it("recent corta a MAX y avisa si quedan más", function()
    local r, more = News.recent({ 1, 2, 3, 4, 5, 6, 7 })
    assert_eq(#r, 5)
    assert_true(more)
    r, more = News.recent({ 1, 2 })
    assert_eq(#r, 2)
    assert_false(more)
    assert_eq(#News.recent(nil), 0)
  end)

  it("escape duplica la barra vertical del cliente", function()
    assert_eq(News.escape("a | b"), "a || b")
  end)
end)

describe("NewsData (escrito a mano)", function()
  it("cada versión trae las mismas notas en los dos idiomas", function()
    assert_true(#ns.NewsData >= 1)
    for _, v in ipairs(ns.NewsData) do
      assert_true(v.unreleased or v.version, "una versión sin número ni unreleased")
      assert_eq(#(v.es or {}), #(v.en or {}), "es y en con distinto número de notas")
    end
  end)

  it("todas las notas tienen título y detalle", function()
    for _, v in ipairs(ns.NewsData) do
      for _, lang in ipairs({ "es", "en" }) do
        for _, line in ipairs(v[lang] or {}) do
          local t, _, b = News.split(line)
          assert_true(t ~= "" and b ~= "", "nota sin «Título: detalle»: " .. line)
        end
      end
    end
  end)
end)
