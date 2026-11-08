-- Battle backgrounds on the Game Boy games (Red, Blue, Yellow, Gold, Silver, Crystal)
-- Gold, Silver and Crystal's battle screen starts each frame by clearing to
-- white (BattleState.drawPanel, then Chrome.clear); Red, Blue and Yellow's
-- wide battle fills its field with paper (WideBattle.draw). A set's scene
-- is painted there instead, so the boxes, the Pokémon and the text all
-- draw over it as usual. -Elvie
--
-- The sets are the Gen 3 ones (assets/battlebg/), 240x112. The Game Boy
-- screen has 160x96 above the text box, so the middle of the scene is
-- shown at its own size, keeping the bottom, where the ground is. The
-- scene is picked from where the battle is: the map's environment and
-- tileset, the gym, surfing or the grass. -Elvie
-- --------------------------------------------------

local scenes = {}

-- Where the scene last landed on the game screen, for the window around it
-- (scenes.edges): { image, canvas, x, y, kx, ky, stamp } -Elvie
local shown, frame = nil, 0
local blurOf

-- Notes the scene drawn this frame, for the borders to show blurred. The
-- position arguments are kept for the callers; the blurred backdrop only
-- needs the picture -Elvie
local function note(image, qx, qy, dx, dy)
  local G = love.graphics
  if type(G.transformPoint) ~= "function" or type(G.getCanvas) ~= "function" then return end
  local canvas = G.getCanvas()
  if type(canvas) == "table" then canvas = canvas[1] and (canvas[1].texture or canvas[1]) end
  if not canvas then return end
  local x0, y0 = G.transformPoint(dx - qx, dy - qy)
  local x1, y1 = G.transformPoint(dx - qx + 1, dy - qy + 1)
  shown = { image = image, canvas = canvas, x = x0, y = y0, kx = x1 - x0, ky = y1 - y0, stamp = frame }
end
scenes._note = note

-- The borders show the scene zoomed in and blurred, a little darker, so
-- the sharp battle sits in front of a soft backdrop of itself -Elvie
scenes.ZOOM, scenes.DIM = 1.15, 0.8

-- The scale that makes a w x h picture cover a ww x wh window, zoomed in a
-- little more -Elvie
function scenes.coverScale(w, h, ww, wh, zoom)
  return math.max(ww / w, wh / h) * (zoom or 1)
end

-- A blurred copy of a scene, made once: halved again and again with
-- smooth sampling (each halving averages 2x2), down to about 16 across;
-- drawn back up with smooth filtering, that's the blur -Elvie
local blurs = setmetatable({}, { __mode = "k" })
blurOf = function(image)
  local hit = blurs[image]
  if hit ~= nil then return hit or nil end
  blurs[image] = false
  local G = love.graphics
  local ok, result = pcall(function()
    local w, h = image:getDimensions()
    local src, filter = image, { image:getFilter() }
    image:setFilter("linear", "linear")
    local out
    G.push("all")
    while w > 16 do
      w, h = math.max(1, math.floor(w / 2)), math.max(1, math.floor(h / 2))
      local c = G.newCanvas(w, h)
      c:setFilter("linear", "linear")
      G.setCanvas(c)
      G.origin()
      G.setShader()
      G.setBlendMode("replace", "premultiplied")
      G.clear(0, 0, 0, 0)
      G.setColor(1, 1, 1, 1)
      local sw, sh = src:getDimensions()
      G.draw(src, 0, 0, 0, w / sw, h / sh)
      src, out = c, c
    end
    G.pop()
    image:setFilter(filter[1], filter[2])
    return out
  end)
  if ok and result then blurs[image] = result end
  return blurs[image] or nil
end

