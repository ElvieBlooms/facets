-- YOUR SIDE's animation in Gold, Silver and Crystal
-- Crystal plays a Pokémon's front animation when the foe's comes out
-- (BattleState.startFrontAnim, ANIM_MON_NORMAL on the enemy's frontpic)
-- and draws its frames only on the foe's side: your side shows a backpic,
-- which never moves. With YOUR SIDE on FRONT or MIRRORED your Pokémon is a
-- front picture, so it gets the same animation when it's sent out, from
-- the same data and sheet (the game's, or the POKEMON set's through
-- pokemon.sprite), each frame copied out once, mirrored for MIRRORED, and
-- handed to drawPic as your side's picture while it plays. Gold and Silver
-- have no animations, so there it does nothing -Elvie
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
function sideAnim.install(BattleState, MonAnim, side, log)
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

  local function start(self, mon)
    self.facetsSideAnim = nil
    local s = side()
    if s ~= "front" and s ~= "mirrored" or type(mon) ~= "table" then return end
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

  local ownUpdate = BattleState.update
  BattleState.update = function(self, ...)
    local state = self.facetsSideAnim
    if state then
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
    local okF, frame = pcall(state.runner.currentFrame, state.runner)
    if not okF then return image, trueColor, path end
    local img = frameImage(state.sheetPath, frame, state.size, state.mirror)
    if not img then return image, trueColor, path end
    return img, trueColor, path
  end
  return true
end

return sideAnim
