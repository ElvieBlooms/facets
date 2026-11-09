-- BW ANIM: Black/White's animated Pokémon
-- With DarkHeros' BW Animated Sprites installed, the choice is his: Facets
-- steps aside and his mod draws Black/White's animations at their own
-- size. Without it, Facets plays them itself, fitted to Gen 3's 64x64 like
-- the DS choices: from the engine's own Black/White import if there is
-- one (what his mod reads), else Black 2/White 2 through Prism Importer.
-- Each picture loops its idle animation for as long as it's on screen.
-- The DS choices use the same player for their own dumps (bw.dsSource).
-- Nothing from the games ships with Facets. -Elvie
-- --------------------------------------------------

local ds = require("mods.facets.ds")

local bw = {}

bw.EXTERNAL = "BW-Animated-Sprites"
local IMPORTER, PACK = "gen5_bw", "battle_sprites"

-- Whether DarkHeros' mod is on -Elvie
function bw.external(mod)
  if not (mod and type(mod.find) == "function") then return false end
  local ok, other = pcall(mod.find, bw.EXTERNAL)
  return ok and other ~= nil and other ~= false
end

-- The frame showing after `ticks` 60ths of a second: through the whole
-- animation once, then round from loopStartFrame, as the engine's own
-- Black/White pack plays -Elvie
-- ANIMATION, for every animated look in all three gens: LOOP plays it
-- round and round, INTRO once through as the Pokémon comes out and then
-- holds the still, OFF only the still -Elvie
bw.MODES = { { "LOOP", "loop" }, { "INTRO", "intro" }, { "OFF", "off" } }
function bw.mode(mod)
  local ok, v = pcall(function() return mod.options:get("animMode") end)
  v = ok and v or nil
  if v == "intro" or v == "off" then return v end
  return "loop"
end

-- How long an animation runs once through, in ticks (1/60 s) -Elvie
function bw.total(sprite)
  local d = type(sprite) == "table" and sprite.durations
  if type(d) ~= "table" then return 0 end
  local total = 0
  for _, n in ipairs(d) do total = total + (tonumber(n) or 1) end
  return total
end

-- The frame `ticks` in, for a mode: LOOP's goes round, INTRO's stops on
-- the still (0) once it's been through, OFF's is always the still -Elvie
function bw.playAt(sprite, ticks, mode)
  if mode == "off" then return 0 end
  if mode == "intro" and (ticks or 0) >= bw.total(sprite) then return 0 end
  return bw.frameAt(sprite, ticks or 0)
end

function bw.frameAt(sprite, ticks)
  local d = type(sprite) == "table" and sprite.durations
  if type(d) ~= "table" or #d == 0 then return 0 end
  local total, loopAt = 0, 0
  local loopFrame = tonumber(sprite.loopStartFrame) or 0
  for i, n in ipairs(d) do
    if i - 1 == loopFrame then loopAt = total end
    total = total + (tonumber(n) or 1)
  end
  if total <= 0 then return 0 end
  local t = math.floor(ticks)
  if t >= total then
    local span = total - loopAt
    if span <= 0 then return #d - 1 end
    t = loopAt + (t - total) % span
  end
  local at = 0
  for i, n in ipairs(d) do
    at = at + (tonumber(n) or 1)
    if t < at then return i - 1 end
  end
  return #d - 1
end

-- Where the pictures come from: the engine's Black/White import, else
-- Prism Importer's Black 2/White 2. Returns { name, load(id) } or nil;
-- load gives the sheet's ImageData and its sprite table -Elvie
function bw.source(mod)
  local packs = mod and mod.packs
  if type(packs) == "table" and type(packs.info) == "function" then
    local ok, info = pcall(packs.info, packs, IMPORTER, PACK)
    if ok and info then
      return { name = "Black/White", load = function(id)
        local okE, entry = pcall(packs.entry, packs, IMPORTER, PACK, id)
        if not (okE and type(entry) == "table" and type(entry.sprite) == "table") then return nil end
        local okR, bytes = pcall(packs.read, packs, IMPORTER, PACK, id)
        if not (okR and type(bytes) == "string") then return nil end
        local okD, data = pcall(function()
          return love.image.newImageData(love.filesystem.newFileData(bytes, "bw.png"))
        end)
        if not okD then return nil end
        return data, entry.sprite
      end }
    end
  end
  local api = ds.api(mod)
  if api and ds.state(api, "bw2") == "ready" then
    return { name = "Black 2/White 2", load = function(id)
      local ok, data, entry = pcall(api.imageData, "bw2", "battle_sprites", id)
      if not (ok and data and type(entry) == "table" and type(entry.sprite) == "table") then return nil end
      return data, entry.sprite
    end }
  end
  return nil
