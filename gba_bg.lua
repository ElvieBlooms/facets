-- The GBA games' own battle backgrounds, as BATTLE BG choices everywhere
-- FRLG, EMERALD and R/S: each game's background with its two platforms,
-- built from the player's own imported FireRed or LeafGreen, Emerald, or
-- Ruby or Sapphire (the engine keeps them in its import cache as it
-- imports), so nothing from the games ships with Facets. In Red, Blue,
-- Yellow, Gold, Silver and Crystal they're scene sets like SCENERY; in
-- the GBA games they can stand in for the game's own, so FireRed can
-- fight on Emerald's -Elvie
-- --------------------------------------------------

local gb = require("mods.facets.gb")

local gbaBg = {}

gbaBg.SETS = {
  { key = "gba_frlg", label = "FRLG", games = { "firered", "leafgreen" }, name = "FireRed or LeafGreen" },
  { key = "gba_emerald", label = "EMERALD", games = { "emerald" }, name = "Emerald" },
  { key = "gba_rs", label = "R/S", games = { "ruby", "sapphire" }, name = "Ruby or Sapphire" },
}
gbaBg.BY_KEY = {}
for _, set in ipairs(gbaBg.SETS) do gbaBg.BY_KEY[set.key] = set end

gbaBg.DIR = "data/generated/gba/pokemon/battle/"
gbaBg.W, gbaBg.H = 240, 112

-- What each terrain looks like as one of Facets' scenes, for SCENE TIME's
-- light (outdoors or not) -Elvie
gbaBg.SCENE_OF = {
  grass = "grass", long_grass = "forest", sand = "beach", underwater = "underwater", water = "sea",
  pond = "lake", mountain = "mountain", cave = "cave", building = "indoors", plain = "route",
  link = "neutral", tower = "neutral", frontier = "neutral", gym = "gym", leader = "gym",
  indoor_1 = "indoors", indoor_2 = "indoors", lorelei = "gym", bruno = "gym", agatha = "gym", lance = "gym",
  champion = "space", groudon = "volcano", magma = "volcano", kyogre = "sea", aqua = "sea",
  rayquaza = "space", sidney = "gym", phoebe = "gym", glacia = "gym", drake = "gym",
}

-- The terrains to try, in order, for a GBA terrain from another game or
-- one of Facets' scene names (Red to Crystal's battles): the closest each
-- game has comes first -Elvie
gbaBg.TRY = {
  -- scene names -Elvie
  forest = { "long_grass", "grass" }, beach = { "sand" }, desert = { "sand" }, sea = { "water" },
  lake = { "pond", "water" }, lab = { "building" }, indoors = { "building" }, route = { "plain", "grass" },
  town = { "plain", "grass" }, neutral = { "plain", "building" }, snow = { "plain", "grass" },
  snow_cave = { "cave" }, snow_mountain = { "mountain" }, volcano = { "groudon", "magma", "mountain" },
  space = { "champion", "rayquaza" },
  -- one game's terrains in another's -Elvie
  gym = { "gym", "leader", "building" }, leader = { "leader", "gym", "building" },
  champion = { "champion", "leader", "building" },
  lorelei = { "lorelei", "glacia", "leader" }, bruno = { "bruno", "drake", "leader" },
  agatha = { "agatha", "phoebe", "leader" }, lance = { "lance", "drake", "leader" },
  sidney = { "sidney", "agatha", "leader" }, phoebe = { "phoebe", "agatha", "leader" },
  glacia = { "glacia", "lorelei", "leader" }, drake = { "drake", "lance", "leader" },
  indoor_1 = { "indoor_1", "building" }, indoor_2 = { "indoor_2", "building" },
  link = { "link", "building" }, tower = { "tower", "frontier", "building" }, frontier = { "frontier", "tower", "building" },
  groudon = { "groudon", "magma", "mountain" }, magma = { "magma", "groudon", "building" },
  kyogre = { "kyogre", "aqua", "water" }, aqua = { "aqua", "kyogre", "building" },
  rayquaza = { "rayquaza", "champion" },
}

-- The terrains to try for a name, ending on the plain ones every game
-- has -Elvie
function gbaBg.candidates(name)
  name = tostring(name or "")
  local out, seen = {}, {}
  local function add(k) if not seen[k] then seen[k] = true; out[#out + 1] = k end end
  add(name)
  for _, k in ipairs(gbaBg.TRY[name] or {}) do add(k) end
  add("building"); add("grass")
  return out
end

-- Whether the player has imported one of a set's games: the game, or nil -Elvie
function gbaBg.game(set)
  set = type(set) == "table" and set or gbaBg.BY_KEY[set]
  return set and gb.imported(set.games) or nil
end

local bytes = {}
local function read(game, file)
  local id = game .. "/" .. file
  local hit = bytes[id]
  if hit ~= nil then return hit or nil end
  local got = gb.readAt(gbaBg.DIR .. file, { game })
  bytes[id] = type(got) == "string" and #got >= 256 * 160 * 4 and got or false
  return bytes[id] or nil
end

-- A background and its platforms laid together, the part above the text
-- box (240x112), as ImageData; nil when they can't be read -Elvie
function gbaBg.compose(bg, enemy, player)
  local w, h = gbaBg.W, gbaBg.H
  local layers = {}
  for _, raw in ipairs({ bg, enemy, player }) do
    if raw then layers[#layers + 1] = love.image.newImageData(256, 160, "rgba8", raw:sub(1, 256 * 160 * 4)) end
  end
  if #layers == 0 then return nil end
  local out = love.image.newImageData(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local r, g, b = 0, 0, 0
      for _, l in ipairs(layers) do
        local lr, lg, lb, la = l:getPixel(x, y)
        if la > 0 then r, g, b = lr * la + r * (1 - la), lg * la + g * (1 - la), lb * la + b * (1 - la) end
      end
      out:setPixel(x, y, r, g, b, 1)
    end
  end
  return out
end

-- A set's background for a terrain or scene name: ImageData and the
-- terrain it came from, or nil (not imported, or nothing to show).
-- Built once each -Elvie
local built = {}
function gbaBg.imageData(setKey, name)
  local set = gbaBg.BY_KEY[setKey]
  local game = set and gbaBg.game(set)
  if not game then return nil end
  for _, key in ipairs(gbaBg.candidates(name)) do
    if key:match("^[%w_]+$") then
      local id = game .. "/" .. key
      local hit = built[id]
      if hit == nil then
        local bg = read(game, "terrain_bg_" .. key .. ".rgba")
        local ok, data = false, nil
        if bg then
          ok, data = pcall(gbaBg.compose, bg, read(game, "terrain_enemy_" .. key .. ".rgba"),
            read(game, "terrain_player_" .. key .. ".rgba"))
        end
        hit = ok and data or false
        built[id] = hit
      end
      if hit then return hit, key end
    end
  end
  return nil
end

-- The scene name SCENE TIME goes by for a terrain -Elvie
function gbaBg.sceneName(key)
  return gbaBg.SCENE_OF[tostring(key or "")] or "neutral"
end

-- For the tests, and after an import -Elvie
function gbaBg.reset() bytes, built = {}, {} end

return gbaBg
