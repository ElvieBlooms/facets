-- NPC overworld sprites (FireRed, LeafGreen, Ruby, Sapphire, Emerald)
-- Every overworld sheet, NPC or player, is fetched through OwSprites.get,
-- so one wrapper there covers drawing, the weather mask, reflections and
-- the Fame Checker icons. Files are named after the game's own sprite
-- names (NURSE.png, BROCK.png), so the folder is the mapping: the names
-- are turned into graphics ids from the engine's event_objects table for
-- the running game. -Elvie
--
-- Emerald Lens wraps the same function for the player and the rival.
-- Facets never touches those ids (names.lua), so each wrapper passes the
-- other's ids straight through and load order doesn't matter. -Elvie
-- --------------------------------------------------

local names = require("mods.facets.names")
local gb = require("mods.facets.gb")

local gen3 = {}

local PREFIX = "OBJ_EVENT_GFX_"
local WIDE = 32 -- the frame size for art drawn bigger than the game's own (Gen 4 style)

-- Logs a bad file once instead of every frame it's requested. -Elvie
local warned = {}
local function warnOnce(mod, key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  mod.log:warn(fmt, ...)
end

-- ctx comes from npcs.lua: { setKeys, npcsDir }, with setKeys in fallback
-- order, the selected set first. nil means OFF: everything is the game's
-- own. Returns a handle whose configure(ctx) changes the choice later. -Elvie
function gen3.init(mod, ctx)
  local GameVersion = require("src.core.GameVersion")
  local version = GameVersion.get()
  local family = GameVersion.layout(version)
  if family ~= "frlg" and family ~= "rse" then return nil end

  -- Graphics id names for this game. LeafGreen reads FireRed's table and
  -- Sapphire Ruby's, through the engine's own lookup. -Elvie
  local okC, Constants = pcall(require, "src.core.game3.constants")
  local okT, objects = false, nil
  if okC and type(Constants.of) == "function" then
    okT, objects = pcall(function() return Constants.of(version):raw("event_objects") end)
  end
  local nameOf = okT and type(objects) == "table" and type(objects.byId) == "table"
    and objects.byId[PREFIX] or nil
  if type(nameOf) ~= "table" then
    mod.log:warn("no graphics id names for %s; Facets is off", tostring(version))
    return nil
  end

  local okOw, OwSprites = pcall(require, "src.core.game3.ow_sprites")
  if not okOw or type(OwSprites) ~= "table" or type(OwSprites.get) ~= "function" then
    mod.log:warn("OwSprites.get not found; Facets is off")
    return nil
  end

  -- The current choice. Everything below reads these, so configure() only
  -- has to replace them. -Elvie
  local bases = {}    -- sets to look in, in fallback order: { dir, gb = map or nil }
  local fileFor       -- [graphics id] = file, or a Game Boy entry; nil = look again
  local built         -- [vanilla record] = our record, or false if it failed
  local replaced = {} -- [graphics id] = true once handed out, for cache drops

  -- Lists each folder once and keeps the first file found for each id,
  -- by the sprite's own name, then its other-game alias. File names are
  -- matched without regard to case. A Game Boy set offers the names in its
  -- map whose sprite the player's install has, so a missing one falls
  -- through to the next set like a missing file. -Elvie
  local function resolveFiles()
    fileFor = {}
    local filesIn = {}
    for i, base in ipairs(bases) do
      local byName = {}
      if base.gb then
        for name, entry in pairs(base.gb) do
          if type(entry) == "string" then entry = { sprite = entry } end
          if type(entry) == "table" and type(entry.sprite) == "string" then
            local src, game = gb.read(entry.sprite, entry.games)
            if src then
              byName[name:upper()] = { gb = entry, src = src, scale = base.scale,
                label = ("%s (%s's %s)"):format(name:upper(), game, entry.sprite) }
            end
          end
        end
      else
        for _, file in ipairs(mod.assets:list(base.dir)) do
          local stem = file:match("^(.+)%.[Pp][Nn][Gg]$")
          if stem then byName[stem:upper()] = base.dir .. "/" .. file end
        end
      end
      filesIn[i] = byName
    end
    for id, full in pairs(nameOf) do
      local name = type(full) == "string" and full:sub(#PREFIX + 1) or nil
      if name and full:sub(1, #PREFIX) == PREFIX and not names.skipped(family, name) then
        local found
        for i = 1, #bases do
          for _, candidate in ipairs(names.candidates(family, name)) do
            found = found or filesIn[i][candidate]
          end
          if found then break end
        end
        if found then fileFor[tonumber(id)] = found end
      end
    end
  end

  -- Accepted sheets: frames stacked in one column, the game's frame size
  -- or 32x32 for a 16-wide person, and 9 frames or the game's own count.
  -- FR/LG trainers have a 10th frame (the VS Seeker hand raise) and the
  -- nurse a bow; with 9 frames those show the standing frame instead,
  -- since the engine only uses frame 9 when frameCount > 9. -Elvie
  local function build(vanilla, ref, id)
    local rel = type(ref) == "table" and ref.label or ref
    local w0, h0, n0 = vanilla.width, vanilla.height, vanilla.frameCount
    if not (w0 and h0 and n0) then return nil end
    if vanilla.inanimate or n0 < 9 or w0 > WIDE or h0 > WIDE then
      warnOnce(mod, rel, "%s: the game's sprite here isn't a walking person (%dx%d, %d frames); skipping it",
        rel, w0, h0, n0)
      return nil
    end
    if not (love and love.image and love.graphics) then return nil end
    local ok, data
    if type(ref) == "table" then
      -- Game Boy sprite: built at the game's own size, 9 frames. -Elvie
      local why
      local scale = ref.scale == 2 and 2 or 1
      local fw0, fh0 = w0, h0
      if scale == 2 then fw0, fh0 = WIDE, WIDE end
      ok, data, why = pcall(gb.sheet, ref.src, ref.gb.palette, fw0, fh0, scale)
      if ok and not data then
        warnOnce(mod, rel, "%s: %s; skipping it", rel, tostring(why))
        return nil
      end
    else
      ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
    end
    if not ok or not data then
      warnOnce(mod, rel, "could not load %s; skipping it", rel)
      return nil
    end
    local w, h = data:getDimensions()
    local fw, fh
    if w == w0 then fw, fh = w0, h0
    elseif w == WIDE then fw, fh = WIDE, WIDE end
    local n = fh and h % fh == 0 and math.floor(h / fh) or nil
    if not fw or not (n == 9 or n == n0) then
      local counts = n0 == 9 and "9" or ("9 or " .. n0)
      warnOnce(mod, rel, "%s is %dx%d but needs %s frames of %dx%d%s, stacked; skipping it",
        rel, w, h, counts, w0, h0, w0 < WIDE and (" or %dx%d"):format(WIDE, WIDE) or "")
      return nil
    end
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    -- Everything else is the game's own: paletteSlot for the weather
    -- mask, draw offsets, the palette fields. -Elvie
    local record = {}
    for k, v in pairs(vanilla) do record[k] = v end
    record.image, record.imageData = image, data
    record.width, record.height, record.frameCount = fw, fh, n
    record.quads = {}
    for fi = 0, n - 1 do
      record.quads[fi] = love.graphics.newQuad(0, fi * fh, fw, fh, fw, fh * n)
    end
    replaced[id] = true
    return record
  end

  local originalGet = OwSprites.get
  OwSprites.get = function(graphicsId)
    local vanilla = originalGet(graphicsId)
    if not vanilla or #bases == 0 then return vanilla end
    -- Keyed by the game's record, so a cache reload (another save, a new
    -- game) builds ours again. -Elvie
    local record = built[vanilla]
    if record ~= nil then return record or vanilla end
    if not fileFor then resolveFiles() end
    local id = tonumber(graphicsId)
    local rel = id and fileFor[id]
    if not rel then return vanilla end
    record = build(vanilla, rel, id) or false
    built[vanilla] = record
    return record or vanilla
  end

  -- Engine caches
  -- Reflections are recoloured from the drawn sprite and kept per id, and
  -- a palette override keeps its own copy. On a change of set these are
  -- dropped for every id Facets replaced, so they're made again. -Elvie
  -- ---------------------------------------------
  local function dropEngineCaches()
    local fxRse = package.loaded["src.core.game3.field_effects_rse"]
    for id in pairs(replaced) do
      if type(OwSprites._reflectionLoaded) == "table" then OwSprites._reflectionLoaded[id] = nil end
      local ov = type(OwSprites._overrides) == "table" and OwSprites._overrides[id]
      if type(ov) == "table" then ov.spr = nil end
      if type(fxRse) == "table" and type(fxRse._images) == "table" then fxRse._images[id] = nil end
    end
    replaced = {}
  end

  -- configure
  -- Takes a new ctx (or nil for OFF) and starts over from it. -Elvie
  -- ---------------------------------------------
  local function configure(newCtx)
    dropEngineCaches()
    bases = {}
    local seen = {}
    for _, key in ipairs(newCtx and newCtx.setKeys or {}) do
      if not seen[key] then
        seen[key] = true
        local map = newCtx.gbMaps and newCtx.gbMaps[key]
        bases[#bases + 1] = { dir = newCtx.npcsDir .. "/" .. key .. "/gen3/" .. family,
          gb = type(map) == "table" and type(map[family]) == "table" and map[family] or nil,
          scale = newCtx.gbScale and newCtx.gbScale[key] or 1 }
      end
    end
    fileFor = nil
    built = setmetatable({}, { __mode = "k" })
  end

  configure(ctx)
  return {
    configure = configure,
    family = family,
    -- For tests and the log: the file each id would use right now. -Elvie
    files = function()
      if not fileFor then resolveFiles() end
      return fileFor
    end,
  }
end

return gen3
