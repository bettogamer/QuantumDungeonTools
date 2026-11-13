-- modules/InstanceTracker/core/ChatParse.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- Reads the player's own loot-money and reputation chat lines (plan M1 F4). The patterns are
-- built from the client's localized format strings (YOU_LOOT_MONEY, GOLD_AMOUNT,
-- FACTION_STANDING_INCREASED...), passed in as a table, so the module works in any locale
-- and is tested headless. Strings that do not exist in a client are simply skipped.
local _, ns = ...

local ChatParse = {}
ns.InstanceChatParse = ChatParse

-- Format string -> Lua pattern + what each capture is ({ pos, kind = "s"|"d"|"f" }).
-- Handles %s %d %i %.1f, positional %1$s, flags/width, and a literal %%.
local cache = {}
function ChatParse.compile(fmt, anchored)
  local ck = fmt .. (anchored and "\1" or "\0")
  if cache[ck] then return cache[ck].pat, cache[ck].caps end
  local out, caps, auto, i = {}, {}, 0, 1
  while i <= #fmt do
    local c = fmt:sub(i, i)
    if c == "%" then
      if fmt:sub(i + 1, i + 1) == "%" then
        out[#out + 1] = "%%"
        i = i + 2
      else
        local s, e, posn, conv = fmt:find("^%%(%d*%$?)[%-%+ #0]*%d*%.?%d*([sdif])", i)
        if not s then
          out[#out + 1] = "%%"
          i = i + 1
        else
          local pos = tonumber(posn:match("^(%d+)%$"))
          if not pos then auto = auto + 1; pos = auto end
          local kind = (conv == "i") and "d" or conv
          caps[#caps + 1] = { pos = pos, kind = kind }
          out[#out + 1] = kind == "s" and "(.-)" or kind == "d" and "([%d,%.]+)" or "([%d%.,]+)"
          i = e + 1
        end
      end
    else
      out[#out + 1] = c:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
      i = i + 1
    end
  end
  local pat = table.concat(out)
  if anchored then pat = "^" .. pat .. "$" end
  cache[ck] = { pat = pat, caps = caps }
  return pat, caps
end

-- Matches text against a format; returns the captures as { [pos] = { kind, value } } or nil.
function ChatParse.match(fmt, text, anchored)
  if type(fmt) ~= "string" or type(text) ~= "string" then return nil end
  local pat, caps = ChatParse.compile(fmt, anchored)
  local got = { text:match(pat) }
  if #got == 0 or #got < #caps then return nil end
  local args = {}
  for k, cap in ipairs(caps) do args[cap.pos] = { kind = cap.kind, value = got[k] } end
  return args
end

-- "1,234" / "1.234" -> 1234 (amounts are integers; separators vary by locale).
local function int(v)
  if type(v) ~= "string" then return nil end
  return tonumber((v:gsub("[,%.]", "")))
end

-- First capture of a kind, by argument position.
local function first(args, kind)
  local best
  for pos, a in pairs(args) do
    if a.kind == kind and (not best or pos < best) then best = pos end
  end
  return best and args[best].value or nil
end

-- Formats sorted longest first, so "You loot %s (%s deposited to guild bank)" is tried before
-- "You loot %s" (both anchored, but the specific one must win).
local function formats(G, names)
  local list = {}
  for _, n in ipairs(names) do
    if type(G[n]) == "string" then list[#list + 1] = { name = n, fmt = G[n] } end
  end
  table.sort(list, function(a, b) return #a.fmt > #b.fmt end)
  return list
end

local COINS = { { "GOLD", 10000 }, { "SILVER", 100 }, { "COPPER", 1 } }

-- Coin string ("1 Gold, 5 Silver" or the texture variant) -> copper, or nil if no coin found.
function ChatParse.coins(text, G)
  local total, found = 0, false
  for _, coin in ipairs(COINS) do
    for _, suffix in ipairs({ "_AMOUNT", "_AMOUNT_TEXTURE" }) do
      local args = ChatParse.match(G[coin[1] .. suffix], text, false)
      local n = args and args[1] and int(args[1].value)
      if n then
        total, found = total + n * coin[2], true
        break
      end
    end
  end
  return found and total or nil
end

local MONEY = { "YOU_LOOT_MONEY", "YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT", "LOOT_MONEY_SPLIT_GUILD" }

-- The player's own looted money -> copper, or nil (other players' loot, other lines).
-- The guild-bank share is not ours: only the first %s (what the player got) counts.
function ChatParse.money(text, G)
  for _, f in ipairs(formats(G, MONEY)) do
    local args = ChatParse.match(f.fmt, text, true)
    if args and args[1] then
      local c = ChatParse.coins(args[1].value, G)
      if c then return c end
    end
  end
  return nil
end

local REP_UP = {
  "FACTION_STANDING_INCREASED", "FACTION_STANDING_INCREASED_ACCOUNT_WIDE",
  "FACTION_STANDING_INCREASED_BONUS", "FACTION_STANDING_INCREASED_BONUS_ACCOUNT_WIDE",
  "FACTION_STANDING_INCREASED_DOUBLE_BONUS", "FACTION_STANDING_INCREASED_DOUBLE_BONUS_ACCOUNT_WIDE",
  "FACTION_STANDING_INCREASED_ACH_BONUS", "FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE",
}
local REP_DOWN = { "FACTION_STANDING_DECREASED", "FACTION_STANDING_DECREASED_ACCOUNT_WIDE" }

-- "Reputation with Undercity increased by 25." -> "Undercity", 25 (negative when it decreased).
-- Lines without an amount (the _GENERIC ones) return nil.
function ChatParse.rep(text, G)
  for sign, names in pairs({ [1] = REP_UP, [-1] = REP_DOWN }) do
    for _, f in ipairs(formats(G, names)) do
      local args = ChatParse.match(f.fmt, text, true)
      if args then
        local faction, amount = first(args, "s"), int(first(args, "d"))
        if faction and faction ~= "" and amount then return faction, sign * amount end
      end
    end
  end
  return nil
end

return ChatParse
