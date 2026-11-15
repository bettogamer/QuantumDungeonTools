-- tests/core/News_spec.lua -- PURE "What's new" model: CHANGELOG parsing and page helpers.
local helper = dofile("tests/helper.lua")

local ns = helper.newNS()
helper.loadModule("QuantumDungeonTools/core/News.lua", "QuantumDungeonTools", ns)
local News = ns.News

local MD = table.concat({
  "# Changelog",
  "",
  "Formato: Keep a Changelog.",
  "",
  "## [Unreleased]",
  "",
  "### Añadido",
  "",
  "- **Icono del minimapa** (hito M1 F6e): clic abre la ventana; se arrastra",
  "  por el borde y `/qdt minimap` lo muestra.",
  "- **Instance Tracker distingue la COPIA** por el zoneUID: si sales, run nueva.",
  "- `/qdt it demo <live | done>`: enseña cada estado.",
  "",
  "- **Sin cuerpo**",
  "",
  "### Cambiado",
  "",
  "- **Barras con BettoBar** (Craft v2.50.0, re-vendoreada): el relleno usa la textura.",
  "",
  "### Arreglado",
  "",
  "## [0.2.0] - 2026-11-03",
  "",
  "### Arreglado",
  "",
  "- Un **fallo** con [el reloj](https://x.y) al recargar.",
}, "\n")

describe("News.parse", function()
  local list = News.parse(MD)

  it("una entrada por versión, en el orden del archivo", function()
    assert_eq(#list, 2)
    assert_true(list[1].unreleased)
    assert_eq(list[1].version, nil)
    assert_eq(list[2].version, "0.2.0")
    assert_eq(list[2].date, "2026-11-03")
  end)

  it("descarta los apartados vacíos (Arreglado de Unreleased)", function()
    assert_eq(#list[1].sections, 2)
    assert_eq(list[1].sections[1].name, "Añadido")
    assert_eq(list[1].sections[2].name, "Cambiado")
  end)

  it("une las líneas de continuación y separa viñetas por línea en blanco", function()
    local items = list[1].sections[1].items
    assert_eq(#items, 4)
    assert_eq(items[1].body, "Clic abre la ventana; se arrastra por el borde y /qdt minimap lo muestra.")
  end)

  it("título en negrita + «: » → punto y mayúscula; la nota (hito …) se quita", function()
    local it1 = list[1].sections[1].items[1]
    assert_eq(it1.title, "Icono del minimapa")
    assert_eq(it1.sep, ". ")
  end)

  it("el paréntesis antes de los dos puntos también se quita (versión de lib)", function()
    local it1 = list[1].sections[2].items[1]
    assert_eq(it1.title, "Barras con BettoBar")
    assert_eq(it1.body, "El relleno usa la textura.")
  end)

  it("título que sigue la frase: separador espacio, sin mayúscula", function()
    local it2 = list[1].sections[1].items[2]
    assert_eq(it2.title, "Instance Tracker distingue la COPIA")
    assert_eq(it2.sep, " ")
    assert_eq(it2.body, "por el zoneUID: si sales, run nueva.")
  end)

  it("viñeta sin título: todo es cuerpo, sin markdown", function()
    local it3 = list[1].sections[1].items[3]
    assert_eq(it3.title, nil)
    assert_eq(it3.body, "/qdt it demo <live | done>: enseña cada estado.")
    assert_eq(list[2].sections[1].items[1].body, "Un fallo con el reloj al recargar.")
  end)

  it("título solo: cuerpo vacío y sin separador", function()
    local it4 = list[1].sections[1].items[4]
    assert_eq(it4.title, "Sin cuerpo")
    assert_eq(it4.body, "")
    assert_eq(it4.sep, "")
  end)

  it("el CHANGELOG real se parsea y empieza por Unreleased", function()
    local fh = assert(io.open("CHANGELOG.md", "rb"))
    local real = News.parse(fh:read("*a"))
    fh:close()
    assert_true(#real >= 1)
    assert_true(#real[1].sections >= 1)
  end)
end)

describe("News helpers", function()
  it("recent corta a MAX y avisa si quedan más", function()
    local l = { 1, 2, 3, 4, 5, 6, 7 }
    local r, more = News.recent(l)
    assert_eq(#r, 5)
    assert_true(more)
    r, more = News.recent({ 1, 2 })
    assert_eq(#r, 2)
    assert_false(more)
    assert_eq(#News.recent(nil), 0)
  end)

  it("heading pasa a mayúsculas con tildes y eñe", function()
    assert_eq(News.heading("Añadido"), "AÑADIDO")
    assert_eq(News.heading("Corrección"), "CORRECCIÓN")
  end)

  it("Añadido lleva el punto oro; el resto el apagado", function()
    assert_eq(News.dotTone("Añadido"), "gold")
    assert_eq(News.dotTone("Cambiado"), "muted")
  end)

  it("cabecera: En desarrollo + SIN PUBLICAR en oro; publicada: vN + fecha", function()
    local L = { dev = "En desarrollo", unreleased = "SIN PUBLICAR", months = { [11] = "nov" } }
    local t, tag, tone = News.header({ unreleased = true }, L)
    assert_eq(t, "En desarrollo")
    assert_eq(tag, "SIN PUBLICAR")
    assert_eq(tone, "gold")
    t, tag, tone = News.header({ version = "1.0.0", date = "2026-11-03" }, L)
    assert_eq(t, "v1.0.0")
    assert_eq(tag, "3 nov 2026")
    assert_eq(tone, "muted")
    tag = select(2, News.header({ version = "1.0.0" }, L))
    assert_eq(tag, nil)
  end)

  it("line arma título.cuerpo y escapa la barra vertical del cliente", function()
    assert_eq(News.line({ title = "A", sep = ". ", body = "b | c" }, "<", ">"), "<A.> b || c")
    assert_eq(News.line({ title = "A", sep = " ", body = "por x" }, "<", ">"), "<A> por x")
    assert_eq(News.line({ title = "A", sep = "", body = "" }, "<", ">"), "<A>")
    assert_eq(News.line({ sep = "", body = "x" }, "<", ">"), "x")
  end)
end)
