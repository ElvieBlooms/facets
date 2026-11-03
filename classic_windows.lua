-- WINDOWS on the Game Boy games
-- Every box Red/Blue/Yellow and Gold/Silver/Crystal draw goes through
-- Font.drawBox (Gold/Silver/Crystal's with a palette shader on), one 8x8
-- tile border round a filled inside: the same grid as Gen 3's windows.
-- So a box drawn there gets a Gen 3 frame instead:
--   FIRERED 1-10: the frames from FireRed's OPTION menu, and FireRed's
--     own text box for the six-row box at the bottom, read from the
--     player's imported FireRed (then LeafGreen, then Emerald).
--   A window set's style (assets/windows/<set>/, TITO's): its text box at
--     the bottom, and FireRed's frame 1 round everything else.
-- Six-row boxes are the text box: Gen 3's is two tiles thick at the sides
-- and one at the top and bottom, round four rows of text. Boxes under
-- three tiles either way stay the game's own. -Elvie
-- --------------------------------------------------

local windows = {}

local GAME = "game"
local DIR = "assets/windows"
local T = 8
local gba = require("mods.facets.classic_gba")
local GAMES = { "firered", "leafgreen", "emerald" }

windows.FRAMES = 10

-- A tile row: the next box drawn there (eight wide, four tall or more)
-- gets the text box look. The FACETS page sets it for the WINDOWS row,
-- so that row shows the text box the style gives -Elvie
windows.textBoxAt = nil

-- Whether WINDOWS changes anything, once init has run -Elvie
function windows.styled() return false end

-- The text box drawn last with a coloured inside (TITO's WOODY and the
-- like): { x, y, w, h, fill = {r, g, b} 0-255, at = time, calls = draw
-- calls }. Gold/Silver/Crystal print letters on a white tile, so text in
-- it takes that colour instead -Elvie
windows.paper = nil

-- Whether pixel x, y is inside the paper box drawn this frame. Boxes are
-- drawn again every frame, so one from before the last present is stale:
-- the draw call count starts again from nothing then -Elvie
function windows.paperAt(paper, x, y, now, calls)
  if type(paper) ~= "table" or type(x) ~= "number" or type(y) ~= "number" then return nil end
  if now and paper.at and now - paper.at > 0.012 then return nil end
  if calls and paper.calls and calls < paper.calls then return nil end
  if x < paper.x or y < paper.y or x >= paper.x + paper.w or y >= paper.y + paper.h then return nil end
  return paper.fill
end

-- A palette with its paper (colour 0) as fill, as a new table -Elvie
function windows.onPaper(pal, fill)
  if type(pal) ~= "table" or type(fill) ~= "table" then return pal end
  return { { fill[1], fill[2], fill[3] }, pal[2], pal[3], pal[4] }
end

-- A WINDOWS value: "fr:<n>" for FireRed's frame n, "<set>:<n>" for a
-- set's style n. Returns kind, key, n -Elvie
function windows.parse(value)
  local key, n = tostring(value or ""):match("^([%w_%-]+):(%d+)$")
  if not key then return nil end
  n = tonumber(n)
  if key == "fr" then
    if n >= 1 and n <= windows.FRAMES then return "fr", key, n end
    return nil
  end
  return "set", key, n
end

-- Which art a box gets: "dialogue" for the six-row text box, "frame" for
-- the rest, nil to leave it to the game -Elvie
function windows.kind(tw, th)
  if type(tw) ~= "number" or type(th) ~= "number" or tw < 3 or th < 3 then return nil end
  if th == 6 and tw >= 8 then return "dialogue" end
  return "frame"
end

-- As kind, with the FACETS page's WINDOWS row (textBoxAt) as a text box -Elvie
function windows.boxKind(ty, tw, th)
  local kind = windows.kind(tw, th)
  if kind and windows.textBoxAt == ty and tw >= 8 and th >= 4 then return "dialogue" end
  return kind
end

