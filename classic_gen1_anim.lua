-- Pokémon animations on Red, Blue and Yellow
-- Gen 1 never animated its Pokémon. Facets plays two kinds there: Crystal's
-- animation when the foe's Pokémon comes out (POKEMON on CRYSTAL, or an
-- EMERALD look, from the player's own Crystal), and the DS games' idles,
-- round and round on both sides (DPPT, HGSS and B2W2). The battle draws
-- every picture through picImage, so while one is moving that's handed
-- the frame showing instead of the still one, and does with it all it
-- does with the still one: COLORS, the fades, the black slide-in, the
-- mono modes. Each frame is its own picture, loaded the way the game
-- loads its own (getImage, through BattleState.trainerSprite), so it has
-- the still one's colours, ground line and size -Elvie
-- --------------------------------------------------

local g1 = {}

-- The frame of a column sheet as ImageData: slot n (0 = the still one) -Elvie
function g1.slot(sheet, size, n)
  local w, h = sheet:getDimensions()
  if n < 0 or (n + 1) * size > h or size > w then return nil end
  local out = love.image.newImageData(size, size)
  out:paste(sheet, 0, 0, 0, n * size, size, size)
  return out
end

-- A grey or full-colour frame in a Gen 1 palette's four colours, by
-- brightness, the way the game tints its own pictures -Elvie
function g1.tint(data, colors)
  if type(colors) ~= "table" then return data end
  local w, h = data:getDimensions()
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local r, _, _, a = data:getPixel(x, y)
      if a and a > 0 then
        local c = r > 0.83 and colors[1] or r > 0.5 and colors[2] or r > 0.17 and colors[3] or colors[4]
        data:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, a)
      end
    end
  end
  return data
end

-- A Pokémon's colours the way the battle asks for them (monPalette) -Elvie
local function palette(PaletteFX, data, species)
  local okC, colors = pcall(PaletteFX.monPal, data, species)
  if not (okC and colors) then return nil end
  local okN, name = pcall(PaletteFX.monPalName, data, species)
  name = okN and name or tostring(species)
  local okG, gbc = pcall(PaletteFX.usesGbcPack)
  if okG and gbc then name = "redpp:" .. name end
  return { name = name, colors = colors }
end

-- A picture at path, loaded by the battle itself, in a Pokémon's colours
-- (unless full colour is shown as it is): getImage is the battle's own,
-- reached through trainerSprite, which only hands its three answers to
-- it -Elvie
function g1.engineImage(BattleState, data, species, path, trueColor)
  local okF, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not okF then return nil end
  local pal = palette(PaletteFX, data, species)
  local P, Q, T = BattleState.trainerPicPath, BattleState.trainerPalette, BattleState.trainerTrueColor
  BattleState.trainerPicPath = function() return path end
  BattleState.trainerPalette = function() return pal end
  BattleState.trainerTrueColor = function() return trueColor and true or false end
  local ok, img = pcall(BattleState.trainerSprite, data, {}, nil, nil)
  BattleState.trainerPicPath, BattleState.trainerPalette, BattleState.trainerTrueColor = P, Q, T
  return ok and img or nil
end

-- source(battle, battler) gives what's playing on that side, or nil:
--   { key, frameAt(now) -> n, framePath(n) -> path, trueColor, once }
-- framePath(0) is never asked for; n = 0 is the still picture. once means
-- it plays a single time from when the Pokémon is fully out (Crystal's);
-- otherwise it loops by the clock. Returns whether it went in -Elvie
function g1.install(BattleState, source, log)
  if type(BattleState) ~= "table" or type(BattleState.picImage) ~= "function"
      or type(BattleState.trainerSprite) ~= "function" then return false end

  local own = BattleState.picImage
  local function out(self, b)
    -- still sliding in: Crystal's plays once the foe has stopped -Elvie
    if (self.introSlide or 0) > 0 then return false end
    if self.enemySendingOut and b == self.enemy then return false end
    if b == self.enemy and self.showEnemyTrainer then return false end
    if type(self.growInScale) == "function" and self:growInScale(b) then return false end
    return true
  end
  BattleState.picImage = function(self, img, ...)
    if img == nil then return own(self, img, ...) end
    local b
    if self.enemy and img == self.enemy.sprite then b = self.enemy
    elseif self.player and img == self.player.sprite then b = self.player end
    if not (b and b.mon) then return own(self, img, ...) end
    local ok, frame = pcall(function()
      local st = b.facetsAnim
      if not st or st.mon ~= b.mon or st.img ~= img then
        st = { mon = b.mon, img = img }
        b.facetsAnim = st
      end
      if st.src == nil then
        if not out(self, b) then return nil end
        st.src = source(self, b) or false
        st.at = love.timer and love.timer.getTime() or 0
      end
      local src = st.src
      if not src then return nil end
      local now = love.timer and love.timer.getTime() or st.at
      local n = src.frameAt(now - st.at)
      if not n or n <= 0 then
        if src.once and n == nil then st.src = false end
        return nil
      end
      st.images = st.images or {}
      local hit = st.images[n]
      if hit == nil then
        local path = src.framePath(n)
        hit = path and g1.engineImage(BattleState, self.data, b.mon.species, path, src.trueColor) or false
        st.images[n] = hit
      end
      return hit or nil
    end)
    if not ok then
      if log then log("a Pokémon's animation stopped: %s", tostring(frame)) end
      b.facetsAnim = { mon = b.mon, img = img, src = false }
      frame = nil
    end
    return own(self, frame or img, ...)
  end
  return true
end

-- A Crystal script played once, as a source's frameAt: the frame showing
-- `elapsed` seconds in, or nil when it's over -Elvie
function g1.once(MonAnim, script)
  local runner = MonAnim.new(script, "battle")
  if not runner then return nil end
  local ticks = 0
  return function(elapsed)
    local due = math.floor(elapsed * 60)
    while ticks < due do
      runner:update()
      ticks = ticks + 1
      if runner:finished() then return nil end
    end
    return runner:currentFrame() or 0
  end
end

return g1
