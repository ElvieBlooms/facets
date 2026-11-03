-- Crystal's art on Red, Blue and Yellow
-- CRYSTAL under POKEMON: SET (and ICONS) reads Crystal's battle sprites
-- and party icons from the player's own install (then Gold's, then
-- Silver's), nothing shipped. They're four greys like Gen 1's own, so with
-- the usual COLORS they're handed over grey and the game tints them as it
-- does its own; on RED++ they get Crystal's colours. -Elvie
-- --------------------------------------------------

local crystal = {}

local gb = require("mods.facets.gb")
local NAMES = require("mods.facets.mon_names")

crystal.CHOICE = "gb_crystal"
crystal.LABEL = "CRYSTAL"
local GAMES = { "crystal", "gold", "silver" }
local WHITE, BLACK = { 255, 255, 255 }, { 0, 0, 0 }

-- Crystal's palettes.lua and icons.lua, read once as text (mods can't
-- load() Lua) -Elvie
local palettes, icons, partyPal
local function data(file)
  return gb.readAt(gb.path("data", file), GAMES)
end
local function monPalettes()
  if palettes == nil then
    local mons = require("mods.facets.mons")
    palettes = mons.parsePalettes(data("palettes.lua")) or false
  end
  return palettes or nil
end
local function iconTable()
  if icons == nil then
    local mons = require("mods.facets.mons")
    icons = mons.parseIcons(data("icons.lua")) or false
    partyPal = mons.parsePartyPalette(data("palettes.lua"))
  end
  return icons or nil
end

-- Forget what was read, for a game imported since -Elvie
function crystal.reset()
  palettes, icons, partyPal = nil, nil, nil
end

-- A grey sprite through a palette (colours 1 and 2; 0 white, 3 black),
-- the see-through kept. pal nil keeps it grey -Elvie
function crystal.colour(src, pal)
  local w, h = src:getDimensions()
  local out = love.image.newImageData(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local r, _, _, a = src:getPixel(x, y)
      if a and a > 0 then
        if pal then
          local k = r > 0.83 and 0 or r > 0.5 and 1 or r > 0.17 and 2 or 3
          local c = k == 0 and WHITE or k == 3 and BLACK or pal[k]
          out:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, 1)
        else
          out:setPixel(x, y, r, r, r, 1)
        end
      end
    end
  end
  return out
end

-- The file for a Pokémon's front or back, or nil (dex 1-251) -Elvie
function crystal.picturePath(dex, face)
  local row = type(dex) == "number" and NAMES[dex]
  if not row or row[1] == "unown" then return nil end
  local file = face == "back" and (row[1] .. "_back") or row[1]
  return gb.path("assets", "battle/" .. (face == "back" and "back" or "front") .. "/" .. file .. ".png")
end

-- A battle sprite as ImageData: grey, or in Crystal's colours -Elvie
function crystal.picture(dex, face, shiny, coloured)
  local path = crystal.picturePath(dex, face)
  local src = path and gb.readImage(path, GAMES)
  if not src then return nil end
  if not coloured then return crystal.colour(src, nil) end
  local all = monPalettes()
  local pal = all and all[NAMES[dex][2]]
  if not pal then return crystal.colour(src, nil) end
  return crystal.colour(src, shiny and pal.shiny or pal.normal)
end

-- A party icon (16x32, two frames) as ImageData, or nil -Elvie
function crystal.icon(dex, coloured)
  local t = iconTable()
  local row = type(dex) == "number" and NAMES[dex]
  local id = t and row and t.species[row[2]]
  local file = id and t.image[id]
  local src = file and gb.readImage(file, GAMES)
  if not src then return nil end
  return crystal.colour(src, coloured and partyPal or nil)
end

return crystal
