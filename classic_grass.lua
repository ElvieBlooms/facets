-- Tall grass and tall people on Red, Blue and Yellow
-- OverworldState:drawWorld draws everyone first, then every tall grass
-- strip (the bottom 8 rows of whoever stands in grass) after them all. A
-- Game Boy sprite never reaches the square above it, but a set's 32-pixel
-- person stands 16 pixels into it, so the grass of whoever is behind them
-- (Oak walking you out of Pallet Town's grass) was drawn across their
-- chest. Here each tall NPC's body above its feet is noted as it's drawn,
-- and the strips are drawn around those boxes. A person's own strip starts
-- below their box, so their own feet still go into the grass. Gold, Silver
-- and Crystal draw each person's grass with them, so they don't need this.
-- Emerald Lens does the same for the player; the two wraps nest -Elvie
-- --------------------------------------------------

local grass = {}

-- The part of a tall sprite above its feet strip, { x0, y0, x1, y1 } in
-- map pixels, or nil for a sprite 16 tall or less. The same sums as
-- TileRenderer.feetStrip -Elvie
function grass.body(sprite, px, py)
  if type(sprite) ~= "table" or type(px) ~= "number" or type(py) ~= "number" then return nil end
  local fw, fh = sprite.frameWidth or 16, sprite.frameHeight or 16
  if fh <= 16 then return nil end
  local x0 = math.floor(px + 8 - (sprite.anchorX or fw / 2))
  local top = math.floor(py + 12 - (sprite.anchorY or fh))
  return { x0, top, x0 + fw, top + fh - 8 }
end

-- Calls draw(x0, y0, x1, y1) for each piece of the strip outside every box:
-- above, below, left and right of each box in turn, each pixel once -Elvie
function grass.around(boxes, i, x0, y0, x1, y1, draw)
  local box = boxes[i]
  if not box then return draw(x0, y0, x1, y1) end
  if x1 <= box[1] or x0 >= box[3] or y1 <= box[2] or y0 >= box[4] then
    return grass.around(boxes, i + 1, x0, y0, x1, y1, draw)
  end
  local my0, my1 = math.max(y0, box[2]), math.min(y1, box[4])
  if y0 < box[2] then grass.around(boxes, i + 1, x0, y0, x1, box[2], draw) end
  if y1 > box[4] then grass.around(boxes, i + 1, x0, box[4], x1, y1, draw) end
  if x0 < box[1] then grass.around(boxes, i + 1, x0, my0, box[1], my1, draw) end
  if x1 > box[3] then grass.around(boxes, i + 1, box[3], my0, x1, my1, draw) end
end

-- Red, Blue and Yellow's own modules; the names are built so a Gen 2 or
-- Gen 3 check doesn't look for them there -Elvie
local function gen1(...) return pcall(require, table.concat({ ... }, ".")) end

function grass.install(log)
  local okO, Overworld = gen1("src", "world", "OverworldController")
  local okN, NPC = gen1("src", "world", "NPC")
  local okT, TileRenderer = gen1("src", "render", "TileRenderer")
  if not (okO and okN and okT and type(Overworld) == "table" and type(NPC) == "table"
      and type(TileRenderer) == "table" and type(Overworld.drawWorld) == "function"
      and type(NPC.draw) == "function" and type(NPC.pose) == "function"
      and type(TileRenderer.drawStrip) == "function") then
    if log then log:warn("the overworld's grass drawing wasn't found; tall people may get grass across them") end
    return false
  end

  -- only while the map's own people are drawn: neighbouring maps' people
  -- are in their own map's pixels -Elvie
  local boxes, here, drawing = {}, nil, false
  local ownWorld = Overworld.drawWorld
  Overworld.drawWorld = function(self, ...)
    boxes, here, drawing = {}, {}, true
    for _, e in ipairs(type(self) == "table" and type(self.entities) == "table" and self.entities or {}) do
      here[e] = true
    end
    local results = { pcall(ownWorld, self, ...) }
    drawing = false
    if not results[1] then error(results[2], 0) end
    return unpack(results, 2)
  end

  -- NPC:pose has no side effects, so asking it again is safe -Elvie
  local ownDraw = NPC.draw
  NPC.draw = function(self, ...)
    if drawing and here and here[self] then
      local ok, sprite, px, py = pcall(self.pose, self)
      local box = ok and grass.body(sprite, px, py)
      if box then boxes[#boxes + 1] = box end
    end
    return ownDraw(self, ...)
  end

  for _, name in ipairs({ "drawStrip", "markStripRedraw" }) do
    local own = TileRenderer[name]
    if type(own) == "function" then
      TileRenderer[name] = function(self, x0, y0, x1, y1, ...)
        if not drawing or #boxes == 0 or type(x0) ~= "number" then return own(self, x0, y0, x1, y1, ...) end
        local rest = { ... }
        local n = select("#", ...)
        grass.around(boxes, 1, x0, y0, x1, y1, function(a, b, c, d)
          own(self, a, b, c, d, unpack(rest, 1, n))
        end)
      end
    end
  end
  return true
end

return grass
