-- core/News.lua -- PURE: the "What's new" page model (no WoW API).
--
-- The page is generated from CHANGELOG.md (owner, 2026-11-14): scripts/gen-news.lua runs
-- News.parse over it and writes core/NewsData.lua, so the text lives in ONE place. Spanish
-- only, like the CHANGELOG (owner OK). The page shows the newest MAX versions; [Unreleased]
-- comes first as "In development · NOT RELEASED" (canvas artboard "Novedades").
--
-- Parsed shape: { { version = "1.0.0" | nil, date = "2026-11-20" | nil, unreleased = bool,
--   sections = { { name = "Añadido", items = { { title = "Icono del minimapa" | nil,
--   body = "…", sep = ". " | " " | "" } } } } } }
local _, ns = ...

local News = { MAX = 5 }
ns.News = News

-- Inline markdown -> plain text: `code`, **bold**, *em*, [text](url).
local function plain(s)
  s = s:gsub("%[([^%]]-)%]%([^%)]-%)", "%1")
  s = s:gsub("%*%*(.-)%*%*", "%1")
  s = s:gsub("`([^`]-)`", "%1")
  s = s:gsub("%f[%*]%*([^%*]-)%*", "%1")
  return s
end

-- First ASCII letter to upper case (accented first letters stay: there is no utf8 lib in WoW).
local function capital(s)
  return (s:gsub("^%l", string.upper))
end

-- "- **Title** (hito M1 F6e): rest" -> title, body, sep. A parenthesis right before the colon is
-- an internal note (milestone, vendored lib version): dropped, as on the artboard.
function News.item(raw)
  local text = raw:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  local title, rest = text:match("^%*%*(.-)%*%*(.*)$")
  if not title then return { body = plain(text), sep = "" } end
  rest = rest:gsub("^%s*%b()%s*:", ":")
  local sep
  if rest:match("^%s*:") then
    rest, sep = capital((rest:gsub("^%s*:%s*", ""))), ". "
  elseif rest:match("^[,;%.]") then
    sep = ""
  else
    rest, sep = rest:gsub("^%s+", ""), " "
  end
  if rest == "" then sep = "" end
  return { title = plain(title), body = plain(rest), sep = sep }
end

-- CHANGELOG.md text -> list of versions, newest first (file order).
function News.parse(md)
  local out, ver, sec, item = {}, nil, nil, nil
  local function flush()
    if item and sec then sec.items[#sec.items + 1] = News.item(item) end
    item = nil
  end
  for line in (md .. "\n"):gmatch("(.-)\r?\n") do
    local head = line:match("^##%s+%[(.-)%]")
    if head and not line:match("^###") then
      flush()
      local unreleased = head:lower() == "unreleased"
      ver = { version = not unreleased and head or nil, unreleased = unreleased,
        date = line:match("(%d%d%d%d%-%d%d%-%d%d)"), sections = {} }
      out[#out + 1], sec = ver, nil
    elseif ver and line:match("^###%s+") then
      flush()
      sec = { name = line:match("^###%s+(.-)%s*$"), items = {} }
      ver.sections[#ver.sections + 1] = sec
    elseif sec and line:match("^%-%s+") then
      flush()
      item = line:gsub("^%-%s+", "")
    elseif item and line:match("^%s+%S") then
      item = item .. " " .. line
    elseif line:match("^%s*$") then
      flush()
    end
  end
  flush()
  -- Drop empty sections and versions (an [Unreleased] with only headings shows nothing).
  local kept = {}
  for _, v in ipairs(out) do
    local secs = {}
    for _, s in ipairs(v.sections) do
      if #s.items > 0 then secs[#secs + 1] = s end
    end
    v.sections = secs
    if #secs > 0 then kept[#kept + 1] = v end
  end
  return kept
end

-- The newest `max` versions (default MAX) and whether older ones were left out.
function News.recent(list, max)
  max = max or News.MAX
  local out = {}
  for i = 1, math.min(#(list or {}), max) do out[i] = list[i] end
  return out, #(list or {}) > max
end

-- Section heading as the artboard paints it: upper case, Spanish accents included.
local UPPER = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
function News.heading(name)
  local s = name:upper()
  for lo, up in pairs(UPPER) do s = s:gsub(lo, up) end
  return s
end

-- "Añadido" carries the gold dot; every other section the muted one (artboard).
function News.dotTone(name)
  return name == "Añadido" and "gold" or "muted"
end

-- One item as the page prints it: the title (with its period) wrapped in open/close (the cream
-- color escape) and the body after it. "|" is the client's escape character: doubled.
function News.line(item, open, close)
  local function esc(s) return (s:gsub("|", "||")) end
  local body = esc(item.body or "")
  if not item.title then return body end
  local head, tail = (item.sep or ""):match("^(%S*)(%s*)$")
  return open .. esc(item.title) .. head .. close .. (body ~= "" and tail .. body or "")
end

-- Version header: title + tag. L = { dev, unreleased, months = { "ene"... } }.
function News.header(v, L)
  if v.unreleased then return L.dev, L.unreleased, "gold" end
  local tag
  local y, m, d = (v.date or ""):match("^(%d+)%-(%d+)%-(%d+)$")
  if y then
    local month = (L.months or {})[tonumber(m)] or m
    tag = string.format("%d %s %s", tonumber(d), month, y)
  end
  return "v" .. v.version, tag, "muted"
end
