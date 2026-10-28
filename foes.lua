-- Trainer battle pictures (foes.lua: the trainers you battle)
-- The picture of the trainer you battle (and in the Hall of Fame, the
-- PokéNav and the Battle Dome) comes from TrainerPic.front, so wrapping
-- that one function covers every screen. A TRAINERS SET picks the look;
-- it's OFF by default. -Elvie
--
-- Sets are folders under assets/trainers/ with a meta.json:
--   "source": "gb"  a Game Boy set: the game's own picture made Game Boy
--                   (as GB EMERALD makes Pokémon), unless...
--   gb.json         ...names a Gen 1/2 trainer for a picture: Crystal's
--                   (then Gold, Silver) in Crystal's colours for that
--                   trainer, or Yellow's (then Red, Blue) for Kanto's
--                   Gen 1-only trainers, read from the player's install.
--   <NAME>.png      a set's own 64x64 picture, by the game's own picture
--                   name (YOUNGSTER, LEADER_BROCK...), for art sets.
-- Nothing from the games is included. -Elvie
--
-- The player's and the rival's pictures are Emerald Lens's: the player's
-- are never touched, and any picture another mod has already swapped
-- stays as it is. -Elvie
-- --------------------------------------------------
local gb = require("mods.facets.gb")

local trainers = {}

local OFF = "__off"
local SIZE = 64
local DIR = "assets/trainers"
local WHITE, BLACK = { 255, 255, 255 }, { 0, 0, 0 }
local CRYSTAL = { "crystal", "gold", "silver" }
local YELLOW = { "yellow", "red", "blue" }

-- The player's own pictures: Emerald Lens's, always the game's here. -Elvie
trainers.PLAYER = {
  RED = true, LEAF = true, BRENDAN = true, MAY = true,
  RS_BRENDAN = true, RS_MAY = true, RS_BRENDAN_1 = true, RS_MAY_1 = true,
  RS_BRENDAN_2 = true, RS_MAY_2 = true,
}

