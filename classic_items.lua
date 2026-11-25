-- ITEMS on the Game Boy games (Red, Blue, Yellow, Gold, Silver, Crystal)
-- An item lying on the map is a Poké Ball in every game. With ITEMS on,
-- it shows as the item it is: a Potion, an Ultra Ball, a TM disc in its
-- move's type's colour. A Poké Ball with a Pokémon in it (the starters on
-- the table, a gift) shows as a Poké Ball of the same look. -Elvie
--
-- FIRERED: FireRed's (or LeafGreen's) bag icons, 24x24, from the player's
-- own imported game. HGSS: HeartGold's or SoulSilver's, 32x32, from the
-- player's own dump through Prism Importer (0.4.0 or newer), which has
-- Kurt's Apricorn balls and the Park Ball too. An item one look hasn't
-- got is drawn from the other when it's there, and as the game's own ball
-- when neither has it. An icon stands on its tile, centred, as tall as
-- it is. Nothing from any game is included with Facets. -Elvie
-- --------------------------------------------------

local items = {}

local OFF = "game"
items.OFF = OFF
items.GBA = "gba_firered"
items.DS = "ds_hgss"

-- The Game Boy games' item names that the later games spell another
-- way, or have in another form: FireRed's name, HeartGold's -Elvie
items.ALIASES = {
  ELIXER = { "ELIXIR", "elixir" },
  MAX_ELIXER = { "MAX_ELIXIR", "max_elixir" },
  PARLYZ_HEAL = { "PARALYZE_HEAL", "parlyz_heal" },
  X_DEFEND = { "X_DEFEND", "x_defense" },
  EXP_ALL = { "EXP_SHARE", "exp_share" },
  ITEMFINDER = { "ITEMFINDER", "dowsing_mchn" },
  POKE_FLUTE = { "POKE_FLUTE", "poke_flute" },
  -- Gold, Silver and Crystal's berries, as the later games named them
  BERRY = { "ORAN_BERRY", "oran_berry" },
  GOLD_BERRY = { "SITRUS_BERRY", "sitrus_berry" },
  PRZCUREBERRY = { "CHERI_BERRY", "cheri_berry" },
  MINT_BERRY = { "CHESTO_BERRY", "chesto_berry" },
  PSNCUREBERRY = { "PECHA_BERRY", "pecha_berry" },
  ICE_BERRY = { "RAWST_BERRY", "rawst_berry" },
  BURNT_BERRY = { "ASPEAR_BERRY", "aspear_berry" },
  BITTER_BERRY = { "PERSIM_BERRY", "persim_berry" },
  MIRACLEBERRY = { "LUM_BERRY", "lum_berry" },
  MYSTERYBERRY = { "LEPPA_BERRY", "leppa_berry" },
}

-- A TM or HM disc in its move's type's colour: the TM of each type, in
-- FireRed (which has no Bug TM: a Normal disc stands in) and HeartGold
-- -Elvie
items.TM_GBA = { NORMAL = 5, FIGHTING = 1, FLYING = 40, POISON = 6, GROUND = 26, ROCK = 37, BUG = 5,
  GHOST = 30, STEEL = 23, FIRE = 35, WATER = 3, GRASS = 9, ELECTRIC = 24, PSYCHIC = 29, ICE = 13,
  DRAGON = 2, DARK = 12 }
items.TM_DS = { NORMAL = 5, FIGHTING = 1, FLYING = 40, POISON = 6, GROUND = 26, ROCK = 37, BUG = 89,
  GHOST = 30, STEEL = 23, FIRE = 35, WATER = 3, GRASS = 9, ELECTRIC = 24, PSYCHIC = 29, ICE = 13,
  DRAGON = 2, DARK = 12 }

-- The game's move type, as the later games name it -Elvie
function items.typeName(t)
  t = tostring(t or "NORMAL"):gsub("_TYPE$", "")
  if t == "CURSE" or t == "" then return "NORMAL" end
  return t
end

-- What a map object shows: { name } for an item, { tm = type } for a TM
-- or HM, { name = "POKE_BALL" } for a ball with a Pokémon in it, or nil
-- for anything else. def: the object; data: the game's data (items and
-- moves) -Elvie
function items.what(def, data, spriteId)
  if type(def) ~= "table" or spriteId ~= "SPRITE_POKE_BALL" then return nil end
  local name = def.item
  -- Gold, Silver and Crystal: the item ball's item by its number -Elvie
  if type(def.itemball) == "table" then
    local index = tonumber(def.itemball.item)
    name = nil
    if index and index > 0 and type(data) == "table" and type(data.items) == "table" then
      for key, it in pairs(data.items) do
        if type(it) == "table" and it.index == index then name = key break end
      end
    end
    if not name then return nil end
  end
  if name == nil or name == "0" or name == 0 or name == "" then return { name = "POKE_BALL", gift = true } end
  if type(name) ~= "string" then return nil end
  local move = name:match("^[TH]M_(.+)$")
  if move then
    local it = type(data) == "table" and type(data.items) == "table" and data.items[name]
    move = (type(it) == "table" and it.teaches) or move
    local m = type(data) == "table" and type(data.moves) == "table" and data.moves[move]
    return { tm = items.typeName(type(m) == "table" and m.type) }
  end
  return { name = name }
end

-- FireRed's item number for what's shown, or nil. ids: gba_ids' FireRed
-- items -Elvie
function items.gbaNumber(what, ids)
  if type(what) ~= "table" or type(ids) ~= "table" then return nil end
  if what.tm then return ids[("TM%02d"):format(items.TM_GBA[what.tm] or 5)] end
  local alias = items.ALIASES[what.name]
  return ids[alias and alias[1] or what.name]
end

