-- The Game Boy Color's Poké Ball, for FireRed to Emerald's ITEMS: GBC
-- (items3.lua): the ball lying on the map, and the ball thrown in battle,
-- each as Crystal drew it. Read from the player's own Crystal, Gold or
-- Silver: the overworld ball's sprite, the battle ball's tiles and the
-- colours Crystal gives each ball. Nothing is included with Facets. -Elvie
-- --------------------------------------------------

local ball = {}

local gb = require("mods.facets.gb")
local GAMES = { "crystal", "gold", "silver" }

-- Crystal's ball colours (engine/battle_anims/functions.asm, GetBallAnimPal
-- and data/battle_anims/ball_colors.asm), by the GBA games' ball number:
-- Poké, Great, Safari, Ultra, Master, Net, Dive, Nest, Repeat, Timer,
-- Luxury, Premier. The GBA balls Crystal hasn't got take the nearest
-- colour. -Elvie
ball.COLOURS = { [0] = "PAL_BATTLE_OB_RED", "PAL_BATTLE_OB_BLUE", "PAL_BATTLE_OB_GREEN",
  "PAL_BATTLE_OB_YELLOW", "PAL_BATTLE_OB_GREEN", "PAL_BATTLE_OB_BLUE", "PAL_BATTLE_OB_BLUE",
  "PAL_BATTLE_OB_GREEN", "PAL_BATTLE_OB_RED", "PAL_BATTLE_OB_RED", "PAL_BATTLE_OB_GRAY",
  "PAL_BATTLE_OB_GRAY" }

-- Crystal's battle ball, from its tiles (OAM sets 0A, closed, and 0D,
-- open): { tile, x, y, xflip } in a 16x16 frame, tile numbers in the
-- 8-across sheet -Elvie
ball.CLOSED = { { 0, 0, 0, false }, { 0, 8, 0, true }, { 1, 0, 8, false }, { 1, 8, 8, true } }
ball.OPEN = { { 7, 0, 4, false }, { 7, 8, 4, true } }

-- palettes.lua's battleObjects: { NAME = { 4 colours } } -Elvie
function ball.parsePalettes(text)
  if type(text) ~= "string" then return nil end
  local start = text:find("battleObjects = {", 1, true)
  if not start then return nil end
  local out, n = {}, 0
  local section = text:sub(start, (text:find("\n  [%a_]+ = {", start + 1)) or #text)
  for name, body in section:gmatch("(PAL_BATTLE_OB_[%u_]+) = {(.-)\n    }") do
    local v = {}
    for num in body:gmatch("%d+") do v[#v + 1] = tonumber(num) end
    if #v >= 12 then
      out[name] = { { v[1], v[2], v[3] }, { v[4], v[5], v[6] }, { v[7], v[8], v[9] }, { v[10], v[11], v[12] } }
      n = n + 1
    end
  end
  return n > 0 and out or nil
end

local palettes
local function palette(name)
  if palettes == nil then
    palettes = ball.parsePalettes(gb.readAt(gb.path("data", "palettes.lua"), GAMES)) or false
  end
  return palettes and (palettes[name] or palettes.PAL_BATTLE_OB_RED) or nil
end

-- The battle ball's sheet: three 16x16 frames across (closed, opening,
-- open, as the GBA's thrown ball has them), in ball n's colours, as
-- ImageData, or nil -Elvie
function ball.battleSheet(n)
  local src = gb.readImage(gb.path("assets", "battle_anims/battle_anim_gfx_poke_ball.png"), GAMES)
  local pal = palette(ball.COLOURS[n] or ball.COLOURS[0])
  if not (src and pal) then return nil end
  local out = love.image.newImageData(48, 16)
  local sw = src:getDimensions()
  local function put(frame, parts)
    for _, p in ipairs(parts) do
      local tx, ty = (p[1] % (sw / 8)) * 8, math.floor(p[1] / (sw / 8)) * 8
      for y = 0, 7 do
        for x = 0, 7 do
          local k = gb.shade((src:getPixel(tx + (p[4] and 7 - x or x), ty + y)))
          if k then
            local c = pal[k + 1]
            out:setPixel(frame * 16 + p[2] + x, p[3] + y, c[1] / 255, c[2] / 255, c[3] / 255, 1)
          end
        end
      end
    end
  end
  put(0, ball.CLOSED)
  put(1, ball.OPEN)
  put(2, ball.OPEN)
  return out
end

-- The ball lying on the map: Crystal's overworld Poké Ball, 16x16, in its
-- red, as ImageData, or nil -Elvie
function ball.mapBall()
  local src = gb.read("poke_ball", GAMES)
  if not src then return nil end
  local ok, sheet = pcall(gb.sheet, src, "PAL_OW_RED", 16, 16, 1)
  if not (ok and sheet) then return nil end
  local out = love.image.newImageData(16, 16)
  out:paste(sheet, 0, 0, 0, 0, 16, 16)
  return out
end

return ball
