-- Thrown balls on the Game Boy games (Red, Blue, Yellow, Gold, Silver, Crystal)
-- With ITEMS on FIRERED or HGSS (classic_items.lua), the ball you throw
-- in battle is that game's own ball too: FireRed's thrown balls, or
-- HeartGold's, Kurt's Apricorn balls and the Park Ball among them. It
-- flies, bounces and wobbles where the game's own would, and opens where
-- the game's opens. A ball one look hasn't got comes from the other, and
-- stays the game's own when neither has it. -Elvie
--
-- The game draws its ball from a few 8x8 tiles. Facets takes those tiles
-- out of what's drawn, finds where the ball is and how it's turned from
-- them, and draws the later game's ball there instead. Nothing from any
-- game is included with Facets. -Elvie
-- --------------------------------------------------

local balls = {}

-- FireRed's thrown balls: one column each, closed, opening and open, in
-- the GBA games' own order -Elvie
balls.GBA_COLUMN = { POKE_BALL = 0, GREAT_BALL = 1, SAFARI_BALL = 2, ULTRA_BALL = 3, MASTER_BALL = 4,
  NET_BALL = 5, DIVE_BALL = 6, NEST_BALL = 7, REPEAT_BALL = 8, TIMER_BALL = 9, LUXURY_BALL = 10, PREMIER_BALL = 11 }

-- Red, Blue and Yellow's ball tiles (move_anim_0, frame blocks 3 to 5):
-- the closed ball, and the ball tipped over, one way or the other -Elvie
balls.GEN1_CLOSED = { [2] = true, [18] = true }
balls.GEN1_TIPPED = { [6] = true, [7] = true, [22] = true, [23] = true }
balls.GEN1_ANIMS = { TOSS_ANIM = true, GREATTOSS_ANIM = true, ULTRATOSS_ANIM = true,
  SHAKE_ANIM = true, BLOCKBALL_ANIM = true }
-- Gold, Silver and Crystal's: the ball sheet's tiles 0-1 upright, 2-5
-- tipped (mirrored for the other way), 6 and 7 opening -Elvie
balls.GEN2_GFX = "BATTLE_ANIM_GFX_POKE_BALL"

balls.TILT = math.pi / 4

-- How the game's ball is turned, from Red to Yellow's ball sprites:
-- "closed" or "tilt", and which way (1 or -1) -Elvie
function balls.gen1Pose(list)
  local pose, dir = "closed", 1
  for _, s in ipairs(list) do
    if balls.GEN1_TIPPED[s.tile] then
      pose = "tilt"
      if s.tile == 6 then dir = s.xf and -1 or 1 end
    end
  end
  return pose, dir
end

-- ...and from Gold to Crystal's: { index in the ball sheet, xflip } -Elvie
function balls.gen2Pose(list)
  local pose, dir = "closed", 1
  for _, e in ipairs(list) do
    if e.index >= 6 then return "open", 1 end
    if e.index >= 2 then
      pose = "tilt"
      if e.index == 2 then dir = e.xflip and -1 or 1 end
    end
  end
  return pose, dir
end

-- The middle of 8x8 hardware sprites at OAM (x, y), each drawn at
-- (x - 8, y - 16) -Elvie
function balls.middle(list)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, s in ipairs(list) do
    local x, y = s.x - 8, s.y - 16
    if x < x0 then x0 = x end
    if y < y0 then y0 = y end
    if x + 8 > x1 then x1 = x + 8 end
    if y + 8 > y1 then y1 = y + 8 end
  end
  return (x0 + x1) / 2, (y0 + y1) / 2
end

-- The sheet's frames for a ball: { image, closed = { x, y, w, h }, open = ... }
local function frames(image, closed, open)
  return { image = image, closed = closed, open = open, quads = {} }
end

-- Draws a ball's frame, its middle at (cx, cy), turned for a tilt -Elvie
function balls.draw(art, pose, dir, cx, cy)
  local box = pose == "open" and art.open or art.closed
  local q = art.quads[box]
  if not q then
    local iw, ih = art.image:getDimensions()
    q = love.graphics.newQuad(box[1], box[2], box[3], box[4], iw, ih)
    art.quads[box] = q
  end
  local angle = pose == "tilt" and balls.TILT * (dir or 1) or 0
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(art.image, q, math.floor(cx + 0.5), math.floor(cy + 0.5), angle, 1, 1, box[3] / 2, box[4] / 2)
end

