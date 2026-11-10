-- SIZE on the GBA games (FireRed, LeafGreen, Ruby, Sapphire, Emerald)
-- Every battle picture there is a 64x64 slot, which is what the sets are
-- drawn for, and DS art is already fitted into it (ds.lua), so FIT is how
-- they've always looked. SMALL (0.75x) and TINY (0.5x) shrink a set's
-- picture inside its slot, about the spot it stands on: a Pokémon's feet
-- (or, for your side, the top of the text box) and a trainer's lowest
-- row, so they stay on the ground. Battles only; the summary, Pokédex and
-- the rest keep the full picture, as on the Game Boy games -Elvie
-- --------------------------------------------------

local size = {}

size.SIZES = { { "FIT", "fit" }, { "SMALL", "0.75" }, { "TINY", "0.5" } }

-- The scale a SIZE value means, or nil for FIT (anything unknown is FIT,
-- FULL included, since it isn't offered yet) -Elvie
function size.scaleOf(value)
  local s = tonumber(value)
  if not s or s >= 1 or s <= 0 then return nil end
  return s
end

-- The lowest drawn row of a picture, plus one (where it stands), or nil
-- for an empty one -Elvie
function size.standsAt(data)
  local w, h = data:getDimensions()
  for y = h - 1, 0, -1 do
    for x = 0, w - 1 do
      local _, _, _, a = data:getPixel(x, y)
      if a > 0 then return y + 1 end
    end
  end
  return nil
end

-- data shrunk by s inside a picture the same size, about the point ax, ay
-- (pixel edges: 32 is the middle of a 64-wide picture). Each new pixel
-- stands for a block of old ones: on the picture's edge (a block that's
-- partly see-through) it takes the darkest drawn one, so the outline
-- stays whole, and inside it takes the middle one, so the colours stay
-- as drawn. Every frame of an animation shrinks about the same point, so
-- they don't jump against each other -Elvie
function size.shrink(data, s, ax, ay)
  local w, h = data:getDimensions()
  local out = love.image.newImageData(w, h)
  local EPS = 1e-6
  local function span(d, a, n)
    local lo = math.floor(a + (d - a) / s + EPS)
    local hi = math.ceil(a + (d + 1 - a) / s - EPS) - 1
    if lo < 0 then lo = 0 end
    if hi > n - 1 then hi = n - 1 end
    return lo, hi
  end
  -- only the new pixels the picture can reach -Elvie
  local dx0, dx1 = math.max(0, math.floor(ax - ax * s)), math.min(w - 1, math.ceil(ax + (w - ax) * s))
  local dy0, dy1 = math.max(0, math.floor(ay - ay * s)), math.min(h - 1, math.ceil(ay + (h - ay) * s))
  for dy = dy0, dy1 do
    local y0, y1 = span(dy, ay, h)
    for dx = dx0, dx1 do
      local x0, x1 = span(dx, ax, w)
      if x0 <= x1 and y0 <= y1 then
        local clear, dark, darkL = false, nil, nil
        for y = y0, y1 do
          for x = x0, x1 do
            local r, g, b, a = data:getPixel(x, y)
            if a > 0 then
              local l = 0.299 * r + 0.587 * g + 0.114 * b
              if not darkL or l < darkL then dark, darkL = { r, g, b, a }, l end
            else
              clear = true
            end
          end
        end
        if dark then
          local c = dark
          if not clear then
            local mx, my = math.floor((x0 + x1) / 2), math.floor((y0 + y1) / 2)
            local r, g, b, a = data:getPixel(mx, my)
            c = { r, g, b, a }
          end
          out:setPixel(dx, dy, c[1], c[2], c[3], c[4])
        end
      end
    end
  end
  return out
end

-- A picture's pixels, for one with no ImageData of its own: drawn once
-- into a canvas and read back -Elvie
local function pixelsOf(entry)
  if entry.imageData then return entry.imageData end
  local image = entry.image
  if not (image and love.graphics and love.graphics.newCanvas) then return nil end
  local ok, data = pcall(function()
    local iw, ih = image:getDimensions()
    local canvas = love.graphics.newCanvas(iw, ih, { dpiscale = 1 })
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, 0, 0)
    love.graphics.pop()
    local got = canvas:newImageData()
    canvas:release()
    return got
  end)
  return ok and data or nil
end

-- A sizer: sized(entry, s, standsAt) gives the entry shrunk by s, made
-- once per picture and scale and kept while the picture is; standsAt is
-- the row it stands on, or nil for its lowest drawn row. Anything that
-- can't be shrunk comes back as it was -Elvie
function size.sizer()
  local made = {}
  local function sized(entry, s, standsAt)
    if not (s and type(entry) == "table" and entry.image) or entry.facetsSized then return entry end
    local byEntry = made[s]
    if not byEntry then
      byEntry = setmetatable({}, { __mode = "k" })
      made[s] = byEntry
    end
    local got = byEntry[entry]
    if got ~= nil then return got or entry end
    byEntry[entry] = false
    local data = pixelsOf(entry)
    if not data then return entry end
    local w = data:getDimensions()
    local ay = standsAt or size.standsAt(data)
    if not ay then return entry end
    local ok, small = pcall(size.shrink, data, s, w / 2, ay)
    if not ok then return entry end
    local image = love.graphics.newImage(small)
    image:setFilter("nearest", "nearest")
    local copy = {}
    for k, v in pairs(entry) do copy[k] = v end
    copy.image, copy.imageData, copy.facetsSized = image, small, true
    byEntry[entry] = copy
    return copy
  end
  return sized, function() made = {} end
end

return size
