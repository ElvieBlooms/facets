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

-- An animation's frames as one sheet: every frame cut to the edge of all
-- of them together and shrunk by the same amount, so nothing jumps when
-- the frame changes. Each sits in a square, centred and on the bottom
-- row, and the square's side (a whole number of tiles) comes back too.
-- frames: list of ImageData; order: which frame goes in each slot -Elvie
function classic.sheet(frames, order, box)
  local x0, y0, x1, y1
  for _, f in ipairs(frames) do
    local a, b, c, d = classic.bounds(f)
    if a then
      x0, y0 = math.min(x0 or a, a), math.min(y0 or b, b)
      x1, y1 = math.max(x1 or c, c), math.max(y1 or d, d)
    end
  end
  if not x0 then return nil end
  local w, h = x1 - x0 + 1, y1 - y0 + 1
  local s = classic.fitScale(w, h, box)
  local ow, oh = math.max(1, math.floor(w * s + 0.5)), math.max(1, math.floor(h * s + 0.5))
  local side = math.ceil(math.max(ow, oh) / 8) * 8
  local out = love.image.newImageData(side, side * #order)
  local left, top = math.floor((side - ow) / 2), side - oh
  for slot, index in ipairs(order) do
    local src = frames[index]
    local base = (slot - 1) * side
    for oy = 0, oh - 1 do
      local sy = y1 - math.min(h - 1, math.floor((oh - 1 - oy + 0.5) / s))
      for ox = 0, ow - 1 do
        local sx = x0 + math.min(w - 1, math.floor((ox + 0.5) / s))
        local r, g, b, a = src:getPixel(sx, sy)
        if a > 0 then out:setPixel(left + ox, base + top + oy, r, g, b, a) end
      end
    end
  end
  return out, side
end

-- A picture flipped left to right, kept the same size -Elvie
function classic.flip(src)
  local w, h = src:getDimensions()
  local out = love.image.newImageData(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local r, g, b, a = src:getPixel(x, y)
      if a > 0 then out:setPixel(w - 1 - x, y, r, g, b, a) end
    end
  end
  return out
end

-- 1 or 2: which Game Boy generation is running -Elvie
function classic.generation()
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if ok and type(GameVersion) == "table" and type(GameVersion.generation) == "function" then
    local okG, gen = pcall(GameVersion.generation)
    if okG and type(gen) == "number" then return gen end
  end
  return 2
end

-- SIZE, for Pokémon and trainers both; added after their rows -Elvie
function classic.sizeRow(rows)
  rows[#rows + 1] = { key = "classicSize", type = "choice", label = "PICTURE SIZE",
    choices = classic.SIZES, default = "fit" }
end

-- One set of pictures for every part: { has(rel), picture(pick) }, or nil
-- when the engine can't take them. pick = { rel, path, box, mirror, scale,
-- load } (load, when there, makes the ImageData instead of rel) -Elvie
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
        -- a picture from another game comes with its own loader -Elvie
        local ok, src
        if pick.load then ok, src = pcall(pick.load) else ok, src = pcall(love.image.newImageData, mod.assets:path(pick.rel)) end
        -- raw: already laid out (an animation's still frame) -Elvie
        local out = ok and src and (pick.raw and src or classic.build(src, pick.box, pick.mirror))
        if out then return out end
        mod.log:warn("%s couldn't be read", pick.rel)
        return love.image.newImageData(1, 1)
      end)
    end
    scaleFor[pick.path] = pick.scale
    return pick.path
  end
  -- The same picture as a PNG in the engine's install cache, for a
  -- screen that loads straight from a file. Kept between runs in a folder
  -- named for Facets' version, the engine's and each imported game's, so
  -- anything new makes them again and the old ones are deleted. nil when
  -- it can't be written -Elvie
  local written, folder = {}, nil
  local function setUpFiles(cache)
    if folder ~= nil then return folder end
    folder = false
    local disk = require("mods.facets.diskcache")
    local okV, Version = pcall(require, "src.core.Version")
    local engine = okV and type(Version) == "table" and (tostring(Version.engine) .. " " .. tostring(Version.cache)) or "?"
    local okC, Contract = pcall(require, "src.import.CacheContract")
    local markers = {}
    for _, g in ipairs({ "firered", "leafgreen", "emerald", "crystal", "gold", "silver" }) do
      local marker = okC and type(Contract) == "table" and type(Contract.readMarker) == "function"
        and select(2, pcall(Contract.readMarker, g)) or nil
      markers[g] = type(marker) == "string" and marker or "none"
    end
    local stamp = disk.hash(disk.stampText(mod.version, engine, markers))
    local okR, old = pcall(cache.read, cache, "pics/stamp.txt")
    if not (okR and old == stamp) then
      local okL, list = pcall(cache.read, cache, "pics/files.txt")
      if okL and type(list) == "string" then
        for rel in list:gmatch("[^\n]+") do pcall(cache.delete, cache, rel) end
      end
      pcall(cache.write, cache, "pics/files.txt", "")
      pcall(cache.write, cache, "pics/stamp.txt", stamp)
    end
    folder = "pics/" .. stamp .. "/"
    return folder
  end
  local listed = nil
  -- name: where it goes under the folder; make: gives the ImageData -Elvie
  function pics.fileOf(name, make)
    local cache = mod.cache
    if not (type(cache) == "table" and type(cache.write) == "function") then return nil end
    local dir = setUpFiles(cache)
    if not dir then return nil end
    local rel = dir .. name:gsub("[^%w%._@/%-]", "_")
    if written[rel] == nil then
      if cache:exists(rel) then
        written[rel] = true
      else
        local ok, data = pcall(make)
        local okE, bytes = false, nil
        if ok and data then okE, bytes = pcall(function() return data:encode("png"):getString() end) end
        written[rel] = okE and type(bytes) == "string" and cache:write(rel, bytes) and true or false
        if written[rel] then
          -- the list of files, so a new folder can clear this one -Elvie
          if listed == nil then
            local okL, list = pcall(cache.read, cache, "pics/files.txt")
            listed = okL and type(list) == "string" and list or ""
          end
          listed = listed .. rel .. "\n"
          pcall(cache.write, cache, "pics/files.txt", listed)
        end
      end
    end
    -- mod.cache sits at mod_cache/<id> in the save folder -Elvie
    return written[rel] and ("mod_cache/" .. mod.id .. "/" .. rel) or nil
  end
  function pics.file(pick)
    return pics.fileOf(pick.path:gsub("^facets/classic/", ""), function()
      return Assets.imageData(pics.picture(pick))
    end)
  end
  -- any picture flipped, as the game would load it: for YOUR SIDE when
  -- the front isn't ours -Elvie
  function pics.flipped(src)
    local path = "facets/classic/flip/" .. src
    if not made[path] then
      made[path] = true
      Assets.compose(path, function()
        local ok, data = pcall(Assets.imageData, src)
        if not ok or not data then
          mod.log:warn("%s couldn't be flipped", tostring(src))
          return love.image.newImageData(1, 1)
        end
        return classic.flip(data)
      end)
    end
    return path
  end

  -- the engine keeps a scaled picture on the ground line, centred -Elvie
  if classic.generation() == 1 then
    -- Gen 1 draws its own backs at 2x; ours are already their size, so
    -- every picture of ours is 1x unless PICTURE SIZE says otherwise -Elvie
    local okB, BattleState = pcall(require, "src.battle.BattleState")
    if okB and type(BattleState) == "table" and type(BattleState.resolveBattleScale) == "function" then
      local own = BattleState.resolveBattleScale
      BattleState.resolveBattleScale = function(data, side, path, species)
        if path and made[path] then return scaleFor[path] or 1 end
        return own(data, side, path, species)
      end
    else
      mod.log:warn("BattleState.resolveBattleScale not found; Gen 1 pictures may be the wrong size")
    end
    return pics
  end
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
