-- NPC overworld sprites on the Game Boy games (Red, Blue, Yellow, Gold, Silver, Crystal)
-- Every person on a map is drawn by a SpriteRenderer made from the game's
-- sprite record (SPRITE_YOUNGSTER and so on), so one wrap on
-- SpriteRenderer.new covers them all, including someone who changes
-- sprite mid-script. -Elvie
--
-- The sets are the Gen 3 ones: 9-frame sheets cut down to the game's 6
-- (stand down, up, left; step down, up, left), with Gen 3's second steps
-- on the other beat, in full colour. Gen 3 people are taller than the
-- Game Boy's and stand into the tile above, as they do on the GBA. -Elvie
--
-- A sheet is found by the sprite's own name first (FALKNER.png) in every
-- set, then by the Gen 3 names gbc/gb.json pairs with it and STAND_INS,
-- set by set. The chosen set comes first, then the others in menu order,
-- then the fill-in sets (DS-style ones before GBA-style ones). The GBA
-- look reads the player's FireRed or Emerald, then the fill-ins (GBA-style
-- first). Anyone without a sheet stays the game's own, and so do the
-- player and the rival (Crystal Lens's and Emerald Lens's) and anything
-- that isn't a person. Yellow's Pikachu has a row of its own. -Elvie
-- --------------------------------------------------

local classic = {}

local gba = require("mods.facets.classic_gba")

local NPCS_DIR = "assets/npcs"
local OFF = "__off"
local PREFIX = "facets/classic/npcs/"
-- johto: sheets under the Game Boy sprite's own name, which Gen 3 never
-- reads (the fill-in sets keep theirs there) -Elvie
local FAMILIES = { "frlg", "rse", "johto" }