-- The text box's tiles from Gen 3's 18-tile atlas, for a box at tx, ty
-- tw x th (tiles): cell index and flip for each tile on the border, as
-- pokefirered's menu.c lays them out round content (2, 15) 26x4. Calls
-- put(cell, cx, cy, flip) -Elvie
function windows.dialogueCells(tx, ty, tw, th, put)
  local L, Top, W, H = tx + 2, ty + 1, tw - 4, th - 2
  for _, edge in ipairs({ { Top - 1, false }, { Top + H, true } }) do
    local y, f = edge[1], edge[2]
    put(0, L - 2, y, f); put(1, L - 1, y, f)
    for i = 0, W - 1 do put(2, L + i, y, f) end
    put(3, L + W, y, f); put(4, L + W + 1, y, f)
  end
  local rows = { { 5, 6, 8, 9, false }, { 10, 11, 12, 13, false }, { 10, 11, 12, 13, true }, { 5, 6, 8, 9, true } }
  for r = 1, H do
    -- rows past the fourth repeat the middle ones -Elvie
    local c = rows[r == H and 4 or (r == 1 and 1 or (r <= H / 2 and 2 or 3))]
    local y = Top + r - 1
    put(c[1], L - 2, y, c[5]); put(c[2], L - 1, y, c[5])
    put(c[3], L + W, y, c[5]); put(c[4], L + W + 1, y, c[5])
  end
end

-- A 3x3 frame's tiles on a box's border ring: put(cell, cx, cy) -Elvie
function windows.frameCells(tx, ty, tw, th, put)
  put(0, tx, ty)
  for i = 1, tw - 2 do put(1, tx + i, ty) end
  put(2, tx + tw - 1, ty)
  for j = 1, th - 2 do
    put(3, tx, ty + j)
    put(5, tx + tw - 1, ty + j)
  end
  put(6, tx, ty + th - 1)
  for i = 1, tw - 2 do put(7, tx + i, ty + th - 1) end
  put(8, tx + tw - 1, ty + th - 1)
end

-- The window sets and their styles, from meta.json -Elvie
local function findSets(mod)
  local sets = {}
  local okD, decode = pcall(function() return require("mods.facets.npcs").decodeJson end)
  for _, key in ipairs(mod.assets:list(DIR) or {}) do
    local rel = DIR .. "/" .. key .. "/meta.json"
    if key:match("^[%w_%-]+$") and key ~= "fr" and okD and mod.assets:info(rel) then
      local ok, meta = pcall(decode, mod:read(rel))
      if ok and type(meta) == "table" and type(meta.styles) == "table" then
        sets[#sets + 1] = { key = key, styles = meta.styles,
          label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper() }
      end
    end
  end
  table.sort(sets, function(a, b) return a.label < b.label end)
  return sets
end

