-- Big pictures under Gold/Silver/Crystal's move animations
-- A move that shakes or slides the field (Body Slam, Tackle, the intro
-- slide) draws the battle into a canvas and copies it back a line at a
-- time, each line shifted on its own. The lines a Pokémon's box covers
-- move together, so the game's own pictures move whole. A picture bigger
-- than its box (POKEMON SIZE on FULL) reaches lines that don't move, and was
-- cut in two there. So only the part inside the box goes into the canvas,
-- and the rest is drawn after, moved as the box's nearest edge line
-- moved -Elvie
-- --------------------------------------------------

local bands = {}

-- Each side's box, lines top (in) to bottom (out), from
-- engine/battle/core.asm: the enemy's 7x7 tiles at row 0, the player's
-- 6x6 at row 6 -Elvie
bands.BOX = { enemy = { 0, 56 }, player = { 48, 96 } }

-- The text box starts here; nothing of a picture goes past it -Elvie
bands.FLOOR = 96

local function signed(v)
  v = tonumber(v) or 0
  if v >= 128 then return v - 256 end
  return v
end
bands.signed = signed

-- How line `row` of the canvas moved: dx, dy, from the drawn lines
-- ({ src, dest, dx }, as BattleAnimView.scanlines gives them). The
-- topmost line it was drawn on for a top edge, the lowest for a bottom
-- one; when it wasn't drawn at all, the nearest line inside the box that
-- was. nil when nothing of the box shows -Elvie
function bands.edge(lines, row, box, bottom)
  local best, bestGap = nil, nil
  for _, l in ipairs(lines or {}) do
    if l.src >= box[1] and l.src < box[2] then
      local gap = math.abs(l.src - row)
      if not best or gap < bestGap
          or (gap == bestGap and ((bottom and l.dest > best.dest) or (not bottom and l.dest < best.dest))) then
        best, bestGap = l, gap
      end
    end
  end
  if not best then return nil end
  return best.dx, best.dest - best.src
end

-- The intro slide's lines: the top band to $40, the middle to $60, the
-- rest still (BattleAnimView.presentSlide) -Elvie
function bands.slideLines(top, middle)
  local function dx(scx)
    if scx > 128 then return 256 - scx end
    return -scx
  end
  local lines = {}
  for row = 0, 143 do
    local scx = 0
    if row < 0x40 then scx = top elseif row < 0x60 then scx = middle end
    lines[#lines + 1] = { src = row, dest = row, dx = dx(scx) }
  end
  return lines
end

-- Wraps the battle's picture drawing; on(battle) says whether a Facets set
-- is drawing the pictures -Elvie
function bands.install(on)
  local okV, AnimView = pcall(require, "src.ui.gen2.BattleAnimView")
  local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
  local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
  local okG, GbcPalette = pcall(require, "src.render.GbcPalette")
  if not (okV and okB and okC and okG and type(AnimView) == "table" and type(BattleState) == "table"
      and type(AnimView.bake) == "function" and type(AnimView.present) == "function"
      and type(AnimView.scanlines) == "function" and type(BattleState.drawPic) == "function"
      and type(Chrome.clipTo) == "function") then
    return false
  end
  local G = love.graphics
  local baking, mode, over = false, nil, {}

  local ownBake = AnimView.bake
  AnimView.bake = function(...)
    baking = true
    local ok, err = pcall(ownBake, ...)
    baking = false
    if not ok then error(err, 0) end
  end

  local ownDraw = BattleState.drawPic
  BattleState.drawPic = function(self, mon, back, ...)
    if not (baking and mode) then return ownDraw(self, mon, back, ...) end
    local side = back and "player" or "enemy"
    if back and self.slidingBackpic then return ownDraw(self, mon, back, ...) end
    local state = type(self.animPicState) == "function" and self:animPicState(side)
    if state and state.lifted then return ownDraw(self, mon, back, ...) end
    local okOn, yes = pcall(on, self)
    if not (okOn and yes) then return ownDraw(self, mon, back, ...) end
    local box = bands.BOX[side]
    G.push("all")
    Chrome.clipTo(-1000, box[1], 3000, box[2] - box[1])
    local ok, err = pcall(ownDraw, self, mon, back, ...)
    G.pop()
    if not ok then error(err, 0) end
    over[side] = { self = self, mon = mon, back = back }
  end

  -- the parts outside the boxes, after the lines are on screen -Elvie
  local function drawOver(lines, byte)
    for side, o in pairs(over) do
      local box = bands.BOX[side]
      local parts = {
        { from = -1000, to = box[1], row = box[1], bottom = false },
        { from = box[2], to = bands.FLOOR, row = box[2] - 1, bottom = true },
      }
      for _, part in ipairs(parts) do
        local dx, dy = bands.edge(lines, part.row, box, part.bottom)
        if dx and part.to > part.from then
          G.push("all")
          G.translate(dx, dy)
          Chrome.clipTo(-1000, part.from, 3000, part.to - part.from)
          local previous = GbcPalette.setBgp(byte)
          local ok, err = pcall(ownDraw, o.self, o.mon, o.back)
          GbcPalette.setBgp(previous)
          G.pop()
          if not ok then error(err, 0) end
        end
      end
    end
    over = {}
  end

  local ownPresent = AnimView.present
  AnimView.present = function(self, runner, drawBg, battle, ...)
    local bg = type(runner) == "table" and runner.bg
    if type(bg) ~= "table" or bg.lcdc == "BGP" then return ownPresent(self, runner, drawBg, battle, ...) end
    over, mode = {}, "present"
    local ok, err = pcall(ownPresent, self, runner, drawBg, battle, ...)
    mode = nil
    if not ok then over = {} error(err, 0) end
    if next(over) then
      local lines = AnimView.scanlines(bg)
      local baseX = -signed(bg.scx)
      for _, l in ipairs(lines) do l.dx = l.dx + baseX end
      local byte = bg.bgp ~= GbcPalette.BGP_IDENTITY and GbcPalette.available() and bg.bgp or nil
      drawOver(lines, byte)
    end
  end

  if type(AnimView.presentSlide) == "function" and type(AnimView.slideOffsets) == "function" then
    local ownSlide = AnimView.presentSlide
    AnimView.presentSlide = function(self, frame, drawBg, drawBackpic, ...)
      over, mode = {}, "slide"
      local ok, err = pcall(ownSlide, self, frame, drawBg, drawBackpic, ...)
      mode = nil
      if not ok then over = {} error(err, 0) end
      if next(over) then
        local top, middle = AnimView.slideOffsets(frame)
        drawOver(bands.slideLines(top or 0, middle or 0), nil)
      end
    end
  end
  return true
end

return bands