-- A picture's name without TRAINER_PIC_ and FR/LG's RS_ (Ruby and
-- Sapphire's versions of the same trainer). -Elvie
function trainers.normal(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("^TRAINER_PIC_", "")
  if trainers.PLAYER[name] then return name end
  return (name:gsub("^RS_", ""))
end

-- Crystal's trainer colours: palettes.lua's trainers = { NAME = { {r,g,b},
-- {r,g,b} } }, colours 1-2 (0 is white and 3 black). Read as text. -Elvie
function trainers.parsePalettes(text)
  if type(text) ~= "string" then return nil end
  local start = text:find("\n  trainers = {", 1, true)
  if not start then return nil end
  local stop = text:find("\n  [%a_]+ = {", start + 1)
  local section = text:sub(start, stop or #text)
  local out, n = {}, 0
  for name, body in section:gmatch("\n    ([%w_]+) = {(.-)\n    }") do
    local v = {}
    for num in body:gmatch("%d+") do v[#v + 1] = tonumber(num) end
    if #v == 6 then
      out[name] = { { v[1], v[2], v[3] }, { v[4], v[5], v[6] } }
      n = n + 1
    end
  end
  return n > 0 and out or nil
end

-- Game Boy trainer pictures sit on white with no see-through pixels. The
-- white reached from the top and sides is the outside; the bottom is left
-- out, since the trainer is cut off there and white clothes reach it. -Elvie
function trainers.outside(src)
  local w, h = src:getDimensions()
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local _, _, _, a = src:getPixel(x, y)
      if not a or a <= 0 then return nil end
    end
  end
  local out, stack = {}, {}
  local function push(x, y)
    if x < 0 or y < 0 or x >= w or y >= h or out[y * w + x] then return end
    local r = src:getPixel(x, y)
    if r > 0.83 then out[y * w + x] = true; stack[#stack + 1] = { x, y } end
  end
  for x = 0, w - 1 do push(x, 0) end
  for y = 0, h - 1 do push(0, y); push(w - 1, y) end
  while #stack > 0 do
    local p = table.remove(stack)
    push(p[1] + 1, p[2]); push(p[1] - 1, p[2]); push(p[1], p[2] + 1); push(p[1], p[2] - 1)
  end
  return out
end

-- colour(r, g, b, a) for mons.layOut: grey 255/170/85/0 to white, the
-- trainer's two colours and black, the outside see-through. -Elvie
function trainers.colourFor(src, pal)
  local outside, w = trainers.outside(src), (src:getDimensions())
  local x, y = -1, 0
  return function(r, _, _, a)
    x = x + 1
    if x == w then x, y = 0, y + 1 end
    if not a or a <= 0 or (outside and outside[y * w + x]) then return nil end
    local k = r > 0.83 and 0 or r > 0.5 and 1 or r > 0.17 and 2 or 3
    return k == 0 and WHITE or k == 3 and BLACK or pal[k]
  end
end

local function ownColour(r, g, b, a)
  if not a or a <= 0 then return nil end
  return { r * 255, g * 255, b * 255, a }
end

-- The lowest drawn row of a 64x64 RGBA picture, plus one: where a new
-- picture's feet go so it stands where the game's own does. -Elvie
function trainers.bottomOf(rgba)
  if type(rgba) ~= "string" or #rgba < SIZE * SIZE * 4 then return SIZE end
  for y = SIZE - 1, 0, -1 do
    for x = 0, SIZE - 1 do
      if rgba:byte((y * SIZE + x) * 4 + 4) > 0 then return y + 1 end
    end
  end
  return SIZE
end

function trainers.init(mod, rows, menu)
  local function isDirectory(rel)
    local info = mod.assets:info(rel)
    return info and info.type == "directory"
  end
  local decode = require("mods.facets.npcs").decodeJson
  local function readJson(rel)
    if not mod.assets:info(rel) then return nil end
    local ok, decoded = pcall(decode, mod:read(rel))
    if ok and type(decoded) == "table" then return decoded end
    mod.log:warn("%s couldn't be read", rel)
    return nil
  end

  local sets = {}
  for _, key in ipairs(mod.assets:list(DIR)) do
    if isDirectory(DIR .. "/" .. key) then
      local meta = readJson(DIR .. "/" .. key .. "/meta.json") or {}
      local map = readJson(DIR .. "/" .. key .. "/gb.json")
      sets[#sets + 1] = { key = key, label = type(meta.label) == "string" and meta.label or key:upper(),
        credit = meta.credit, gb = meta.source == "gb", map = map and map.trainers or nil,
        shades = tonumber(meta.builtShades) or 8 }
    end
  end
  table.sort(sets, function(a, b) return a.label < b.label end)
  if #sets == 0 then return nil end

  local choices = {}
  for _, set in ipairs(sets) do choices[#choices + 1] = { set.label, set.key } end
  choices[#choices + 1] = { "OFF", OFF }
  rows[#rows + 1] = { key = "sectionTrainers", type = "choice", label = "TRAINERS",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "setTrainers", type = "choice", label = "  SET", choices = choices, default = OFF }
  if menu then trainers.screenPart(mod, menu, sets, choices) end

  return function()
    local okT, TrainerPic = pcall(require, "src.core.game3.trainer_pic")
    if not okT or type(TrainerPic) ~= "table" or type(TrainerPic.front) ~= "function" then
      mod.log:warn("TrainerPic.front not found; TRAINERS is off")
      return
    end
    local disk = require("mods.facets.diskcache")
    local current, cache, names, palettes = nil, {}, nil, nil

    local function game()
      local ok, GameVersion = pcall(require, "src.core.GameVersion")
      return ok and type(GameVersion) == "table" and tostring(GameVersion.get()) or nil
    end
    -- picture id -> name, from the game's own constants -Elvie
    local function nameOf(id)
      if names == nil then
        names = {}
        local okC, Constants = pcall(require, "src.core.game3.constants")
        if okC and type(Constants.of) == "function" then
          local ok, raw = pcall(function() return Constants.of(game()):raw("trainer_classes") end)
          local byId = ok and type(raw) == "table" and type(raw.byId) == "table" and raw.byId.TRAINER_PIC_
          if type(byId) == "table" then
            for k, v in pairs(byId) do
              if tonumber(k) and type(v) == "string" then names[tonumber(k)] = trainers.normal(v) end
            end
          end
        end
      end
      return names[id]
    end
    trainers.nameOf = nameOf

    local function rgbaOf(id)
      local rel = gb.path("trainers", "front/" .. id .. ".rgba")
      return rel and (gb.readAt(rel, { game() })) or nil
    end

    -- The game's own picture made Game Boy (mons.toGbc). -Elvie
    local function built(rgba)
      if type(rgba) ~= "string" or #rgba < SIZE * SIZE * 4 then return nil end
      local px = {}
      for i = 1, SIZE * SIZE do
        local o = (i - 1) * 4
        local r, g, b, a = rgba:byte(o + 1, o + 4)
        px[i] = { r, g, b, a }
      end
      local out = require("mods.facets.mons").toGbc(px, px, current.shades)
      if not out then return nil end
      local data = love.image.newImageData(SIZE, SIZE)
      for i, p in ipairs(out) do
        if p[4] > 0 then
          data:setPixel((i - 1) % SIZE, math.floor((i - 1) / SIZE), p[1] / 255, p[2] / 255, p[3] / 255, 1)
        end
      end
      return data
    end

    -- A Gen 1/2 trainer from the install, in Crystal's colours for it. -Elvie
    local function fromGameBoy(entry, rgba)
      if type(entry) == "string" then entry = { crystal = entry } end
      if type(entry) ~= "table" then return nil end
      local stem = entry.crystal or entry.red
      if type(stem) ~= "string" or stem:find("[^%w_%.]") then return nil end
      local rel = gb.path("assets", "battle/trainers/" .. stem .. ".png")
      local src = rel and gb.readImage(rel, entry.crystal and CRYSTAL or YELLOW)
      if not src then return nil end
      if palettes == nil then
        palettes = trainers.parsePalettes(gb.readAt(gb.path("data", "palettes.lua"), { "crystal" })) or false
      end
      local pal = palettes and palettes[entry.palette or (entry.crystal or ""):upper()]
      if not pal then return nil end
      return (require("mods.facets.mons").layOut(src, trainers.bottomOf(rgba), trainers.colourFor(src, pal)))
    end

    local function build(id, name)
      local rgba = rgbaOf(id)
      local own = DIR .. "/" .. current.key .. "/" .. name .. ".png"
      if mod.assets:info(own) then
        local ok, src = pcall(love.image.newImageData, mod.assets:path(own))
        if ok and src then
          return (require("mods.facets.mons").layOut(src, trainers.bottomOf(rgba), ownColour))
        end
      end
      if current.map and current.map[name] then
        local data = fromGameBoy(current.map[name], rgba)
        if data then return data end
      end
      if current.gb then return built(rgba) end
      return nil
    end

    local function lookup(id)
      local name = nameOf(id)
      if not name or trainers.PLAYER[name] then return nil end
      local hit = cache[id]
      if hit ~= nil then return hit or nil end
      local group = "trainers-" .. tostring(game()) .. "-" .. current.key
      local key = tostring(id)
      local data = disk.get(group, key)
      if not data then
        local ok, got = pcall(build, id, name)
        if not ok then mod.log:warn("trainer %s: %s", name, tostring(got)) end
        data = ok and got or nil
        if data then disk.put(group, key, data) end
      end
      local entry = false
      if data and love and love.graphics then
        local image = love.graphics.newImage(data)
        image:setFilter("nearest", "nearest")
        entry = { image = image, imageData = data, w = SIZE, h = SIZE }
      end
      cache[id] = entry
      return entry or nil
    end

    local origFront = TrainerPic.front
    TrainerPic.front = function(picId, ...)
      local vanilla = origFront(picId, ...)
      local id = tonumber(picId)
      if not current or not id or type(picId) == "string" then return vanilla end
      -- another mod's picture (Emerald Lens's rival) stays -Elvie
      local own = type(TrainerPic._front) == "table" and TrainerPic._front[id] or nil
      if vanilla and own and vanilla ~= own then return vanilla end
      return lookup(id) or vanilla
    end

    -- PREBUILD: every picture the set has -Elvie
    require("mods.facets.prebuild").provide("trainers", function()
      if not current then return {} end
      nameOf(0)
      local units = {}
      local ids = {}
      for id in pairs(names or {}) do ids[#ids + 1] = id end
      table.sort(ids)
      for _, id in ipairs(ids) do units[#units + 1] = function() return lookup(id) end end
      return units
    end, "start")

    local function configure()
      local value = mod.options:get("setTrainers")
      current = nil
      for _, set in ipairs(sets) do if set.key == value then current = set end end
      cache = {}
    end
    configure()
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id and change.key == "setTrainers" then configure() end
      end)
    end
    trainers.lookup = lookup
  end
end

-- The FACETS screen: TRAINERS, with trainers from the game taking turns
-- in the preview while the row is picked. -Elvie
-- --------------------------------------------------
trainers.SHOWCASE = {
  frlg = { "YOUNGSTER", "LASS", "HIKER", "LEADER_BROCK", "ROCKET_GRUNT_M", "LEADER_MISTY" },
  rse = { "YOUNGSTER", "LASS", "HIKER", "LEADER_ROXANNE", "AQUA_GRUNT_M", "LEADER_BRAWLY" },
}
trainers.SLOT_TIME = 2
local FRONT_X, FRONT_Y = 160, 24

function trainers.screenPart(mod, menu, sets, choices)
  local ids = {}
  local function showcase(family)
    if ids[family.id] then return ids[family.id] end
    local list, byName = {}, {}
    local okV, GameVersion = pcall(require, "src.core.GameVersion")
    local okC, Constants = pcall(require, "src.core.game3.constants")
    if okV and okC and type(Constants.of) == "function" then
      local ok, raw = pcall(function() return Constants.of(GameVersion.get()):raw("trainer_classes") end)
      local byId = ok and type(raw) == "table" and type(raw.byId) == "table" and raw.byId.TRAINER_PIC_
      for k, v in pairs(type(byId) == "table" and byId or {}) do
        if tonumber(k) and type(v) == "string" then byName[(v:gsub("^TRAINER_PIC_", ""))] = tonumber(k) end
      end
    end
    for _, name in ipairs(trainers.SHOWCASE[family.id] or {}) do
      if byName[name] then list[#list + 1] = byName[name] end
    end
    ids[family.id] = list
    return list
  end
  local function selected()
    local value = mod.options:get("setTrainers")
    for _, set in ipairs(sets) do if set.key == value then return set end end
    return nil
  end
  menu.register({
    rows = function()
      local set = selected()
      return { { key = "setTrainers", label = "TRAINERS", who = "trainers", choices = choices,
        value = set and set.key or OFF } }
    end,
    preview = function(who)
      if who ~= "trainers" then return nil end
      local set = selected()
      if not set then return { lines = { { text = "The game's own trainers." } } } end
      local lines = require("mods.facets.menu").creditLines(set.credit)
      if set.map and not gb.imported() then
        table.insert(lines, 1, { text = "No Gen 1/2 game imported.", red = true })
      end
      return { lines = lines }
    end,
    draw = function(clock, family, spots, who)
      if who ~= "trainers" or not (love and love.graphics) then return end
      local list = showcase(family)
      if #list == 0 then return end
      local id = list[math.floor((clock or 0) / trainers.SLOT_TIME) % #list + 1]
      local okT, TrainerPic = pcall(require, "src.core.game3.trainer_pic")
      if not okT or type(TrainerPic.front) ~= "function" then return end
      local ok, pic = pcall(TrainerPic.front, id)
      if ok and type(pic) == "table" and pic.image then
        love.graphics.draw(pic.image, FRONT_X, FRONT_Y)
      end
    end,
    credits = function()
      local out = {}
      for _, set in ipairs(sets) do
        out[#out + 1] = { text = "TRAINERS: " .. set.label, heading = true }
        local lines = require("mods.facets.menu").creditLines(set.credit)
        if #lines == 0 then lines[1] = { text = "No credit listed." } end
        for _, line in ipairs(lines) do out[#out + 1] = { text = line.text } end
      end
      return out
    end,
  })
end

return trainers
