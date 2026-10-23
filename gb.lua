-- Game Boy sprites, read from the player's own install
-- A "gb" set ships no art, only gb.json: which Gen 1/2 overworld sprite
-- and palette stands in for each Gen 3 NPC. The sprite is read from the
-- player's imported Crystal (then Gold, Silver, Yellow, Red, Blue) cache
-- at runtime and drawn at 1x, coloured with Crystal's daytime NPC
-- palettes. A player without those games imported just sees the next set,
-- or the game's own NPC. NPCs no Game Boy game has use strips shipped in
-- the set (strips/), in the same layout with their own colours. -Elvie
-- --------------------------------------------------

local gb = {}

gb.GAMES = { "crystal", "gold", "silver", "yellow", "red", "blue" }

-- Crystal's daytime OBJ palettes (MapObjectPals, DAY), colours 1-3; colour
-- 0 is see-through. The same values the engine draws Crystal's NPCs with. -Elvie
gb.PALETTES = {
  PAL_OW_RED   = { { 255, 156, 82 }, { 255, 58, 8 },   { 0, 0, 0 } },
  PAL_OW_BLUE  = { { 255, 156, 82 }, { 82, 74, 255 },  { 0, 0, 0 } },
  PAL_OW_GREEN = { { 255, 156, 82 }, { 58, 189, 25 },  { 0, 0, 0 } },
  PAL_OW_BROWN = { { 255, 156, 82 }, { 123, 82, 25 },  { 0, 0, 0 } },
  PAL_OW_PINK  = { { 255, 156, 82 }, { 247, 82, 49 },  { 0, 0, 0 } },
}

-- The cached overworld sprites are greyscale: 255 is see-through, then
-- 170, 85 and 0 for palette colours 1-3. -Elvie
function gb.shade(v)
  if v > 0.83 then return nil end
  if v > 0.5 then return 1 end
  if v > 0.17 then return 2 end
  return 3
end

-- Reads <game>/<rel> from the first game in the list that has it (the
-- player's imported cache). Returns the bytes and the game, or nil. -Elvie
local CacheFs
function gb.readAt(rel, games)
  if type(rel) ~= "string" or rel:find("%.%.") then return nil end
  if CacheFs == nil then
    local ok, m = pcall(require, "src.import.CacheFs")
    CacheFs = ok and type(m) == "table" and type(m.readAt) == "function" and m or false
  end
  if not CacheFs then return nil end
  for _, game in ipairs(games or gb.GAMES) do
    local ok, bytes = pcall(CacheFs.readAt, game .. "/" .. rel)
    if ok and type(bytes) == "string" then return bytes, game end
  end
  return nil
end

-- A PNG from the first game that has it, as ImageData. -Elvie
function gb.readImage(rel, games)
  if not (love and love.image and love.data) then return nil end
  for _, game in ipairs(games or gb.GAMES) do
    local bytes = gb.readAt(rel, { game })
    if bytes then
      local ok, data = pcall(function() return love.image.newImageData(love.data.newByteData(bytes)) end)
      if ok and data then return data, game end
    end
  end
  return nil
end

-- An overworld sprite, <game>/assets/generated/sprites/<sprite>.png. -Elvie
function gb.read(sprite, games)
  if type(sprite) ~= "string" or sprite:find("[^%w_]") then return nil end
  return gb.readImage("assets/generated/sprites/" .. sprite .. ".png", games)
end

-- GB frames, 16x16 each, stacked: stand down, up, left, then walk down,
-- up, left (a standing-only NPC has just the first three, a few one).
-- The Gen 3 walk cycle steps between a walk frame and its mirror, as the
-- Game Boy did; walking left steps between the walk and stand frames. -Elvie
local FROM = { 1, 2, 3, 4, 4, 5, 5, 6, 3 }
local MIRROR = { false, false, false, false, true, false, true, false, false }

-- A pixel's colour: a cached sprite's shade through the palette, or a
-- strip's own colour (pal nil) where it isn't see-through. -Elvie
local function colourAt(src, pal, x, y)
  local r, g, b, a = src:getPixel(x, y)
  if not pal then
    if a and a > 0 then return { r * 255, g * 255, b * 255 } end
    return nil
  end
  local k = gb.shade(r)
  return k and pal[k] or nil
end

-- Builds a 9-frame sheet, w wide and h tall per frame, the sprite centred
-- with its feet on the feet row. scale 1 is the Game Boy's own size (in
-- the game's frame); scale 2 draws each pixel as a 2x2 block, filling a
-- 32x32 frame. paletteName false keeps the strip's own colours (strips
-- shipped in the GBC set). Returns ImageData, or nil and a reason. -Elvie
function gb.sheet(src, paletteName, w, h, scale)
  scale = scale == 2 and 2 or 1
  local pal
  if paletteName ~= false then
    pal = gb.PALETTES[paletteName or "PAL_OW_RED"]
    if not pal then return nil, "no palette " .. tostring(paletteName) end
  end
  local sw, sh = src:getDimensions()
  if sw ~= 16 or sh % 16 ~= 0 then return nil, ("%dx%d isn't a Game Boy sprite strip"):format(sw, sh) end
  -- Frames are counted by what's drawn: some standing-only NPCs (Crystal's
  -- captain) come padded to six frames with the walk frames left blank. -Elvie
  local count = 0
  for f = 1, sh / 16 do
    local drawn = false
    for y = (f - 1) * 16, f * 16 - 1 do
      for x = 0, 15 do
        if not drawn and colourAt(src, pal, x, y) then drawn = true end
      end
    end
    if drawn then count = f end
  end
  if count == 0 then return nil, "the sprite is empty" end
  if count > 3 and count < 6 then count = 3 end
  local out = love.image.newImageData(w, h * 9)
  local size = 16 * scale
  local ox = math.floor((w - size) / 2)
  local oy = h > size and h - size - 1 or h - size
  for i = 1, 9 do
    local f = FROM[i]
    if f > count then f = (f - 1) % 3 + 1 end
    if f > count then f = 1 end
    local top = (f - 1) * 16
    for y = 0, 15 do
      for x = 0, 15 do
        local sx = MIRROR[i] and (15 - x) or x
        local c = colourAt(src, pal, sx, top + y)
        if c then
          for by = 0, scale - 1 do
            for bx = 0, scale - 1 do
              local dx, dy = ox + x * scale + bx, oy + y * scale + by
              if dx >= 0 and dx < w and dy >= 0 and dy < h then
                out:setPixel(dx, (i - 1) * h + dy, c[1] / 255, c[2] / 255, c[3] / 255, 1)
              end
            end
          end
        end
      end
    end
  end
  return out
end

return gb
