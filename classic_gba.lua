-- The GBA look for the Game Boy games: NPCs, trainers and Pokémon from
-- the player's own imported FireRed (or LeafGreen) and Emerald, read from
-- the engine's cache of those games while you play. Nothing from any game
-- is included with Facets. -Elvie
--
-- FIRERED reads FireRed, then LeafGreen, then Emerald for anyone missing;
-- EMERALD reads Emerald first. Names are turned into the games' own ids
-- with gba_ids.lua (made by tools/make_gba_ids.py), since a Gen 2 game
-- can't load the engine's Gen 3 modules. -Elvie
-- --------------------------------------------------

local gba = {}

gba.CHOICES = { { "FIRERED", "gba_firered" }, { "EMERALD", "gba_emerald" } }

-- the games each choice reads, in order, and the id table each uses -Elvie
gba.ORDER = {
  gba_firered = { "firered", "leafgreen", "emerald" },
  gba_emerald = { "emerald", "firered", "leafgreen" },
}
gba.TABLE = { firered = "firered", leafgreen = "firered", emerald = "emerald" }

function gba.isChoice(value) return gba.ORDER[value] ~= nil end

local ids
local function idTable(game)
  if ids == nil then
    local ok, got = pcall(require, "mods.facets.gba_ids")
    ids = ok and type(got) == "table" and got or false
  end
  return ids and ids[gba.TABLE[game]] or nil
end

-- The engine's Gen 3 cache folder, from its extractor, so Facets doesn't
-- name it itself -Elvie
local root
local function cacheRoot()
  if root == nil then
    local ok, Extract = pcall(require, "src.import.gba.extract_island1")
    root = ok and type(Extract) == "table" and type(Extract.CACHE_ROOT) == "string" and Extract.CACHE_ROOT or false
  end
  return root or nil
end

-- One cached file's bytes, decoded, or nil. Misses are kept until reset()
-- so a missing game isn't read every frame -Elvie
local CacheFs
local seen = {}
function gba.read(game, rel)
  local base = cacheRoot()
  if not base then return nil end
  local key = game .. "/" .. base .. "/" .. rel
  local hit = seen[key]
  if hit == false then return nil end
  if CacheFs == nil then
    local ok, m = pcall(require, "src.import.CacheFs")
    CacheFs = ok and type(m) == "table" and type(m.readAt) == "function" and m or false
  end
  if not CacheFs then return nil end
  local ok, bytes = pcall(CacheFs.readAt, key)
  if ok and type(bytes) == "string" then
    seen[key] = true
    return bytes
  end
  seen[key] = false
  return nil
end

-- forget misses: a game imported since -Elvie
function gba.reset() seen = {}; gba.sizes = {} end

-- Raw RGBA bytes as ImageData, or nil when the size is wrong -Elvie
function gba.image(bytes, w, h)
  if type(bytes) ~= "string" or #bytes ~= w * h * 4 then return nil end
  local ok, data = pcall(love.image.newImageData, w, h, "rgba8", bytes)
  return ok and data or nil
end

-- A Pokémon picture: { game, rel } for the first game that has it, shiny
-- falling back to plain. face is "front" or "back" -Elvie
function gba.monPicture(choice, dex, face, shiny)
  local order = gba.ORDER[choice]
  if not order or type(dex) ~= "number" or dex < 1 or dex > 251 then return nil end
  for _, game in ipairs(order) do
    for _, dir in ipairs(shiny and { face .. "_shiny", face } or { face }) do
      local rel = "pokemon/" .. dir .. "/" .. dex .. ".rgba"
      if gba.read(game, rel) then return { game = game, rel = rel, w = 64, h = 64 } end
    end
  end
  return nil
end

-- A trainer picture by Gen 3 names (TRAINER_PIC_ without the prefix) -Elvie
function gba.trainerPicture(choice, names)
  local order = gba.ORDER[choice]
  if not order then return nil end
  for _, game in ipairs(order) do
    local t = idTable(game)
    for _, name in ipairs(names) do
      local id = t and t.pics[name]
      if id then
        local rel = "trainers/front/" .. id .. ".rgba"
        if gba.read(game, rel) then return { game = game, rel = rel, w = 64, h = 64 } end
      end
    end
  end
  return nil
end

-- An overworld sheet's size from the game's ow/manifest.lua: atlas w, h -Elvie
gba.sizes = {}
function gba.sheetSize(game, id)
  local sizes = gba.sizes[game]
  if not sizes then
    sizes = {}
    local text = gba.read(game, "ow/manifest.lua")
    for n, body in (text or ""):gmatch("%[(%d+)%]%s*=%s*{([^}]*)}") do
      local w, h = body:match("atlasW%s*=%s*(%d+)"), body:match("atlasH%s*=%s*(%d+)")
      local inanimate = body:match("inanimate%s*=%s*true") ~= nil
      if w and h then sizes[tonumber(n)] = { tonumber(w), tonumber(h), inanimate } end
    end
    gba.sizes[game] = sizes
  end
  return sizes[id]
end

-- An NPC sheet by Gen 3 names (OBJ_EVENT_GFX_ without the prefix): a
-- walking person's sheet, 9 frames or more, 32 tall or the small 16x16
-- ones (FireRed's Little Boy and Little Girl) -Elvie
function gba.walks(size)
  if type(size) ~= "table" or size[3] then return false end
  local w, h = size[1], size[2]
  return h >= 9 * 32 or (w <= 16 and h >= 9 * 16 and h % 16 == 0)
end

function gba.npcSheet(choice, names)
  local order = gba.ORDER[choice]
  if not order then return nil end
  for _, game in ipairs(order) do
    local t = idTable(game)
    for _, name in ipairs(names) do
      local id = t and t.ow[name]
      local size = id and gba.sheetSize(game, id)
      if gba.walks(size) then
        local rel = "ow/" .. id .. ".rgba"
        if gba.read(game, rel) then return { game = game, rel = rel, w = size[1], h = size[2] } end
      end
    end
  end
  return nil
end

-- ImageData for one of the finds above -Elvie
-- Emerald's two-frame front (64x128: still, then moving), for a choice
-- that reads Emerald for this Pokémon; FireRed and LeafGreen have none -Elvie
function gba.monAnim(choice, dex, shiny)
  local found = gba.monPicture(choice, dex, "front", shiny)
  if not found or found.game ~= "emerald" then return nil end
  for _, dir in ipairs(shiny and { "front_anim_shiny", "front_anim" } or { "front_anim" }) do
    local rel = "pokemon/" .. dir .. "/" .. dex .. ".rgba"
    if gba.read("emerald", rel) then return { game = "emerald", rel = rel, w = 64, h = 128 } end
  end
  return nil
end

-- Its two frames, as 64x64 ImageData each -Elvie
function gba.animFrames(found)
  local data = gba.load(found)
  if not data then return nil end
  local a, b = love.image.newImageData(64, 64), love.image.newImageData(64, 64)
  a:paste(data, 0, 0, 0, 0, 64, 64)
  b:paste(data, 0, 0, 0, 64, 64, 64)
  return a, b
end

function gba.load(found)
  return found and gba.image(gba.read(found.game, found.rel), found.w, found.h) or nil
end

return gba
