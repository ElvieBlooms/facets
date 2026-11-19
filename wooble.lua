-- WoobleView (gen3-hd-sprites, by poooooby), when it's installed and on.
--
-- Its Battle Fit draws a battle's Pokémon to one scale by their real
-- heights, the camera pulling back for a tall one, for a sprite mod that
-- tags its pictures (WoobleSpritePack). Facets tags the battle pictures it
-- makes the same way: its SET's, Emerald's for FR/LG ANIMS, and YOUR SIDE:
-- FRONT's, each with its side, the Pokémon's height from the player's own
-- game (the Pokédex's), and where in the picture its art is. A sprite
-- pack's own pictures, or any picture another mod has tagged, are left to
-- it. And where the two would both draw the same thing, Facets steps
-- aside: a battle background set (SCENERY and the rest) gives way to
-- WoobleView's zoomed background, or its 3D Battle Scene. -Elvie

local wooble = {}

wooble.ID = "gen3-hd-sprites"

-- WoobleView's exports, or nil -Elvie
function wooble.exports(mod)
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return nil end
  local ok, h = pcall(mod.find, wooble.ID)
  local ex = ok and type(h) == "table" and h.exports or nil
  if type(ex) ~= "table" then return nil end
  if type(ex.isActive) == "function" then
    local okA, on = pcall(ex.isActive)
    if not (okA and on) then return nil end
  end
  return ex
end

-- Battle Fit on (it draws the battle, its background and its Pokémon,
-- zoomed to the screen) -Elvie
function wooble.fitting(mod)
  local ex = wooble.exports(mod)
  if not ex or type(ex.fitEnabled) ~= "function" then return false end
  local ok, on = pcall(ex.fitEnabled)
  return ok and on == true
end

-- A Pokémon's height in metres, from the player's own game's Pokédex,
-- or nil -Elvie
local heights = {}
function wooble.height(species)
  local sp = tonumber(species)
  if not sp then return nil end
  if heights[sp] ~= nil then return heights[sp] or nil end
  local h = false
  pcall(function()
    local Data = require("src.core.game3.pokedex_data")
    -- (its entry's raw height, by the game's own species number: getEntry
    -- would write out the weight too, in the game's text, which isn't
    -- loaded in a battle) -Elvie
    Data.init()
    local raw = type(Data._entries) == "table" and Data._entries[sp]
    local dm = type(raw) == "table" and tonumber(raw.height) or nil
    if dm and dm > 0 then h = dm / 10 end
  end)
  heights[sp] = h
  return h or nil
end

-- Where a picture's art is, { x0, y0, x1, y1 } in its pixels (past the
-- last), from its pixels, or nil -Elvie
function wooble.artBox(data)
  if not (data and data.getDimensions and data.getPixel) then return nil end
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
  if x1 < 0 then return nil end
  return { x0, y0, x1 + 1, y1 + 1 }
end

-- Tag a battle picture Facets made (an entry, { image, imageData }) for
-- Battle Fit: side "enemy" or "player", its species for the height. Once
-- for each picture; never one another mod tagged. Nothing without Battle
-- Fit, or a height -Elvie
local done = setmetatable({}, { __mode = "k" })
function wooble.tag(mod, entry, side, species)
  if type(entry) ~= "table" then return end
  local image = entry.image
  if not (image and image.getDimensions) or done[image] then return end
  local ex = wooble.exports(mod)
  if not ex or type(ex.tag) ~= "function" then return end
  local okF, fit = pcall(ex.fitEnabled)
  if not (okF and fit) then return end
  done[image] = true
  if type(ex.tagOf) == "function" then
    local okT, already = pcall(ex.tagOf, image)
    if okT and already ~= nil then return end
  end
  local h = wooble.height(species)
  if not h then return end
  local spec = { side = side == "player" and "player" or "enemy", height = h, texture = image, filter = "nearest" }
  local art = wooble.artBox(entry.imageData)
  if art then spec.art, spec.top = art, art[2] end
  pcall(ex.tag, image, spec)
end

return wooble
