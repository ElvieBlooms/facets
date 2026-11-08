-- The DS games' Pokémon on Red, Blue, Yellow, Gold, Silver and Crystal
-- DPPT, HGSS and B2W2 under POKEMON: SET, from the player's own dumps
-- through Prism Importer, as on Gen 3. Every frame of a Pokémon's
-- animation is cut from one rectangle round all of them and fitted to the
-- game's box together (classic.sheet), so the still picture is the first
-- frame and the rest drop in on top of it without a jump. In battle they
-- loop for as long as they're on screen, as on Gen 3: Gold, Silver and
-- Crystal ask for the battle picture every frame (BattleState.pic), and
-- Red, Blue and Yellow draw every picture through picImage. Anything a
-- dump doesn't have, or before it's imported, comes from the DS set
-- Facets ships. Nothing from the games ships with Facets -Elvie
-- --------------------------------------------------

local ds = require("mods.facets.ds")
local bw = require("mods.facets.bw")
local shared = require("mods.facets.classic")

local cds = {}

cds.PREFIX = "ds_"

-- The DS choices for the SET row: one per dump picked in Prism Importer -Elvie
function cds.choices(api)
  local out = {}
  for _, g in ipairs(ds.picked(api)) do out[#out + 1] = { g.label, cds.PREFIX .. g.id } end
  return out
end

-- The dump a SET value names, or nil -Elvie
function cds.game(set)
  if type(set) ~= "string" or set:sub(1, #cds.PREFIX) ~= cds.PREFIX then return nil end
  local id = set:sub(#cds.PREFIX + 1)
  return ds.NAMES[id] and id or nil
end

-- A sheet's frames as separate ImageData, in order. A back keeps only the
-- top 64 rows of the drawing round all its frames, as on Gen 3 (the DS
-- games hide the rest behind the text box); mirror flips each one -Elvie
function cds.frames(data, sprite, back, mirror)
  local box = bw.box(data, sprite)
  if not box then return nil end
  local fw, fh = tonumber(sprite.width), tonumber(sprite.height)
  local cols = math.max(1, tonumber(sprite.columns) or 1)
  local count = math.max(1, tonumber(sprite.frames) or #(sprite.durations or {}) or 1)
  local x0, y0, w, h = box[1], box[2], box[3], box[4]
  if back and h > 64 then h = 64 end
  local sw, sh = data:getDimensions()
  local out = {}
  for n = 0, count - 1 do
    local sx, sy = (n % cols) * fw + x0, math.floor(n / cols) * fh + y0
    if sx + w > sw or sy + h > sh then break end
    local f = love.image.newImageData(w, h)
    if mirror then
      for y = 0, h - 1 do
        for x = 0, w - 1 do f:setPixel(w - 1 - x, y, data:getPixel(sx + x, sy + y)) end
      end
    else
      f:paste(data, 0, 0, sx, sy, w, h)
    end
    out[#out + 1] = f
  end
  if #out == 0 then return nil end
  return out
end

-- One slot of a column sheet of side x side squares, as ImageData -Elvie
function cds.slot(sheet, side, n)
  local w, h = sheet:getDimensions()
  if n < 0 or (n + 1) * side > h or side > w then return nil end
  local out = love.image.newImageData(side, side)
  out:paste(sheet, 0, 0, 0, n * side, side, side)
  return out
end

-- The pictures: build(mod) gives { record(game, dex, face, shiny, mirror,
-- box), frameAt(rec), image(rec, n, colors) } -Elvie
function cds.new(mod)
  local api = ds.api(mod)
  local okA, Assets = pcall(require, "src.render.Assets")
  local self = { api = api }
  local sources, records, images = {}, {}, {}

  -- A Pokémon's animation laid out for the game, or nil: { path (its
  -- sheet, composed), side, sprite (timings), count, still } -Elvie
  function self.record(game, dex, face, shiny, mirror, box)
    if not (api and okA and ds.state(api, game) == "ready") then return nil end
    if type(dex) ~= "number" or dex < 1 or dex == 201 or dex > 493 then return nil end
    local key = ("%s/%d%s_%s%s@%s"):format(game, dex, shiny and "s" or "", face, mirror and "m" or "", box or "cut")
    local hit = records[key]
    if hit ~= nil then return hit or nil end
    records[key] = false
    if sources[game] == nil then sources[game] = bw.dsSource(api, game) or false end
    local src = sources[game]
    if not src then return nil end
    local id = ds.monId(game, face == "back" and "back" or "front", shiny, dex, 0, "")
    local data, sprite = id and src.load(id)
    if not data then return nil end
    local okF, frames = pcall(cds.frames, data, sprite, face == "back", mirror)
    if not (okF and frames) then return nil end
    local order = {}
    for i = 1, #frames do order[i] = i end
    local sheet, side = shared.sheet(frames, order, box)
    if not sheet then return nil end
    local path = "facets/classic/dsanim/" .. key .. ".png"
    Assets.compose(path, function() return sheet end)
    local rec = { path = path, sheet = sheet, side = side, sprite = sprite, count = #frames }
    records[key] = rec
    return rec
  end

  -- Which frame is showing now (0 = the still one): the idle, round and
  -- round -Elvie
  function self.frameAt(rec)
    if not rec or rec.count < 2 then return 0 end
    local now = love.timer and love.timer.getTime() or os.clock()
    return math.min(rec.count - 1, bw.frameAt(rec.sprite, now * 60))
  end

  -- Frame n as an Image; colors (four { r, g, b }) tints it the way Gen 1
  -- tints its own pictures -Elvie
  function self.image(rec, n, colors, tintKey)
    local key = rec.path .. "#" .. n .. (tintKey or "")
    local hit = images[key]
    if hit ~= nil then return hit or nil end
    images[key] = false
    local data = cds.slot(rec.sheet, rec.side, n)
    if not data then return nil end
    if colors then
      local g1 = require("mods.facets.classic_gen1_anim")
      g1.tint(data, colors)
    end
    local ok, img = pcall(love.graphics.newImage, data)
    if not ok then return nil end
    img:setFilter("nearest", "nearest")
    images[key] = img
    return img
  end

  function self.reset() records, images, sources = {}, {}, {} end
  return self
end

return cds
