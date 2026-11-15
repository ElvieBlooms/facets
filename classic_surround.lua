-- SURROUND: what fills the window round the game screen outside battle
-- (battles have BORDERS), on all eleven games. Red to Crystal's own UI
-- LETTERBOX (OPTION) gives flat colours; these are Facets' own:
--   WORLD    the map you were on, dimmed round the menu, as BATTLE BG:
--            WORLD shows it round a battle
--   GLOW     soft lights drifting slowly, in your menus' colour, on a
--            darker shade of it
--   SCENE    the blurred battle scene for where you are (on the GBA
--            games, for the ground of your last battle)
--   WINDOWS  your WINDOWS frame's colour
--   DOTS, CHECKS, STRIPES  a soft pattern in your colours
-- Drawn by the engine's render.letterbox
-- (classic_scenes, or gbui on the GBA games, hands it on), as
-- parts of a picture, never through a scissor, so it lines up on every
-- screen -Elvie
-- --------------------------------------------------

local surround = {}

local GAME = "game"
surround.CHOICES = {
  { "GAME", GAME }, { "WORLD", "world" }, { "GLOW", "glow" }, { "SCENE", "scene" }, { "WINDOWS", "windows" },
  { "DOTS", "dots" }, { "CHECKS", "checks" }, { "STRIPES", "stripes" },
}
surround.DIM = 0.7
-- the battles' own WORLD dim (BattleState.BG_WORLD_DIM) -Elvie
surround.WORLD_DIM = 0.55

local mod = nil
local snapshot, snapAt = nil, 0
-- on the GBA games the kept picture is the map alone, placed as the game
-- places it: centred, snapScale pixels to a GBA pixel -Elvie
local snapScale = nil

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

-- The choices: the same on every game -Elvie
function surround.choices() return surround.CHOICES end

