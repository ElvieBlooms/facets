-- SURROUND: what fills the window round the game screen on Red to Crystal,
-- outside battle (battles have BORDERS). The
-- engine's own UI LETTERBOX (OPTION) gives flat colours; these are Facets'
-- own:
--   WORLD    the map you were on, dimmed round the menu, as BATTLE BG:
--            WORLD shows it round a battle
--   SCENE    the blurred battle scene for where you are
--   WINDOWS  your WINDOWS frame's colour
--   DOTS, CHECKS, STRIPES  a soft pattern in your colours
-- Drawn by the engine's render.letterbox (classic_scenes hands it on), as
-- parts of a picture, never through a scissor, so it lines up on every
-- screen -Elvie
-- --------------------------------------------------

local surround = {}

local GAME = "game"
surround.CHOICES = {
  { "GAME", GAME }, { "WORLD", "world" }, { "SCENE", "scene" }, { "WINDOWS", "windows" },
  { "DOTS", "dots" }, { "CHECKS", "checks" }, { "STRIPES", "stripes" },
}
surround.DIM = 0.7
-- the battles' own WORLD dim (BattleState.BG_WORLD_DIM) -Elvie
surround.WORLD_DIM = 0.55

local mod = nil
local snapshot, snapAt = nil, 0

-- Whether WORLD should show the map round the screen now: it's chosen, no
-- battle is up (battles have BORDERS and their own BATTLE BG), and the map
-- is under something that covers it -Elvie
local function worldUnder(stack)
  if surround.mode() ~= "world" then return nil end
  local game = mod and mod.game
  local ow = game and game.overworld
  local states = stack and stack.states
  if not (ow and type(states) == "table") then return nil end
  for _, st in ipairs(states) do
    if type(st) == "table" and st.bgMode then return nil end
  end
  for i, st in ipairs(states) do
    if st == ow then return i end
  end
  return nil
end
surround.worldUnder = worldUnder

