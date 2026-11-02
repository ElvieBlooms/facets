-- Battle backgrounds on the Game Boy games (Gold, Silver, Crystal)
-- The battle screen starts each frame by clearing to white
-- (BattleState.drawPanel, then Chrome.clear); a set's scene is painted
-- there instead, so the boxes, the Pokémon and the text all draw over it as
-- usual. -Elvie
--
-- The sets are the Gen 3 ones (assets/battlebg/), 240x112. The Game Boy
-- screen has 160x96 above the text box, so the middle of the scene is
-- shown at its own size, keeping the bottom, where the ground is. The
-- scene is picked from where the battle is: the map's environment and
-- tileset, the gym, surfing or the grass. -Elvie
-- --------------------------------------------------

local scenes = {}

local DIR = "assets/battlebg"
local GAME = "game"
scenes.W, scenes.H = 160, 96

-- The scene name for a battle, from the map (its id, environment and
-- tileset), whether the player is surfing and whether it's a trainer -Elvie
function scenes.pick(where)
  where = where or {}
  local id = tostring(where.map or "")
  local env = tostring(where.environment or "")
  local tiles = tostring(where.tileset or "")
  if where.surfing then return "sea" end
  -- Gen 1's maps have a tileset but no environment -Elvie
  if env == "" and tiles ~= "" then
    if id:find("CHAMPIONS_ROOM") then return "space" end
    for _, room in ipairs({ "LORELEIS_ROOM", "BRUNOS_ROOM", "AGATHAS_ROOM", "LANCES_ROOM" }) do
      if id:find(room) then return "gym" end
    end
    if id:find("SEAFOAM") then return "snow_cave" end
    if tiles:find("GATE") then return "indoors" end
  end
  if tiles:find("CHAMPIONS_ROOM") then return "space" end
  if id:find("_GYM") or tiles:find("ELITE_FOUR") then return "gym" end
  if id:find("SILVER_CAVE") or id:find("MOUNT_SILVER") then return "snow_mountain" end
  if tiles:find("ICE_PATH") then return "snow_cave" end
  if tiles:find("FOREST") then return "forest" end
  if tiles:find("LAB") then return "lab" end
  if env == "CAVE" or tiles:find("CAVE") then return "cave" end
  if env == "DUNGEON" then return "indoors" end
  if env == "INDOOR" or env == "GATE" then return "indoors" end
  if tiles:find("PORT") then return "beach" end
  if env == "TOWN" then return "town" end
  if env == "ROUTE" then return where.trainer and "route" or "grass" end
  if env == "" and tiles == "OVERWORLD" then
    if id:find("^ROUTE") then return where.trainer and "route" or "grass" end
    return "town"
  end
  if env == "" and tiles ~= "" then return "indoors" end
  return "neutral"
end

-- The part of a 240x112 scene the Game Boy screen shows: x, y, w, h -Elvie
function scenes.crop(w, h, maxW)
  local cw, ch = math.min(maxW or scenes.W, w), math.min(scenes.H, h)
  return math.floor((w - cw) / 2), h - ch, cw, ch
end

local function findSets(mod)
  local sets = {}
  local decode = require("mods.facets.npcs").decodeJson
  for _, key in ipairs(mod.assets:list(DIR) or {}) do
    local rel = DIR .. "/" .. key .. "/meta.json"
    if key:match("^[%w_%-]+$") and mod.assets:info(rel) then
      local ok, meta = pcall(decode, mod:read(rel))
      if ok and type(meta) == "table" and type(meta.scenes) == "table" then
        sets[#sets + 1] = { key = key, scenes = meta.scenes,
          label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper() }
      end
    end
  end
  table.sort(sets, function(a, b) return a.label < b.label end)
  return sets
end

