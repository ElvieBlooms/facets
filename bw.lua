-- BW ANIM: Black/White's animated Pokémon
-- With DarkHeros' BW Animated Sprites installed, the choice is his: Facets
-- steps aside and his mod draws Black/White's animations at their own
-- size. Without it, Facets plays them itself, fitted to Gen 3's 64x64 like
-- the DS choices: from the engine's own Black/White import if there is
-- one (what his mod reads), else Black 2/White 2 through Prism Importer.
-- Each picture loops its idle animation for as long as it's on screen.
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

-- Frame n of a sheet, fitted to 64x64 the way the DS choices are. The
-- frames are the animation's whole extent, so every frame gets the same
-- cut and the animation moves as it should -Elvie
function bw.cut(data, sprite, n, back)
  local fw, fh = tonumber(sprite.width), tonumber(sprite.height)
  local cols = math.max(1, tonumber(sprite.columns) or 1)
  if not (fw and fh) then return nil end
  local sx0, sy0 = (n % cols) * fw, math.floor(n / cols) * fh
  local sw, sh = data:getDimensions()
  if sx0 + fw > sw or sy0 + fh > sh then return nil end
  local keepH, scale = ds.fitPlan(fw, fh, back)
  local ow, oh = math.max(1, math.floor(fw * scale + 0.5)), math.max(1, math.floor(keepH * scale + 0.5))
  local out = love.image.newImageData(ow, oh)
  for y = 0, oh - 1 do
    local sy = sy0 + math.min(keepH - 1, math.floor(y / scale))
    for x = 0, ow - 1 do
      out:setPixel(x, y, data:getPixel(sx0 + math.min(fw - 1, math.floor(x / scale)), sy))
    end
  end
  return out
end

return bw