-- the Gen 3 frames for the game's 6 (stand down, up, left, step down, up,
-- left), then Gen 3's second steps down, up and left -Elvie
classic.FRAMES = { 0, 1, 2, 3, 5, 7, 4, 6, 8 }
-- On every other tile the Game Boy mirrors the down and up step (which
-- swaps a tail, a cap or a ponytail from side to side) and repeats the
-- side step (so the feet don't move): Gen 3's second steps are shown there
-- instead, right still the mirror of left -Elvie
classic.SECOND_STEP = { down = 6, up = 7, left = 8, right = 8 }

-- Gen 2 sprites with no Gen 3 name of their own in gb.json, and the Gen 3
-- person who stands in until there's art of them -Elvie
classic.STAND_INS = {
  OFFICER = { "POLICEMAN" },
  STANDING_YOUNGSTER = { "YOUNGSTER" },
  OLD_LINK_RECEPTIONIST = { "LINK_RECEPTIONIST" },
  GUARD = { "POLICEMAN" },
  -- Kanto's people FireRed and Emerald have under other names -Elvie
  BIKE_SHOP_CLERK = { "CLERK" },
  SAFARI_ZONE_WORKER = { "WORKER_M" },
  SILPH_PRESIDENT = { "GENTLEMAN" },
  SILPH_WORKER_M = { "DEVON_EMPLOYEE" },
  SILPH_WORKER_F = { "WORKER_F" },
  SWIMMER = { "SWIMMER_M_WATER" },
  WAITER = { "COOK" },
  WARDEN = { "OLD_MAN_2" },
  -- Johto's -Elvie
  PHARMACIST = { "MART_EMPLOYEE" },
}

-- A name looked for before the sprite's own, in one generation: Crystal's
-- Mom is Johto's, not the sets' Kanto one -Elvie
classic.OWN_NAME_BY_GEN = {
  [2] = { MOM = "MOM_JOHTO" },
}

-- The same sprite name, a different person in each generation -Elvie
classic.STAND_INS_BY_GEN = {
  [1] = { FISHING_GURU = { "FISHER" } },
  [2] = { FISHING_GURU = { "FISHERMAN" } },
}

-- The player and the rival are Crystal Lens's -Elvie
classic.SKIP = { CHRIS = true, CHRIS_BIKE = true, KRIS = true, KRIS_BIKE = true, RIVAL = true,
  CAL = true, RED = true, RED_BIKE = true, BLUE = true }

-- A full-colour sheet as the Game Boy's four greys (classic.lua) -Elvie
classic.greys = require("mods.facets.classic").greys

-- Gen 2 sprite name -> Gen 3 names, from gb.json ({ family = { NAME = {
-- sprite = "youngster" } } }): the one that's the same name first, then the
-- rest in order -Elvie
function classic.namesFrom(map)
  local out = {}
  for _, family in ipairs(FAMILIES) do
    local names = {}
    for name, entry in pairs(type(map) == "table" and map[family] or {}) do
      local sprite = type(entry) == "table" and entry.sprite or entry
      if type(sprite) == "string" then names[#names + 1] = { name, sprite:upper() } end
    end
    table.sort(names, function(a, b) return a[1] < b[1] end)
    for _, pair in ipairs(names) do
      local name, sprite = pair[1], pair[2]
      local list = out[sprite]
      if not list then list = {}; out[sprite] = list end
      local seen = false
      for _, have in ipairs(list) do if have == name then seen = true end end
      if not seen then
        if name == sprite then table.insert(list, 1, name) else list[#list + 1] = name end
      end
    end
  end
  return out
end

-- The names to look for, in order, for a sprite id (SPRITE_YOUNGSTER),
-- or nil for one Facets leaves alone -Elvie
function classic.candidates(id, names, gen)
  if type(id) ~= "string" then return nil end
  local short = id:match("^SPRITE_(.+)$")
  if not short or classic.SKIP[short] then return nil end
  local out, seen = {}, {}
  local function add(name) if not seen[name] then seen[name] = true; out[#out + 1] = name end end
  local own = classic.OWN_NAME_BY_GEN[gen or 0]
  if own and own[short] then add(own[short]) end
  add(short)
  for _, name in ipairs(names[short] or {}) do add(name) end
  for _, name in ipairs(classic.STAND_INS[short] or {}) do add(name) end
  local byGen = classic.STAND_INS_BY_GEN[gen or 0]
  for _, name in ipairs(byGen and byGen[short] or {}) do add(name) end
  return out
end

-- The sheet for a sprite: the person's own name in any set first (in
-- order), so a fill-in's real Sage beats a set's Expert; then the first
-- set with any of the other names, in any family folder. has(rel) says
-- whether a file is there. Returns rel or nil -Elvie
function classic.find(sets, names, has)
  for _, set in ipairs(sets) do
    for _, family in ipairs(FAMILIES) do
      local rel = NPCS_DIR .. "/" .. set .. "/gen3/" .. family .. "/" .. tostring(names[1]) .. ".png"
      if names[1] and has(rel) then return rel end
    end
  end
  for _, set in ipairs(sets) do
    for _, name in ipairs(names) do
      for _, family in ipairs(FAMILIES) do
        local rel = NPCS_DIR .. "/" .. set .. "/gen3/" .. family .. "/" .. name .. ".png"
        if has(rel) then return rel end
      end
    end
  end
  return nil
end

-- A Gen 3 sheet's frame size: as wide as the sheet, 32 tall (a sheet
-- with an extra frame is 320) -Elvie
function classic.frameSize(w, h)
  if h % 32 == 0 and h >= 32 * 9 then return w, 32 end
  -- the small 16x16 walkers (FireRed's Little Girl has a tenth frame) -Elvie
  if w <= 16 and h % 16 == 0 and h >= 16 * 9 then return w, 16 end
  return w, math.floor(h / 9)
end

-- The 6-frame sheet, from a Gen 3 one: ImageData, frame w, frame h -Elvie
function classic.sheet(src)
  local w, h = src:getDimensions()
  local fw, fh = classic.frameSize(w, h)
  local out = love.image.newImageData(fw, fh * #classic.FRAMES)
  for i, from in ipairs(classic.FRAMES) do
    for y = 0, fh - 1 do
      local sy = from * fh + y
      if sy < h then
        for x = 0, fw - 1 do
          local r, g, b, a = src:getPixel(x, sy)
          if a > 0 then out:setPixel(x, (i - 1) * fh + y, r, g, b, a) end
        end
      end
    end
  end
  return out, fw, fh
end

-- Sets in label order, like the Gen 3 menu. The Game Boy ones and the
-- numbered test set are left out: the first is these games' own look -Elvie
local function findSets(mod)
  local sets = {}
  local okD, decode = pcall(function() return require("mods.facets.npcs").decodeJson end)
  for _, key in ipairs(mod.assets:list(NPCS_DIR) or {}) do
    local dir = NPCS_DIR .. "/" .. key
    local info = mod.assets:info(dir .. "/gen3")
    if info and info.type == "directory" and key ~= "test_frames" then
      local meta = {}
      if okD and mod.assets:info(dir .. "/meta.json") then
        local ok, got = pcall(decode, mod:read(dir .. "/meta.json"))
        if ok and type(got) == "table" then meta = got end
      end
      -- "fill": true: only for people the chosen set doesn't have, never
      -- a choice of its own -Elvie
      -- "style": "gba" for GBA-style art (Heart & Soul): first for the GBA
      -- look's fill-ins, last for the sets' -Elvie
      sets[#sets + 1] = { key = key, fill = meta.fill == true, gba = meta.style == "gba",
        label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper() }
    end
  end
  table.sort(sets, function(a, b) return a.label < b.label end)
  return sets
end

-- Yellow's Pikachu looks: assets/pikachu/<key>.png, labels and credits
-- in its meta.json -Elvie
classic.PIKACHU_DIR = "assets/pikachu"
classic.PIKA_GAME = "game"
local function pikachuLooks(mod)
  local looks = {}
  local okD, decode = pcall(function() return require("mods.facets.npcs").decodeJson end)
  local rel = classic.PIKACHU_DIR .. "/meta.json"
  if not (okD and mod.assets:info(rel)) then return looks end
  local ok, meta = pcall(decode, mod:read(rel))
  for _, look in ipairs(ok and type(meta) == "table" and type(meta.looks) == "table" and meta.looks or {}) do
    if type(look) == "table" and type(look.key) == "string" and look.key:match("^[%w_]+$")
        and mod.assets:info(classic.PIKACHU_DIR .. "/" .. look.key .. ".png") then
      looks[#looks + 1] = { key = look.key, label = type(look.label) == "string" and look.label or look.key:upper() }
    end
  end
  return looks
end

-- Whether the running game is Yellow -Elvie
local function yellow()
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if not (ok and type(GameVersion) == "table" and type(GameVersion.get) == "function") then return false end
  local okV, v = pcall(GameVersion.get)
  return okV and v == "yellow"
end

function classic.init(mod, rows)
  local sets = findSets(mod)
  if #sets == 0 then return nil end
  local looks = yellow() and pikachuLooks(mod) or {}
  local choices = {}
  for _, set in ipairs(sets) do
    if not set.fill then choices[#choices + 1] = { set.label, set.key } end
  end
  for _, c in ipairs(gba.CHOICES) do choices[#choices + 1] = c end
  choices[#choices + 1] = { "OFF", OFF }
  rows[#rows + 1] = { key = "sectionClassicNpcs", type = "choice", label = "NPCS",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "classicNpcs", type = "choice", label = "  SET", choices = choices, default = OFF }
  if #looks > 0 then
    -- GAME: Yellow's own, whatever the NPC set -Elvie
    local pika = { { "GAME", classic.PIKA_GAME } }
    for _, look in ipairs(looks) do pika[#pika + 1] = { look.label, look.key } end
    rows[#rows + 1] = { key = "classicPikachu", type = "choice", label = "  PIKACHU", choices = pika,
      default = classic.PIKA_GAME }
  end

  return function()
    local okS, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
    local okA, Assets = pcall(require, "src.render.Assets")
    if not (okS and type(SpriteRenderer) == "table" and type(SpriteRenderer.new) == "function"
        and okA and type(Assets) == "table" and type(Assets.compose) == "function") then
      mod.log:warn("SpriteRenderer.new not found; NPCs are off")
      return
    end
    local names = {}
    if mod.assets:info(NPCS_DIR .. "/gbc/gb.json") then
      local okJ, map = pcall(require("mods.facets.npcs").decodeJson, mod:read(NPCS_DIR .. "/gbc/gb.json"))
      if okJ then names = classic.namesFrom(map) end
    end
    local pics = require("mods.facets.classic").setup(mod)
    if not pics then return end

    -- the chosen set first, then the rest in menu order -Elvie
    local order, chosen
    local function configure()
      chosen = mod.options:get("classicNpcs")
      order = {}
      if chosen == OFF then return end
      if gba.isChoice(chosen) then gba.reset() return end
      order[1] = chosen
      for _, set in ipairs(sets) do if set.key ~= chosen and not set.fill then order[#order + 1] = set.key end end
      for _, set in ipairs(sets) do if set.fill and not set.gba then order[#order + 1] = set.key end end
      for _, set in ipairs(sets) do if set.fill and set.gba then order[#order + 1] = set.key end end
    end
    configure()

    -- whether the running game shows full colour as it is: Gen 2, or Gen 1
    -- with COLORS on RED++ -Elvie
    local okF, PaletteFX = pcall(require, "src.render.PaletteFX")
    local gen1 = require("mods.facets.classic").generation() == 1
    -- Red, Blue and Yellow draw tall grass after everyone; keep it off a
    -- tall person's body -Elvie
    if gen1 then
      local okG, grass = pcall(require, "mods.facets.classic_grass")
      if okG and type(grass) == "table" then grass.install(mod.log) end
    end
    local function fullColour()
      if not gen1 then return true end
      if not (okF and type(PaletteFX) == "table" and type(PaletteFX.honorsTrueColor) == "function") then return false end
      local ok, yes = pcall(PaletteFX.honorsTrueColor)
      return ok and yes and true or false
    end

    local defs = {} -- [set .. id] = our record, or false -Elvie
    local function ours(def)
      local pikaLook = #looks > 0 and def.id == "SPRITE_PIKACHU" and mod.options:get("classicPikachu") or nil
      local key = chosen .. ":" .. def.id .. (fullColour() and "" or ":grey") .. ":" .. tostring(pikaLook)
      local hit = defs[key]
      if hit ~= nil then return hit or nil end
      defs[key] = false
      local want = classic.candidates(def.id, names, require("mods.facets.classic").generation())
      if not want then return nil end
      local path, fw, fh, read, rel
      local grey = false
      if pikaLook == classic.PIKA_GAME then
        return nil
      elseif pikaLook then
        -- one of Yellow's Pikachu looks -Elvie
        local rel = classic.PIKACHU_DIR .. "/" .. pikaLook .. ".png"
        if not pics.has(rel) then return nil end
        fw, fh = 32, 32
        path = PREFIX .. "pikachu/" .. pikaLook .. ".png"
        read = function()
          local ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
          return ok and data or nil
        end
        -- Gen 1 outside RED++ shades by brightness, which turns Pikachu's
        -- yellow white: handed over grey instead, for the game to tint as
        -- it does its own -Elvie
        if not fullColour() then
          grey = true
          path = path:gsub("%.png$", "@grey.png")
          local plain = read
          read = function()
            local data = plain()
            return data and classic.greys(data) or nil
          end
        end
      elseif chosen == OFF then
        return nil
      else
        if gba.isChoice(chosen) then
          -- the GBA look: the Gen 3 sheet from the player's own game; anyone
          -- neither game has comes from the fill-in sets (Heart & Soul's,
          -- GBA-style already) -Elvie
          local found = gba.npcSheet(chosen, want)
          if found then
            fw, fh = classic.frameSize(found.w, found.h)
            path = PREFIX .. chosen .. "/" .. found.game .. "/" .. found.rel:gsub("%.rgba$", ".png")
            read = function() return gba.load(found) end
          else
            local fills = {}
            for _, set in ipairs(sets) do if set.fill and set.gba then fills[#fills + 1] = set.key end end
            for _, set in ipairs(sets) do if set.fill and not set.gba then fills[#fills + 1] = set.key end end
            rel = classic.find(fills, want, pics.has)
            if not rel then return nil end
          end
        else
          rel = classic.find(order, want, pics.has)
          if not rel then return nil end
        end
      end
      if not read then
        local okI, src = pcall(love.image.newImageData, mod.assets:path(rel))
        if not okI then
          mod.log:warn("%s couldn't be read", rel)
          return nil
        end
        fw, fh = classic.frameSize(src:getDimensions())
        path = PREFIX .. rel:sub(#NPCS_DIR + 2)
        read = function()
          local ok, again = pcall(love.image.newImageData, mod.assets:path(rel))
          return ok and again or nil
        end
      end
      Assets.compose(path, function()
        local ok, src = pcall(read)
        return ok and src and (classic.sheet(src)) or love.image.newImageData(1, 1)
      end)
      local record = {}
      for k, v in pairs(def) do record[k] = v end
      record.image = path
      record.frames = #classic.FRAMES
      record.frameWidth, record.frameHeight = fw, fh
      record.frameColumns, record.frameOffset, record.cells = nil, nil, nil
      record.anchorX, record.anchorY = nil, nil
      record.gbaArt = not grey
      defs[key] = record
      return record
    end

    -- the second step on the tiles the game would mirror -Elvie
    local function bothSteps(renderer)
      if type(renderer) ~= "table" or type(renderer.draw) ~= "function" then return renderer end
      local draw = renderer.draw
      renderer.draw = function(self, px, py, camX, camY, facing, walkPhase, stepFlip, topHalf, forceFlip,
          frameOverride, ...)
        if frameOverride == nil and walkPhase == 1 and stepFlip and classic.SECOND_STEP[facing] then
          frameOverride = classic.SECOND_STEP[facing]
          forceFlip = facing == "right" or forceFlip
        end
        return draw(self, px, py, camX, camY, facing, walkPhase, stepFlip, topHalf, forceFlip, frameOverride, ...)
      end
      return renderer
    end

    local own = SpriteRenderer.new
    SpriteRenderer.new = function(def, seed, ...)
      if seed ~= "player" and type(def) == "table" and type(def.id) == "string"
          and (chosen ~= OFF or (#looks > 0 and def.id == "SPRITE_PIKACHU")) then
        local record = ours(def)
        if record then return bothSteps(own(record, seed, ...)) end
      end
      return own(def, seed, ...)
    end

    -- Everyone already on the map keeps the renderer they were made with,
    -- so a new SET draws them again: Gen 1's by their sprite id, Gen 2's
    -- by their sheet, with its palette put back on -Elvie
    local function redraw()
      local okG, game = pcall(function() return mod.game end)
      if not (okG and type(game) == "table") then return end
      local data = game.data or (package.loaded["src.core.Game"] or {}).data
      local seen = {}
      local function again(world, npc)
        if type(npc) ~= "table" or seen[npc] or not npc.sprite then return end
        seen[npc] = true
        local def = npc.spriteDef
        if not def then
          local id = npc.appearance or (type(npc.def) == "table" and npc.def.sprite)
          def = type(data) == "table" and type(data.sprites) == "table" and data.sprites[id]
        end
        if type(def) ~= "table" then return end
        local ok, renderer = pcall(SpriteRenderer.new, def, npc.id)
        if not (ok and renderer) then return end
        npc.sprite = renderer
        npc.appearances = nil
        if type(world.applySpritePalette) == "function" then pcall(world.applySpritePalette, world, npc) end
      end
      local worlds = { game.world, game.overworld }
      local stack = type(game.stack) == "table" and game.stack.states
      for _, state in ipairs(type(stack) == "table" and stack or {}) do worlds[#worlds + 1] = state end
      for _, world in pairs(worlds) do
        if type(world) == "table" and (type(world.npcPool) == "table" or type(world.npcs) == "table") then
          for _, npc in pairs(world.npcPool or {}) do again(world, npc) end
          for _, npc in ipairs(world.npcs or {}) do again(world, npc) end
        end
      end
    end

    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id
            and (change.key == "classicNpcs" or change.key == "classicPikachu") then
          configure()
          pcall(redraw)
        end
      end)
    end
  end
end

return classic