function surround.init(m, rows)
  mod = m
  rows[#rows + 1] = { key = "surround", type = "choice", label = "SURROUND", choices = surround.CHOICES, default = GAME }
  return function()
    -- Red, Blue and Yellow: the game itself keeps drawing the map under a
    -- menu, as it does under a BATTLE BG: WORLD battle, and dims it the
    -- same way -Elvie
    pcall(function()
      local Game = require("src.core.Game")
      if type(Game.drawBaseInStack) == "function" and not Game.facetsSurround then
        Game.facetsSurround = true
        local ownBase, ownDim = Game.drawBaseInStack, Game.worldBgBattleDim
        Game.drawBaseInStack = function(stack, visibleBase, ...)
          local at = ownBase(stack, visibleBase, ...)
          local ok, ow = pcall(worldUnder, stack)
          if ok and ow and ow < at then return ow end
          return at
        end
        if type(ownDim) == "function" then
          Game.worldBgBattleDim = function(stack, ...)
            local dim = ownDim(stack, ...)
            if dim ~= nil then return dim end
            local ok, ow = pcall(worldUnder, stack)
            if ok and ow and stack.visibleBase and ow < stack:visibleBase() then return surround.WORLD_DIM end
            return nil
          end
        end
      end
    end)
    -- Gold, Silver and Crystal draw the map and the menus into one picture:
    -- the last frame of just the map is kept (every few frames), to show
    -- round the menus -Elvie
    pcall(function()
      mod.hooks:wrap("render.compose", function(nextFn, renderer, ctx, ...)
        if type(ctx) == "table" and ctx.generation == 2 and ctx.worldActive and ctx.sceneCanvas
            and surround.mode() == "world" then
          snapAt = snapAt + 1
          local okT, top = pcall(function() return renderer.stack:top() end)
          if okT and top == nil and snapAt % 6 == 1 then
            pcall(function()
              local G = love.graphics
              local src = ctx.sceneCanvas
              local w, h = src:getDimensions()
              if not snapshot or snapshot:getWidth() ~= w or snapshot:getHeight() ~= h then
                snapshot = G.newCanvas(w, h)
              end
              G.push("all")
              G.setCanvas(snapshot)
              G.origin()
              G.setShader()
              G.setScissor()
              G.setBlendMode("replace", "premultiplied")
              G.setColor(1, 1, 1, 1)
              G.draw(src, 0, 0)
              G.pop()
            end)
          end
        end
        return nextFn(renderer, ctx, ...)
      end)
    end)
  end
end

function surround.mode()
  if not mod then return GAME end
  local ok, v = pcall(function() return mod.options:get("surround") end)
  return ok and v or GAME
end

-- Two colours to draw with: the screen's paper and a deeper one. The
-- deeper one is the WINDOWS frame's colour when there is one -Elvie
function surround.colours()
  local pr, pg, pb = 1, 1, 1
  pcall(function()
    local PaletteFX = require("src.render.PaletteFX")
    pr, pg, pb = PaletteFX.paperShade(mod.game and mod.game.data)
  end)
  local ink
  pcall(function()
    local c = require("mods.facets.classic_windows").colour()
    if c then ink = c end
  end)
  ink = ink or { pr * 0.78, pg * 0.78, pb * 0.86 }
  return { pr, pg, pb }, ink
end

-- a mix of two colours, t of the way from a to b -Elvie
function surround.mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- A pattern's tile as rows of 0 (paper) and 1 (ink), 8 Game Boy pixels a
-- side -Elvie
function surround.tile(kind)
  local rows = {}
  for y = 0, 7 do
    local row = {}
    for x = 0, 7 do
      local on = false
      if kind == "dots" then on = (x % 4 == 1 and y % 4 == 1)
      elseif kind == "checks" then on = ((math.floor(x / 4) + math.floor(y / 4)) % 2 == 1)
      elseif kind == "stripes" then on = ((x + y) % 8 < 3) end
      row[#row + 1] = on and 1 or 0
    end
    rows[#rows + 1] = row
  end
  return rows
end

local tiles = {}
local function tileImage(kind, paper, ink)
  local id = kind .. string.format("|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f", paper[1], paper[2], paper[3], ink[1], ink[2], ink[3])
  if tiles[id] then return tiles[id] end
  -- soft: the pattern's ink only part of the way from the paper -Elvie
  local soft = surround.mix(paper, ink, kind == "dots" and 0.85 or 0.45)
  local data = love.image.newImageData(8, 8)
  for y, row in ipairs(surround.tile(kind)) do
    for x, v in ipairs(row) do
      local c = v == 1 and soft or paper
      data:setPixel(x - 1, y - 1, c[1], c[2], c[3], 1)
    end
  end
  local img = love.graphics.newImage(data)
  img:setFilter("nearest", "nearest")
  img:setWrap("repeat", "repeat")
  tiles[id] = img
  return img
end

-- Whether a battle is up: battles size their screen their own way
-- (BATTLE SIZE), so SURROUND leaves them to BORDERS and the game -Elvie
local battleKinds = nil
function surround.inBattle(game)
  if not battleKinds then
    battleKinds = {}
    for _, name in ipairs({ "src.battle.BattleState", "src.ui.gen2.BattleState" }) do
      local ok, m = pcall(require, name)
      if ok and type(m) == "table" then battleKinds[m] = true end
    end
  end
  local states = game and game.stack and game.stack.states
  if type(states) ~= "table" then return false end
  for _, st in ipairs(states) do
    if type(st) == "table" and battleKinds[getmetatable(st)] then return true end
  end
  return false
end

-- Fill the window round the game screen (info: render.letterbox's) -Elvie
function surround.draw(info)
  local mode = surround.mode()
  if mode == GAME or type(info) ~= "table" or info.worldActive then return false end
  if surround.inBattle(mod and mod.game) then return false end
  local ww, wh = tonumber(info.ww), tonumber(info.wh)
  local ox, oy, vpw, vph = tonumber(info.ox), tonumber(info.oy), tonumber(info.vpw), tonumber(info.vph)
  if not (ww and wh and ox and oy and vpw and vph and ww > 0 and wh > 0) then return false end
  local scenes = require("mods.facets.classic_scenes")
  local G = love.graphics
  local d = type(G.getDPIScale) == "function" and G.getDPIScale() or 1
  local dx, dy = tonumber(info.dpiX) or d, tonumber(info.dpiY) or d
  local bl, bt, bw, bh = scenes.borderEdges(ox, oy, vpw, vph, dx, dy)
  local bars = scenes.bars(bl, bt, bw, bh, ww, wh)
  if #bars == 0 then return false end

  local function each(fn)
    for _, r in ipairs(bars) do
      G.push("all")
      G.origin()
      G.setShader()
      fn(r)
      G.pop()
    end
  end
  if mode == "world" then
    -- Red to Yellow draw the map themselves (above); Gold to Crystal get
    -- the kept picture of it, dimmed as the battles dim theirs -Elvie
    if not snapshot then return false end
    local sw, sh = snapshot:getDimensions()
    local pw = tonumber(info.pw) or ww * dx
    each(function(r)
      local k = 1 - surround.WORLD_DIM
      G.setColor(k, k, k, 1)
      -- the picture is the window in pixels: one unit is pw / ww of them -Elvie
      scenes.drawPart(snapshot, sw, sh, 0, 0, 0, 0, ww / pw, wh / (tonumber(info.ph) or wh * dy), r)
    end)
    return true
  end

  if mode == "scene" then
    local s = type(scenes.here) == "function" and scenes.here() or nil
    local blur = s and scenes.blurOf(s.image)
    if not blur then return false end
    local iw, ih = s.image:getDimensions()
    local bw2, bh2 = blur:getDimensions()
    local k = scenes.coverScale(iw, ih, ww, wh, scenes.ZOOM)
    local dw, dh = iw * k, ih * k
    each(function(r)
      G.setColor(surround.DIM, surround.DIM, surround.DIM, 1)
      scenes.drawPart(blur, bw2, bh2, 0, 0, (ww - dw) / 2, (wh - dh) / 2, dw / bw2, dh / bh2, r)
    end)
    return true
  end

  local paper, ink = surround.colours()
  if mode == "windows" then
    local c = ink
    each(function(r)
      G.setColor(c[1], c[2], c[3], 1)
      G.rectangle("fill", r[1], r[2], r[3], r[4])
    end)
    return true
  end

  -- a pattern, in Game Boy pixels, lined up with the screen -Elvie
  local img = tileImage(mode, paper, ink)
  -- one Game Boy pixel, in units: the screen is 160 by 144 of them -Elvie
  local px, py = vpw / 160, vph / 144
  each(function(r)
    G.setColor(1, 1, 1, 1)
    scenes.drawPart(img, 8, 8, 0, 0, ox, oy, px, py, r)
  end)
  return true
end

return surround
