-- ITEMS on the GBA games (FireRed, LeafGreen, Emerald)
-- An item lying on the map is a Poké Ball. With ITEMS on, it shows as the
-- item it is, as on Red to Crystal (classic_items.lua): a Potion, a Rare
-- Candy, a TM disc in its move's type's colour. A Poké Ball with a
-- Pokémon in it (the starters, the Electrode lying in wait at the Power
-- Plant) stays the game's ball with GBA, and is HeartGold's own with HGSS. -Elvie
--
-- GBA: the game's own bag icons, 24x24 (Emerald's, or FireRed's and
-- LeafGreen's), from the player's own imported game. HGSS: HeartGold's or
-- SoulSilver's, 32x32, from the player's own dump through Prism Importer
-- (0.4.0 or newer). An item one hasn't got comes from the other, or stays
-- the game's ball. The GBC people (NPCS) bring the Game Boy's own Poké
-- Ball with them, for ITEMS: GAME (assets/npcs/gbc/gb.json). Nothing from
-- any game is included with Facets. -Elvie
-- --------------------------------------------------

local items3 = {}

local OFF = "game"
items3.OFF = OFF
items3.GBA = "gba"
items3.DS = "ds_hgss"

items3.POKE_BALL = 4 -- the item number of a Poké Ball, in every GBA game -Elvie
items3.ITEM_VAR = 0x8000 -- an item ball's script puts its item here -Elvie

-- The item an item ball's script gives, by its number, or nil for a ball
-- with no item (a gift Pokémon, a Pokémon lying in wait) -Elvie
function items3.itemOf(script)
  if type(script) ~= "table" then return nil end
  for _, op in ipairs(script) do
    if type(op) == "table" and op.op == "setorcopyvar" and tonumber(op[1]) == items3.ITEM_VAR then
      local n = tonumber(op[2])
      if n and n > 0 then return n end
    end
  end
  return nil
end

-- What a ball shows: { number, name, gift } -Elvie
function items3.what(script, names)
  local n = items3.itemOf(script)
  if not n then return { number = items3.POKE_BALL, name = "POKE_BALL", gift = true } end
  return { number = n, name = type(names) == "table" and names[n] or nil }
end

-- Names by number, from gba_ids' FireRed items (Emerald's numbers are
-- the same up to the key items FireRed added) -Elvie
function items3.names(ids)
  local out = {}
  for name, n in pairs(type(ids) == "table" and ids or {}) do
    if name ~= "NONE" then out[n] = name end
  end
  return out
end

-- HeartGold's name for what's shown -Elvie
function items3.dsName(what, aliases)
  local name = type(what) == "table" and what.name
  if type(name) ~= "string" then return nil end
  local alias = aliases and aliases[name]
  return alias and alias[2] or name:lower()
end

