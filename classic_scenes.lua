-- Battle backgrounds on the Game Boy games (Red, Blue, Yellow, Gold, Silver, Crystal)
-- Gold, Silver and Crystal's battle screen starts each frame by clearing to
-- white (BattleState.drawPanel, then Chrome.clear); Red, Blue and Yellow's
-- wide battle fills its field with paper (WideBattle.draw). A set's scene
-- is painted there instead, so the boxes, the Pokémon and the text all
-- draw over it as usual. -Elvie
--
-- The sets are the Gen 3 ones (assets/battlebg/), 240x112. The Game Boy
-- screen has 160x96 above the text box, so the middle of the scene is
-- shown at its own size, keeping the bottom, where the ground is. The
-- scene is picked from where the battle is: the map's environment and
-- tileset, the gym, surfing or the grass. -Elvie
-- --------------------------------------------------

local scenes = {}

-- Where the scene last landed on the game screen, for the window around it
-- (scenes.edges): { image, canvas, x, y, kx, ky, stamp } -Elvie
local shown, frame = nil, 0
local blurOf

-- Notes the scene drawn this frame, for the borders to show blurred. The
-- position arguments are kept for the callers; the blurred backdrop only
-- needs the picture -Elvie
local function note(image, qx, qy, dx, dy, light)
  local G = love.graphics
  if type(G.transformPoint) ~= "function" or type(G.getCanvas) ~= "function" then return end
  local canvas = G.getCanvas()
  if type(canvas) == "table" then canvas = canvas[1] and (canvas[1].texture or canvas[1]) end
  if not canvas then return end
  local x0, y0 = G.transformPoint(dx - qx, dy - qy)
  local x1, y1 = G.transformPoint(dx - qx + 1, dy - qy + 1)
  shown = { image = image, canvas = canvas, x = x0, y = y0, kx = x1 - x0, ky = y1 - y0, stamp = frame, light = light,
    at = love.timer and love.timer.getTime() or nil }
end
scenes._note = note

-- Whether a battle scene is up: noted in the last tenth of a second (Red,
-- Blue and Yellow's normal screen notes it after its boxes are drawn, so
-- it's the last frame's) -Elvie
function scenes.showing()
  if not (shown and shown.at and love.timer) then return false end
  return love.timer.getTime() - shown.at < 0.1
end

-- --------------------------------------------------
-- The time of day
-- --------------------------------------------------
-- Outdoor scenes take the light of the hour, as Gold, Silver and Crystal's
-- maps do, with HeartGold and SoulSilver's evening too: morning's a soft
-- gold, day's as drawn, evening's a sunset rose, night's dark and blue.
-- The hours are HeartGold and SoulSilver's (morning 4 to 10, day to 17,
-- evening to 20, night after). Indoors, caves, gyms and the rest stay as
-- drawn -Elvie
scenes.OUTDOORS = { grass = true, forest = true, beach = true, sea = true, lake = true, mountain = true,
  route = true, town = true, snow = true, snow_mountain = true, desert = true }
scenes.LIGHT = { MORN = { 1, 0.93, 0.82 }, DAY = { 1, 1, 1 }, EVE = { 0.96, 0.76, 0.7 },
  NITE = { 0.5, 0.56, 0.8 } }
scenes.MORN_HOUR, scenes.DAY_HOUR, scenes.EVE_HOUR, scenes.NITE_HOUR = 4, 10, 17, 20

-- MORN, DAY, EVE or NITE for an hour (0-23) -Elvie
function scenes.daytime(hour)
  hour = math.floor(tonumber(hour) or 12) % 24
  if hour < scenes.MORN_HOUR then return "NITE" end
  if hour < scenes.DAY_HOUR then return "MORN" end
  if hour < scenes.EVE_HOUR then return "DAY" end
  if hour < scenes.NITE_HOUR then return "EVE" end
  return "NITE"
end

-- The colour to draw a scene in, { r, g, b }, or nil for as drawn: its
-- light at this hour if it's outdoors -Elvie
function scenes.lightFor(name, hour)
  if not (name and scenes.OUTDOORS[name] and hour) then return nil end
  local l = scenes.LIGHT[scenes.daytime(hour)]
  if not l or (l[1] == 1 and l[2] == 1 and l[3] == 1) then return nil end
  return l
end

-- Sets the colour for a scene in that light -Elvie
function scenes.setLight(light, dim)
  dim = dim or 1
  local l = light or scenes.LIGHT.DAY
  love.graphics.setColor(l[1] * dim, l[2] * dim, l[3] * dim, 1)
end

-- The skies: a scene with a sky map (<scene>.sky.png beside it, white
-- where the sky is, painted by hand) has its sky painted for the hour,
-- not only tinted: morning's a soft blue going to peach at the horizon,
-- evening's violet to a sunset orange, night's a navy wash. Each pixel
-- keeps how light it was, so the clouds stay clouds, in the hour's own
-- cloud colour. The ground takes the hour's light as before -Elvie
scenes.SKY = {
  MORN = { top = { 112, 150, 214 }, horizon = { 252, 204, 168 }, cloud = { 255, 232, 222 } },
  EVE = { top = { 84, 72, 150 }, horizon = { 248, 146, 96 }, cloud = { 255, 186, 156 } },
  NITE = { top = { 12, 18, 50 }, horizon = { 40, 58, 112 }, cloud = { 74, 88, 134 } },
}
local function smooth(e0, e1, x)
  local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