-- Gen 1's wide battle: the field's paper fill (PaletteFX.paperShade, then
-- one rectangle) is painted with the scene instead, all 304 across, its
-- sides carried on mirrored. Only there: the 160x144 screen is coloured
-- through the SGB zones, which would shade a scene too, and so is the wide
-- one in the Game Boy greys (CLASSIC, OG) -Elvie
local function startGen1(mod, sceneFor)
  local okW, WideBattle = pcall(require, table.concat({ "src", "battle", "WideBattle" }, "."))
  local okP, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not (okW and type(WideBattle) == "table" and type(WideBattle.draw) == "function"
      and okP and type(PaletteFX) == "table" and type(PaletteFX.paperShade) == "function") then
    mod.log:warn("WideBattle.draw not found; BATTLE BG is off")
    return
  end
  local W, H = tonumber(WideBattle.WIDTH) or 304, tonumber(WideBattle.HEIGHT) or 144
  local BOTTOM = tonumber(WideBattle.FIELD_BOTTOM) or 104
  local function grey()
    local m = PaletteFX.mode
    if m == "og" or m == "og_inv" or m == "classic" then return true end
    local ok, raw = pcall(function() return PaletteFX.forcesRawGrays() end)
    return ok and raw or false
  end
  local quads = {}
  local own = WideBattle.draw
  WideBattle.draw = function(battle, ...)
    local s = type(battle) == "table" and type(battle.wideLayout) == "function" and battle:wideLayout()
      and not grey() and not (type(battle.extendedWorldHUD) == "function" and battle:extendedWorldHUD())
      and sceneFor(battle)
    if not s then return own(battle, ...) end
    local G = love.graphics
    local paper = PaletteFX.paperShade
    local used = false
    PaletteFX.paperShade = function(...)
      if used then return paper(...) end
      used = true
      local r, g, b = paper(...)
      G.setColor(r, g, b, 1)
      G.rectangle("fill", 0, BOTTOM, W, H - BOTTOM)
      local iw, ih = s.image:getDimensions()
      local q = quads[s.image]
      if not q then
        s.image:setWrap("mirroredrepeat", "clamp")
        q = love.graphics.newQuad(math.floor((iw - W) / 2), ih - BOTTOM, W, BOTTOM, iw, ih)
        quads[s.image] = q
      end
      G.setColor(1, 1, 1, 1)
      G.draw(s.image, q, 0, 0)
      -- the game's own fill then goes down see-through -Elvie
      return r, g, b, 0
    end
    local results = { pcall(own, battle, ...) }
    PaletteFX.paperShade = paper
    if not results[1] then error(results[2], 0) end
    return unpack(results, 2)
  end
end