end

-- Gen 4's sheets are two frames with no timing of their own: the still
-- picture held, then the second frame for a beat, round and round -Elvie
bw.GEN4_BEAT = { 60, 20 }

-- A DS dump's battle sprites through Prism Importer, as a source like the
-- one above. Gen 4's get the beat for timing -Elvie
function bw.dsSource(api, game)
  if not (api and type(api.imageData) == "function") then return nil end
  return { name = game, load = function(id)
    local ok, data, entry = pcall(api.imageData, game, "battle_sprites", id)
    if not (ok and data and type(entry) == "table") then return nil end
    local sp = type(entry.sprite) == "table" and entry.sprite or {}
    local sprite = {}
    for k, v in pairs(sp) do sprite[k] = v end
    local sw, sh = data:getDimensions()
    sprite.height = tonumber(sprite.height) or sh
    sprite.width = tonumber(sprite.width) or sprite.height
    sprite.columns = tonumber(sprite.columns) or math.max(1, math.floor(sw / sprite.width))
    sprite.frames = tonumber(sprite.frames) or tonumber(entry.frames) or sprite.columns
    if type(sprite.durations) ~= "table" or #sprite.durations == 0 then
      if sprite.frames < 2 then
        sprite.durations = { 1 }
      else
        sprite.durations = { bw.GEN4_BEAT[1], bw.GEN4_BEAT[2] }
      end
      sprite.loopStartFrame = 0
    end
    return data, sprite
  end }
end

-- The drawn part of every frame together, in frame pixels, so each frame
-- is cut from the same rectangle and the animation stays put -Elvie
function bw.box(data, sprite)
  local fw, fh = tonumber(sprite.width), tonumber(sprite.height)
  local cols = math.max(1, tonumber(sprite.columns) or 1)
  local count = math.max(1, tonumber(sprite.frames) or (type(sprite.durations) == "table" and #sprite.durations) or 1)
  if not (fw and fh) then return nil end
  local sw, sh = data:getDimensions()
  local x0, y0, x1, y1
  for n = 0, count - 1 do
    local sx0, sy0 = (n % cols) * fw, math.floor(n / cols) * fh
    if sx0 + fw <= sw and sy0 + fh <= sh then
      for y = 0, fh - 1 do
        for x = 0, fw - 1 do
          local _, _, _, a = data:getPixel(sx0 + x, sy0 + y)
          if a > 0 then
            if not x0 or x < x0 then x0 = x end
            if not x1 or x > x1 then x1 = x end
            if not y0 or y < y0 then y0 = y end
            if not y1 or y > y1 then y1 = y end
          end
        end
      end
    end
  end
  if not x0 then return nil end
  return { x0, y0, x1 - x0 + 1, y1 - y0 + 1 }
end

-- Frame n of a sheet, fitted to 64x64 the way the DS choices are. box
-- (from bw.box) is the part to cut, the same for every frame; without it
-- the whole frame -Elvie
function bw.cut(data, sprite, n, back, box)
  local fw, fh = tonumber(sprite.width), tonumber(sprite.height)
  local cols = math.max(1, tonumber(sprite.columns) or 1)
  if not (fw and fh) then return nil end
  local sx0, sy0 = (n % cols) * fw, math.floor(n / cols) * fh
  local sw, sh = data:getDimensions()
  if sx0 + fw > sw or sy0 + fh > sh then return nil end
  local bx, by, bw_, bh = 0, 0, fw, fh
  if box then bx, by, bw_, bh = box[1], box[2], box[3], box[4] end
  local keepH, scale = ds.fitPlan(bw_, bh, back)
  local ow, oh = math.max(1, math.floor(bw_ * scale + 0.5)), math.max(1, math.floor(keepH * scale + 0.5))
  local out = love.image.newImageData(ow, oh)
  for y = 0, oh - 1 do
    local sy = sy0 + by + math.min(keepH - 1, math.floor(y / scale))
    for x = 0, ow - 1 do
      out:setPixel(x, y, data:getPixel(sx0 + bx + math.min(bw_ - 1, math.floor(x / scale)), sy))
    end
  end
  return out
end

return bw
