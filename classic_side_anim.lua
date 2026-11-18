-- YOUR SIDE's animation in Gold, Silver and Crystal
-- Crystal plays a Pokémon's front animation when the foe's comes out
-- (BattleState.startFrontAnim, ANIM_MON_NORMAL on the enemy's frontpic)
-- and draws its frames only on the foe's side: your side shows a backpic,
-- which never moves. With YOUR SIDE on FRONT or MIRRORED your Pokémon is a
-- front picture, so it gets the same animation when it's sent out, from
-- the same data and sheet (the game's, or the POKEMON set's through
-- pokemon.sprite), each frame copied out once, mirrored for MIRRORED, and
-- handed to drawPic as your side's picture while it plays. Kanto
-- Reforged's own Pokémon play its strip instead, as it plays the foe's
-- (classic_kr) -Elvie
-- --------------------------------------------------

local sideAnim = {}

-- Which frame of a column sheet is showing: a quad's source rectangle, or
-- nil past the sheet's end. Frame 0 is the still picture -Elvie
function sideAnim.frameRect(frame, size, sheetW, sheetH)
  if type(frame) ~= "number" or frame <= 0 or not size or size <= 0 then return nil end
  if (frame + 1) * size > sheetH then return nil end
  return 0, frame * size, math.min(size, sheetW), size
end

-- side() gives YOUR SIDE: "back", "front" or "mirrored". Returns whether
-- it went in -Elvie
-- seconds a Pokémon stands still between plays, with ANIMATION: LOOP -Elvie
sideAnim.REST = 3

-- mode() gives ANIMATION: "loop", "intro" or "off" -Elvie
function sideAnim.install(BattleState, MonAnim, side, log, mode)
  if type(BattleState) ~= "table" or type(MonAnim) ~= "table" or type(MonAnim.new) ~= "function" then return false end
  for _, name in ipairs({ "animData", "animSheetPath", "finishSendOut", "pic", "update" }) do
    if type(BattleState[name]) ~= "function" then return false end
  end
  local Assets = package.loaded["src.render.Assets"] or require("src.render.Assets")

  -- frames cut from a sheet's pixels, by sheet path and mirror: an Image
  -- each -Elvie
  local cut = {}
  local function frameImage(sheetPath, frame, size, mirror)
    local bySheet = cut[sheetPath] or {}
    cut[sheetPath] = bySheet
    local key = (mirror and "m" or "") .. frame
    if bySheet[key] ~= nil then return bySheet[key] or nil end
    bySheet[key] = false
    local okD, data = pcall(Assets.imageData, sheetPath)
    if not (okD and data) then return nil end
    local w, h = data:getDimensions()
    local x, y, qw, qh = sideAnim.frameRect(frame, size, w, h)
    if not x then return nil end
    local out = love.image.newImageData(qw, qh)
    out:paste(data, 0, 0, x, y, qw, qh)
    if mirror then
      local flipped = love.image.newImageData(qw, qh)
      flipped:mapPixel(function(px, py) return out:getPixel(qw - 1 - px, py) end)
      out = flipped
    end
    local okI, img = pcall(love.graphics.newImage, out)
    if not okI then return nil end
    img:setFilter("nearest", "nearest")
    bySheet[key] = img
    return img
  end

  -- Kanto Reforged's strips, a frame each, by strip path and mirror -Elvie
  local okK, kr = pcall(require, "mods.facets.classic_kr")
  local function stripImage(strip, n, mirror)
    local bySheet = cut[strip.path] or {}
    cut[strip.path] = bySheet
    local key = "kr" .. (mirror and "m" or "") .. n
    if bySheet[key] ~= nil then return bySheet[key] or nil end
    bySheet[key] = false
    local okD, data = pcall(Assets.imageData, strip.path)
    local out = okD and data and kr.cut(data, strip.meta, n, mirror)
    if not out then return nil end
    local okI, img = pcall(love.graphics.newImage, out)
    if not okI then return nil end
    img:setFilter("nearest", "nearest")
    bySheet[key] = img
    return img
  end

  local function start(self, mon)
    self.facetsSideAnim = nil
    local s = side()
    if s ~= "front" and s ~= "mirrored" or type(mon) ~= "table" then return end
    -- one of Kanto Reforged's: its strip, played as it plays the foe's -Elvie
    if okK and kr.owns(self.battle, mon) then
      local strip = kr.strip(self.battle, mon)
      local player = strip and kr.player(strip.meta)
      if player then self.facetsSideAnim = { mon = mon, kr = strip, player = player, mirror = s == "mirrored" } end
      return
    end
    local data = self:animData(mon)
    if type(data) ~= "table" or not data.tiles then return end
    local sheetPath, replaced = self:animSheetPath(mon, data)
    if type(sheetPath) ~= "string" then return end
    -- a front picture replaced without an animation to match stays still,
    -- as the foe's does -Elvie
    if not replaced and type(self.frontPicReplaced) == "function" then
      local okR, yes = pcall(self.frontPicReplaced, self, mon)
      if okR and yes then return end
    end
    self.picCache = self.picCache or {}
    local sheet = self.picCache[sheetPath]
    if sheet == nil then
      local ok, image = pcall(Assets.image, sheetPath)
      sheet = ok and image or false
      self.picCache[sheetPath] = sheet
    end
    if not sheet then return end
    local runner = MonAnim.new(data, "battle")
    if not runner then return end
    self.facetsSideAnim = { mon = mon, runner = runner, sheetPath = sheetPath, size = data.tiles * 8,
      mirror = s == "mirrored" }
  end

  local ownSendOut = BattleState.finishSendOut
  BattleState.finishSendOut = function(self, after, ...)
    local results = { ownSendOut(self, after, ...) }
    if type(after) == "table" and after.side == "player" then
      local ok, err = pcall(start, self, after.mon)
      if not ok and log then log("your side's animation didn't start: %s", tostring(err)) end
    end
    return unpack(results)
  end

  -- ANIMATION: LOOP. The game plays the foe's animation once as it comes
  -- out (self.frontAnim, which the battle also waits on). While the battle
  -- waits for your command, each Pokémon that's out plays it again after
  -- a rest (counted in the battle's frames), with no cry, on a runner of Facets' own so the battle never
  -- waits on it -Elvie
  local function waiting(self)
    local p = self.phase
    if not (p == "menu" or p == "moves" or p == "submenu") then return false end
    if self.frontAnim or self.faintSlide or self.backpicSlide or self.winSliding or self.trainerSlide then return false end
    if self.anim and not (type(self.anim.done) == "function" and self.anim:done()) then return false end
    return true
  end
  local function out(self, which)
    local battle = self.battle
    if type(battle) ~= "table" then return nil end
    local mon = battle[which]
    if type(self.activeMon) == "function" then
      local ok, m = pcall(self.activeMon, self, which)
      if ok and m ~= nil then mon = m end
    end
    if type(mon) ~= "table" or (tonumber(mon.hp) or 0) <= 0 then return nil end
    return mon
  end
  local function foeRunner(self, mon)
    local data = self:animData(mon)
    if type(data) ~= "table" or not data.tiles then return nil end
    local sheetPath, replaced = self:animSheetPath(mon, data)
    if type(sheetPath) ~= "string" then return nil end
    if not replaced and type(self.frontPicReplaced) == "function" then
      local okR, yes = pcall(self.frontPicReplaced, self, mon)
      if okR and yes then return nil end
    end
    self.picCache = self.picCache or {}
    local sheet = self.picCache[sheetPath]
    if sheet == nil then
      local ok, image = pcall(Assets.image, sheetPath)
      sheet = ok and image or false
      self.picCache[sheetPath] = sheet
    end
    if not sheet then return nil end
    local runner = MonAnim.new(data, "battle")
    if not runner then return nil end
    return { mon = mon, runner = runner, sheet = sheet, size = data.tiles * 8, quads = {} }
  end
  local function looping(self, now)
    local rest = self.facetsRest or {}
    self.facetsRest = rest
    if not (mode and mode() == "loop") or not waiting(self) then
      rest.foe, rest.side = nil, nil
      self.facetsFoeLoop = nil
      return
    end
    -- the foe's -Elvie
    local foe = out(self, "enemy")
    local playing = self.facetsFoeLoop
    if playing and playing.mon ~= foe then playing, self.facetsFoeLoop = nil, nil end
    if playing then
      playing.runner:update()
      if playing.runner:finished() then self.facetsFoeLoop = nil; rest.foe = now end
    elseif foe then
      if not rest.foe or rest.foeMon ~= foe then rest.foe, rest.foeMon = now, foe end
      if now - rest.foe >= sideAnim.REST * 60 then
        rest.foe = now
        self.facetsFoeLoop = foeRunner(self, foe)
      end
    end
    -- yours, when YOUR SIDE shows its front -Elvie
    local s = side()
    local mine = (s == "front" or s == "mirrored") and out(self, "player") or nil
    if mine and not self.facetsSideAnim and not self.showPlayerTrainer then
      if not rest.side or rest.sideMon ~= mine then rest.side, rest.sideMon = now, mine end
      if now - rest.side >= sideAnim.REST * 60 then
        rest.side = now
        pcall(start, self, mine)
      end
    elseif self.facetsSideAnim then
      rest.side = now
    end
  end

  if type(BattleState.frontAnimFrame) == "function" then
    local ownFrame = BattleState.frontAnimFrame
    BattleState.frontAnimFrame = function(self, mon, ...)
      local sheet, quad, size = ownFrame(self, mon, ...)
      if sheet then return sheet, quad, size end
      local state = self.facetsFoeLoop
      if not (state and mon and state.mon == mon) then return sheet, quad, size end
      local okF, frame = pcall(state.runner.currentFrame, state.runner)
      if not okF or type(frame) ~= "number" or frame <= 0 then return nil end
      local q = state.quads[frame]
      if not q then
        local w, h = state.sheet:getDimensions()
        local x, y, qw, qh = sideAnim.frameRect(frame, state.size, w, h)
        if not x then return nil end
        q = love.graphics.newQuad(x, y, qw, qh, w, h)
        state.quads[frame] = q
      end
      return state.sheet, q, state.size
    end
  end

  local ownUpdate = BattleState.update
  BattleState.update = function(self, ...)
    -- (the battle steps once a frame, whatever the time passed: so the
    -- rest is counted in its frames) -Elvie
    self.facetsTick = (self.facetsTick or 0) + 1
    local ok, err = pcall(looping, self, self.facetsTick)
    if not ok and log then log("ANIMATION: LOOP: %s", tostring(err)) end
    local state = self.facetsSideAnim
    if state and state.player then
      if not state.player.step() then self.facetsSideAnim = nil end
    elseif state then
      local ok = pcall(state.runner.update, state.runner)
      local okF, done = pcall(state.runner.finished, state.runner)
      if not ok or (okF and done) then self.facetsSideAnim = nil end
    end
    return ownUpdate(self, ...)
  end

  local ownPic = BattleState.pic
  BattleState.pic = function(self, mon, back, ...)
    local image, trueColor, path = ownPic(self, mon, back, ...)
    local state = back and self.facetsSideAnim
    if not (state and image and state.mon == mon) or self.showPlayerTrainer then return image, trueColor, path end
    if state.player then
      local n = state.player.frame()
      local img = n and n > 1 and stripImage(state.kr, n, state.mirror)
      return img or image, trueColor, path
    end
    local okF, frame = pcall(state.runner.currentFrame, state.runner)
    if not okF then return image, trueColor, path end
    local img = frameImage(state.sheetPath, frame, state.size, state.mirror)
    if not img then return image, trueColor, path end
    return img, trueColor, path
  end
  return true
end

return sideAnim