function scenes.init(mod, rows)
  local gen = require("mods.facets.classic").generation()
  if gen ~= 2 and gen ~= 1 then return nil end
  local sets = findSets(mod)
  if #sets == 0 then return nil end
  local byKey = {}
  local choices = { { "GAME", GAME } }
  for _, set in ipairs(sets) do
    byKey[set.key] = set
    choices[#choices + 1] = { set.label, set.key }
  end
  rows[#rows + 1] = { key = "classicBattleBg", type = "choice", label = "BATTLE BG", choices = choices, default = GAME }

  return function()
    local okB, BattleState, okC, Chrome = false, nil, false, nil
    if gen == 2 then
      okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
      okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
    end
    if gen == 2 and not (okB and type(BattleState) == "table" and type(BattleState.drawPanel) == "function"
        and okC and type(Chrome) == "table" and type(Chrome.clear) == "function") then
      mod.log:warn("BattleState.drawPanel not found; BATTLE BG is off")
      return
    end

    local images = {} -- [set/file] = { image, quad }, or false -Elvie
    local function scene(setKey, name)
      local set = byKey[setKey]
      local file = set and (set.scenes[name] or set.scenes.neutral)
      if type(file) ~= "string" or not file:match("^[%w_%-%.]+%.png$") then return nil end
      local id = setKey .. "/" .. file
      local hit = images[id]
      if hit ~= nil then return hit or nil end
      images[id] = false
      local ok, image = pcall(love.graphics.newImage, mod.assets:path(DIR .. "/" .. id))
      if not ok then
        mod.log:warn("battlebg/%s couldn't be read", id)
        return nil
      end
      image:setFilter("nearest", "nearest")
      local w, h = image:getDimensions()
      local x, y, cw, ch = scenes.crop(w, h)
      -- the wide battle has room for the whole width -Elvie
      local wx, wy, ww, wh = scenes.crop(w, h, w)
      images[id] = { image = image, quad = love.graphics.newQuad(x, y, cw, ch, w, h),
        wide = love.graphics.newQuad(wx, wy, ww, wh, w, h), wideX = math.floor((scenes.W - ww) / 2) }
      return images[id]
    end

    -- where this battle is, read once per battle -Elvie
    local where
    where = function(state)
      local world = state.game and state.game.world
      local map = world and world.map
      local def = map and map.def or {}
      return { map = map and map.id, environment = def.environment, tileset = def.tileset,
        surfing = world and world.playerState == "surf",
        trainer = state.battle and state.battle.trainer ~= nil }
    end

    -- Gen 1: the overworld under the battle, from WorldAPI -Elvie
    if gen == 1 then
      where = function(state)
        local ow
        pcall(function() ow = require("src.world.WorldAPI").new(state.game):overworld() end)
        local map = type(ow) == "table" and ow.map or nil
        local def = type(map) == "table" and map.def or {}
        return { map = map and map.id, tileset = def.tileset,
          surfing = type(ow) == "table" and type(ow.player) == "table" and ow.player.surfing and true or false,
          trainer = state.kind == "trainer" }
      end
    end

    -- this battle's scene, or nil for the game's own -Elvie
    local function sceneFor(self)
      local setKey = mod.options:get("classicBattleBg")
      -- The engine's BATTLE BG only fills the screen around the battle; the
      -- battle keeps its paper field in every mode but one, the EXTENDED
      -- HUD over the world, which has no field to paint -Elvie
      if setKey == GAME or not byKey[setKey] then return nil end
      if type(self.extendedWorldHUD) == "function" and self:extendedWorldHUD() then return nil end
      if self._facetsScene == nil or self._facetsSceneSet ~= setKey then
        local name = scenes.pick(where(self))
        self._facetsScene = scene(setKey, name) or false
        self._facetsSceneSet = setKey
        -- the scene this battle is in, for Scenic Route -Elvie
        scenes.last = self._facetsScene and name or nil
      end
      return self._facetsScene or nil
    end
    -- runs fn with Chrome.clear painting the scene after it clears -Elvie
    local function painted(s, wide, fn, ...)
      local clear = Chrome.clear
      Chrome.clear = function(...)
        clear(...)
        love.graphics.setColor(1, 1, 1, 1)
        if wide then
          love.graphics.draw(s.image, s.wide, s.wideX, 0)
        else
          love.graphics.draw(s.image, s.quad, 0, 0)
        end
      end
      local ok, err = pcall(fn, ...)
      Chrome.clear = clear
      if not ok then error(err, 0) end
    end

    if gen == 1 then return startGen1(mod, sceneFor) end

    local own = BattleState.drawPanel
    BattleState.drawPanel = function(self, ...)
      local s = sceneFor(self)
      if not s then return own(self, ...) end
      painted(s, false, own, self, ...)
    end

    local okW, WideBattle = pcall(require, "src.ui.gen2.WideBattle")
    if okW and type(WideBattle) == "table" and type(WideBattle.drawField) == "function" then
      local ownField = WideBattle.drawField
      WideBattle.drawField = function(battle, ...)
        local s = sceneFor(battle)
        if not s then return ownField(battle, ...) end
        local results
        painted(s, true, function(...) results = { ownField(...) } end, battle, ...)
        return results and results[1]
      end
    end
  end
end

return scenes
