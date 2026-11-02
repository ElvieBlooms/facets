-- CREDITS on the Game Boy games
-- The last row of the FACETS page: who made everything Facets can show
-- here, from each set's meta.json (the same lines Gen 3's CREDITS page
-- shows), Yellow's Pikachu looks, the Minidex, and a line for what's read
-- from your own games. In the game's own font and box; up and down scroll
-- a line, left and right a page, A or B goes back. -Elvie
-- --------------------------------------------------

local credits = {}

local W = 17 -- letters a line, inside the box with a letter spare -Elvie
local ROWS = 14

-- Letters the Game Boy font hasn't got: "#" is its POKé, "&" is blank -Elvie
credits.SWAP = { ["&"] = "and", ["#"] = "-" }

function credits.plain(text)
  return (tostring(text or ""):gsub("[&#]", credits.SWAP))
end

-- Where each row's sets keep their meta.json -Elvie
credits.DIRS = {
  { "classicNpcs", "assets/npcs", "NPCS" },
  { "classicTrainers", "assets/trainers", "TRAINERS" },
  { "classicMons", "assets/mons", "POKEMON" },
  { "classicBattleBg", "assets/battlebg", "BATTLE BG" },
  { "classicBattleUi", "assets/battleui", "BATTLE UI" },
  { "classicWindows", "assets/windows", "WINDOWS" },
}

-- Choices read from the player's own games, not shipped -Elvie
local OWN = { firered = true, emerald = true, crystal = true, fr = true, gbc = true }

credits.MINIDEX = "Kanto and Johto icons from the Minidex 001-251, by Chamber, Soloo993, Blue Emerald, Lake, Neslug and Pikachu25, used with credit"
credits.OWN_GAMES = "FIRERED, EMERALD and CRYSTAL choices are read while you play from the games you imported yourself (Nintendo / Game Freak). None of it is included with Facets."