-- HeartGold's item name for what's shown -Elvie
function items.dsName(what)
  if type(what) ~= "table" then return nil end
  if what.tm then return ("tm%02d"):format(items.TM_DS[what.tm] or 5) end
  local alias = items.ALIASES[what.name]
  return alias and alias[2] or tostring(what.name):lower()
end

-- Where an icon of w x h, its art at art = { x0, y0, x1, y1 }, is drawn
-- for a 16x16 sprite at (x, y): centred, its art's foot on the tile's
-- foot -Elvie
function items.place(x, y, w, h, art)
  art = art or { 0, 0, w, h }
  local cx = (art[1] + art[3]) / 2
  return math.floor(x + 8 - cx + 0.5), y + 16 - art[4]
end

-- the art's box in an ImageData: { x0, y0, x1, y1 } (past the last) -Elvie
function items.artBox(data)
  local w, h = data:getDimensions()
  local x0, y0, x1, y1 = w, h, -1, -1
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local _, _, _, a = data:getPixel(x, y)
      if a > 0 then
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        y1 = y
      end
    end
  end
  if x1 < 0 then return { 0, 0, w, h } end
  return { x0, y0, x1 + 1, y1 + 1 }
end

function items.init(mod, rows)
  local gba = require("mods.facets.classic_gba")
  local ds = require("mods.facets.ds")
  local choices = { { "GAME", OFF }, { "FIRERED", items.GBA } }
  local api = ds.api(mod)
  if api and ds.state(api, "hgss") ~= "absent" then choices[#choices + 1] = { "HGSS", items.DS } end
  rows[#rows + 1] = { key = "classicItems", type = "choice", label = "  ITEMS", choices = choices, default = OFF }

  return function()
    local okS, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
    if not (okS and type(SpriteRenderer) == "table" and type(SpriteRenderer.draw) == "function") then
      mod.log:warn("SpriteRenderer not found; ITEMS is off")
      return
    end
    local okP, PaletteFX = pcall(require, "src.render.PaletteFX")

    -- FireRed's item numbers, by name -Elvie
    local okI, ids = pcall(require, "mods.facets.gba_ids")
    local frItems = okI and type(ids) == "table" and ids.firered and ids.firered.items or {}

    -- icons made once each: { image, art } or false -Elvie
    local made = {}
    local function gbaIcon(what)
      local n = items.gbaNumber(what, frItems)
      if not n then return nil end
      local key = "gba:" .. n
      if made[key] == nil then
        made[key] = false
        for _, game in ipairs({ "firered", "leafgreen" }) do
          local data = gba.image(gba.read(game, "items/bag/icons/" .. n .. ".rgba"), 24, 24)
          if data then
            local okImg, img = pcall(love.graphics.newImage, data)
            if okImg then
              img:setFilter("nearest", "nearest")
              made[key] = { image = img, art = items.artBox(data) }
            end
            break
          end
        end
      end
      return made[key] or nil
    end
    local function dsIcon(what)
      local name = items.dsName(what)
      if not name then return nil end
      local key = "ds:" .. name
      if made[key] == nil then
        local dsApi = ds.api(mod)
        -- (not ready yet, or still importing: asked again later) -Elvie
        if not (dsApi and ds.state(dsApi, "hgss") == "ready") then return nil end
        made[key] = false
        if type(dsApi.imageData) == "function" then
          local okD, data = pcall(dsApi.imageData, "hgss", "item_icons", name)
          if okD and data then
            local okImg, img = pcall(love.graphics.newImage, data)
            if okImg then
              img:setFilter("nearest", "nearest")
              made[key] = { image = img, art = items.artBox(data) }
            end
          end
        end
      end
      return made[key] or nil
    end
    local function icon(what)
      local look = mod.options:get("classicItems")
      if look == items.GBA then return gbaIcon(what) or dsIcon(what) end
      if look == items.DS then return dsIcon(what) or gbaIcon(what) end
      return nil
    end

    -- what each object shows, worked out once -Elvie
    local shows = setmetatable({}, { __mode = "k" })
    local function whatOf(def, spriteId)
      local got = shows[def]
      if got == nil then
        local game = mod.game
        got = items.what(def, type(game) == "table" and game.data, spriteId) or false
        shows[def] = got
      end
      return got or nil
    end

    -- The NPC drawing an item ball hands its object to its sprite for the
    -- draw, and the sprite draws the icon instead of the ball -Elvie
    local ownDraw = SpriteRenderer.draw
    SpriteRenderer.draw = function(self, px, py, camX, camY, ...)
      local def = self._facetsItemDef
      if def and mod.options:get("classicItems") ~= OFF then
        local what = whatOf(def, type(self.def) == "table" and self.def.id)
        local got = what and icon(what)
        if got then
          local x, y = self:getScreenOrigin(px, py, camX, camY)
          local w, h = got.image:getDimensions()
          local dx, dy = items.place(x, y, w, h, got.art)
          if okP and type(PaletteFX.markTrueColor) == "function" then
            pcall(PaletteFX.markTrueColor, dx + got.art[1], dy + got.art[2],
              got.art[3] - got.art[1], got.art[4] - got.art[2])
          end
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(got.image, dx, dy)
          return
        end
      end
      return ownDraw(self, px, py, camX, camY, ...)
    end

    for _, path in ipairs({ "src.world.NPC", "src.world.gen2.Npc" }) do
      local okN, NPC = pcall(require, path)
      if okN and type(NPC) == "table" and type(NPC.draw) == "function" then
        local own = NPC.draw
        NPC.draw = function(self, ...)
          local sprite = self.sprite
          if type(sprite) == "table" then sprite._facetsItemDef = self.def end
          return own(self, ...)
        end
      end
    end
  end
end

return items
