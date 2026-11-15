-- core/News.lua -- PURE: the "What's new" page model (no WoW API).
--
-- The page shows SHORT notes written by hand in core/NewsData.lua, one sentence per change, in
-- Spanish and English (owner, 2026-11-14, Naowh Forever's pattern). CHANGELOG.md stays the full
-- technical record (it goes to CurseForge); it is not read in game. One card per version, newest
-- first and open, the rest folded (canvas artboard "Novedades").
--
-- NewsData shape: { { version = "1.0.0" | nil, date = "2026-11-20" | nil, unreleased = bool,
--   es = { "Título (etiqueta): detalle", ... }, en = { ... } }, ... }
local _, ns = ...

local News = { MAX = 5 }
ns.News = News

-- Client locale -> notes language: Spanish for esES/esMX, English for everything else.
function News.lang(locale)
  return (type(locale) == "string" and locale:match("^es")) and "es" or "en"
end

-- The notes of one version in `lang`, falling back to the other language (never empty when
-- one of the two was written).
function News.lines(v, lang)
  local other = lang == "es" and "en" or "es"
  local l = v[lang]
  if not l or #l == 0 then l = v[other] end
  return l or {}
end

-- "Title (tag): detail" -> title, tag | nil, detail. Only a parenthesis right before the colon
-- is a tag; a line without a colon is all title.
function News.split(line)
  local title, tag, body = line:match("^([^:%(]-)%s*%(([^%(%):]-)%)%s*:%s*(.*)$")
  if title and title ~= "" then return title, tag, body end
  title, body = line:match("^(.-):%s*(.*)$")
  if title and title ~= "" then return title, nil, body end
  return line, nil, ""
end

-- The newest `max` versions (default MAX) and whether older ones were left out.
function News.recent(list, max)
  max = max or News.MAX
  local out = {}
  for i = 1, math.min(#(list or {}), max) do out[i] = list[i] end
  return out, #(list or {}) > max
end

-- Card header: title, tag (NOT RELEASED, gold) or nil, and the muted meta line.
-- L = { dev, unreleased, changes = "%d cambios", one = "1 cambio", months = { "ene"... } }.
function News.header(v, n, L)
  local count = n == 1 and L.one or L.changes:format(n)
  if v.unreleased then return L.dev, L.unreleased, count end
  local y, m, d = (v.date or ""):match("^(%d+)%-(%d+)%-(%d+)$")
  local meta = count
  if y then
    meta = string.format("%d %s %s · %s", tonumber(d), (L.months or {})[tonumber(m)] or m, y, count)
  end
  return "v" .. tostring(v.version), nil, meta
end

-- "|" is the client's escape character: doubled so it prints.
function News.escape(s)
  return (tostring(s or ""):gsub("|", "||"))
end