-- The window around the game screen: the scene, zoomed and blurred, in the
-- borders instead of a flat colour. Drawn by the engine's render.letterbox before
-- the game screen goes on top. Only on a frame the scene was drawn -Elvie
function scenes.edges(info)
  local s = shown
  frame = frame + 1
  if not (s and s.stamp == frame - 1 and type(info) == "table") or info.worldActive then return end
  local cw, ch = s.canvas:getDimensions()
  local vpw, vph = tonumber(info.vpw), tonumber(info.vph)
  if not (cw and ch and cw > 0 and ch > 0 and vpw and vph) then return end
  local ww, wh = tonumber(info.ww), tonumber(info.wh)
  if not (ww and wh and ww > 0 and wh > 0) then return end
  local blur = blurOf(s.image)
  if not blur then return end
  local G = love.graphics
  -- the whole scene, zoomed to cover the window a little past its edges
  -- and centred on it -Elvie
  local iw, ih = s.image:getDimensions()
  local k = scenes.coverScale(iw, ih, ww, wh, scenes.ZOOM)
  local bw, bh = blur:getDimensions()
  local dw, dh = iw * k, ih * k
  -- only the borders: whatever order the engine puts the game screen down
  -- in, the screen itself is never drawn over -Elvie
  local ox, oy = math.floor((tonumber(info.ox) or 0) + 0.5), math.floor((tonumber(info.oy) or 0) + 0.5)
  for _, r in ipairs(scenes.bars(ox, oy, math.floor(vpw + 0.5), math.floor(vph + 0.5), ww, wh)) do
    G.push("all")
    G.origin()
    G.intersectScissor(r[1], r[2], r[3], r[4])
    G.setColor(scenes.DIM, scenes.DIM, scenes.DIM, 1)
    G.draw(blur, (ww - dw) / 2, (wh - dh) / 2, 0, dw / bw, dh / bh)
    G.pop()
  end
end

