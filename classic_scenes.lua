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

function scenes.init(mod, rows)
  -- Gen 1 colours its battle screen through the SGB zones, which would
  -- shade a scene too; Gen 2 only for now -Elvie
  if require("mods.facets.classic").generation() ~= 2 then return nil end
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
    local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
    local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
    if not (okB and type(BattleState) == "table" and type(BattleState.drawPanel) == "function"
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
    local function where(state)
      local world = state.game and state.game.world
      local map = world and world.map
      local def = map and map.def or {}
      return { map = map and map.id, environment = def.environment, tileset = def.tileset,
        surfing = world and world.playerState == "surf",
        trainer = state.battle and state.battle.trainer ~= nil }
    end

    -- this battle's scene, or nil for the game's own -Elvie
    local function sceneFor(self)
      local setKey = mod.options:get("classicBattleBg")
      if setKey == GAME or not byKey[setKey] or self:bgMode() ~= "white" then return nil end
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