end
-- data (ImageData) with its sky (mask, ImageData the same size) painted
-- for daytime and the rest in ground ({ r, g, b } 0-1): a new ImageData,
-- or nil when there's no sky to paint -Elvie
function scenes.skyBake(data, mask, daytime, ground)
  local sky = scenes.SKY[daytime]
  if not (sky and data and mask) then return nil end
  local w, h = data:getDimensions()
  local mw, mh = mask:getDimensions()
  if mw ~= w or mh ~= h then return nil end
  local lo, hi, bottom = math.huge, -math.huge, -1
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local _, _, _, a = mask:getPixel(x, y)
      if a > 0.5 then
        local r, g, b = data:getPixel(x, y)
        local l = 0.299 * r + 0.587 * g + 0.114 * b
        if l < lo then lo = l end
        if l > hi then hi = l end
        if y > bottom then bottom = y end
      end
    end
  end
  if bottom < 0 then return nil end
  -- (a sky in one or two flat colours, the snow's, keeps to the hour's
  -- gradient: its small differences aren't clouds) -Elvie
  local span = math.max(0.3, hi - lo)
  local gr, gg, gb = ground and ground[1] or 1, ground and ground[2] or 1, ground and ground[3] or 1
  local top, hor, cloud = sky.top, sky.horizon, sky.cloud
  local out = data:clone()
  out:mapPixel(function(x, y, r, g, b, a)
    local _, _, _, m = mask:getPixel(x, y)
    if m <= 0.5 then return r * gr, g * gg, b * gb, a end
    local ln = (0.299 * r + 0.587 * g + 0.114 * b - lo) / span
    local t = smooth(0, 1, y / math.max(1, bottom))
    local c = smooth(0.45, 0.95, ln)
    local k = (0.88 + 0.24 * ln) / 255
    local function ch(i)
      local v = top[i] + (hor[i] - top[i]) * t
      v = v + (cloud[i] - v) * c
      return math.max(0, math.min(1, v * k))
    end
    return ch(1), ch(2), ch(3), a
  end)
  return out
end
-- The sky map for a scene file in dir (mod.assets), as ImageData, or
-- false -Elvie
local skyMaps = {}
function scenes.skyMap(mod, dir, file)
  local path = tostring(dir) .. "/" .. tostring(file):gsub("%.png$", "") .. ".sky.png"
  if skyMaps[path] ~= nil then return skyMaps[path] end
  skyMaps[path] = false
  local ok, data = pcall(function()
    if mod.assets.info and not mod.assets:info(path) then return nil end
    return love.image.newImageData(mod.assets:path(path))
  end)
  if ok and data then skyMaps[path] = data end
  return skyMaps[path]
end
-- The scene (data, from dir/file) as an Image with the hour's sky, or nil
-- when it has no sky map. Kept per scene and hour -Elvie
local skyImages = setmetatable({}, { __mode = "k" })
function scenes.skyImage(mod, dir, file, data, daytime)
  if not (data and scenes.SKY[daytime]) then return nil end
  local per = skyImages[data]
  if not per then per = {}; skyImages[data] = per end
  if per[daytime] ~= nil then return per[daytime] or nil end
  per[daytime] = false
  local mask = scenes.skyMap(mod, dir, file)
  if not mask then return nil end
  local ok, img = pcall(function()
    local baked = scenes.skyBake(data, mask, daytime, scenes.LIGHT[daytime])
    if not baked then return nil end
    local i = love.graphics.newImage(baked)
    i:setFilter("nearest", "nearest")
    i:setWrap("mirroredrepeat", "mirroredrepeat")
    return i
  end)
  per[daytime] = ok and img or false
  return per[daytime] or nil
end

-- The scene just drawn is kept from PAPER: its own white (snow, clouds)
-- stays as painted, not the paper's colour -Elvie
function scenes.keepScene()
  local f = package.loaded["mods.facets.filter"]
  if type(f) == "table" and type(f.keepScene) == "function" then pcall(f.keepScene) end
end

-- The borders show the scene zoomed in and blurred, a little darker, so
-- the sharp battle sits in front of a soft backdrop of itself -Elvie
scenes.ZOOM, scenes.DIM = 1.15, 0.8

-- BORDERS: BLUR (that), FILL (one big scene behind the whole battle:
-- sharp, zoomed until it covers the window, the screen's own field showing
-- its middle) or OFF (the engine's own surround); or one of SURROUND's
-- own fills (GLOW, WINDOWS, DOTS, CHECKS, STRIPES), as round your menus,
-- with or without a scene. Set from the options by whichever part is
-- running -Elvie
scenes.BORDERS = { { "BLUR", "blur" }, { "FILL", "fill" }, { "OFF", "off" },
  { "GLOW", "glow" }, { "WINDOWS", "windows" }, { "DOTS", "dots" }, { "CHECKS", "checks" }, { "STRIPES", "stripes" } }
scenes.SURROUNDS = { glow = true, windows = true, dots = true, checks = true, stripes = true, world = true }
scenes.borders = function() return "blur" end

-- FILL: where the big scene lies in the window, from the last frame's
-- borders: the screen's rectangle and the window's size -Elvie
local fillAt = nil

-- The big scene's place in the window for a picture: its quad's source
-- rectangle (the scene inside it, gba_bg.core), the window spot of its
-- corner and its scale -Elvie
-- (g, ox, oy: a game pixel's size in the window and the game screen's
-- corner, when the screen is drawn at the game's own size and scaled up.
-- The scene then lands on the game's pixel grid, each of its pixels a
-- whole number of game pixels, so the screen's part, drawn at the game's
-- size, lines up with the borders round it. Without that, at a scale
-- that isn't a whole number (720p, 480p), the two missed each other and
-- the screen's part tore into stripes) -Elvie
function scenes.fillPlace(iw, ih, ww, wh, g, ox, oy)
  local cx, cy, cw, ch = require("mods.facets.gba_bg").core(iw, ih)
  g = tonumber(g)
  if not (g and g > 0) then
    local k = scenes.coverScale(cw, ch, ww, wh)
    return cx, cy, cw, ch, (ww - cw * k) / 2, (wh - ch * k) / 2, k
  end
  -- (covering a game pixel past each edge, for the snap) -Elvie
  local k = math.max(1, math.ceil(scenes.coverScale(cw, ch, ww + 2 * g, wh + 2 * g) / g)) * g
  local x0, y0 = (ww - cw * k) / 2, (wh - ch * k) / 2
  ox, oy = tonumber(ox) or 0, tonumber(oy) or 0
  x0 = ox + math.floor((x0 - ox) / g + 0.5) * g
  y0 = oy + math.floor((y0 - oy) / g + 0.5) * g
  return cx, cy, cw, ch, x0, y0, k
end

-- FILL inside the game screen: the part of the big scene the screen
-- covers, drawn in the screen's own coordinates (gx0, gy0 its corner,
-- gameW across), so the field shows the same picture as the window round
-- it. false when there's nothing to go by yet (the first frame) -Elvie
function scenes.fillDraw(image, gx0, gy0, gameW)
  local m = fillAt
  if not (m and scenes.borders() == "fill" and m.sw and m.sw > 0) then return false end
  local iw, ih = image:getDimensions()
  local f = m.sw / gameW
  -- (the borders go by this game's pixel from the next frame on) -Elvie
  scenes.fillGameW = gameW
  local cx, cy, cw, ch, x0, y0, k = scenes.fillPlace(iw, ih, m.ww, m.wh, m.g and f, m.ox, m.oy)
  local q = scenes._fillQuad
  if not q then
    q = love.graphics.newQuad(cx, cy, cw, ch, iw, ih)
    scenes._fillQuad = q
  else
    q:setViewport(cx, cy, cw, ch, iw, ih)
  end
  love.graphics.draw(image, q, gx0 + (x0 - m.ox) / f, gy0 + (y0 - m.oy) / f, 0, k / f, k / f)
  return true
end

-- Where the scene's picture sits in the window, for SCENE: x, y of its
-- top-left corner and the window pixels to one of its pixels. Straight
-- from the note when the scene went on the window's own canvas; else (the
-- GBA games, Red, Blue and Yellow's normal screen) the note's canvas is the
-- game screen, put down at ox, oy, vpw wide -Elvie
function scenes.placed(s, onCanvas, ox, oy, vpw)
  if onCanvas then return s.x, s.y, s.kx, s.ky end
  local cw = s.canvas and s.canvas.getDimensions and s.canvas:getDimensions()
  if not (cw and cw > 0 and vpw) then return nil end
  local f = vpw / cw
  return ox + s.x * f, oy + s.y * f, s.kx * f, s.ky * f
end

-- The scale that makes a w x h picture cover a ww x wh window, zoomed in a
-- little more -Elvie
function scenes.coverScale(w, h, ww, wh, zoom)
  return math.max(ww / w, wh / h) * (zoom or 1)
end

-- A blurred copy of a scene, made once: halved again and again with
-- smooth sampling (each halving averages 2x2), down to about 16 across;
-- drawn back up with smooth filtering, that's the blur -Elvie
local blurs = setmetatable({}, { __mode = "k" })
function scenes.blurOf(image) return blurOf(image) end
blurOf = function(image)
  local hit = blurs[image]
  if hit ~= nil then return hit or nil end
  blurs[image] = false
  local G = love.graphics
  local ok, result = pcall(function()
    local w, h = image:getDimensions()
    local src, filter = image, { image:getFilter() }
    image:setFilter("linear", "linear")
    local out
    G.push("all")
    while w > 16 do
      w, h = math.max(1, math.floor(w / 2)), math.max(1, math.floor(h / 2))
      local c = G.newCanvas(w, h)
      c:setFilter("linear", "linear")
      G.setCanvas(c)
      G.origin()
      G.setShader()
      G.setBlendMode("replace", "premultiplied")
      G.clear(0, 0, 0, 0)
      G.setColor(1, 1, 1, 1)
      local sw, sh = src:getDimensions()
      G.draw(src, 0, 0, 0, w / sw, h / sh)
      src, out = c, c
    end
    G.pop()
    image:setFilter(filter[1], filter[2])
    return out
  end)
  if ok and result then blurs[image] = result end
  return blurs[image] or nil
end

-- The window around the game screen: the scene, zoomed and blurred, in the
-- borders instead of a flat colour. Drawn by the engine's render.letterbox before
-- the game screen goes on top. Only on a frame the scene was drawn -Elvie
function scenes.edges(info)
  local s = shown
  frame = frame + 1
  -- SURROUND's fills round a battle: drawn by SURROUND, round the screen
  -- as it was really drawn when that's known -Elvie
  local mode = scenes.borders()
  if scenes.SURROUNDS[mode] and type(info) == "table" and not info.worldActive then
    local surround = require("mods.facets.classic_surround")
    if surround.inBattle(surround.game()) then
      local canvas = love.graphics.getCanvas and love.graphics.getCanvas()
      if type(canvas) == "table" and canvas[1] then canvas = canvas[1].texture or canvas[1] end
      local real = s and s.stamp == frame - 1 and scenes.screenRect(s, canvas) or nil
      -- with no scene, where the battle put itself (a wide battle, or one
      -- BATTLE SIZE made bigger, is more than the letterbox) -Elvie
      local b = scenes.battleScreen
      if not real and b and b.frame >= frame - 2 and b.canvas == canvas then real = b.rect end
      return surround.draw(info, mode, real)
    end
  end
  if not (s and s.stamp == frame - 1 and type(info) == "table") or info.worldActive then return end
  local cw, ch = s.canvas:getDimensions()
  local vpw, vph = tonumber(info.vpw), tonumber(info.vph)
  -- (a scene on the menus' layer, Red, Blue and Yellow's normal battle and
  -- the GBA games', is where that layer really went, which a window not a
  -- whole number of screens across (720p, 480p) puts somewhere other than
  -- the letterbox's ox, oy and vpw) -Elvie
  local fm = package.loaded["mods.facets.filter"]
  local up = type(fm) == "table" and fm.uiPlace or nil
  local uox, uoy
  if up and up.canvas == s.canvas and up.at and love.timer and love.timer.getTime() - up.at < 0.2 then
    vpw, vph, uox, uoy = up.w, up.h, up.x, up.y
  end
  if not (cw and ch and cw > 0 and ch > 0 and vpw and vph) then return end
  local ww, wh = tonumber(info.ww), tonumber(info.wh)
  if not (ww and wh and ww > 0 and wh > 0) then return end
  local mode = scenes.borders()
  if mode == "off" then return end
  if mode ~= "fill" then fillAt = nil end
  local blur = mode ~= "fill" and blurOf(s.image)
  if mode ~= "fill" and not blur then return end
  local G = love.graphics
  -- the whole scene, zoomed to cover the window a little past its edges
  -- and centred on it -Elvie
  local iw, ih = s.image:getDimensions()
  local k = scenes.coverScale(iw, ih, ww, wh, scenes.ZOOM)
  local bw, bh = 1, 1
  if blur then bw, bh = blur:getDimensions() end
  local dw, dh = iw * k, ih * k
  -- only the borders: whatever order the engine puts the game screen down
  -- in, the screen itself is never drawn over -Elvie
  local ox, oy = uox or tonumber(info.ox) or 0, uoy or tonumber(info.oy) or 0
  local sw, sh = vpw, vph
  -- the screen as it was really drawn, when that's known and on the same
  -- canvas (BATTLE SIZE: FILL draws it bigger than the letterbox) -Elvie
  local real = scenes.screenRect(s, G.getCanvas and G.getCanvas())
  if real then ox, oy, sw, sh = real[1], real[2], real[3], real[4] end
  -- pixels to a unit, each way: on some handhelds (the AYN Thor) they
  -- differ, and getDPIScale is only one of them -Elvie
  local d = type(G.getDPIScale) == "function" and G.getDPIScale() or 1
  local dx, dy = tonumber(info.dpiX) or d, tonumber(info.dpiY) or d
  local bl, bt, bw2, bh2 = scenes.borderEdges(ox, oy, sw, sh, dx, dy)
  if mode == "fill" then
    -- the scene, sharp, zoomed until it covers the whole window and
    -- centred on it (some of it goes past the edges, never mirrored);
    -- the borders only, so the screen stays in front -Elvie
    local g = scenes.fillGameW and sw / scenes.fillGameW or nil
    local cx, cy, cw2, ch2, fx, fy, kc = scenes.fillPlace(iw, ih, ww, wh, g, ox, oy)
    fillAt = { ox = ox, oy = oy, sw = sw, ww = ww, wh = wh, g = g }
    local q = scenes._borderQuad
    if not q then
      q = love.graphics.newQuad(cx, cy, cw2, ch2, iw, ih)
      scenes._borderQuad = q
    else
      q:setViewport(cx, cy, cw2, ch2, iw, ih)
    end
    for _, r in ipairs(scenes.bars(bl, bt, bw2, bh2, ww, wh)) do
      G.push("all")
      G.origin()
      scenes.setLight(s.light)
      scenes.drawPart(s.image, iw, ih, cx, cy, fx, fy, kc, kc, r)
      G.pop()
    end
    return true
  end
  for _, r in ipairs(scenes.bars(bl, bt, bw2, bh2, ww, wh)) do
    G.push("all")
    G.origin()
    scenes.setLight(s.light, scenes.DIM)
    scenes.drawPart(blur, bw, bh, 0, 0, (ww - dw) / 2, (wh - dh) / 2, dw / bw, dh / bh, r)
    G.pop()
  end
  return true
end

-- One border: the part of a picture (drawn at x0, y0, scaled kx, ky, its
-- own top left at sx, sy) that falls in r, drawn as that part itself. Not
-- cut out with a scissor: LOVE places a scissor by getDPIScale on both
-- axes, so where a unit is more pixels one way than the other (the AYN
-- Thor) it missed the screen's edge, leaving white lines round the game
-- and down the window's own edges -Elvie
scenes._partQuads = {}
function scenes.drawPart(img, iw, ih, sx, sy, x0, y0, kx, ky, r)
  local qx, qy = sx + (r[1] - x0) / kx, sy + (r[2] - y0) / ky
  local qw, qh = r[3] / kx, r[4] / ky
  local q = scenes._partQuads[img]
  if q then q:setViewport(qx, qy, qw, qh, iw, ih)
  else
    q = love.graphics.newQuad(qx, qy, qw, qh, iw, ih)
    scenes._partQuads[img] = q
  end
  love.graphics.draw(img, q, r[1], r[2], 0, kx, ky)
end

-- The game screen's rectangle as it was really drawn this frame (it can
-- end part way through a pixel), or nil if it wasn't noted or was drawn
-- into another canvas than the one the borders go on -Elvie
function scenes.screenRect(s, canvas)
  local r = type(s) == "table" and s.screen
  if not (r and r[3] and r[4] and r[3] > 0 and r[4] > 0) then return nil end
  if type(canvas) == "table" and canvas[1] then canvas = canvas[1].texture or canvas[1] end
  if canvas ~= s.canvas then return nil end
  return { r[1], r[2], r[3], r[4] }
end

-- The screen's edges, moved out to the window's pixels for the borders:
-- each border runs on over the pixel the screen's edge cuts through, so no
-- sliver of the surround shows between them (on a high-DPI screen a whole
-- unit is two or three pixels, which used to leave a faint line). d is
-- pixels to a unit -Elvie
function scenes.borderEdges(ox, oy, sw, sh, d, dy)
  local dx = d or 1
  dy = dy or dx
  local l = math.ceil(ox * dx - 1e-6) / dx
  local t = math.ceil(oy * dy - 1e-6) / dy
  -- right and bottom start a pixel inside: the engine's own picture of
  -- the screen can stop short of its last pixel (it did on the AYN Thor,
  -- leaving a white line down the right and along the bottom) -Elvie
  local r = (math.floor((ox + sw) * dx + 1e-6) - 1) / dx
  local b = (math.floor((oy + sh) * dy + 1e-6) - 1) / dy
  return l, t, math.max(0, r - l), math.max(0, b - t)
end

-- The four borders round the game screen at (ox, oy) vpw x vph in a
-- window ww x wh, as x, y, w, h; the empty ones left out -Elvie
function scenes.bars(ox, oy, vpw, vph, ww, wh)
  local out = {}
  local function add(x, y, w, h) if w > 0 and h > 0 then out[#out + 1] = { x, y, w, h } end end
  add(0, 0, ox, wh)
  add(ox + vpw, 0, ww - ox - vpw, wh)
  add(ox, 0, vpw, oy)
  add(ox, oy + vph, vpw, wh - oy - vph)
  return out
end

local DIR = "assets/battlebg"
local GAME = "game"
scenes.W, scenes.H = 160, 96
scenes.WIDE_W = 304
scenes.SCREEN_H = 144

-- SCENE COLORS: GBC. The scenes were painted for the GBA's screen and
-- read pale beside Crystal's sprites, so each colour's saturation is
-- raised, then rounded to the Game Boy Color's 32 levels a channel. One
-- pixel in, one out: r, g, b (0-1) -Elvie
function scenes.gbcColour(r, g, b)
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local l = (mx + mn) / 2
  if mx > mn then
    -- push each channel away from the pixel's grey by the same factor,
    -- kept inside 0-1 -Elvie
    local k = 1.35
    for _, c in ipairs({ r, g, b }) do
      local over = c - l
      if over > 0 then k = math.min(k, (1 - l) / over) elseif over < 0 then k = math.min(k, l / -over) end
    end
    r, g, b = l + (r - l) * k, l + (g - l) * k, l + (b - l) * k
  end
  local function q(c) return math.floor(math.max(0, math.min(1, c)) * 31 + 0.5) / 31 end
  return q(r), q(g), q(b)
end

-- The scene name for a battle, from the map (its id, environment and
-- tileset), whether the player is surfing and whether it's a trainer -Elvie
function scenes.pick(where)
  where = where or {}
  local id = tostring(where.map or "")
  local env = tostring(where.environment or "")
  local tiles = tostring(where.tileset or "")
  if where.surfing then return "sea" end
  -- Oak's Lab is on the Dojo's tileset in Red, Blue and Yellow, so it's
  -- named here to get the lab, as are the Gen 2 labs -Elvie
  if id:find("OAKS_LAB") or id:find("ELMS_LAB") then return "lab" end
  -- Gen 1's maps have a tileset but no environment -Elvie
  if env == "" and tiles ~= "" then
    if id:find("CHAMPIONS_ROOM") then return "space" end
    for _, room in ipairs({ "LORELEIS_ROOM", "BRUNOS_ROOM", "AGATHAS_ROOM", "LANCES_ROOM" }) do
      if id:find(room) then return "gym" end
    end
    if id:find("SEAFOAM") then return "snow_cave" end
    if tiles:find("GATE") then return "indoors" end
  end
  if tiles:find("CHAMPIONS_ROOM") then return "space" end
  if id:find("_GYM") or tiles:find("ELITE_FOUR") then return "gym" end
  if id:find("SILVER_CAVE") or id:find("MOUNT_SILVER") then return "snow_mountain" end
  if tiles:find("ICE_PATH") then return "snow_cave" end
  if tiles:find("FOREST") then return "forest" end
  if tiles:find("LAB") then return "lab" end
  if env == "CAVE" or tiles:find("CAVE") then return "cave" end
  if env == "DUNGEON" then return "indoors" end
  if env == "INDOOR" or env == "GATE" then return "indoors" end
  if tiles:find("PORT") then return "beach" end
  if env == "TOWN" then return "town" end
  if env == "ROUTE" then return where.trainer and "route" or "grass" end
  if env == "" and tiles == "OVERWORLD" then
    if id:find("^ROUTE") then return where.trainer and "route" or "grass" end
    return "town"
  end
  if env == "" and tiles ~= "" then return "indoors" end
  return "neutral"
end

-- The part of a 240x112 scene the Game Boy screen shows: x, y, w, h -Elvie
function scenes.crop(w, h, maxW)
  local cw, ch = math.min(maxW or scenes.W, w), math.min(scenes.H, h)
  return math.floor((w - cw) / 2), h - ch, cw, ch
end

local function findSets(mod)
  local sets = {}
  local decode = require("mods.facets.npcs").decodeJson
  for _, key in ipairs(mod.assets:list(DIR) or {}) do
    local rel = DIR .. "/" .. key .. "/meta.json"
    if key:match("^[%w_%-]+$") and mod.assets:info(rel) then
      local ok, meta = pcall(decode, mod:read(rel))
      if ok and type(meta) == "table" and type(meta.scenes) == "table" then
        sets[#sets + 1] = { key = key, scenes = meta.scenes,
          label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper() }
      end
    end
  end
  table.sort(sets, function(a, b) return a.label < b.label end)
  return sets
end

-- Gen 1's wide battle: the field's paper fill (PaletteFX.paperShade, then
-- one rectangle) is painted with the scene instead, all 304 across, its
-- sides carried on mirrored. The 160x144 screen goes under the SGB zones'
-- colouring instead (below). Neither in the Game Boy greys (CLASSIC, OG),
-- where a scene would be shaded too -Elvie
local function startGen1(mod, sceneFor)
  local okW, WideBattle = pcall(require, table.concat({ "src", "battle", "WideBattle" }, "."))
  local okP, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not (okW and type(WideBattle) == "table" and type(WideBattle.draw) == "function"
      and okP and type(PaletteFX) == "table" and type(PaletteFX.paperShade) == "function") then
    mod.log:warn("WideBattle.draw not found; BATTLE BG is off")
    return
  end
  local W, H = tonumber(WideBattle.WIDTH) or 304, tonumber(WideBattle.HEIGHT) or 144
  local BOTTOM = tonumber(WideBattle.FIELD_BOTTOM) or 104
  local function grey()
    local m = PaletteFX.mode
    if m == "og" or m == "og_inv" or m == "classic" then return true end
    local ok, raw = pcall(function() return PaletteFX.forcesRawGrays() end)
    return ok and raw or false
  end
  local quads = {}
  local own = WideBattle.draw
  WideBattle.draw = function(battle, ...)
    local s = type(battle) == "table" and type(battle.wideLayout) == "function" and battle:wideLayout()
      and not grey() and not (type(battle.extendedWorldHUD) == "function" and battle:extendedWorldHUD())
      and sceneFor(battle)
    if not s then return own(battle, ...) end
    local G = love.graphics
    local paper = PaletteFX.paperShade
    local used = false
    PaletteFX.paperShade = function(...)
      if used then return paper(...) end
      used = true
      local r, g, b = paper(...)
      G.setColor(r, g, b, 1)
      G.rectangle("fill", 0, BOTTOM, W, H - BOTTOM)
      local iw, ih = s.image:getDimensions()
      local q = quads[s.image]
      if not q then
        s.image:setWrap("mirroredrepeat", "mirroredrepeat")
        -- on down past the field to the bottom of the screen, so the
        -- ground carries on behind the text box instead of a white band
        -- (the art's last rows mirrored) -Elvie
        q = love.graphics.newQuad(math.floor((iw - W) / 2), (s.coreBottom or ih) - BOTTOM, W, H, iw, ih)
        quads[s.image] = q
      end
      -- (in the hour's light, SCENE TIME on your own clock) -Elvie
      scenes.setLight(scenes.litNow)
      -- FILL: the field's part of the one big scene -Elvie
      if not scenes.fillDraw(s.image, 0, 0, W) then G.draw(s.image, q, 0, 0) end
      G.setColor(1, 1, 1, 1)
      scenes.keepScene()
      local qx, qy = q:getViewport()
      note(s.image, qx, qy, 0, 0, scenes.litNow)
      -- the game's own fill then goes down see-through -Elvie
      return r, g, b, 0
    end
    local results = { pcall(own, battle, ...) }
    PaletteFX.paperShade = paper
    if not results[1] then error(results[2], 0) end
    return unpack(results, 2)
  end

  -- The 160x144 screen: the battle is drawn in the Game Boy greys, on a
  -- white sheet, then coloured through the SGB zones in one pass
  -- (drawZonePass), and the Pokémon go on after. Here the sheet's cleared
  -- instead (the HUDs are the first thing drawn on it), that pass is drawn
  -- aside, and put down over the scene with whatever's still clear left
  -- see-through: the field, and round a TEXT BOX's edges, but never inside
  -- the game's own boxes, which fill themselves. The HUDs' letters and
  -- lines keep a one-pixel white rim, so they read over the scene -Elvie
  local okB, BattleState = pcall(require, "src.battle.BattleState")
  if not (okB and type(BattleState) == "table" and type(BattleState.drawZonePass) == "function") then
    mod.log:warn("drawZonePass not found; BATTLE BG stays wide only")
    return
  end
  local okS, shader = pcall(love.graphics.newShader, [[
    extern Image paper;
    extern vec2 offset;
    extern vec2 size;
    vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 at) {
      vec4 c = Texel(tex, uv) * colour;
      vec2 p = uv * size - offset;
      if (p.x >= 0.0 && p.y >= 0.0 && p.x < size.x && p.y < size.y) {
        if (Texel(paper, p / size).a < 0.01) {
          // a white rim round the boxes' letters and lines, so they read
          // over a busy scene -Elvie
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              vec4 g = Texel(paper, (p + vec2(float(dx), float(dy))) / size);
              if (g.a > 0.5 && g.r < 0.5) return vec4(1.0);
            }
          }
          return vec4(0.0);
        }
      }
      return c;
    }
  ]])
  if not okS then
    mod.log:warn("BATTLE BG on the normal screen: %s", tostring(shader))
    return
  end
  local function onScreen(self)
    return type(self) == "table" and not (type(self.wideLayout) == "function" and self:wideLayout())
      and not grey() and not (type(self.extendedWorldHUD) == "function" and self:extendedWorldHUD())
      and sceneFor(self)
  end
  if type(BattleState.drawHUDs) == "function" then
    local ownHUDs = BattleState.drawHUDs
    BattleState.drawHUDs = function(self, ...)
      if self.bgCanvas and love.graphics.getCanvas() == self.bgCanvas and onScreen(self) then
        love.graphics.clear(0, 0, 0, 0)
      end
      return ownHUDs(self, ...)
    end
  end
  local aside
  local ownZone = BattleState.drawZonePass
  BattleState.drawZonePass = function(self, src, sx, sy, ...)
    local s = type(src) == "userdata" and onScreen(self)
    if not s then return ownZone(self, src, sx, sy, ...) end
    local G = love.graphics
    local sw, sh = src:getDimensions()
    if not aside or aside:getWidth() ~= sw or aside:getHeight() ~= sh then
      aside = G.newCanvas(sw, sh)
      aside:setFilter("nearest", "nearest")
    end
    G.push("all")
    G.setCanvas(aside)
    G.origin()
    G.clear(0, 0, 0, 0)
    local ok, err = pcall(ownZone, self, src, sx, sy, ...)
    G.pop()
    if not ok then error(err, 0) end
    G.push("all")
    scenes.setLight(scenes.litNow)
    if not scenes.fillDraw(s.image, sx or 0, sy or 0, scenes.W) then G.draw(s.image, s.quad, sx or 0, sy or 0) end
    G.setColor(1, 1, 1, 1)
    scenes.keepScene()
    note(s.image, s.x, s.y, sx or 0, sy or 0, scenes.litNow)
    shader:send("paper", src)
    shader:send("offset", { sx or 0, sy or 0 })
    shader:send("size", { sw, sh })
    G.setShader(shader)
    G.setBlendMode("alpha", "premultiplied")
    G.draw(aside, 0, 0)
    G.pop()
  end
end

function scenes.init(mod, rows)
  local gen = require("mods.facets.classic").generation()
  if gen ~= 2 and gen ~= 1 then return nil end
  local sets = findSets(mod)
  -- FRLG, EMERALD and R/S: the GBA games' own, from the player's
  -- imports (gba_bg) -Elvie
  local gbaBg = require("mods.facets.gba_bg")
  for _, g in ipairs(gbaBg.SETS) do
    sets[#sets + 1] = { key = g.key, label = g.label, gba = true, scenes = {} }
  end
  -- COLORS: plain colour, BG COLOR's (filter.bgColour) -Elvie
  sets[#sets + 1] = { key = "colours", label = "COLORS", colours = true, scenes = {} }
  local byKey = {}
  local choices = { { "GAME", GAME } }
  for _, set in ipairs(sets) do
    byKey[set.key] = set
    choices[#choices + 1] = { set.label, set.key }
  end
  rows[#rows + 1] = { key = "classicBattleBg", type = "choice", label = "BATTLE BG", choices = choices, default = GAME }
  rows[#rows + 1] = { key = "classicSceneColours", type = "choice", label = "SCENE COLORS",
    choices = { { "ORIGINAL", "original" }, { "GBC", "gbc" } }, default = "original" }
  rows[#rows + 1] = { key = "bgColour", type = "choice", label = "BG COLOR",
    choices = require("mods.facets.filter").BG_COLOURS, default = "paper" }
  rows[#rows + 1] = { key = "sceneBorders", type = "choice", label = "BORDERS", choices = scenes.BORDERS, default = "blur" }
  scenes.borders = function() return mod.options:get("sceneBorders") or "blur" end
  -- (Red, Blue and Yellow have no clock: theirs is your own. Gold, Silver
  -- and Crystal go by theirs, or by yours on SYSTEM) -Elvie
  rows[#rows + 1] = { key = "sceneTime", type = "choice", label = "SCENE TIME",
    choices = gen == 2 and { { "ON", "on" }, { "SYSTEM", "system" }, { "OFF", "off" } } or { { "ON", "on" }, { "OFF", "off" } },
    default = "on" }

  return function()
    local okB, BattleState, okC, Chrome = false, nil, false, nil
    if gen == 2 then
      okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
      okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
    end
    if gen == 2 and not (okB and type(BattleState) == "table" and type(BattleState.drawPanel) == "function"
        and okC and type(Chrome) == "table" and type(Chrome.clear) == "function") then
      mod.log:warn("BattleState.drawPanel not found; BATTLE BG is off")
      return
    end

    local images = {} -- [set/file] = { image, quad }, or false -Elvie
    local function scene(setKey, name)
      local set = byKey[setKey]
      local gbaData
      local file
      if set and set.colours then
        -- one plain picture, as big as the GBA ones with their
        -- surroundings, so it's cropped and carried on like any scene
        -- -Elvie
        local c = require("mods.facets.filter").bgColour(function(k) return mod.options:get(k) end)
        local id = ("colours#%d,%d,%d"):format(c[1], c[2], c[3])
        local hit = images[id]
        if hit ~= nil then return hit or nil end
        gbaData = love.image.newImageData(scenes.WIDE_W + 2 * gbaBg.PAD, scenes.SCREEN_H + 2 * gbaBg.PAD)
        gbaData:mapPixel(function() return c[1] / 255, c[2] / 255, c[3] / 255, 1 end)
        file = id
      elseif set and set.gba then
        local terrain
        -- widened, so the wide battles' sides carry the background on
        -- rather than mirroring a platform in -Elvie
        gbaData, terrain = gbaBg.imageData(setKey, name, gbaBg.PAD)
        if not gbaData then return nil end
        file = terrain
      else
        file = set and (set.scenes[name] or set.scenes.neutral)
        if type(file) ~= "string" or not file:match("^[%w_%-%.]+%.png$") then return nil end
      end
      local path = setKey .. "/" .. file
      local gbc = mod.options:get("classicSceneColours") == "gbc" and not (set and set.colours)
      local id = path .. (gbc and "#gbc" or "")
      local hit = images[id]
      if hit ~= nil then return hit or nil end
      images[id] = false
      local ok, image, data = pcall(function()
        local data = gbaData and gbaData:clone() or love.image.newImageData(mod.assets:path(DIR .. "/" .. path))
        if gbc then
          data:mapPixel(function(_, _, r, g, b, a)
            r, g, b = scenes.gbcColour(r, g, b)
            return r, g, b, a
          end)
        end
        return love.graphics.newImage(data), data
      end)
      if not ok then
        mod.log:warn("battlebg/%s couldn't be read", path)
        return nil
      end
      image:setFilter("nearest", "nearest")
      -- past its edges the art carries on mirrored, as the wide battles'
      -- sides do -Elvie
      image:setWrap("mirroredrepeat", "mirroredrepeat")
      local w, h = image:getDimensions()
      -- a GBA background is built with its surroundings round it: the
      -- scene itself is the 240x112 at pad, pad (gba_bg) -Elvie
      local pad = gbaData and gbaBg.PAD or 0
      local x, y, cw, ch = scenes.crop(w - 2 * pad, h - 2 * pad)
      x, y = x + pad, y + pad
      -- the wide battle has room for the whole width, and more: its field
      -- is 304 across, so the art carries on mirrored to both its edges
      -- (it's drawn from the 160 screen's left, 72 in) -Elvie
      local wx, wy, ww, wh = scenes.crop(w - 2 * pad, h - 2 * pad, w - 2 * pad)
      wy = wy + pad
      ww = scenes.WIDE_W
      wx = math.floor((w - ww) / 2)
      -- Both run on down the whole screen, so the ground carries on
      -- behind the text box and shows round its corners -Elvie
      local down = scenes.SCREEN_H - ch
      images[id] = { image = image, quad = love.graphics.newQuad(x, y, cw, ch + down, w, h),
        wide = love.graphics.newQuad(wx, wy, ww, wh + down, w, h), wideX = math.floor((scenes.W - ww) / 2),
        x = x, y = y, wx = wx, wy = wy, coreBottom = h - pad,
        -- (a set's own picture, kept for its sky at each hour) -Elvie
        data = not gbaData and data or nil, dir = DIR .. "/" .. setKey, file = file }
      return images[id]
    end

    -- where this battle is, read once per battle -Elvie
    local where
    where = function(state)
      local world = state.game and state.game.world
      local map = world and world.map
      local def = map and map.def or {}
      return { map = map and map.id, environment = def.environment, tileset = def.tileset,
        surfing = world and world.playerState == "surf",
        trainer = state.battle and state.battle.trainer ~= nil }
    end

    -- Gen 1: the overworld under the battle, from WorldAPI -Elvie
    if gen == 1 then
      where = function(state)
        local ow
        pcall(function() ow = require("src.world.WorldAPI").new(state.game):overworld() end)
        local map = type(ow) == "table" and ow.map or nil
        local def = type(map) == "table" and map.def or {}
        return { map = map and map.id, tileset = def.tileset,
          surfing = type(ow) == "table" and type(ow.player) == "table" and ow.player.surfing and true or false,
          trainer = state.kind == "trainer" }
      end
    end

    -- the light outdoor scenes are in now: Gold, Silver and Crystal's own
    -- clock (the one their maps follow), read once a second -Elvie
    local light, lightAt, lightName, lightTime = nil, -1, nil, nil
    local function lightOf(self, name)
      local st = mod.options:get("sceneTime")
      if st == "off" then return nil end
      local now = os.time()
      if now == lightAt and name == lightName then return light end
      lightAt, lightName = now, name
      local hour
      if gen == 2 and st ~= "system" then
        pcall(function()
          local world = self.game and self.game.world
          if world and type(world.hour) == "function" then hour = world:hour() end
        end)
      end
      hour = hour or tonumber(os.date("%H"))
      light = scenes.lightFor(name, hour)
      lightTime = light and scenes.daytime(hour) or nil
      return light
    end
    local lit = nil
    -- the scene with the hour's sky painted, when it has a sky map: the
    -- same entry, its picture swapped, kept per hour -Elvie
    local skied = setmetatable({}, { __mode = "k" })
    local function withSky(entry, daytime)
      if not (entry and entry.data and daytime) then return nil end
      local per = skied[entry]
      if not per then per = {}; skied[entry] = per end
      if per[daytime] ~= nil then return per[daytime] or nil end
      local img = scenes.skyImage(mod, entry.dir, entry.file, entry.data, daytime)
      if not img then per[daytime] = false; return nil end
      local copy = {}
      for k, v in pairs(entry) do copy[k] = v end
      copy.image = img
      per[daytime] = copy
      return copy
    end

    -- this battle's scene, or nil for the game's own -Elvie
    local function sceneFor(self)
      local setKey = mod.options:get("classicBattleBg")
      -- The engine's BATTLE BG only fills the screen around the battle; the
      -- battle keeps its paper field in every mode but one, the EXTENDED
      -- HUD over the world, which has no field to paint -Elvie
      if setKey == GAME or not byKey[setKey] then return nil end
      if type(self.extendedWorldHUD) == "function" and self:extendedWorldHUD() then return nil end
      local look = setKey .. "|" .. tostring(mod.options:get("classicSceneColours"))
        .. "|" .. tostring(mod.options:get("bgColour")) .. "|" .. tostring(mod.options:get("paper"))
      if self._facetsScene == nil or self._facetsSceneSet ~= look then
        local name = scenes.pick(where(self))
        self._facetsScene = scene(setKey, name) or false
        self._facetsSceneSet = look
        -- the scene this battle is in, for Scenic Route -Elvie
        scenes.last = self._facetsScene and name or nil
        self._facetsSceneName = name
      end
      lit = self._facetsScene and lightOf(self, self._facetsSceneName) or nil
      -- a plain COLORS field on dark paper is the paper itself, unlit, so
      -- the HUDs drawn on it in the paper's colour sit flush -Elvie
      if lit and byKey[setKey].colours then
        local okF, F = pcall(require, "mods.facets.filter")
        if okF and type(F.paperNow) == "function" and F.paperNow() then lit = nil end
      end
      if lit and self._facetsScene then
        local sky = withSky(self._facetsScene, lightTime)
        if sky then
          lit = nil
          scenes.litNow = nil
          return sky
        end
      end
      -- (for Red, Blue and Yellow's drawing, which is apart from this) -Elvie
      scenes.litNow = lit
      return self._facetsScene or nil
    end
    -- Gold, Silver and Crystal's wide battle with BATTLE HUD: EXTENDED
    -- docks its boxes to the top and bottom of a column as tall as the
    -- window, and paints the rest of the column paper: the scene fills the
    -- whole column instead (zoomed to cover it, as BORDERS: FILL does the
    -- window), the field showing its part, so there's no white between the
    -- Pokémon and the boxes. { ox, oy, scale, x, y, w, h } while it draws -Elvie
    local dock = nil
    -- the docked column while it draws, whatever BORDERS is: the borders
    -- go round all of it, not just the field, so they never cover its
    -- boxes -Elvie
    local column = nil
    -- FILL's picture is the window's (as the borders have it), so the
    -- column and the borders round it are one -Elvie
    local function dockPlace(s)
      local iw, ih = s.image:getDimensions()
      return scenes.fillPlace(iw, ih, dock.ww, dock.wh)
    end
    local function dockQuad(s)
      local iw, ih = s.image:getDimensions()
      local cx, cy, cw, ch, x0, y0, k = dockPlace(s)
      local q = scenes._dockQuad
      if not q then q = love.graphics.newQuad(cx, cy, cw, ch, iw, ih); scenes._dockQuad = q
      else q:setViewport(cx, cy, cw, ch, iw, ih) end
      return q, x0, y0, k
    end

    local function drawScene(s, wide)
      scenes.setLight(lit)
      if wide and dock then
        -- the field's part of the column's scene: the field's 0, 0 is the
        -- window's ox, oy, drawn from s.wideX here -Elvie
        local q, x0, y0, k = dockQuad(s)
        love.graphics.draw(s.image, q, s.wideX + (x0 - dock.ox) / dock.scale, (y0 - dock.oy) / dock.scale, 0,
          k / dock.scale, k / dock.scale)
        note(s.image, s.wx, s.wy, s.wideX, 0, lit)
        if shown and column then shown.screen = { column.x, column.y, column.w, column.h } end
      elseif wide then
        -- FILL: the field's part of the one big scene -Elvie
        if not scenes.fillDraw(s.image, s.wideX, 0, scenes.WIDE_W) then
          love.graphics.draw(s.image, s.wide, s.wideX, 0)
        end
        note(s.image, s.wx, s.wy, s.wideX, 0, lit)
        -- the borders go round the wide screen (or the docked column), so
        -- they keep off its sides and boxes -Elvie
        if shown and column then
          shown.screen = { column.x, column.y, column.w, column.h }
        elseif shown and type(love.graphics.transformPoint) == "function" then
          local x0, y0 = love.graphics.transformPoint(s.wideX, 0)
          local x1, y1 = love.graphics.transformPoint(s.wideX + scenes.WIDE_W, scenes.SCREEN_H)
          shown.screen = { x0, y0, x1 - x0, y1 - y0 }
        end
      else
        -- FILL: the screen's part of the one big scene -Elvie
        if not scenes.fillDraw(s.image, 0, 0, scenes.W) then love.graphics.draw(s.image, s.quad, 0, 0) end
        note(s.image, s.x, s.y, 0, 0, lit)
        -- where the game screen itself landed in the window: with BATTLE
        -- SIZE on FILL it's drawn bigger than the letterbox the borders are
        -- told about, so they go by this instead and keep off it -Elvie
        if shown and type(love.graphics.transformPoint) == "function" then
          local x0, y0 = love.graphics.transformPoint(0, 0)
          local x1, y1 = love.graphics.transformPoint(scenes.W, scenes.SCREEN_H)
          shown.screen = { x0, y0, x1 - x0, y1 - y0 }
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
    end

    -- A move's animation (and the intro slide) draws the battle into a
    -- canvas and copies it to the screen in bands, each shifted on its own,
    -- as the Game Boy scrolls the attacker's half. A scene painted in there
    -- would tear with them, so while the canvas is drawn it's left
    -- see-through, and the scene goes under the bands instead, where the
    -- game fills its own white, and stays still -Elvie
    local baking, pending = false, nil
    local okV, AnimView = pcall(require, "src.ui.gen2.BattleAnimView")
    if okV and type(AnimView) == "table" and type(AnimView.bake) == "function"
        and type(AnimView.fillBackground) == "function" then
      local ownBake, ownFill = AnimView.bake, AnimView.fillBackground
      AnimView.bake = function(...)
        baking, pending = true, nil
        local ok, err = pcall(ownBake, ...)
        baking = false
        if not ok then error(err, 0) end
      end
      AnimView.fillBackground = function(view, ...)
        local results = { ownFill(view, ...) }
        if pending then
          drawScene(pending.s, pending.wide)
          -- (kept from PAPER, but for the boxes baked into the canvas the
          -- bands come from) -Elvie
          local f = package.loaded["mods.facets.filter"]
          local c = type(view) == "table" and view.canvas or nil
          if type(c) == "table" then c = c.canvas or c.texture or c end
          if type(f) == "table" and type(f.keepScene) == "function" then pcall(f.keepScene, c) end
        end
        pending = nil
        return unpack(results)
      end
    end

    -- runs fn with Chrome.clear painting the scene after it clears -Elvie
    local function painted(s, wide, fn, ...)
      local clear = Chrome.clear
      Chrome.clear = function(...)
        if baking then
          pending = { s = s, wide = wide }
          return
        end
        clear(...)
        drawScene(s, wide)
        scenes.keepScene()
      end
      local ok, err = pcall(fn, ...)
      Chrome.clear = clear
      if not ok then error(err, 0) end
    end

    -- the scene for where the player is now, outside battle, for
    -- SURROUND: SCENE (classic_surround.lua): BATTLE BG's set, or SCENERY
    -- when that's GAME. Looked up again when the map changes -Elvie
    local hereMap, hereScene = nil, nil
    function scenes.here()
      local game = mod.game
      if not game then return nil end
      local setKey = mod.options:get("classicBattleBg")
      if setKey == GAME or not byKey[setKey] then setKey = "scenery" end
      if not byKey[setKey] then return nil end
      local w = where({ game = game })
      local id = setKey .. "|" .. tostring(w.map) .. "|" .. tostring(w.surfing) .. "|"
        .. tostring(mod.options:get("classicSceneColours"))
      if id ~= hereMap then
        hereMap = id
        hereScene = scene(setKey, scenes.pick(w)) or false
      end
      return hereScene or nil
    end

    -- the window round the game screen carries the scene on in battle,
    -- and SURROUND fills it the rest of the time -Elvie
    pcall(function()
      mod.hooks:wrap("render.letterbox", function(nextFn, info, ...)
        local results = { nextFn(info, ...) }
        local ok, drew = pcall(scenes.edges, info)
        if not ok then mod.log:warn("scenery round the screen: %s", tostring(drew)) end
        if not (ok and drew) then
          local okS, err = pcall(function() require("mods.facets.classic_surround").draw(info) end)
          if not okS then mod.log:warn("SURROUND: %s", tostring(err)) end
        end
        return unpack(results)
      end)
    end)

    if gen == 1 then return startGen1(mod, sceneFor) end

    local own = BattleState.drawPanel
    BattleState.drawPanel = function(self, ...)
      local s = sceneFor(self)
      if not s then return own(self, ...) end
      painted(s, false, own, self, ...)
    end

    -- Gold, Silver and Crystal's own trainer pictures come out of the
    -- import with no see-through (their Pokémon have it): over a scene the
    -- trainer stood in a white square. While a scene's up, the white round
    -- the edge of a game trainer picture is made see-through (a flood from
    -- its border, so white inside the trainer stays), once a picture -Elvie
    local okA, Assets = pcall(require, "src.render.Assets")
    local keyed = {}
    function scenes.floodClear(data)
      local w, h = data:getDimensions()
      local seen, stack = {}, {}
      local function push(x, y)
        local i = y * w + x
        if seen[i] then return end
        seen[i] = true
        local r, g, b, a = data:getPixel(x, y)
        if a > 0 and r >= 0.99 and g >= 0.99 and b >= 0.99 then stack[#stack + 1] = i end
      end
      for x = 0, w - 1 do push(x, 0); push(x, h - 1) end
      for y = 0, h - 1 do push(0, y); push(w - 1, y) end
      while #stack > 0 do
        local i = table.remove(stack)
        local x, y = i % w, math.floor(i / w)
        data:setPixel(x, y, 1, 1, 1, 0)
        if x > 0 then push(x - 1, y) end
        if x < w - 1 then push(x + 1, y) end
        if y > 0 then push(x, y - 1) end
        if y < h - 1 then push(x, y + 1) end
      end
      return data
    end
    local function keyedTrainer(path)
      if type(path) ~= "string" or not (okA and type(Assets.imageData) == "function") then return nil end
      local hit = keyed[path]
      if hit ~= nil then return hit or nil end
      keyed[path] = false
      local okD, data = pcall(Assets.imageData, path)
      if not (okD and data) then return nil end
      local ok, img = pcall(function()
        local copy = scenes.floodClear(data:clone())
        local image = love.graphics.newImage(copy)
        image:setFilter("nearest", "nearest")
        return image
      end)
      keyed[path] = ok and img or false
      return keyed[path] or nil
    end
    if type(BattleState.drawPic) == "function" then
      local ownPic = BattleState.drawPic
      BattleState.drawPic = function(self, mon, back, ...)
        if back or not (self.showEnemyTrainer and self.enemyTrainerImage) or self.enemyTrainerTrueColor
            or not sceneFor(self) then
          return ownPic(self, mon, back, ...)
        end
        local img = keyedTrainer(self.enemyTrainerPath)
        if not img then return ownPic(self, mon, back, ...) end
        local saved = self.enemyTrainerImage
        self.enemyTrainerImage = img
        local ok, err = pcall(ownPic, self, mon, back, ...)
        self.enemyTrainerImage = saved
        if not ok then error(err, 0) end
      end
    end

    local okW, WideBattle = pcall(require, "src.ui.gen2.WideBattle")
    if okW and type(WideBattle) == "table" and type(WideBattle.drawField) == "function" then
      local ownField = WideBattle.drawField
      WideBattle.drawField = function(battle, ...)
        local s = sceneFor(battle)
        if not s then return ownField(battle, ...) end
        local results
        painted(s, true, function(...) results = { ownField(...) } end, battle, ...)
        return results and results[1]
      end
    end
    -- Where Gold, Silver and Crystal's battle screen really is in the
    -- window, each frame, for BORDERS' SURROUND fills when there's no scene
    -- to note it (scenes.edges) -Elvie
    local function noteBattle(x, y, w, h)
      local canvas = love.graphics.getCanvas and love.graphics.getCanvas()
      if type(canvas) == "table" and canvas[1] then canvas = canvas[1].texture or canvas[1] end
      scenes.battleScreen = { rect = { x, y, w, h }, frame = frame, canvas = canvas }
    end
    if type(BattleState.draw) == "function" and type(love.graphics.transformPoint) == "function" then
      local ownState = BattleState.draw
      BattleState.draw = function(self, ...)
        if not (type(self.wideLayout) == "function" and self:wideLayout()) then
          local x0, y0 = love.graphics.transformPoint(0, 0)
          local x1, y1 = love.graphics.transformPoint(scenes.W, scenes.SCREEN_H)
          noteBattle(x0, y0, x1 - x0, y1 - y0)
        end
        return ownState(self, ...)
      end
    end
    if okW and type(WideBattle) == "table" and type(WideBattle.draw) == "function"
        and type(Chrome.fitOriginFor) == "function" then
      local ownWide = WideBattle.draw
      WideBattle.draw = function(battle, winW, winH, ...)
        pcall(function()
          local scale = battle:battlePanelScale(winW, winH)
          local ox, oy = Chrome.fitOriginFor(winW, winH, scale, WideBattle.TILES_W, WideBattle.TILES_H)
          local okD, docked = pcall(WideBattle.docked, battle)
          if okD and docked and type(Chrome.playfieldRect) == "function" then
            local _, py, _, ph = Chrome.playfieldRect(winW, winH)
            noteBattle(ox, py, WideBattle.WIDTH * scale, ph)
          else
            noteBattle(ox, oy, WideBattle.WIDTH * scale, WideBattle.HEIGHT * scale)
          end
        end)
        return ownWide(battle, winW, winH, ...)
      end
    end

    if okW and type(WideBattle) == "table" and type(WideBattle.draw) == "function"
        and type(WideBattle.docked) == "function" and type(Chrome.paletteFill) == "function"
        and type(Chrome.fitOriginFor) == "function" and type(Chrome.playfieldRect) == "function" then
      local ownDraw = WideBattle.draw
      WideBattle.draw = function(battle, winW, winH, ...)
        local s = sceneFor(battle)
        local okD, docked = pcall(WideBattle.docked, battle)
        -- BORDERS says how: FILL one zoomed picture for the whole column,
        -- BLUR the field as it is with the scene blurred round it (as the
        -- window's borders), OFF the game's own white -Elvie
        local mode = scenes.borders()
        if not (s and okD and docked) or mode == "off" then return ownDraw(battle, winW, winH, ...) end
        local blur = mode ~= "fill" and blurOf(s.image)
        if mode ~= "fill" and not blur then return ownDraw(battle, winW, winH, ...) end
        local okP, place = pcall(function()
          local scale = battle:battlePanelScale(winW, winH)
          local ox, oy = Chrome.fitOriginFor(winW, winH, scale, WideBattle.TILES_W, WideBattle.TILES_H)
          local _, py, _, ph = Chrome.playfieldRect(winW, winH)
          return { ox = ox, oy = oy, scale = scale, x = ox, y = py, w = WideBattle.WIDTH * scale, h = ph,
            ww = winW, wh = winH }
        end)
        if not okP then return ownDraw(battle, winW, winH, ...) end
        -- the column's paper fill gets the scene painted over it -Elvie
        local fill = Chrome.paletteFill
        local firstFill = true
        Chrome.paletteFill = function(...)
          local r = { fill(...) }
          if firstFill and not baking then
            firstFill = false
            local G = love.graphics
            G.push("all")
            G.setScissor(place.x, place.y, place.w, place.h)
            if blur then
              -- the window's blur, as the borders draw it -Elvie
              local iw, ih = s.image:getDimensions()
              local k = scenes.coverScale(iw, ih, place.ww, place.wh, scenes.ZOOM)
              local bw, bh = blur:getDimensions()
              scenes.setLight(lit, scenes.DIM)
              G.draw(blur, (place.ww - iw * k) / 2, (place.wh - ih * k) / 2, 0, iw * k / bw, ih * k / bh)
            else
              dock = place
              local q, x0, y0, k = dockQuad(s)
              scenes.setLight(lit)
              G.draw(s.image, q, x0, y0, 0, k, k)
            end
            G.pop()
          end
          return unpack(r)
        end
        dock = not blur and place or nil
        column = place
        local ok, err = pcall(ownDraw, battle, winW, winH, ...)
        Chrome.paletteFill, dock, column = fill, nil, nil
        if not ok then error(err, 0) end
      end
    end
  end
end

return scenes