-- One 24x24 icon's bytes out of Emerald's strip of them, one under
-- another, or nil -Elvie
function items3.slice(bytes, n, count)
  local size = 24 * 24 * 4
  if type(bytes) ~= "string" or n < 0 or n >= (count or math.floor(#bytes / size)) then return nil end
  local at = n * size
  if #bytes < at + size then return nil end
  return bytes:sub(at + 1, at + size)
end

-- the item ball's graphics id in the running game, from gba_ids -Elvie
local function ballGid()
  local okV, GameVersion = pcall(require, "src.core.GameVersion")
  local version = okV and type(GameVersion) == "table" and type(GameVersion.get) == "function" and GameVersion.get()
  local okI, ids = pcall(require, "mods.facets.gba_ids")
  local table3 = okI and type(ids) == "table" and ids[version == "emerald" and "emerald" or "firered"]
  return table3 and table3.ow and table3.ow.ITEM_BALL or nil, version
end

function items3.init(mod, rows, menu)
  local ds = require("mods.facets.ds")
  local choices = { { "GAME", OFF }, { "GBA", items3.GBA } }
  local api = ds.api(mod)
  if api and ds.state(api, "hgss") ~= "absent" then choices[#choices + 1] = { "HGSS", items3.DS } end
  rows[#rows + 1] = { key = "setItems", type = "choice", label = "ITEMS", choices = choices, default = OFF }

  if menu then
    menu.register({
      rows = function()
        return { { key = "setItems", label = "ITEMS", who = "items", choices = choices,
          value = mod.options:get("setItems") or OFF } }
      end,
      preview = function(who)
        if who ~= "items" then return nil end
        local v = mod.options:get("setItems") or OFF
        if v == items3.GBA then return { lines = { { text = "Items on the map: the bag's icons." } } } end
        if v == items3.DS then return { lines = { { text = "Items on the map: HeartGold's icons." } } } end
        return { lines = { { text = "Items on the map: the game's Poké Balls." } } }
      end,
    })
  end

  return function()
    local okO, OwSprites = pcall(require, "src.core.game3.ow_sprites")
    if not (okO and type(OwSprites) == "table" and type(OwSprites.draw) == "function") then
      mod.log:warn("Gen 3's overworld sprites not found; ITEMS is off")
      return
    end
    local gid, version = ballGid()
    if not gid then
      mod.log:warn("no item ball in %s; ITEMS is off", tostring(version))
      return
    end
    local gba = require("mods.facets.classic_gba")
    local citems = require("mods.facets.classic_items")
    local okI, ids = pcall(require, "mods.facets.gba_ids")
    local names = items3.names(okI and type(ids) == "table" and ids.firered and ids.firered.items)

    -- icons made once each: { image, art } or false -Elvie
    local made = {}
    local function keep(key, data)
      if not data then return nil end
      data = citems.small(data)
      local okImg, img = pcall(love.graphics.newImage, data)
      if not okImg then return nil end
      img:setFilter("nearest", "nearest")
      made[key] = { image = img, art = citems.artBox(data) }
      return made[key]
    end
    -- the running game's own icons first, then the other GBA games' -Elvie
    local order = version == "emerald" and { "emerald", "firered", "leafgreen" }
      or { version == "leafgreen" and "leafgreen" or "firered", version == "leafgreen" and "firered" or "leafgreen", "emerald" }
    local strip -- Emerald's icons, read once: bytes or false -Elvie
    local function gbaIcon(what)
      local n = what.number
      local key = "gba:" .. n
      if made[key] == nil then
        made[key] = false
        for _, game in ipairs(order) do
          local bytes
          if game == "emerald" then
            if strip == nil then strip = gba.read("emerald", "rse/bag/icons.rgba") or false end
            bytes = strip and items3.slice(strip, n)
          else
            bytes = gba.read(game, "items/bag/icons/" .. n .. ".rgba")
          end
          local data = gba.image(bytes, 24, 24)
          if data then keep(key, data) break end
        end
      end
      return made[key] or nil
    end
    local function dsIcon(what)
      local name = items3.dsName(what, citems.ALIASES)
      if not name then return nil end
      local key = "ds:" .. name
      if made[key] == nil then
        local dsApi = ds.api(mod)
        -- (not ready yet, or still importing: asked again later) -Elvie
        if not (dsApi and ds.state(dsApi, "hgss") == "ready") then return nil end
        made[key] = false
        if type(dsApi.imageData) == "function" then
          local okD, data = pcall(dsApi.imageData, "hgss", "item_icons", name)
          if okD and data then keep(key, data) end
        end
      end
      return made[key] or nil
    end
    -- A ball with a Pokémon in it: the game's own ball for GBA, and
    -- HeartGold's for HGSS -Elvie
    local function dsBall()
      if made.dsBall == nil then
        local dsApi = ds.api(mod)
        if not (dsApi and ds.state(dsApi, "hgss") == "ready") then return nil end
        made.dsBall = citems.dsBall(dsApi) or false
      end
      return made.dsBall or nil
    end
    local function icon(what)
      local look = mod.options:get("setItems")
      if what.gift then return look == items3.DS and dsBall() or nil end
      if look == items3.GBA then return gbaIcon(what) or dsIcon(what) end
      if look == items3.DS then return dsIcon(what) or gbaIcon(what) end
      return nil
    end

    -- what each ball shows, by its object, worked out once -Elvie
    local shows = setmetatable({}, { __mode = "k" })
    local function whatOf(def)
      local got = shows[def]
      if got == nil then
        local Sp = package.loaded["src.core.game3.scripting.space"]
        local scripts = type(Sp) == "table" and type(Sp.bundle) == "table" and Sp.bundle.scripts
        local key = def.scriptKey
        local script = type(scripts) == "table" and key ~= nil and rawget(scripts, key)
        -- (scripts not loaded yet: asked again later) -Elvie
        if not script then return nil end
        got = items3.what(script, names)
        shows[def] = got
      end
      return got
    end

    -- The ball's object, from where it's drawn: the map's own objects,
    -- then the next maps' along the edge, as the field draws them -Elvie
    local CELL = 16
    local function defAt(px, py)
      local Objects = package.loaded["src.core.game3.objects"]
      if type(Objects) == "table" and type(Objects.forDraw) == "function" then
        for _, eo in ipairs(Objects.forDraw()) do
          if eo.graphicsId == gid and type(eo.def) == "table"
              and (eo.px or (eo.cellX or 0) * CELL) + (eo.raiseX or 0) == px
              and (eo.py or (eo.cellY or 0) * CELL) + (eo.raiseY or 0) == py then
            return eo.def
          end
        end
      end
      local Map = package.loaded["src.core.game3.map"]
      local Ghosts = package.loaded["src.core.game3.ghosts"]
      if type(Map) == "table" and type(Map.world) == "table" and type(Ghosts) == "table" and type(Ghosts.forDraw) == "function" then
        for _, entry in ipairs(Map.world) do
          local okG, live = pcall(Ghosts.forDraw, entry.id)
          for _, eo in ipairs(okG and type(live) == "table" and live or {}) do
            local def = eo.def
            if type(def) == "table" and (eo.graphicsId or def.graphicsId or def.graphics) == gid
                and (eo.px or (eo.cellX or 0) * CELL) + (entry.ox or 0) * CELL == px
                and (eo.py or (eo.cellY or 0) * CELL) + (entry.oy or 0) * CELL == py then
              return def
            end
          end
        end
      end
      return nil
    end

    local own = OwSprites.draw
    OwSprites.draw = function(graphicsId, px, py, camX, camY, ...)
      if graphicsId == gid and mod.options:get("setItems") ~= OFF then
        local def = defAt(px, py)
        local what = def and whatOf(def)
        local got = what and icon(what)
        if got then
          local opts = select(4, ...)
          local w, h = got.image:getDimensions()
          local dx, dy = citems.place(px - camX, py - camY, w, h, got.art)
          love.graphics.setColor(1, 1, 1, type(opts) == "table" and opts.alpha or 1)
          love.graphics.draw(got.image, dx, dy)
          love.graphics.setColor(1, 1, 1, 1)
          return true
        end
      end
      return own(graphicsId, px, py, camX, camY, ...)
    end

    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id and change.key == "setItems" then made = {} end
      end)
    end
  end
end

return items3