function windows.init(mod, rows)
  local sets = findSets(mod)
  local byKey = {}
  local choices = { { "GAME", GAME } }
  for n = 1, windows.FRAMES do choices[#choices + 1] = { "FIRERED " .. n, "fr:" .. n } end
  for _, set in ipairs(sets) do
    byKey[set.key] = set
    for n, st in ipairs(set.styles) do
      if type(st) == "table" and type(st.dialogue) == "string" then
        choices[#choices + 1] = { set.label .. " " .. tostring(st.name or n), set.key .. ":" .. n }
      end
    end
  end
  rows[#rows + 1] = { key = "classicWindows", type = "choice", label = "WINDOWS", choices = choices, default = GAME }

  return function()
    local okF, Font = pcall(require, "src.render.Font")
    if not (okF and type(Font) == "table" and type(Font.drawBox) == "function") then
      mod.log:warn("Font.drawBox not found; WINDOWS is off")
      return
    end

    local images, quads = {}, {}
    local function fromGame(rel, w, h)
      local id = "game:" .. rel
      if images[id] ~= nil then return images[id] or nil end
      images[id] = false
      for _, game in ipairs(GAMES) do
        local data = gba.image(gba.read(game, rel), w, h)
        if data then
          local img = love.graphics.newImage(data)
          img:setFilter("nearest", "nearest")
          images[id] = img
          return img
        end
      end
      return nil
    end
    local function fromSet(key, file)
      local id = key .. "/" .. tostring(file)
      if images[id] ~= nil then return images[id] or nil end
      images[id] = false
      if type(file) ~= "string" or not file:match("^[%w_%-%.]+%.png$") then return nil end
      local ok, img = pcall(love.graphics.newImage, mod.assets:path(DIR .. "/" .. key .. "/" .. file))
      if not ok then return nil end
      img:setFilter("nearest", "nearest")
      images[id] = img
      return img
    end
    local function quad(img, i)
      local byImg = quads[img]
      if not byImg then byImg = {}; quads[img] = byImg end
      local q = byImg[i]
      if not q then
        local w, h = img:getDimensions()
        q = love.graphics.newQuad((i % (w / T)) * T, math.floor(i / (w / T)) * T, T, T, w, h)
        byImg[i] = q
      end
      return q
    end

    -- The art for the chosen WINDOWS: { frame, dialogue, fill } -Elvie
    local function art()
      local kind, key, n = windows.parse(mod.options:get("classicWindows"))
      if not kind then return nil end
      if kind == "fr" then
        return { frame = fromGame("chrome/user_frame_" .. (n - 1) .. ".rgba", 24, 24),
          dialogue = fromGame("chrome/menu_message_rgba.rgba", 48, 24), fill = { 1, 1, 1 } }
      end
      local set = byKey[key]
      local st = set and set.styles[n]
      if type(st) ~= "table" then return nil end
      local c = type(st.fill) == "table" and st.fill or { 255, 255, 255 }
      return { frame = fromGame("chrome/user_frame_0.rgba", 24, 24), dialogue = fromSet(key, st.dialogue),
        fill = { (tonumber(c[1]) or 255) / 255, (tonumber(c[2]) or 255) / 255, (tonumber(c[3]) or 255) / 255 } }
    end

    local okP, PaletteFX = pcall(require, "src.render.PaletteFX")
    local function grey()
      if not (okP and type(PaletteFX) == "table") then return true end
      local m = PaletteFX.mode
      if m == "og" or m == "og_inv" or m == "classic" then return true end
      local ok, raw = pcall(function() return PaletteFX.forcesRawGrays() end)
      return ok and raw or false
    end

    windows.styled = function() return art() ~= nil end

    local own = Font.drawBox
    Font.drawBox = function(tx, ty, tw, th, fill, ...)
      local kind = windows.boxKind(ty, tw, th)
      local a = kind and art()
      local img = a and (kind == "dialogue" and a.dialogue or a.frame)
      if not img then return own(tx, ty, tw, th, fill, ...) end
      local G = love.graphics
      local r, g, b, al = G.getColor()
      -- Gold/Silver/Crystal draw boxes through a palette shader; the frame
      -- is in its own colours -Elvie
      local shader = G.getShader and G.getShader() or nil
      if shader then G.setShader() end
      local inside = kind == "dialogue" and a.fill
        or (type(fill) == "table" and fill[1] and { fill[1] / 255, fill[2] / 255, fill[3] / 255 }) or { 1, 1, 1 }
      G.setColor(inside[1], inside[2], inside[3], 1)
      G.rectangle("fill", tx * T, ty * T, tw * T, th * T)
      G.setColor(1, 1, 1, 1)
      if kind == "dialogue" then
        windows.dialogueCells(tx, ty, tw, th, function(i, cx, cy, flip)
          if flip then G.draw(img, quad(img, i), cx * T, cy * T + T, 0, 1, -1)
          else G.draw(img, quad(img, i), cx * T, cy * T) end
        end)
      else
        windows.frameCells(tx, ty, tw, th, function(i, cx, cy) G.draw(img, quad(img, i), cx * T, cy * T) end)
      end
      if shader then G.setShader(shader) end
      if kind == "dialogue" then
        local c = a.fill
        if c[1] < 1 or c[2] < 1 or c[3] < 1 then
          local stats = G.getStats and G.getStats()
          windows.paper = { x = tx * T, y = ty * T, w = tw * T, h = th * T,
            fill = { math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5) },
            at = love.timer and love.timer.getTime() or nil, calls = stats and stats.drawcalls or nil }
        else
          windows.paper = nil
        end
      end
      -- Red/Blue/Yellow recolour the screen afterwards: the box keeps its
      -- own colours, as full-colour pictures do, but in the Game Boy greys
      -- (CLASSIC, OG) -Elvie
      if okP and type(PaletteFX.markTrueColor) == "function" and not grey() then
        pcall(PaletteFX.markTrueColor, tx * T, ty * T, tw * T, th * T)
      end
      G.setColor(r, g, b, al)
    end

    -- Gold/Silver/Crystal's letters (and the cursor and the more arrow)
    -- carry their own white paper; in a coloured text box it's the box's
    -- colour instead -Elvie
    local okC, Chrome = false, nil
    if require("mods.facets.classic").generation() == 2 then
      okC, Chrome = pcall(require, table.concat({ "src", "ui", "gen2", "Chrome" }, "."))
    end
    if okC and type(Chrome) == "table" and type(Chrome.paletteGlyphs) == "function" then
      local G = love.graphics
      local function fillAt(x, y)
        local paper = windows.paper
        if not paper then return nil end
        local stats = G.getStats and G.getStats()
        return windows.paperAt(paper, x, y, love.timer and love.timer.getTime() or nil, stats and stats.drawcalls or nil)
      end
      local onFill = nil
      local ownThrough, ownRaw = Chrome.throughPalette, Chrome.rawPalette
      Chrome.throughPalette = function(...)
        local pal = ownThrough(...)
        return onFill and windows.onPaper(pal, onFill) or pal
      end
      Chrome.rawPalette = function(...)
        local pal = ownRaw(...)
        return onFill and windows.onPaper(pal, onFill) or pal
      end
      -- text and the cursor printed at a tile -Elvie
      local function atTile(own)
        return function(text, tx, ty, ...)
          local fill = type(tx) == "number" and type(ty) == "number" and fillAt(tx * T, ty * T)
          if not fill then return own(text, tx, ty, ...) end
          onFill = fill
          local results = { pcall(own, text, tx, ty, ...) }
          onFill = nil
          if not results[1] then error(results[2], 0) end
          return unpack(results, 2)
        end
      end
      if type(Chrome.printThrough) == "function" then Chrome.printThrough = atTile(Chrome.printThrough) end
      if type(Chrome.cursorThrough) == "function" then
        local ownCursor = Chrome.cursorThrough
        Chrome.cursorThrough = function(tx, ty, ...)
          return atTile(function(_, x, y, ...) return ownCursor(x, y, ...) end)(nil, tx, ty, ...)
        end
      end
      -- the text box's letters, placed one by one -Elvie
      local ownGlyphs = Chrome.paletteGlyphs
      Chrome.paletteGlyphs = function(palette, invert, raw, ...)
        local previous = G.getShader and G.getShader() or nil
        local pal, drawGlyph, finish = ownGlyphs(palette, invert, raw, ...)
        if not pal or not windows.paper then return pal, drawGlyph, finish end
        local okG, GbcPalette = pcall(require, "src.render.GbcPalette")
        local okFont, Font2 = pcall(require, "src.render.Font")
        if not (okG and okFont) then return pal, drawGlyph, finish end
        local ours = false
        local function glyph(code, x, y)
          local fill = code < (Font2.TTF_BASE or math.huge) and fillAt(x, y)
          if not fill then return drawGlyph(code, x, y) end
          G.setColor(1, 1, 1, 1)
          GbcPalette.useRaw(windows.onPaper(pal, fill))
          Font2.drawCode(code, x, y)
          -- back to the game's own, for its next letter -Elvie
          GbcPalette.useRaw(pal)
          ours = true
        end
        local function done()
          finish()
          if ours then G.setShader(previous) end
        end
        return pal, glyph, done
      end
      -- the more arrow's square -Elvie
      if type(Chrome.paletteFill) == "function" then
        local ownFill = Chrome.paletteFill
        Chrome.paletteFill = function(px, py, pw, ph, palette, ...)
          local fill = type(pw) == "number" and pw <= T and ph == T and fillAt(px, py)
          if not fill then return ownFill(px, py, pw, ph, palette, ...) end
          local shader = G.getShader and G.getShader() or nil
          if shader then G.setShader() end
          G.setColor(fill[1] / 255, fill[2] / 255, fill[3] / 255, 1)
          G.rectangle("fill", px, py, pw, ph)
          if shader then G.setShader(shader) end
          G.setColor(0, 0, 0, 1)
        end
      end
    end

    -- Red/Blue/Yellow's battle draws its text box into a grey layer and
    -- recolours it zone by zone, as the Super Game Boy did, so with COLORS
    -- on RED++ the text area is drawn again, in its own colours, after
    -- that. It's below the Pokémon, so nothing it covers is lost -Elvie
    local gen1 = require("mods.facets.classic").generation() == 1
    local okB, Battle1 = false, nil
    if gen1 then okB, Battle1 = pcall(require, table.concat({ "src", "battle", "BattleState" }, ".")) end
    if okB and type(Battle1) == "table" and type(Battle1.drawZonePass) == "function"
        and type(Battle1.drawTextArea) == "function" then
      local ownZone = Battle1.drawZonePass
      Battle1.drawZonePass = function(self, src, sx, sy, ...)
        local results = { ownZone(self, src, sx, sy, ...) }
        local full = okP and type(PaletteFX.honorsTrueColor) == "function" and PaletteFX.honorsTrueColor()
        if full and not grey() and art() then
          love.graphics.push()
          love.graphics.translate(sx or 0, sy or 0)
          local ok, err = pcall(self.drawTextArea, self)
          love.graphics.pop()
          if not ok then mod.log:warn("the battle text box couldn't be drawn again: %s", tostring(err)) end
        end
        return unpack(results)
      end
    end

    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id and change.key == "classicWindows" then
          images = {}
          gba.reset()
        end
      end)
    end
  end
end

return windows