function surround.init(m, rows, gen)
  mod = m
  surround.gen = gen or 1
  rows[#rows + 1] = { key = "surround", type = "choice", label = "SURROUND", choices = surround.choices(), default = GAME }
  return function()
    -- Red, Blue and Yellow: the game itself keeps drawing the map under a
    -- menu, as it does under a BATTLE BG: WORLD battle, and dims it the
    -- same way -Elvie
    -- (only there: the other games' engines have no such Game, and asking
    -- for it only fills their logs) -Elvie
    if surround.gen == 1 and require("mods.facets.classic").generation() == 1 then pcall(function()
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
    end) end
    -- Gold, Silver and Crystal draw the map and the menus into one picture,
    -- and FireRed to Emerald leave the map out under their full-screen
    -- menus: so the last frame of just the map is kept (every few frames)
    -- to show round the menus -Elvie
    pcall(function()
      mod.hooks:wrap("render.compose", function(nextFn, renderer, ctx, ...)
        local gen = type(ctx) == "table" and ctx.generation
        local src
        if gen == 2 and ctx.worldActive and ctx.sceneCanvas then
          local okT, top = pcall(function() return renderer.stack:top() end)
          if okT and top == nil then src = ctx.sceneCanvas end
        elseif gen == 3 and ctx.worldActive and ctx.worldCanvas then
          src = ctx.worldCanvas
        end
        if src and surround.mode() == "world" then
          snapAt = snapAt + 1
          if snapAt % 6 == 1 then
            pcall(function()
              local G = love.graphics
              if gen == 3 then
                local okZ, Zoom = pcall(require, "src.render.Zoom")
                local sp = tonumber(ctx.scale) or 1
                snapScale = okZ and type(Zoom.scale) == "function" and Zoom.scale(sp) or sp
              else
                snapScale = nil
              end
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

-- The commonest colour in a picture that isn't near white or near black,
-- or nil -Elvie
function surround.commonColour(data)
  local count, best, bestN = {}, nil, 0
  local w, h = data:getDimensions()
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local r, g, b, al = data:getPixel(x, y)
      local hi, lo = math.max(r, g, b), math.min(r, g, b)
      if al > 0.9 and lo < 0.9 and hi > 0.15 then
        local key = math.floor(r * 255) * 65536 + math.floor(g * 255) * 256 + math.floor(b * 255)
        local n = (count[key] or 0) + 1
        count[key] = n
        if n > bestN then best, bestN = { r, g, b }, n end
      end
    end
  end
  return best
end

-- the GBA games: a window set's frame, read once each -Elvie
local gen3Colours = {}
local function gen3Frame()
  local gbui = package.loaded["mods.facets.gbui"]
  if not (gbui and mod) then return nil end
  local value = tostring(mod.options:get("gbcFrame") or "game")
  if gen3Colours[value] ~= nil then return gen3Colours[value] or nil end
  gen3Colours[value] = false
  pcall(function()
    local st, set = gbui.style(value)
    local file = st and st.frame
    if type(file) == "string" and file:match("^[%w_%-%.]+%.png$") then
      local data = love.image.newImageData(mod.assets:path(gbui.WINDOWS_DIR .. "/" .. set.key .. "/" .. file))
      gen3Colours[value] = surround.commonColour(data) or false
    end
  end)
  return gen3Colours[value] or nil
end

-- Your WINDOWS frame's colour, or nil with the game's own frame -Elvie
function surround.frameColour()
  if surround.gen == 3 then return gen3Frame() end
  local ok, c = pcall(function() return require("mods.facets.classic_windows").colour() end)
  return ok and c or nil
end

-- Two colours to draw with: the screen's paper and a deeper one, the
-- WINDOWS frame's colour when there is one -Elvie
function surround.colours()
  local pr, pg, pb = 1, 1, 1
  if surround.gen == 3 then
    -- the GBA games' windows are near white, with a blue-grey edge -Elvie
    pr, pg, pb = 0.97, 0.97, 0.98
  else
    pcall(function()
      local PaletteFX = require("src.render.PaletteFX")
      pr, pg, pb = PaletteFX.paperShade(mod.game and mod.game.data)
    end)
  end
  local ink = surround.frameColour()
  if not ink and surround.gen == 3 then ink = { 0.45, 0.55, 0.72 } end
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

-- GLOW's lights: where each one is at time t (seconds), across a window w
-- by h, with its size and brightness. The same lights every time (a fixed
-- seed), each drifting slowly on its own line and wrapping round -Elvie
surround.LIGHTS = 14
function surround.lights(t, w, h)
  local out = {}
  local seed = 12345
  local function rnd()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
  end
  local span = math.max(w, h)
  for i = 1, surround.LIGHTS do
    local x0, y0 = rnd(), rnd()
    local angle = rnd() * math.pi * 2
    local speed = 0.006 + rnd() * 0.012 -- of the window a second: slow -Elvie
    local size = (0.06 + rnd() * 0.12) * span
    local glow = 0.18 + rnd() * 0.22
    local tint = rnd() * 0.45
    local phase = rnd() * math.pi * 2
    local m = size / span
    local x = ((x0 + math.cos(angle) * speed * t) % (1 + 2 * m)) - m
    local y = ((y0 + math.sin(angle) * speed * t) % (1 + 2 * m)) - m
    -- each one breathes a little as it goes -Elvie
    local a = glow * (0.75 + 0.25 * math.sin(t * 0.4 + phase))
    out[i] = { x = x * w, y = y * h, r = size / 2, a = a, tint = tint }
  end
  return out
end

-- a soft round light, bright in the middle and fading to nothing -Elvie
local disc = nil
local function discImage()
  if disc then return disc end
  local n = 64
  local data = love.image.newImageData(n, n)
  for y = 0, n - 1 do
    for x = 0, n - 1 do
      local dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
      local d = math.sqrt(dx * dx + dy * dy)
      -- a flat middle with a soft rim, like an out-of-focus light -Elvie
      local a = d >= 1 and 0 or (d < 0.7 and 1 or (1 - (d - 0.7) / 0.3))
      a = a * a
      data:setPixel(x, y, 1, 1, 1, a)
    end
  end
  disc = love.graphics.newImage(data)
  disc:setFilter("linear", "linear")
  return disc
end

-- The GBA games' SCENE: BATTLE BG's set (SCENERY when it's GAME or
-- WHITE) for the ground of your last battle, grass before any -Elvie
local gen3Scenes = {}
function surround.gen3Scene()
  local gbui = package.loaded["mods.facets.gbui"]
  if not (gbui and mod) then return nil end
  local setKey = tostring(mod.options:get("gbcBattleBg") or "game")
  if not gbui.BG_SETS[setKey] then setKey = "scenery" end
  if not gbui.BG_SETS[setKey] then return nil end
  local key = gbui.lastTerrain or "grass"
  local id = setKey .. "/" .. tostring(key)
  if gen3Scenes[id] == nil then
    local ok, img = pcall(gbui.scene, mod, setKey, key)
    gen3Scenes[id] = ok and img and { image = img } or false
  end
  return gen3Scenes[id] or nil
end

-- Whether a battle is up: battles size their screen their own way
-- (BATTLE SIZE), so SURROUND leaves them to BORDERS and the game -Elvie
local battleKinds = nil
function surround.inBattle(game)
  if surround.gen == 3 then
    local ok, active = pcall(function() return require("src.core.game3.battle").isActive() end)
    return ok and active and true or false
  end
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
  if mode == GAME or type(info) ~= "table" then return false end
  -- Red to Crystal's map fills the window itself; the GBA games' map is
  -- the GBA screen, with room round it like any other -Elvie
  if info.worldActive and surround.gen ~= 3 then return false end
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
  if mode == "glow" then
    -- the menus' colour (your WINDOWS frame's, or the screen's paper) as
    -- the lights, on a deep shade of it -Elvie
    local paper, ink = surround.colours()
    local base = ink
    if not surround.frameColour() and surround.gen ~= 3 then base = paper end
    local bg = { base[1] * 0.28, base[2] * 0.28, base[3] * 0.32 }
    local img = discImage()
    local iw = img:getWidth()
    local t = love.timer and love.timer.getTime() or 0
    -- only the borders: some screens are drawn before the surround, so a
    -- light crossing the screen's edge is cut there (as the part of it in
    -- each border, not with a scissor) -Elvie
    local lights = surround.lights(t, ww, wh)
    each(function(r)
      G.setColor(bg[1], bg[2], bg[3], 1)
      G.rectangle("fill", r[1], r[2], r[3], r[4])
      G.setBlendMode("add")
      for _, l in ipairs(lights) do
        local x0, y0, k = l.x - l.r, l.y - l.r, 2 * l.r / iw
        local ax, ay = math.max(r[1], x0), math.max(r[2], y0)
        local bx, by = math.min(r[1] + r[3], x0 + 2 * l.r), math.min(r[2] + r[4], y0 + 2 * l.r)
        if bx > ax and by > ay then
          local c = surround.mix(base, { 1, 1, 1 }, l.tint)
          G.setColor(c[1], c[2], c[3], l.a)
          scenes.drawPart(img, iw, iw, 0, 0, x0, y0, k, k, { ax, ay, bx - ax, by - ay })
        end
      end
    end)
    return true
  end

  if mode == "world" then
    -- Red to Yellow draw the map themselves (above); Gold to Emerald get
    -- the kept picture of it, dimmed as Crystal's WORLD battles dim theirs -Elvie
    if not snapshot then return false end
    local sw, sh = snapshot:getDimensions()
    local pw = tonumber(info.pw) or ww * dx
    local ph = tonumber(info.ph) or wh * dy
    local k = 1 - surround.WORLD_DIM
    each(function(r)
      G.setColor(k, k, k, 1)
      if snapScale then
        -- the GBA map, centred in the window at the game's own scale -Elvie
        local x0 = math.floor((pw - sw * snapScale) / 2) / dx
        local y0 = math.floor((ph - sh * snapScale) / 2) / dy
        scenes.drawPart(snapshot, sw, sh, 0, 0, x0, y0, snapScale / dx, snapScale / dy, r)
      else
        -- the picture is the window in pixels: one unit is pw / ww of them -Elvie
        scenes.drawPart(snapshot, sw, sh, 0, 0, 0, 0, ww / pw, wh / ph, r)
      end
    end)
    return true
  end

  if mode == "scene" then
    local s = type(scenes.here) == "function" and scenes.here() or nil
    if surround.gen == 3 then s = surround.gen3Scene() end
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
  local px, py = vpw / (tonumber(info.uiw) or 160), vph / (tonumber(info.uih) or 144)
  each(function(r)
    G.setColor(1, 1, 1, 1)
    scenes.drawPart(img, 8, 8, 0, 0, ox, oy, px, py, r)
  end)
  return true
end

return surround
