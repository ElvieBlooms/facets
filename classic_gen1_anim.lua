-- Pokémon animations on Red, Blue and Yellow
-- Gen 1 never animated its Pokémon; Crystal plays one when the foe's comes
-- out. With POKEMON on CRYSTAL (Crystal's own frames) or an EMERALD look
-- (Emerald's two frames to Crystal's script), Facets plays that same
-- animation on the foe's Pokémon once it's fully on screen, from the
-- player's own Crystal. The battle draws every picture through picImage,
-- so while the animation runs that hands back the frame showing, tinted
-- the way the game tints the still one. Only at SIZE FIT, where the frames
-- and the still picture are the same size -Elvie
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

-- info(battle, mon) gives { path, size, script, trueColor } or nil.
-- Returns whether it went in -Elvie
function g1.install(BattleState, MonAnim, info, log)
  if type(BattleState) ~= "table" or type(BattleState.picImage) ~= "function" then return false end
  if type(MonAnim) ~= "table" or type(MonAnim.new) ~= "function" then return false end
  local okA, Assets = pcall(require, "src.render.Assets")
  local okF, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not (okA and okF) then return false end

  local images = {}
  local function frameImage(battle, st, n)
    local key = st.path .. "#" .. n .. (st.tintName or "")
    local hit = images[key]
    if hit ~= nil then return hit or nil end
    images[key] = false
    local okS, sheet = pcall(Assets.imageData, st.path)
    if not (okS and sheet) then return nil end
    local data = g1.slot(sheet, st.size, n)
    if not data then return nil end
    if st.colors then g1.tint(data, st.colors) end
    local okI, img = pcall(love.graphics.newImage, data)
    if not okI then return nil end
    img:setFilter("nearest", "nearest")
    images[key] = img
    return img
  end

  local function start(battle, e)
    local st = { mon = e.mon }
    battle.facetsGen1Anim = st
    local got = info(battle, e.mon)
    if type(got) ~= "table" then return st end
    local runner = MonAnim.new(got.script, "battle")
    if not runner then return st end
    st.runner, st.path, st.size, st.ticks = runner, got.path, got.size, 0
    st.at = love.timer and love.timer.getTime() or 0
    -- the game tints a picture unless it's full colour and shown as it is -Elvie
    local honours = type(PaletteFX.honorsTrueColor) == "function" and PaletteFX.honorsTrueColor()
    if not (got.trueColor and honours) and type(PaletteFX.monPal) == "function" then
      local okP, colors = pcall(PaletteFX.monPal, battle.data, e.mon.species)
      if okP and type(colors) == "table" then
        st.colors = colors
        local okN, name = pcall(PaletteFX.monPalName, battle.data, e.mon.species)
        st.tintName = "@" .. tostring(okN and name or "") .. (PaletteFX.usesGbcPack and PaletteFX.usesGbcPack() and "+" or "")
      end
    end
    return st
  end

  local function plain(battle)
    if battle.grayPics or battle.blackedOut or (battle.introSlide or 0) > 0 then return false end
    local mode = PaletteFX.mode
    if mode == "og" or mode == "og_inv" or mode == "classic" then return false end
    if type(PaletteFX.forcesRawGrays) == "function" and PaletteFX.forcesRawGrays() then return false end
    return true
  end

  local own = BattleState.picImage
  BattleState.picImage = function(self, img, ...)
    local out = own(self, img, ...)
    local e = self.enemy
    if img == nil or not (e and e.mon and img == e.sprite) or not plain(self) then return out end
    local ok, frame = pcall(function()
      local st = self.facetsGen1Anim
      if not st or st.mon ~= e.mon then
        -- once it's fully out: not mid-slide, mid-throw or growing -Elvie
        if self.enemySendingOut or self.showEnemyTrainer then return nil end
        if type(self.growInScale) == "function" and self:growInScale(e) then return nil end
        st = start(self, e)
      end
      if not st.runner then return nil end
      local now = love.timer and love.timer.getTime() or st.at
      local due = math.floor((now - st.at) * 60)
      while st.ticks < due do
        st.runner:update()
        st.ticks = st.ticks + 1
        if st.runner:finished() then st.runner = nil return nil end
      end
      local n = st.runner:currentFrame() or 0
      if n <= 0 then return nil end
      return frameImage(self, st, n)
    end)
    if not ok then
      if log then log("the foe's animation stopped: %s", tostring(frame)) end
      self.facetsGen1Anim = { mon = e.mon }
      return out
    end
    return frame or out
  end
  return true
end

return g1