function balls.init(mod)
  return function()
    local items = require("mods.facets.classic_items")
    local gba = require("mods.facets.classic_gba")
    local ds = require("mods.facets.ds")
    local okP, PaletteFX = pcall(require, "src.render.PaletteFX")

    local made = {}
    local function gbaArt(ball)
      local col = balls.GBA_COLUMN[ball]
      if not col then return nil end
      if made.gbaSheet == nil then
        made.gbaSheet = false
        for _, game in ipairs({ "firered", "leafgreen", "emerald" }) do
          local data = gba.image(gba.read(game, "pokemon/battle/ball_open/balls.rgba"), 192, 48)
          if data then
            local okImg, img = pcall(love.graphics.newImage, data)
            if okImg then
              img:setFilter("nearest", "nearest")
              made.gbaSheet = img
            end
            break
          end
        end
      end
      if not made.gbaSheet then return nil end
      local key = "gba:" .. ball
      made[key] = made[key] or frames(made.gbaSheet, { col * 16, 0, 16, 16 }, { col * 16, 16, 16, 16 })
      return made[key]
    end
    local function dsArt(ball)
      local name = tostring(ball):lower()
      local key = "ds:" .. name
      if made[key] == nil then
        local dsApi = ds.api(mod)
        -- (not ready yet, or still importing: asked again later) -Elvie
        if not (dsApi and ds.state(dsApi, "hgss") == "ready") then return nil end
        made[key] = false
        if type(dsApi.imageData) == "function" then
          local okD, data = pcall(dsApi.imageData, "hgss", "balls", name)
          if okD and data then
            local okImg, img = pcall(love.graphics.newImage, data)
            if okImg then
              img:setFilter("nearest", "nearest")
              made[key] = frames(img, { 0, 0, 16, 16 }, { 0, 16, 32, 32 })
            end
          end
        end
      end
      return made[key] or nil
    end
    local function art(ball)
      ball = ball or "POKE_BALL"
      local look = mod.options:get("classicItems")
      if look == items.GBA then return gbaArt(ball) or dsArt(ball) end
      if look == items.DS then return dsArt(ball) or gbaArt(ball) end
      return nil
    end
    local function drawBall(a, pose, dir, cx, cy)
      if okP and type(PaletteFX.markTrueColor) == "function" then
        local r = pose == "open" and a.open[3] / 2 or 12
        pcall(PaletteFX.markTrueColor, math.floor(cx - r), math.floor(cy - r), r * 2, r * 2)
      end
      balls.draw(a, pose, dir, cx, cy)
    end

    -- Red, Blue and Yellow: the move animation player, which knows the
    -- ball being thrown -Elvie
    local okA, AnimPlayer = pcall(require, "src.battle.AnimPlayer")
    if okA and type(AnimPlayer) == "table" and type(AnimPlayer.start) == "function"
        and type(AnimPlayer.drawSprites) == "function" then
      local ownStart = AnimPlayer.start
      AnimPlayer.start = function(self, moveId, attackerIsPlayer, opts, ...)
        self._facetsMove = moveId
        if type(opts) == "table" and opts.ball then self._facetsBall = opts.ball end
        return ownStart(self, moveId, attackerIsPlayer, opts, ...)
      end
      local ownDraw = AnimPlayer.drawSprites
      AnimPlayer.drawSprites = function(self, sprites, colorFn, ...)
        local a = balls.GEN1_ANIMS[self._facetsMove] and type(sprites) == "table" and art(self._facetsBall)
        if not a then return ownDraw(self, sprites, colorFn, ...) end
        local rest, ball = {}, {}
        for _, s in ipairs(sprites) do
          if s.ts == 0 and (balls.GEN1_CLOSED[s.tile] or balls.GEN1_TIPPED[s.tile]) then
            -- (the hardware hides sprites at the edges) -Elvie
            if s.x > 0 and s.x < 168 and s.y > 0 and s.y < 160 then ball[#ball + 1] = s end
          else
            rest[#rest + 1] = s
          end
        end
        if #ball == 0 then return ownDraw(self, sprites, colorFn, ...) end
        ownDraw(self, rest, colorFn, ...)
        local pose, dir = balls.gen1Pose(ball)
        local cx, cy = balls.middle(ball)
        drawBall(a, pose, dir, cx, cy)
      end
    end

    -- Gold, Silver and Crystal: the battle animation's objects, and the
    -- ball the battle screen says is being thrown -Elvie
    local okS, BattleState2 = pcall(require, "src.ui.gen2.BattleState")
    if okS and type(BattleState2) == "table" and type(BattleState2.startBallAnim) == "function" then
      local own = BattleState2.startBallAnim
      BattleState2.startBallAnim = function(self, param, itemId, ...)
        balls.thrown = itemId
        return own(self, param, itemId, ...)
      end
    end
    local okV, View = pcall(require, "src.ui.gen2.BattleAnimView")
    if okV and type(View) == "table" and type(View.drawObjects) == "function" then
      local own = View.drawObjects
      View.drawObjects = function(self, runner, battle, ...)
        local a = type(runner) == "table" and type(runner.loaded) == "table" and art(balls.thrown)
        if not a then return own(self, runner, battle, ...) end
        local okO, oam = pcall(runner.oam, runner)
        if not (okO and type(oam) == "table") then return own(self, runner, battle, ...) end
        local rest, ball = {}, {}
        for _, obj in ipairs(oam) do
          local entry, index
          for i = #runner.loaded, 1, -1 do
            local e = runner.loaded[i]
            if obj.tile >= e.tile and obj.tile < e.tile + math.max(e.tiles or 0, 1) then
              entry, index = e, obj.tile - e.tile
              break
            end
          end
          if entry and entry.gfx == balls.GEN2_GFX then
            ball[#ball + 1] = { x = obj.x, y = obj.y, index = index, xflip = (obj.attr or 0) % 64 >= 32 }
          else
            rest[#rest + 1] = obj
          end
        end
        if #ball == 0 then return own(self, runner, battle, ...) end
        runner.oam = function() return rest end
        local ok, err = pcall(own, self, runner, battle, ...)
        runner.oam = nil
        if not ok then error(err, 0) end
        local pose, dir = balls.gen2Pose(ball)
        local cx, cy = balls.middle(ball)
        drawBall(a, pose, dir, cx, cy)
      end
    end
  end
end

return balls