-- The four borders round the game screen at (ox, oy) vpw x vph in a
-- window ww x wh, as x, y, w, h; the empty ones left out -Elvie
function scenes.bars(ox, oy, vpw, vph, ww, wh)
  local out = {}
  local function add(x, y, w, h) if w > 0 and h > 0 then out[#out + 1] = { x, y, w, h } end end
  add(0, 0, ox, wh)
  add(ox + vpw, 0, ww - ox - vpw, wh)
  add(ox, 0, vpw, oy)
  add(ox, oy + vph, vpw, wh - oy - vph)
  return out
end

local DIR = "assets/battlebg"
local GAME = "game"
scenes.W, scenes.H = 160, 96
scenes.SCREEN_H = 144

-- SCENE COLOURS: GBC. The scenes were painted for the GBA's screen and
-- read pale beside Crystal's sprites, so each colour's saturation is
-- raised, then rounded to the Game Boy Color's 32 levels a channel. One
-- pixel in, one out: r, g, b (0-1) -Elvie
function scenes.gbcColour(r, g, b)
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local l = (mx + mn) / 2
  if mx > mn then
    -- push each channel away from the pixel's grey by the same factor,
    -- kept inside 0-1 -Elvie
    local k = 1.35
    for _, c in ipairs({ r, g, b }) do
      local over = c - l
      if over > 0 then k = math.min(k, (1 - l) / over) elseif over < 0 then k = math.min(k, l / -over) end
    end
    r, g, b = l + (r - l) * k, l + (g - l) * k, l + (b - l) * k
  end
  local function q(c) return math.floor(math.max(0, math.min(1, c)) * 31 + 0.5) / 31 end
  return q(r), q(g), q(b)
end

-- The scene name for a battle, from the map (its id, environment and
-- tileset), whether the player is surfing and whether it's a trainer -Elvie
function scenes.pick(where)
  where = where or {}
  local id = tostring(where.map or "")
  local env = tostring(where.environment or "")
  local tiles = tostring(where.tileset or "")
  if where.surfing then return "sea" end
  -- Oak's Lab is on the Dojo's tileset in Red, Blue and Yellow, so it's
  -- named here to get the lab, as are the Gen 2 labs -Elvie
  if id:find("OAKS_LAB") or id:find("ELMS_LAB") then return "lab" end
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
        s.image:setWrap("mirroredrepeat", "mirroredrepeat")
        -- on down past the field to the bottom of the screen, so the
        -- ground carries on behind the text box instead of a white band
        -- (the art's last rows mirrored) -Elvie
        q = love.graphics.newQuad(math.floor((iw - W) / 2), ih - BOTTOM, W, H, iw, ih)
        quads[s.image] = q
      end
      G.setColor(1, 1, 1, 1)
      G.draw(s.image, q, 0, 0)
      local qx, qy = q:getViewport()
      note(s.image, qx, qy, 0, 0)
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
  rows[#rows + 1] = { key = "classicSceneColours", type = "choice", label = "SCENE COLOURS",
    choices = { { "ORIGINAL", "original" }, { "GBC", "gbc" } }, default = "original" }

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
      local path = setKey .. "/" .. file
      local gbc = mod.options:get("classicSceneColours") == "gbc"
      local id = path .. (gbc and "#gbc" or "")
      local hit = images[id]
      if hit ~= nil then return hit or nil end
      images[id] = false
      local ok, image = pcall(function()
        local data = love.image.newImageData(mod.assets:path(DIR .. "/" .. path))
        if gbc then
          data:mapPixel(function(_, _, r, g, b, a)
            r, g, b = scenes.gbcColour(r, g, b)
            return r, g, b, a
          end)
        end
        return love.graphics.newImage(data)
      end)
      if not ok then
        mod.log:warn("battlebg/%s couldn't be read", path)
        return nil
      end
      image:setFilter("nearest", "nearest")
      -- past its edges the art carries on mirrored, as the wide battles'
      -- sides do -Elvie
      image:setWrap("mirroredrepeat", "mirroredrepeat")
      local w, h = image:getDimensions()
      local x, y, cw, ch = scenes.crop(w, h)
      -- the wide battle has room for the whole width -Elvie
      local wx, wy, ww, wh = scenes.crop(w, h, w)
      -- Both run on down the whole screen, so the ground carries on
      -- behind the text box and shows round its corners -Elvie
      local down = scenes.SCREEN_H - ch
      images[id] = { image = image, quad = love.graphics.newQuad(x, y, cw, ch + down, w, h),
        wide = love.graphics.newQuad(wx, wy, ww, wh + down, w, h), wideX = math.floor((scenes.W - ww) / 2),
        x = x, y = y, wx = wx, wy = wy }
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
      local look = setKey .. "|" .. tostring(mod.options:get("classicSceneColours"))
      if self._facetsScene == nil or self._facetsSceneSet ~= look then
        local name = scenes.pick(where(self))
        self._facetsScene = scene(setKey, name) or false
        self._facetsSceneSet = look
        -- the scene this battle is in, for Scenic Route -Elvie
        scenes.last = self._facetsScene and name or nil
      end
      return self._facetsScene or nil
    end
    local function drawScene(s, wide)
      love.graphics.setColor(1, 1, 1, 1)
      if wide then
        love.graphics.draw(s.image, s.wide, s.wideX, 0)
        note(s.image, s.wx, s.wy, s.wideX, 0)
      else
        love.graphics.draw(s.image, s.quad, 0, 0)
        note(s.image, s.x, s.y, 0, 0)
      end
    end

    -- A move's animation (and the intro slide) draws the battle into a
    -- canvas and copies it to the screen in bands, each shifted on its own,
    -- as the Game Boy scrolls the attacker's half. A scene painted in there
    -- would tear with them, so while the canvas is drawn it's left
    -- see-through, and the scene goes under the bands instead, where the
    -- game fills its own white, and stays still -Elvie
    local baking, pending = false, nil
    local okV, AnimView = pcall(require, "src.ui.gen2.BattleAnimView")
    if okV and type(AnimView) == "table" and type(AnimView.bake) == "function"
        and type(AnimView.fillBackground) == "function" then
      local ownBake, ownFill = AnimView.bake, AnimView.fillBackground
      AnimView.bake = function(...)
        baking, pending = true, nil
        local ok, err = pcall(ownBake, ...)
        baking = false
        if not ok then error(err, 0) end
      end
      AnimView.fillBackground = function(...)
        local results = { ownFill(...) }
        if pending then drawScene(pending.s, pending.wide) end
        pending = nil
        return unpack(results)
      end
    end

    -- runs fn with Chrome.clear painting the scene after it clears -Elvie
    local function painted(s, wide, fn, ...)
      local clear = Chrome.clear
      Chrome.clear = function(...)
        if baking then
          pending = { s = s, wide = wide }
          return
        end
        clear(...)
        drawScene(s, wide)
      end
      local ok, err = pcall(fn, ...)
      Chrome.clear = clear
      if not ok then error(err, 0) end
    end

    -- the window round the game screen carries the scene on -Elvie
    pcall(function()
      mod.hooks:wrap("render.letterbox", function(nextFn, info, ...)
        local results = { nextFn(info, ...) }
        local ok, err = pcall(scenes.edges, info)
        if not ok then mod.log:warn("scenery round the screen: %s", tostring(err)) end
        return unpack(results)
      end)
    end)

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