-- Text as lines of at most n letters, split at spaces; a word longer than
-- a line is cut -Elvie
function credits.wrap(text, n)
  local lines, line = {}, ""
  for word in tostring(text or ""):gmatch("%S+") do
    while #word > n do
      if line ~= "" then lines[#lines + 1] = line; line = "" end
      lines[#lines + 1] = word:sub(1, n)
      word = word:sub(n + 1)
    end
    if line == "" then line = word
    elseif #line + 1 + #word <= n then line = line .. " " .. word
    else lines[#lines + 1] = line; line = word end
  end
  if line ~= "" then lines[#lines + 1] = line end
  return lines
end

local function list(credit)
  if type(credit) == "string" then return { credit } end
  if type(credit) ~= "table" then return {} end
  local out = {}
  for _, line in ipairs(credit) do
    if type(line) == "string" and line ~= "" then out[#out + 1] = line end
  end
  return out
end

-- The entries: { text, heading } in page order. read(rel) returns a
-- meta.json table or nil -Elvie
-- fills: the fill-in NPC sets' folders, in menu order -Elvie
function credits.entries(rows, read, fills)
  local out = {}
  out[#out + 1] = { text = "FACETS", heading = true }
  out[#out + 1] = { text = "A time machine for the Game Boy games' people and Pokémon, by Elvie." }
  local byKey = {}
  for _, row in ipairs(rows or {}) do
    if type(row.key) == "string" then byKey[row.key] = row end
  end
  local own, seen = false, {}
  local function add(heading, meta)
    local lines = list(type(meta) == "table" and meta.credit)
    if #lines == 0 then return end
    out[#out + 1] = { text = heading, heading = true }
    for _, line in ipairs(lines) do out[#out + 1] = { text = line } end
  end
  for _, d in ipairs(credits.DIRS) do
    local key, dir, name = d[1], d[2], d[3]
    local row = byKey[key]
    local folders = {}
    for _, choice in ipairs(row and row.choices or {}) do
      local value = tostring(choice[2] or "")
      local folder = value:match("^([%w_%-]+)")
      if folder and OWN[folder] then own = true
      elseif folder and not seen[dir .. "/" .. folder] then
        seen[dir .. "/" .. folder] = true
        folders[#folders + 1] = folder
      end
    end
    -- the fill-in sets (Heart & Soul, Jessie & James) stand in for every
    -- NPC set -Elvie
    if key == "classicNpcs" and row then
      for _, fill in ipairs(fills or { "hns" }) do
        if not seen[dir .. "/" .. fill] then
          seen[dir .. "/" .. fill] = true
          folders[#folders + 1] = fill
        end
      end
    end
    for _, folder in ipairs(folders) do
      local meta = read(dir .. "/" .. folder .. "/meta.json")
      if type(meta) == "table" then
        add(name .. ": " .. tostring(meta.label or folder:upper()), meta)
      end
    end
    if key == "classicNpcs" and byKey.classicPikachu then
      local meta = read("assets/pikachu/meta.json")
      if type(meta) == "table" then
        out[#out + 1] = { text = "PIKACHU", heading = true }
        for _, look in ipairs(type(meta.looks) == "table" and meta.looks or {}) do
          for _, line in ipairs(list(look.credit)) do out[#out + 1] = { text = line } end
        end
        for _, line in ipairs(list(meta.battleCredit)) do out[#out + 1] = { text = line } end
      end
    end
    if key == "classicMons" and byKey.classicIcons then
      out[#out + 1] = { text = "ICONS: MINIDEX", heading = true }
      out[#out + 1] = { text = credits.MINIDEX }
    end
  end
  if own then
    out[#out + 1] = { text = "YOUR OWN GAMES", heading = true }
    out[#out + 1] = { text = credits.OWN_GAMES }
  end
  return out
end

-- The entries as screen lines: a blank line before each heading -Elvie
function credits.lines(entries, n)
  local lines = {}
  for _, entry in ipairs(entries) do
    if entry.heading and #lines > 0 then lines[#lines + 1] = { text = "" } end
    for _, part in ipairs(credits.wrap(credits.plain(entry.text), n or W)) do
      lines[#lines + 1] = { text = part, heading = entry.heading }
    end
  end
  return lines
end

-- The page, pushed on the game's stack -Elvie
function credits.screen(mod, game, rows)
  local Font = mod.ui and mod.ui.Font or require("src.render.Font")
  local Theme = mod.ui and mod.ui.Theme
  local decode = require("mods.facets.npcs").decodeJson
  local function read(rel)
    if not (mod.assets and mod.assets:info(rel)) then return nil end
    local ok, meta = pcall(decode, mod:read(rel))
    return ok and meta or nil
  end
  local fills = {}
  for _, key in ipairs(mod.assets:list("assets/npcs") or {}) do
    local meta = key:match("^[%w_%-]+$") and read("assets/npcs/" .. key .. "/meta.json")
    if type(meta) == "table" and meta.fill == true then fills[#fills + 1] = key end
  end
  table.sort(fills)
  local lines = credits.lines(credits.entries(rows, read, fills), W)
  local self = { isOpaque = true, scroll = 0 }
  local last = math.max(0, #lines - ROWS)

  function self:update()
    local input = game.input
    if not input then return end
    if input:wasPressed("a") or input:wasPressed("b") or input:wasPressed("start") then game.stack:pop() return end
    if input:wasPressed("up") then self.scroll = math.max(0, self.scroll - 1)
    elseif input:wasPressed("down") then self.scroll = math.min(last, self.scroll + 1)
    elseif input:wasPressed("left") then self.scroll = math.max(0, self.scroll - ROWS)
    elseif input:wasPressed("right") then self.scroll = math.min(last, self.scroll + ROWS) end
  end

  function self:draw()
    local G = love.graphics
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, 160, 144)
    Font.drawBox(0, 0, 20, 18)
    G.setColor(0, 0, 0, 1)
    Font.draw("CREDITS", 8, 8)
    for i = 1, ROWS do
      local line = lines[self.scroll + i]
      if not line then break end
      Font.draw(line.text, 8, (i + 1) * 8)
    end
    -- the more-below arrow, as the OPTION page shows it -Elvie
    if self.scroll < last and Theme and Theme.moreArrow then Font.drawCode(Theme.moreArrow, 144, 128) end
    G.setColor(1, 1, 1, 1)
  end

  return self
end

return credits
