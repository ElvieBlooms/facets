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
local animText, animIndex, anims = nil, {}, {}
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
  animText, animIndex, anims = nil, {}, {}
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

-- A Pokémon's colours from Crystal's palettes ({ normal, shiny } pairs of
-- colours 1 and 2), or nil -Elvie
function crystal.palette(dex, shiny)
  local row = type(dex) == "number" and NAMES[dex]
  local all = row and monPalettes()
  local pal = all and all[row[2]]
  if not pal then return nil end
  return shiny and pal.shiny or pal.normal
end

-- Crystal's animation for a Pokémon (its script, with the sheet's path in
-- Crystal's install), or nil; only Crystal has them -Elvie
function crystal.anim(dex)
  local row = type(dex) == "number" and NAMES[dex]
  if not row or row[1] == "unown" then return nil end
  local hit = anims[row[1]]
  if hit ~= nil then return hit or nil end
  if animText == nil then animText = gb.readAt(gb.path("data", "pokemon.lua"), { "crystal" }) or false end
  local mons = require("mods.facets.mons")
  local anim = animText and mons.crystalAnim(animText, row[1], animIndex)
  anims[row[1]] = anim or false
  return anim or nil
end

-- Its frames, each a square ImageData, from Crystal's sheet: grey, or in
-- Crystal's colours -Elvie
function crystal.animFrames(dex, shiny, coloured)
  local anim = crystal.anim(dex)
  local size = anim and tonumber(anim.tiles) and tonumber(anim.tiles) * 8
  local src = size and size > 0 and type(anim.sheet) == "string" and gb.readImage(anim.sheet, { "crystal" })
  if not src then return nil end
  local w, h = src:getDimensions()
  if w < size then return nil end
  local pal = coloured and crystal.palette(dex, shiny) or nil
  local frames = {}
  for i = 0, math.floor(h / size) - 1 do
    local f = love.image.newImageData(size, size)
    f:paste(src, 0, 0, 0, i * size, size, size)
    frames[#frames + 1] = crystal.colour(f, pal)
  end
  if #frames == 0 then return nil end
  return frames
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
