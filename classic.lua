-- Pictures for the Game Boy games (Gold, Silver, Crystal)
-- What the Pokémon and trainer parts share: cutting a set's art to its
-- edge, fitting it to the game's own box, and handing it to the game under
-- a "facets/classic/..." path made in memory (Assets.compose), so the game
-- loads it like one of its own files. SIZE's fixed scales go through the
-- engine's own picture scale, for our battle pictures only. -Elvie
-- --------------------------------------------------

local classic = {}

-- The game's own boxes: hlcoord 12,0 7x7 tiles and hlcoord 2,6 6x6 -Elvie
classic.BOX = { front = 56, back = 48 }

-- Nothing past 1X: a bigger picture runs off the top of the screen -Elvie
classic.SIZES = { { "FIT", "fit" }, { "0.5X", "0.5" }, { "0.75X", "0.75" }, { "1X", "1" } }

-- The see-through edge around the art: x0, y0, x1, y1 (inclusive), or
-- nil when nothing is drawn -Elvie
function classic.bounds(data)
  local w, h = data:getDimensions()
  local x0, y0, x1, y1
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local _, _, _, a = data:getPixel(x, y)
      if a > 0 then
        if not x0 or x < x0 then x0 = x end
        if not x1 or x > x1 then x1 = x end
        if not y0 then y0 = y end
        y1 = y
      end
    end
  end
  if not x0 then return nil end
  return x0, y0, x1, y1
end

-- How much a w x h picture shrinks to fit a box; never grows -Elvie
function classic.fitScale(w, h, box)
  if not box then return 1 end
  return math.min(1, box / w, box / h)
end

-- The art cut to its edge, shrunk to fit box (nearest pixel) when there is
-- one, and flipped when mirror is set. Returns new ImageData, or nil for
-- an empty picture. -Elvie
function classic.build(src, box, mirror)
  local x0, y0, x1, y1 = classic.bounds(src)
  if not x0 then return nil end
  local w, h = x1 - x0 + 1, y1 - y0 + 1
  local s = classic.fitScale(w, h, box)
  local ow, oh = math.max(1, math.floor(w * s + 0.5)), math.max(1, math.floor(h * s + 0.5))
  local out = love.image.newImageData(ow, oh)
  for oy = 0, oh - 1 do
    -- sample from the bottom up, so the feet stay on the ground line -Elvie
    local sy = y1 - math.min(h - 1, math.floor((oh - 1 - oy + 0.5) / s))
    for ox = 0, ow - 1 do
      local sx = x0 + math.min(w - 1, math.floor((ox + 0.5) / s))
      local r, g, b, a = src:getPixel(sx, sy)
      if a > 0 then out:setPixel(mirror and (ow - 1 - ox) or ox, oy, r, g, b, a) end
    end
  end
  return out
end

-- SIZE, for Pokémon and trainers both; added after their rows -Elvie
function classic.sizeRow(rows)
  rows[#rows + 1] = { key = "classicSize", type = "choice", label = "PICTURE SIZE",
    choices = classic.SIZES, default = "fit" }
end

-- One set of pictures for every part: { has(rel), picture(pick) }, or nil
-- when the engine can't take them. pick = { rel, path, box, mirror, scale } -Elvie
local pics
function classic.setup(mod)
  if pics ~= nil then return pics or nil end
  local okA, Assets = pcall(require, "src.render.Assets")
  if not (okA and type(Assets) == "table" and type(Assets.compose) == "function") then
    mod.log:warn("Assets.compose not found; pictures are off")
    pics = false
    return nil
  end
  local found, made, scaleFor = {}, {}, {}
  pics = {}
  function pics.has(rel)
    local got = found[rel]
    if got == nil then
      got = mod.assets:info(rel) ~= nil
      found[rel] = got
    end
    return got
  end
  function pics.picture(pick)
    if not made[pick.path] then
      made[pick.path] = true
      Assets.compose(pick.path, function()
        local ok, src = pcall(love.image.newImageData, mod.assets:path(pick.rel))
        local out = ok and classic.build(src, pick.box, pick.mirror)
        if out then return out end
        mod.log:warn("%s couldn't be read", pick.rel)
        return love.image.newImageData(1, 1)
      end)
    end
    if pick.scale then scaleFor[pick.path] = pick.scale end
    return pick.path
  end

  -- the engine keeps a scaled picture on the ground line, centred -Elvie
  local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
  if okB and type(BattleState) == "table" and type(BattleState.picScale) == "function" then
    local own = BattleState.picScale
    BattleState.picScale = function(self, path, mon, back)
      local s = scaleFor[path]
      if s then return s end
      return own(self, path, mon, back)
    end
  else
    mod.log:warn("BattleState.picScale not found; PICTURE SIZE only fits")
  end
  return pics
end

-- for the tests -Elvie
function classic.reset() pics = nil end

return classic
