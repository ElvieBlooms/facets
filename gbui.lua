-- GBC windows and battle boxes
-- Crystal's interface on Gen 3, read from the player's own imported
-- Crystal (or Gold, Silver) while they play, so none of it is included:
--   WINDOWS: every menu framed with one of Crystal's eight FRAME styles,
--     on white, like Crystal's TYPE option; or a window set's frames
--     (assets/windows/<set>/, in Gen 3's own format).
--   TEXT BOX: the text box, signs and the battle message box, in one of
--     Crystal's frames or a window set's dialogue and sign boxes, drawn
--     the way Gen 3 draws its own. MATCH follows WINDOWS.
--   BATTLE UI: the battle healthboxes as Gen 2 draws them: no box, the
--     bracket under the HP bar, Crystal's HP and EXP bars; or a battle box
--     set's (assets/battleui/<set>/): healthboxes, bars and text box from
--     a patch, or its colours on the game's own. All five games: R/S keep
--     their own status icons and name-row tiles, in the set's colours.
--   BATTLE BG: the terrain and platforms swapped for Crystal's plain white,
--     or a battle background set's scenes (assets/battlebg/<set>/), each
--     of the games' backgrounds mapped to one of its scenes.
-- Each keeps the Gen 3 layout: windows stay where the game puts them, only
-- their borders and fill change. Without a Gen 2 game imported, the game's
-- own are drawn. -Elvie
-- --------------------------------------------------

local gbui = {}

gbui.WINDOWS = { { "GAME", "game" } }
for n = 1, 8 do gbui.WINDOWS[#gbui.WINDOWS + 1] = { "GBC " .. n, tostring(n) } end
-- TEXT BOX: MATCH (whatever WINDOWS gives), GAME, Crystal's, then the
-- sets' text boxes -Elvie
gbui.TEXTBOX = { { "MATCH", "match" }, { "GAME", "game" } }
for n = 1, 8 do gbui.TEXTBOX[#gbui.TEXTBOX + 1] = { "GBC " .. n, tostring(n) } end
gbui.SETS = {}          -- [key] = { label, credit, styles } from assets/windows -Elvie
gbui.WINDOWS_DIR = "assets/windows"
gbui.HUD = { { "GAME", "game" }, { "GBC", "gbc" } }
gbui.UI_SETS = {}       -- [key] = { label, credit, images, palettes, textboxKeep } -Elvie
gbui.UI_DIR = "assets/battleui"
gbui.BG = { { "GAME", "game" }, { "WHITE", "white" } }
gbui.BG_SETS = {}       -- [key] = { label, credit, scenes, keys, default } -Elvie
gbui.BG_DIR = "assets/battlebg"

-- The Gen 2 games, best first: frames, font tiles and HUD are in all three. -Elvie
gbui.GAMES = { "crystal", "gold", "silver" }

local INK = { 0, 0, 0 }
local PAPER = { 255, 255, 255 }
local T = 8

local function getter(mod) return function(key) return mod.options:get(key) end end

-- A window set's style for a WINDOWS value ("<set>:<n>"), or nil. -Elvie
function gbui.style(value)
  local key, n = tostring(value or ""):match("^([%w_%-]+):(%d+)$")
  local set = key and gbui.SETS[key]
  return set and set.styles[tonumber(n)] or nil, set
end

function gbui.settings(get)
  -- a WINDOWS choice that's gone (a set with no frames, as TITO's has had
  -- none since TEXT BOX) goes back to the game's own -Elvie
  local frame = tostring(get("gbcFrame") or "game")
  local frameStyle = gbui.style(frame)
  if not (frame:match("^[1-8]$") or (frameStyle and type(frameStyle.frame) == "string")) then frame = "game" end
  local text = tostring(get("gbcTextBox") or "match")
  if not (text == "game" or text:match("^[1-8]$") or gbui.style(text)) then text = "match" end
  local hud = tostring(get("gbcHud") or "game")
  if hud ~= "gbc" and not gbui.UI_SETS[hud] then hud = "game" end
  local bg = tostring(get("gbcBattleBg") or "game")
  if bg ~= "white" and bg ~= "colours" and not gbui.BG_SETS[bg] then bg = "game" end
  return frame, hud, bg, text
end

-- What draws the text box: "game", "1"-"8" or "<set>:<n>". MATCH takes
-- WINDOWS's, which for a set's style is its text box -Elvie
function gbui.textValue(get)
  local frame, _, _, text = gbui.settings(get)
  if text ~= "match" then return text end
  return frame
end

-- --------------------------------------------------
-- Crystal's art
-- --------------------------------------------------

-- Palettes from palettes.lua: hpBar's green/yellow/red and expBar, each
-- two colours (light, fill). -Elvie
function gbui.parseBars(text)
  if type(text) ~= "string" then return nil end
  local out = {}
  local function six(body)
    local v = {}
    for num in body:gmatch("%d+") do v[#v + 1] = tonumber(num) end
    if #v ~= 6 then return nil end
    return { { v[1], v[2], v[3] }, { v[4], v[5], v[6] } }
  end
  local exp = text:match("\n  expBar = {(.-)\n  }")
  out.exp = exp and six(exp)
  local hp = text:match("\n  hpBar = {(.-)\n  }")
  if hp then
    for name, body in hp:gmatch("\n    ([%w_]+) = {(.-)\n    }") do out[name] = six(body) end
  end
  if not (out.exp and out.green and out.yellow and out.red) then return nil end
  return out
end

-- A copy of a Game Boy tile sheet in real colours. colours[1..4] is
-- lightest to darkest, by the sheet's grey (255, 170, 85, 0); a sheet
-- with see-through pixels (the 1bpp ones) keeps them, its ink drawn in
-- colours[4]. paper: see-through becomes colours[1] instead. -Elvie
function gbui.recolour(src, colours, paper)
  local w, h = src:getDimensions()
  local out = love.image.newImageData(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local r, _, _, a = src:getPixel(x, y)
      local c
      if not a or a <= 0 then
        c = paper and colours[1] or nil
      else
        local k = r > 0.83 and 1 or r > 0.5 and 2 or r > 0.17 and 3 or 4
        c = colours[k]
      end
      if c then out:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, 1) end
    end
  end
  return out
end

local art = nil       -- { frames = { [n] = image }, hp = { green = img, ... }, exp = img, ... } or false
local quads = {}

local function image(data)
  local img = love.graphics.newImage(data)
  img:setFilter("nearest", "nearest")
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

-- Everything from the player's Gen 2 game, once; false if it can't be
-- read (no game imported). -Elvie
function gbui.art()
  if art ~= nil then return art or nil end
  art = false
  if not (love and love.graphics and love.image) then return nil end
  local gb = require("mods.facets.gb")
  local function read(rel) return gb.readImage(gb.path("assets", rel), gbui.GAMES) end
  local frames = read("fonts/frames.png")
  local hpBar, expBar = read("battle/hud/hp_bar.png"), read("battle/hud/exp_bar.png")
  local enemyB, playerB = read("battle/hud/enemy_border.png"), read("battle/hud/player_border.png")
  local pals = gbui.parseBars(gb.readAt(gb.path("data", "palettes.lua"), gbui.GAMES))
  if not frames then return nil end
  local out = { frames = {} }
  -- frames.png: eight frames, a row of six tiles each: corner, top,
  -- corner, side, bottom corner, bottom corner -Elvie
  local fw = frames:getWidth()
  local whole = image(gbui.recolour(frames, { PAPER, PAPER, INK, INK }, true))
  out.framesImage = whole
  out.frameCount = math.floor(frames:getHeight() / T)
  out.framesPerRow = math.floor(fw / T)
  if hpBar and expBar and enemyB and playerB and pals then
    local function four(p) return { PAPER, p[1], p[2], INK } end
    out.hp = {}
    for _, k in ipairs({ "green", "yellow", "red" }) do out.hp[k] = image(gbui.recolour(hpBar, four(pals[k]))) end
    out.expHp = image(gbui.recolour(hpBar, four(pals.exp)))
    out.exp = image(gbui.recolour(expBar, four(pals.exp)))
    out.enemyBorder = image(gbui.recolour(enemyB, { PAPER, PAPER, INK, INK }))
    out.playerBorder = image(gbui.recolour(playerB, { PAPER, PAPER, INK, INK }))
  end
  art = out
  return out
end

function gbui.reset() art = nil; quads = {} end

-- --------------------------------------------------
-- Drawing
-- --------------------------------------------------

-- PAPER: DARK's windows on the GBA games. A window Facets draws itself
-- is marked as paper, as the game's own are (filter.lua) -Elvie
function gbui.markPaper(x, y, w, h)
  local ok, filter = pcall(require, "mods.facets.filter")
  if ok and type(filter.markPaper) == "function" then filter.markPaper(x, y, w, h) end
end

-- DARK, drawn: owns a window Facets draws (kept as drawn, its letters
-- inked) and gives the paper's colour, or nil when not dark; and its
-- frame art with the white inside it in that colour -Elvie
function gbui.own(x, y, w, h)
  local ok, filter = pcall(require, "mods.facets.filter")
  if not (ok and type(filter.paperNow) == "function") then return nil end
  local pp = filter.paperNow()
  if pp and filter.own(x, y, w, h) then return pp end
  return nil
end
-- A light paper, and art with a paper map: the window owned (kept as
-- drawn, letters black), and the paper's colour and the art with its
-- map in it; nil when not -Elvie
function gbui.lit(img, x, y, w, h)
  local ok, filter = pcall(require, "mods.facets.filter")
  if not (ok and type(filter.paperArt) == "function") then return nil end
  local art = filter.paperArt(img)
  if not art then return nil end
  local lp = filter.paperLight()
  if lp and filter.own(x, y, w, h, lp, nil, true) then return lp, art end
  return nil
end
function gbui.darkArt(img, pp, also)
  if not pp then return img end
  local ok, filter = pcall(require, "mods.facets.filter")
  return ok and type(filter.darkArt) == "function" and filter.darkArt(img, also) or img
end

-- A Crystal window: (x, y) its top-left pixel, w by h tiles, border
-- included. Crystal reuses the top edge for the bottom and one side
-- tile for both sides. -Elvie
function gbui.box(frame, x, y, w, h)
  local a = gbui.art()
  local n = (tonumber(frame) or 1) - 1
  if not a or n < 0 or n >= a.frameCount or w < 2 or h < 2 then return false end
  local G = love.graphics
  gbui.markPaper(x, y, w * T, h * T)
  -- DARK: drawn dark and owned (filter.lua) -Elvie
  local pp = gbui.own(x, y, w * T, h * T)
  local lp, lit = nil, nil
  if not pp then lp, lit = gbui.lit(a.framesImage, x, y, w * T, h * T) end
  local fill = pp or lp
  if fill then G.setColor(fill[1], fill[2], fill[3], 1) else G.setColor(PAPER[1] / 255, PAPER[2] / 255, PAPER[3] / 255, 1) end
  G.rectangle("fill", x, y, w * T, h * T)
  G.setColor(1, 1, 1, 1)
  local img, base = lit or gbui.darkArt(a.framesImage, pp), n * a.framesPerRow
  local function tile(i, cx, cy) G.draw(img, quad(img, base + i), x + cx * T, y + cy * T) end
  tile(0, 0, 0)
  for cx = 1, w - 2 do tile(1, cx, 0) end
  tile(2, w - 1, 0)
  for cy = 1, h - 2 do
    tile(3, 0, cy)
    tile(3, w - 1, cy)
  end
  tile(4, 0, h - 1)
  for cx = 1, w - 2 do tile(1, cx, h - 1) end
  tile(5, w - 1, h - 1)
  return true
end

-- Crystal's HP bar (HPBarPals' colour by how full it is, the same pixel
-- maths as Gen 2): "HP:", six cells, and the end cap unless capless. -Elvie
function gbui.hpPixels(hp, maxHp)
  hp, maxHp = math.max(0, tonumber(hp) or 0), math.max(0, tonumber(maxHp) or 0)
  if maxHp <= 0 or hp <= 0 then return 0 end
  local px = math.floor(hp * 48 / maxHp)
  return math.max(1, math.min(48, px))
end

function gbui.hpColour(px)
  if px >= 24 then return "green" end
  if px >= 10 then return "yellow" end
  return "red"
end

function gbui.hpBar(x, y, hp, maxHp, capless)
  local a = gbui.art()
  if not (a and a.hp) then return false end
  local px = gbui.hpPixels(hp, maxHp)
  local img = a.hp[gbui.hpColour(px)]
  local G = love.graphics
  G.setColor(1, 1, 1, 1)
  G.draw(img, quad(img, 0), x, y)
  G.draw(img, quad(img, 1), x + T, y)
  for cell = 0, 5 do
    local filled = math.max(0, math.min(8, px - cell * 8))
    G.draw(img, quad(img, 2 + filled), x + 16 + cell * T, y)
  end
  if not capless then G.draw(img, quad(img, 11), x + 64, y) end
  return true
end

-- Crystal's EXP bar: eight cells, filling from the right. -Elvie
function gbui.expBar(x, y, ratio)
  local a = gbui.art()
  if not (a and a.exp) then return false end
  ratio = math.max(0, math.min(1, tonumber(ratio) or 0))
  local remaining = math.floor(ratio * 64)
  local G = love.graphics
  G.setColor(1, 1, 1, 1)
  for cell = 7, 0, -1 do
    local cx = x + cell * T
    if remaining >= 8 then
      remaining = remaining - 8
      G.draw(a.expHp, quad(a.expHp, 10), cx, y)
    elseif remaining > 0 then
      G.draw(a.exp, quad(a.exp, remaining - 1), cx, y)
      remaining = 0
    else
      G.draw(a.expHp, quad(a.expHp, 2), cx, y)
    end
  end
  return true
end

-- The brackets Gen 2 draws round its HUDs (DrawEnemyHUDBorder,
-- DrawPlayerHUDBorder). (x, y): the HP bar's top-left. -Elvie
function gbui.enemyBracket(x, y)
  local a = gbui.art()
  if not (a and a.enemyBorder) then return false end
  local G, E, P = love.graphics, a.enemyBorder, a.playerBorder
  G.setColor(1, 1, 1, 1)
  G.draw(E, quad(E, 1), x - T, y)             -- side -Elvie
  G.draw(P, quad(P, 1), x - T, y + T)         -- bottom left -Elvie
  for i = 0, 7 do G.draw(P, quad(P, 3), x + i * T, y + T) end
  G.draw(P, quad(P, 5), x + 64, y + T)        -- the point -Elvie
  return true
end

function gbui.playerBracket(x, y)
  local a = gbui.art()
  if not (a and a.playerBorder) then return false end
  local G, E, P = love.graphics, a.enemyBorder, a.playerBorder
  G.setColor(1, 1, 1, 1)
  G.draw(P, quad(P, 0), x + 64, y)            -- side, two rows -Elvie
  G.draw(P, quad(P, 0), x + 64, y + T)
  G.draw(P, quad(P, 4), x + 64, y + 2 * T)    -- bottom right -Elvie
  for i = 0, 7 do G.draw(P, quad(P, 3), x + i * T, y + 2 * T) end
  G.draw(E, quad(E, 3), x - T, y + 2 * T)     -- the point -Elvie
  return true
end

-- --------------------------------------------------
-- Window sets
-- --------------------------------------------------

-- A set's WINDOWS choices (its styles with a frame) and TEXT BOX choices
-- (one per text box picture: LIBERTY's ten frames share one, so it's just
-- LIBERTY; TITO's ten are TITO <name>) -Elvie
function gbui.setChoices(set)
  local frames, boxes, seen, distinct = {}, {}, {}, 0
  for _, st in ipairs(set.styles) do
    if type(st) == "table" and type(st.dialogue) == "string" and not seen[st.dialogue] then
      seen[st.dialogue] = true
      distinct = distinct + 1
    end
  end
  seen = {}
  for n, st in ipairs(set.styles) do
    if type(st) == "table" then
      -- (short: the style's name alone, PAPER WOOD's colours) -Elvie
      local name = set.short and tostring(st.name or n) or set.label .. " " .. tostring(st.name or n)
      if type(st.frame) == "string" then frames[#frames + 1] = { name, set.key .. ":" .. n } end
      if type(st.dialogue) == "string" and not seen[st.dialogue] then
        seen[st.dialogue] = true
        boxes[#boxes + 1] = { distinct == 1 and set.label or name, set.key .. ":" .. n }
      end
    end
  end
  return frames, boxes
end

-- Reads assets/windows/*/meta.json and adds each style to WINDOWS, after
-- Crystal's, as "<LABEL> <name>". -Elvie
function gbui.loadSets(mod)
  gbui.SETS = {}
  local list = {}
  local ok, names = pcall(function() return mod.assets:list(gbui.WINDOWS_DIR) end)
  for _, key in ipairs(ok and names or {}) do
    local rel = gbui.WINDOWS_DIR .. "/" .. key .. "/meta.json"
    if key:match("^[%w_%-]+$") and mod.assets:info(rel) then
      local okM, meta = pcall(function() return require("mods.facets.npcs").decodeJson(mod:read(rel)) end)
      if okM and type(meta) == "table" and type(meta.styles) == "table" and #meta.styles > 0 then
        local label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper()
        gbui.SETS[key] = { key = key, label = label, credit = meta.credit, styles = meta.styles, short = meta.short == true }
        list[#list + 1] = gbui.SETS[key]
      else
        mod.log:warn("windows/%s/meta.json couldn't be read", key)
      end
    end
  end
  table.sort(list, function(a, b) return a.label < b.label end)
  local choices, texts = {}, {}
  for i = 1, 9 do choices[i] = gbui.WINDOWS[i] end
  for i = 1, 10 do texts[i] = gbui.TEXTBOX[i] end
  for _, set in ipairs(list) do
    local frames, boxes = gbui.setChoices(set)
    for _, c in ipairs(frames) do choices[#choices + 1] = c end
    for _, c in ipairs(boxes) do texts[#texts + 1] = c end
  end
  gbui.WINDOWS, gbui.TEXTBOX = choices, texts
  return list
end

-- Reads assets/battlebg/*/meta.json; each set is a BATTLE BG choice after
-- WHITE. -Elvie
function gbui.loadBgSets(mod)
  gbui.BG_SETS = {}
  local list = {}
  local ok, names = pcall(function() return mod.assets:list(gbui.BG_DIR) end)
  for _, key in ipairs(ok and names or {}) do
    local rel = gbui.BG_DIR .. "/" .. key .. "/meta.json"
    if key:match("^[%w_%-]+$") and key ~= "game" and key ~= "white" and mod.assets:info(rel) then
      local okM, meta = pcall(function() return require("mods.facets.npcs").decodeJson(mod:read(rel)) end)
      if okM and type(meta) == "table" and type(meta.scenes) == "table" then
        local label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper()
        gbui.BG_SETS[key] = { key = key, label = label, credit = meta.credit, scenes = meta.scenes,
          keys = type(meta.keys) == "table" and meta.keys or {}, default = meta.default }
        list[#list + 1] = gbui.BG_SETS[key]
      else
        mod.log:warn("battlebg/%s/meta.json couldn't be read", key)
      end
    end
  end
  table.sort(list, function(a, b) return a.label < b.label end)
  -- FRLG, EMERALD and R/S: the GBA games' own backgrounds, from the
  -- player's imports, so one game can fight on another's (gba_bg) -Elvie
  for _, g in ipairs(require("mods.facets.gba_bg").SETS) do
    gbui.BG_SETS[g.key] = { key = g.key, label = g.label, gba = true, scenes = {}, keys = {},
      credit = { "From your own " .. g.name .. "." } }
    list[#list + 1] = gbui.BG_SETS[g.key]
  end
  gbui.BG = { { "GAME", "game" }, { "WHITE", "white" }, { "COLORS", "colours" } }
  for _, set in ipairs(list) do gbui.BG[#gbui.BG + 1] = { set.label, set.key } end
  return list
end

-- A set's scene for one of the games' backgrounds (grass, cave, gym...),
-- loaded once; the set's default for one it doesn't map. -Elvie
local scenes = {}
-- The scene name a set gives one of the games' backgrounds, or nil. -Elvie
-- The woods: Petalburg Woods, Viridian Forest, Berry Forest and Pattern
-- Bush fight on the game's grass, but they're forests, so their scene is
-- the forest. By region map section, the same numbers in both games -Elvie
gbui.FORESTS = { [59] = true, [126] = true, [176] = true, [182] = true }
gbui.WOODS_KEYS = { grass = true, long_grass = true, plain = true }
function gbui.forestKey(bgKey, mapSec)
  if gbui.FORESTS[tonumber(mapSec) or -1] and gbui.WOODS_KEYS[tostring(bgKey or "")] then return "long_grass" end
  return bgKey
end
-- The region map section the player's in, or nil -Elvie
function gbui.mapSec()
  local ok, sec = pcall(function()
    local Runtime = package.loaded["src.core.game3.runtime"]
    local Pokemon = package.loaded["src.core.game3.pokemon"]
    if not (Runtime and Pokemon and type(Pokemon.currentMapSec) == "function") then return nil end
    return Pokemon.currentMapSec(Runtime.getSession and Runtime.getSession() or nil)
  end)
  return ok and sec or nil
end

function gbui.sceneName(setKey, bgKey)
  local set = gbui.BG_SETS[setKey]
  if not set then return nil end
  if set.gba then return require("mods.facets.gba_bg").sceneName(bgKey) end
  local name = set.keys[tostring(bgKey or "")] or set.default
  return type(name) == "string" and set.scenes[name] and name or nil
end

gbui.sceneData = setmetatable({}, { __mode = "k" })
function gbui.scene(mod, setKey, bgKey)
  local set = gbui.BG_SETS[setKey]
  if not set then return nil end
  if set.gba then
    local id = setKey .. "/" .. tostring(bgKey or "")
    local hit = scenes[id]
    if hit ~= nil then return hit or nil end
    local G = require("mods.facets.gba_bg")
    local data = G.imageData(setKey, bgKey, G.PAD)
    scenes[id] = data and image(data) or false
    if scenes[id] then pcall(scenes[id].setWrap, scenes[id], "mirroredrepeat", "mirroredrepeat") end
    return scenes[id] or nil
  end
  local name = set.keys[tostring(bgKey or "")] or set.default
  local file = name and set.scenes[name]
  if type(file) ~= "string" or not file:match("^[%w_%-%.]+%.png$") then return nil end
  local id = setKey .. "/" .. file
  local hit = scenes[id]
  if hit ~= nil then return hit or nil end
  scenes[id] = false
  if not (love and love.graphics and love.image) then return nil end
  local okI, data = pcall(love.image.newImageData, mod.assets:path(gbui.BG_DIR .. "/" .. id))
  if okI and data then
    scenes[id] = image(data)
    -- (its picture kept, for its sky at each hour) -Elvie
    if scenes[id] then gbui.sceneData[scenes[id]] = { data = data, dir = gbui.BG_DIR .. "/" .. setKey, file = file } end
    -- past its edges it carries on mirrored, for the window's borders -Elvie
    pcall(scenes[id].setWrap, scenes[id], "mirroredrepeat", "mirroredrepeat")
  end
  return scenes[id] or nil
end

-- --------------------------------------------------
-- Battle box sets
-- --------------------------------------------------

-- Reads assets/battleui/*/meta.json; each set is a BATTLE UI choice
-- after GBC. -Elvie
function gbui.loadUiSets(mod)
  gbui.UI_SETS = {}
  local list = {}
  local ok, names = pcall(function() return mod.assets:list(gbui.UI_DIR) end)
  for _, key in ipairs(ok and names or {}) do
    local rel = gbui.UI_DIR .. "/" .. key .. "/meta.json"
    if key:match("^[%w_%-]+$") and key ~= "game" and key ~= "gbc" and mod.assets:info(rel) then
      local okM, meta = pcall(function() return require("mods.facets.npcs").decodeJson(mod:read(rel)) end)
      if okM and type(meta) == "table" and (type(meta.images) == "table" or type(meta.palettes) == "table") then
        local label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper()
        gbui.UI_SETS[key] = { key = key, label = label, credit = meta.credit,
          images = type(meta.images) == "table" and meta.images or {},
          palettes = type(meta.palettes) == "table" and meta.palettes or {},
          textboxKeep = type(meta.textboxKeep) == "table" and meta.textboxKeep or {} }
        list[#list + 1] = gbui.UI_SETS[key]
      else
        mod.log:warn("battleui/%s/meta.json couldn't be read", key)
      end
    end
  end
  table.sort(list, function(a, b) return a.label < b.label end)
  gbui.HUD = { { "GAME", "game" }, { "GBC", "gbc" } }
  for _, set in ipairs(list) do gbui.HUD[#gbui.HUD + 1] = { set.label, set.key } end
  return list
end

-- The game's battle pictures a set can change: the engine's field, its
-- cached file, size, and the palette it's drawn in. -Elvie
gbui.UI_PIECES = {
  { name = "healthbox_player", field = "_playerBox", w = 128, h = 64, pal = "healthbox" },
  { name = "healthbox_enemy", field = "_enemyBox", w = 128, h = 32, pal = "healthbox" },
  { name = "healthbox_safari", field = "_safariBox", w = 128, h = 64, pal = "healthbox" },
  { name = "healthbox_doubles_player", field = "_doublesPlayerBox", w = 128, h = 32, pal = "healthbox" },
  { name = "healthbox_doubles_opponent", field = "_doublesOpponentBox", w = 128, h = 32, pal = "healthbox" },
  { name = "elements", field = "_elements", w = 320, h = 24, pal = "healthbar" },
  { name = "elements_exp", field = "_elementsExp", w = 320, h = 24, pal = "healthbox" },
  { name = "party_summary_bar", field = "_partyBar", w = 128, h = 8, pal = "healthbox" },
  { name = "textbox", field = "_textbox", w = 256, h = 512, pal = "textbox" },
}

-- The tiles of R/S's HP and EXP sheet that differ from FireRed's and
-- Emerald's (compared tile by tile, 8x8, 40 to a row): its status icons
-- and the box tiles R/S lays under the name. -Elvie
gbui.RS_ELEMENT_TILES = { 22, 25, 26, 27, 31, 34, 42, 44, 45, 46, 72, 75, 76, 77, 81, 84, 87, 90, 91, 92,
  96, 99, 102, 105, 106, 107, 111, 114 }

local function key5(r, g, b)
  return math.floor(r * 31 + 0.5) + math.floor(g * 31 + 0.5) * 32 + math.floor(b * 31 + 0.5) * 1024
end

-- GBA colour pairs as a lookup: game colour -> the set's, as 0..1 RGB.
-- Colour 0 (see-through) and unchanged ones are left out; where the game
-- uses one colour twice, the first wins. into: add to that table. base:
-- the palette the set was made against (FireRed's), when the game's own
-- (from) differs: only the colours the set changed from base are moved,
-- so another game's colours never take FireRed's. -Elvie
function gbui.colourMap(from, to, into, base)
  local out = into or {}
  if type(from) ~= "table" or type(to) ~= "table" then return out end
  base = type(base) == "table" and base or from
  for i = 2, 16 do
    local a, b, was = tonumber(from[i]), tonumber(to[i]), tonumber(base[i])
    if a and b and was and was ~= b and out[a] == nil then
      out[a] = { (b % 32) / 31, (math.floor(b / 32) % 32) / 31, (math.floor(b / 1024) % 32) / 31 }
    end
  end
  return out
end

-- The 0..1 colour a map turns r, g, b into, or nil. -Elvie
function gbui.mapColour(map, r, g, b)
  if not map or type(r) ~= "number" then return nil end
  return map[key5(r, g or 0, b or 0)]
end

-- A copy of the game's picture (RGBA bytes) in a set's colours. -Elvie
function gbui.recolourRgba(bytes, w, h, map)
  local data = love.image.newImageData(w, h, "rgba8", bytes)
  data:mapPixel(function(_, _, r, g, b, a)
    if a > 0 then
      local c = map[key5(r, g, b)]
      if c then return c[1], c[2], c[3], a end
    end
    return r, g, b, a
  end)
  return data
end

-- A set's pictures for the game in play, built once each: its own where it
-- has them, else the game's in its colours. read(name) gives the game's
-- RGBA bytes; pals the game's own palettes (nil: FireRed's, kept in the
-- set). { images = { [field] = Image }, text = colour map } -Elvie
local uiArt = {}
function gbui.uiArt(mod, key, read, pals, size)
  local set = gbui.UI_SETS[key]
  if not set then return nil end
  local id = key .. "|" .. tostring(size and size.id or "")
  local hit = uiArt[id]
  if hit ~= nil then return hit or nil end
  uiArt[id] = false
  if not (love and love.graphics and love.image) then return nil end
  pals = pals or {}
  local maps = {}
  for name, p in pairs(set.palettes) do
    if type(p) == "table" then
      local from = type(pals[name]) == "table" and #pals[name] >= 16 and pals[name] or p.from
      maps[name] = gbui.colourMap(from, p.to, nil, p.from)
    end
  end
  local out = { images = {}, text = {} }
  -- the healthboxes' text and fills: their colours, then the bars' -Elvie
  for _, name in ipairs({ "healthbox", "healthbar" }) do
    for k, v in pairs(maps[name] or {}) do if out.text[k] == nil then out.text[k] = v end end
  end
  for _, piece in ipairs(gbui.UI_PIECES) do
    local w, h = piece.w, piece.h
    if piece.name == "textbox" and size then w, h = size.w or w, size.h or h end
    local data
    local map = maps[piece.pal]
    local file = set.images[piece.name]
    if type(file) == "string" and file:match("^[%w_%-%.]+%.png$") then
      local okI, own = pcall(love.image.newImageData, mod.assets:path(gbui.UI_DIR .. "/" .. key .. "/" .. file))
      if okI and own then data = own end
    end
    if piece.name == "textbox" and data then
      -- the game's own shows through where the set keeps it -Elvie
      local game = read(piece.name)
      if game and #game >= w * h * 4 then
        local base = map and next(map) and gbui.recolourRgba(game, w, h, map) or love.image.newImageData(w, h, "rgba8", game)
        local dw, dh = data:getDimensions()
        -- R/S's message box runs a column further before its menu (FR/LG's
        -- ends at column 15, R/S's at 16): keep the set's last inside
        -- column and its edge to widen it -Elvie
        local saved
        if size and size.rs and dw >= 17 * T and dh >= 40 * T then
          saved = love.image.newImageData(2 * T, 6 * T)
          saved:paste(data, 0, 0, 14 * T, 34 * T, 2 * T, 6 * T)
        end
        for _, r in ipairs(set.textboxKeep) do
          local x, y, n = (tonumber(r[1]) or 0) * T, (tonumber(r[2]) or 0) * T, (tonumber(r[3]) or 0) * T
          if x + n <= math.min(w, dw) and y + T <= math.min(h, dh) then
            for py = y, y + T - 1 do
              for px = x, x + n - 1 do data:setPixel(px, py, base:getPixel(px, py)) end
            end
          end
        end
        if saved then
          data:paste(saved, 15 * T, 34 * T, 0, 0, T, 6 * T)
          data:paste(saved, 16 * T, 34 * T, T, 0, T, 6 * T)
        end
      end
    elseif data and size and size.rs and (piece.name == "elements" or piece.name == "elements_exp") then
      -- R/S's sheet has its own tiles in these places (its status icons
      -- and the tiles under the name): the game's own, in the set's colours -Elvie
      local game = read(piece.name)
      if game and #game >= w * h * 4 then
        local base = map and next(map) and gbui.recolourRgba(game, w, h, map) or love.image.newImageData(w, h, "rgba8", game)
        for _, t in ipairs(gbui.RS_ELEMENT_TILES) do
          local x, y = (t % 40) * T, math.floor(t / 40) * T
          for py = y, y + T - 1 do
            for px = x, x + T - 1 do data:setPixel(px, py, base:getPixel(px, py)) end
          end
        end
      end
    elseif not data and map and next(map) then
      local game = read(piece.name)
      if game and #game >= w * h * 4 then data = gbui.recolourRgba(game, w, h, map) end
    end
    if data then out.images[piece.field] = image(data) end
  end
  uiArt[id] = out
  return out
end

-- A style's pictures, loaded once: { frame, dialogue, sign } images. -Elvie
local styleArt = {}
function gbui.styleArt(mod, value)
  local hit = styleArt[value]
  if hit ~= nil then return hit or nil end
  local st, set = gbui.style(value)
  if not (st and love and love.graphics) then return nil end
  local out = {}
  for _, kind in ipairs({ "frame", "dialogue", "sign" }) do
    local file = st[kind]
    if type(file) == "string" and file:match("^[%w_%-%.]+%.png$") then
      local rel = gbui.WINDOWS_DIR .. "/" .. set.key .. "/" .. file
      local okI, data = pcall(love.image.newImageData, mod.assets:path(rel))
      if okI and data then
        out[kind] = image(data)
        -- its paper map, if it has one (filter.darkArt) -Elvie
        local okM, mask = pcall(love.image.newImageData, mod.assets:path((rel:gsub("%.png$", ".paper.png"))))
        local okF, filter = pcall(require, "mods.facets.filter")
        if okM and mask and okF and type(filter.setArtMask) == "function" then filter.setArtMask(out[kind], mask) end
      end
    end
  end
  local function colour(c)
    if type(c) ~= "table" then return { 1, 1, 1 } end
    return { (tonumber(c[1]) or 255) / 255, (tonumber(c[2]) or 255) / 255, (tonumber(c[3]) or 255) / 255 }
  end
  out.fill, out.signFill = colour(st.fill), colour(st.signFill or st.fill)
  styleArt[value] = out
  return out
end

-- PRECACHE: the windows for these settings (filter.precacheAdd), set up
-- once with mod -Elvie
function gbui.precacheFor(mod)
  local okF, f = pcall(require, "mods.facets.filter")
  if not (okF and type(f.precacheAdd) == "function") or gbui.precacheAdded then return end
  gbui.precacheAdded = true
  f.precacheAdd(function()
    local out = {}
    local a = gbui.art()
    if a and type(a.framesImage) == "userdata" then out[#out + 1] = { img = a.framesImage } end
    for _, key in ipairs({ "gbcFrame", "gbcTextBox" }) do
      local sa = gbui.styleArt(mod, mod.options:get(key))
      if sa then
        if type(sa.frame) == "userdata" then out[#out + 1] = { img = sa.frame } end
        if type(sa.dialogue) == "userdata" then out[#out + 1] = { img = sa.dialogue, also = sa.fill } end
        if type(sa.sign) == "userdata" then out[#out + 1] = { img = sa.sign, also = sa.signFill } end
      end
    end
    return out
  end)
end

-- A window colour of its own at least this bright (0.299 R + 0.587 G +
-- 0.114 B) is pale (PINK WOOD's, PAPER WOOD's light ones, GAME WOOD's
-- light ones, PAPER WOOD's GREY the least of them at 0.84): the game's own grey letters with their light shadow sit on
-- it as on white. Under it, and not dark, it's a strong colour that reads
-- best with black letters -Elvie
gbui.PALE = 0.8

-- Gen 3's 3x3 window frame round a content area (tiles), white inside. -Elvie
-- (own: the frame's inside colour when it has one of its own, PAPER
-- WOOD's; kept as it is on any paper, as its text box is) -Elvie
function gbui.nineSlice(img, tx, ty, tw, th, own)
  local G = love.graphics
  local X, Y, W, H = (tx - 1) * T, (ty - 1) * T, (tw + 2) * T, (th + 2) * T
  -- (the frame's cells too: their inside is the window's white) -Elvie
  gbui.markPaper(X, Y, W, H)
  local white = type(own) ~= "table" or (math.min(own[1], own[2], own[3]) > 0.9
    and math.max(own[1], own[2], own[3]) - math.min(own[1], own[2], own[3]) < 0.04)
  local pp, lp, lit = nil, nil, nil
  if white then
    pp = gbui.own(X, Y, W, H)
    if not pp then lp, lit = gbui.lit(img, X, Y, W, H) end
  else
    local ok, filter = pcall(require, "mods.facets.filter")
    local l = 0.299 * own[1] + 0.587 * own[2] + 0.114 * own[3]
    if ok and l < 0.35 and type(filter.own) == "function" then
      filter.own(X, Y, W, H, { own[1], own[2], own[3] })
    elseif ok and l < gbui.PALE and type(filter.own) == "function" then
      -- a strong colour that reads best with black letters (GAME WOOD's
      -- DARK GOLD): its letters inked black -Elvie
      filter.own(X, Y, W, H, { own[1], own[2], own[3] }, nil, "black")
    elseif ok and type(filter.paperNow) == "function" and filter.paperNow() and type(filter.keepRect) == "function" then
      filter.keepRect(X, Y, W, H)
    end
  end
  local fill = pp or lp or (not white and own) or nil
  if fill then G.setColor(fill[1], fill[2], fill[3], 1) else G.setColor(1, 1, 1, 1) end
  G.rectangle("fill", tx * T, ty * T, tw * T, th * T)
  G.setColor(1, 1, 1, 1)
  local art = lit or gbui.darkArt(img, pp)
  local function cell(i, cx, cy) G.draw(art, quad(art, i), cx * T, cy * T) end
  cell(0, tx - 1, ty - 1)
  for i = 0, tw - 1 do cell(1, tx + i, ty - 1) end
  cell(2, tx + tw, ty - 1)
  for i = 0, th - 1 do
    cell(3, tx - 1, ty + i)
    cell(5, tx + tw, ty + i)
  end
  cell(6, tx - 1, ty + th)
  for i = 0, tw - 1 do cell(7, tx + i, ty + th) end
  cell(8, tx + tw, ty + th)
end

-- FR/LG's dialogue box from its 18-tile atlas (the sign's 19 tiles use
-- the same cells), content (2, 15) 26x4, inside filled with colour 1
-- (pokefirered/src/menu.c, as chrome.lua draws it). -Elvie
-- (L, W: where its inside runs, in tiles, when not the whole width: a
-- battle's message box beside its menu) -Elvie
function gbui.dialogueBox(img, fill, L0, W0)
  local G = love.graphics
  local L, Top, W, H = L0 or 2, 15, W0 or 26, 4
  gbui.markPaper(L * T, Top * T, W * T, H * T)
  local pp, lp, lit = nil, nil, nil
  -- (white, not a pale colour of the box's own: PINK WOOD's pinks and
  -- PAPER WOOD's light colours keep theirs) -Elvie
  if math.min(fill[1], fill[2], fill[3]) > 0.9 and math.max(fill[1], fill[2], fill[3]) - math.min(fill[1], fill[2], fill[3]) < 0.04 then
    pp = gbui.own((L - 2) * T, (Top - 1) * T, (W + 4) * T, (H + 2) * T)
    if not pp then lp, lit = gbui.lit(img, (L - 2) * T, (Top - 1) * T, (W + 4) * T, (H + 2) * T) end
  end
  -- a dark text box of its own (PAPER WOOD's dark ones): its letters inked
  -- on its own colour, whatever PAPER is -Elvie
  if not pp and 0.299 * fill[1] + 0.587 * fill[2] + 0.114 * fill[3] < 0.35 then
    local ok, filter = pcall(require, "mods.facets.filter")
    if ok and type(filter.own) == "function" then
      filter.own((L - 2) * T, (Top - 1) * T, (W + 4) * T, (H + 2) * T, { fill[1], fill[2], fill[3] })
    end
  elseif not pp and not lp and 0.299 * fill[1] + 0.587 * fill[2] + 0.114 * fill[3] < gbui.PALE then
    -- a strong colour that reads best with black letters (GAME WOOD's
    -- DARK GOLD): its letters inked black -Elvie
    local ok, filter = pcall(require, "mods.facets.filter")
    if ok and type(filter.own) == "function" then
      filter.own((L - 2) * T, (Top - 1) * T, (W + 4) * T, (H + 2) * T, { fill[1], fill[2], fill[3] }, nil, "black")
    end
  elseif not pp and not lp then
    -- a pale one of its own on dark paper (PINK WOOD's PEACH): kept whole,
    -- as drawn -Elvie
    local ok, filter = pcall(require, "mods.facets.filter")
    if ok and type(filter.paperNow) == "function" and filter.paperNow() and type(filter.keepRect) == "function" then
      filter.keepRect((L - 2) * T, (Top - 1) * T, (W + 4) * T, (H + 2) * T)
    end
  end
  local inside = pp or lp or fill
  G.setColor(inside[1], inside[2], inside[3], 1)
  G.rectangle("fill", L * T, Top * T, W * T, H * T)
  G.setColor(1, 1, 1, 1)
  local art = lit or gbui.darkArt(img, pp, { fill[1], fill[2], fill[3] })
  local function cell(i, cx, cy, flip)
    if flip then G.draw(art, quad(art, i), cx * T, cy * T + T, 0, 1, -1)
    else G.draw(art, quad(art, i), cx * T, cy * T) end
  end
  for _, edge in ipairs({ { Top - 1, false }, { Top + H, true } }) do
    local y, f = edge[1], edge[2]
    cell(0, L - 2, y, f); cell(1, L - 1, y, f)
    for i = 0, W - 1 do cell(2, L + i, y, f) end
    cell(3, L + W, y, f); cell(4, L + W + 1, y, f)
  end
  local rows = { { 5, 6, 8, 9, false }, { 10, 11, 12, 13, false }, { 10, 11, 12, 13, true }, { 5, 6, 8, 9, true } }
  for r, c in ipairs(rows) do
    local y = Top + r - 1
    cell(c[1], L - 2, y, c[5]); cell(c[2], L - 1, y, c[5])
    cell(c[3], L + W, y, c[5]); cell(c[4], L + W + 1, y, c[5])
  end
end

-- --------------------------------------------------
-- The part
-- --------------------------------------------------

-- The battle text box's windows, as content rectangles in tiles (left,
-- top, width, height), the way the games lay their menu frames: Emerald's
-- and R/S's from the engine, FR/LG's the same split as Emerald's. The
-- message box fills what's left of the row. -Elvie
gbui.FRLG_MENU_FRAMES = {
  menu = { { 16, 15, 13, 4 } },
  moves = { { 1, 15, 18, 4 }, { 21, 15, 8, 4 } },
}

-- Boxes (x tile, width in tiles) across the bottom six rows for a panel. -Elvie
function gbui.panelBoxes(mode, rects)
  if mode ~= "menu" and mode ~= "moves" then return { { 0, 30 } } end
  rects = rects or gbui.FRLG_MENU_FRAMES[mode]
  local out, x = {}, 0
  for _, r in ipairs(rects or {}) do
    local left = (tonumber(r[1]) or 1) - 1
    if left > x then out[#out + 1] = { x, left - x } end
    out[#out + 1] = { left, (tonumber(r[3]) or 0) + 2 }
    x = left + (tonumber(r[3]) or 0) + 2
  end
  if x < 30 then out[#out + 1] = { x, 30 - x } end
  return out
end

local recentPanel = -1
-- the battle's message box is a set's light one: its white text drawn
-- dark -Elvie
local battleBoxLight = false
-- your side's bar ends at the bracket, not an end cap: set by the box, used
-- by the bar drawn right after it -Elvie
local nextBarCapless = false

-- Battle text that's white on Gen 3's dark box: drawn dark on Crystal's
-- white one. Only just after a panel was drawn, and only in the box. -Elvie
function gbui.lightText(colors)
  local fg = type(colors) == "table" and colors.fg
  if type(fg) ~= "table" then return false end
  return ((fg[1] or 0) + (fg[2] or 0) + (fg[3] or 0)) / 3 > 0.7
end

-- The SCREEN page's sample: a square of a mock screen, bottom right of
-- the window, drawn with the game's own functions (so with whatever's
-- picked): your healthbox and the message box for BATTLE UI, the text
-- box for WINDOWS, the foe's spot for BATTLE BG. -Elvie
gbui.SAMPLE = { x = 160, y = 82, size = 64,
  crops = { gbcHud = { 176, 80 }, gbcFrame = { 0, 0 }, gbcTextBox = { 0, 96 }, gbcBattleBg = { 152, 8 },
  bgColour = { 152, 8 } } }
local sampleCanvas, sampleQuads = nil, {}
local sampleWarned = false
local function logSample(e)
  if sampleWarned then return end
  sampleWarned = true
  print("[facets] SCREEN sample healthbox: " .. tostring(e))
end
function gbui.drawSample(who, bg)
  if who == "bgColour" then bg = "colours" end
  local crop = gbui.SAMPLE.crops[who]
  if not (crop and love and love.graphics and love.graphics.newCanvas) then return end
  local G = love.graphics
  local okB, BattleChrome = pcall(require, "src.ui.game3.battle_chrome")
  if not (okB and type(BattleChrome) == "table") then return end
  sampleCanvas = sampleCanvas or G.newCanvas(240, 160, { dpiscale = 1 })
  sampleCanvas:setFilter("nearest", "nearest")
  G.push("all")
  G.setCanvas(sampleCanvas)
  G.origin()
  G.clear(0, 0, 0, 0)
  G.setColor(1, 1, 1, 1)
  local okI = pcall(BattleChrome.ensureInstalled)
  if who == "gbcFrame" or who == "gbcTextBox" then
    G.setColor(0.55, 0.75, 0.5, 1)
    G.rectangle("fill", 0, 0, 240, 160)
    G.setColor(1, 1, 1, 1)
    local Chrome = require("src.ui.game3.chrome")
    if who == "gbcFrame" then
      -- a small menu window, its frame round the square's middle -Elvie
      pcall(Chrome.stdFrame, 2, 2, 4, 4)
    else
      pcall(Chrome.dialogueFrame)
    end
  else
    if bg == "white" or bg == "colours" then
      if bg == "colours" and gbui.get then
        local c = require("mods.facets.filter").bgColour(gbui.get)
        G.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
      end
      G.rectangle("fill", 0, 0, 240, 160)
    else
      pcall(BattleChrome.drawTerrain, "grass", 0, 0, 0)
    end
    G.setColor(1, 1, 1, 1)
    if okI and who == "gbcHud" then
      local okH, Healthbox = pcall(require, "src.core.game3.battle.healthbox")
      local okA, Anim = pcall(require, "src.core.game3.battle.anim")
      if okH and type(Healthbox) == "table" and okA and type(Anim) == "table" then
        -- out of battle the stage hides the boxes: shown for the sample -Elvie
        local stage = Anim.stage
        Anim.stage = function() return { healthbox = { player = { visible = true } } } end
        local okD, e = pcall(Healthbox.draw, "player", { species = 283, mon = { species = 283, level = 12, hp = 23, maxHp = 37, nickname = "MUDKIP", exp = 0 } })
        Anim.stage = stage
        if not okD then logSample(e) end
      end
      G.setColor(1, 1, 1, 1)
      pcall(BattleChrome.drawPanel, "none")
    end
  end
  G.pop()
  local s = gbui.SAMPLE
  local key = crop[1] .. "," .. crop[2]
  sampleQuads[key] = sampleQuads[key] or G.newQuad(crop[1], crop[2], s.size, s.size, 240, 160)
  G.setColor(0.25, 0.25, 0.25, 1)
  G.rectangle("fill", s.x - 1, s.y - 1, s.size + 2, s.size + 2)
  G.setColor(0, 0, 0, 1)
  G.rectangle("fill", s.x, s.y, s.size, s.size)
  G.setColor(1, 1, 1, 1)
  G.draw(sampleCanvas, sampleQuads[key], s.x, s.y)
end

-- BORDERS on the GBA games: Red to Crystal's, and WORLD, the map you were
-- on, as SURROUND's WORLD shows it round your menus -Elvie
function gbui.BORDERS()
  local out = {}
  for _, c in ipairs(require("mods.facets.classic_scenes").BORDERS) do out[#out + 1] = c end
  table.insert(out, 4, { "WORLD", "world" })
  return out
end

function gbui.init(mod, rows, menu)
  local get = getter(mod)
  gbui.get = get
  gbui.loadSets(mod)
  gbui.loadBgSets(mod)
  gbui.loadUiSets(mod)
  -- under the filter's SCREEN heading; its own when the filter is off -Elvie
  local heading = false
  for _, r in ipairs(rows) do if r.key == "sectionScreen" then heading = true end end
  if not heading then
    rows[#rows + 1] = { key = "sectionScreen", type = "choice", label = "SCREEN", choices = { { "", "_" } }, default = "_" }
  end
  rows[#rows + 1] = { key = "gbcFrame", type = "choice", label = "  WINDOWS", choices = gbui.WINDOWS, default = "game" }
  rows[#rows + 1] = { key = "gbcTextBox", type = "choice", label = "  TEXT BOX", choices = gbui.TEXTBOX, default = "match" }
  rows[#rows + 1] = { key = "gbcHud", type = "choice", label = "  BATTLE UI", choices = gbui.HUD, default = "game" }
  rows[#rows + 1] = { key = "gbcBattleBg", type = "choice", label = "  BATTLE BG", choices = gbui.BG, default = "game" }
  rows[#rows + 1] = { key = "bgColour", type = "choice", label = "  BG COLOR",
    choices = require("mods.facets.filter").BG_COLOURS, default = "paper" }
  rows[#rows + 1] = { key = "sceneTime", type = "choice", label = "  SCENE TIME",
    choices = { { "ON", "on" }, { "SYSTEM", "system" }, { "OFF", "off" } }, default = "on" }
  rows[#rows + 1] = { key = "battleTextBox", type = "choice", label = "  TEXT BOX",
    choices = { { "GAME", "game" }, { "WINDOWS", "windows" } }, default = "game" }
  -- the window's borders round a battle scene: blurred, the scene
  -- itself, or the engine's own (classic_scenes) -Elvie
  do
    local Sc = require("mods.facets.classic_scenes")
    rows[#rows + 1] = { key = "sceneBorders", type = "choice", label = "  BORDERS", choices = gbui.BORDERS(), default = "blur" }
    Sc.borders = function() return mod.options:get("sceneBorders") or "blur" end
  end

  local function imported()
    local gb = package.loaded["mods.facets.gb"] or require("mods.facets.gb")
    return gb.imported(gbui.GAMES)
  end

  if menu then
    menu.register({
      rows = function()
        local frame, hud, bg, text = gbui.settings(get)
        return {
          { key = "gbcFrame", label = "WINDOWS", who = "gbcFrame", choices = gbui.WINDOWS, value = frame },
          { key = "gbcTextBox", label = "TEXT BOX", who = "gbcTextBox", choices = gbui.TEXTBOX, value = text },
          { key = "gbcHud", label = "BATTLE UI", who = "gbcHud", choices = gbui.HUD, value = hud },
          { key = "clearHud", label = "CLEAR HUD", who = "clearHud", choices = require("mods.facets.clearhud3").CHOICES,
            value = (get("clearHud") == "on" and "hud") or tostring(get("clearHud") or "off") },
          { key = "gbcBattleBg", label = "BATTLE BG", who = "gbcBattleBg", choices = gbui.BG, value = bg },
          { key = "bgColour", label = "BG COLOR", who = "bgColour", choices = require("mods.facets.filter").BG_COLOURS,
            value = tostring(get("bgColour") or "paper") },
          { key = "sceneBorders", label = "BORDERS", who = "sceneBorders", choices = gbui.BORDERS(),
            value = tostring(get("sceneBorders") or "blur") },
          { key = "sceneTime", label = "SCENE TIME", who = "sceneTime", choices = { { "ON", "on" }, { "SYSTEM", "system" }, { "OFF", "off" } },
            value = tostring(get("sceneTime") or "on") },
          { key = "battleTextBox", label = "TEXT BOX", who = "battleTextBox", choices = { { "GAME", "game" }, { "WINDOWS", "windows" } },
            value = tostring(get("battleTextBox") or "game") },
        }
      end,
      preview = function(who)
        local frame, hud, bg, textChoice = gbui.settings(get)
        local text = gbui.textValue(get)
        local lines = {}
        local st, set = gbui.style(frame)
        local tst, tset = gbui.style(text)
        if (who == "gbcFrame" and frame ~= "game" and not st) or (who == "gbcHud" and hud == "gbc")
            or (who == "gbcTextBox" and text:match("^[1-8]$")) then
          if not imported() then lines[#lines + 1] = { text = "No Gen 2 game imported.", red = true } end
        end
        local function credit(of)
          local c = type(of.credit) == "table" and of.credit[1] or of.credit
          if type(c) == "string" then lines[#lines + 1] = { text = c } end
        end
        if who == "gbcFrame" then
          -- this screen's own window shows the frame -Elvie
          if st and st.frame then
            lines[#lines + 1] = { text = "Its frame, like this one." }
            credit(set)
          else
            lines[#lines + 1] = { text = (frame == "game" or st) and "The game's own windows." or "Crystal's frame, like this one." }
          end
        elseif who == "gbcTextBox" then
          if textChoice == "match" then
            lines[#lines + 1] = { text = text == "game" and "Matches WINDOWS: the game's own." or "Matches WINDOWS." }
          elseif tst then
            lines[#lines + 1] = { text = "Its text box and signs." }
          else
            lines[#lines + 1] = { text = text == "game" and "The game's own text box." or "Crystal's frame round it." }
          end
          if tst then credit(tset) end
        elseif who == "gbcHud" then
          local uset = gbui.UI_SETS[hud]
          if uset then
            lines[#lines + 1] = { text = "New battle boxes." }
            local credit = type(uset.credit) == "table" and uset.credit[1] or uset.credit
            if type(credit) == "string" then lines[#lines + 1] = { text = credit } end
          else
            lines[#lines + 1] = { text = hud == "gbc" and "Gen 2's HP and EXP bars." or "The game's own battle boxes." }
          end
        elseif who == "gbcBattleBg" then
          local bset = gbui.BG_SETS[bg]
          if bset and bset.gba then
            local g = require("mods.facets.gba_bg")
            if g.game(bg) then
              lines[#lines + 1] = { text = "Its battle backgrounds," }
              lines[#lines + 1] = { text = "from your own game." }
            else
              lines[#lines + 1] = { text = "Needs " .. g.BY_KEY[bg].name .. " imported.", red = true }
            end
          elseif bset then
            lines[#lines + 1] = { text = "New scenes for every battle." }
            local credit = type(bset.credit) == "table" and bset.credit[1] or bset.credit
            if type(credit) == "string" then lines[#lines + 1] = { text = credit } end
          else
            lines[#lines + 1] = { text = bg == "white" and "Plain white, like Gen 2."
              or bg == "colours" and "Plain colour: BG COLOR's." or "The game's own scenery." }
          end
        elseif who == "sceneBorders" then
          local b = tostring(get("sceneBorders") or "blur")
          lines[#lines + 1] = { text = b == "blur" and "The battle's scene, blurred,"
            or b == "fill" and "One big scene behind it all,"
            or b == "off" and "The game's own borders."
            or "SURROUND's fill round it." }
          if b == "blur" or b == "fill" then lines[#lines + 1] = { text = "round the battle." } end
        elseif who == "battleTextBox" then
          lines[#lines + 1] = { text = tostring(get("battleTextBox") or "game") == "windows" and "The battle's boxes in WINDOWS' frame."
            or "The game's own battle box." }
        elseif who == "sceneTime" then
          local st = tostring(get("sceneTime") or "on")
          lines[#lines + 1] = { text = st == "off" and "Scenes as drawn, all day."
            or st == "system" and "The hour on your own clock." or "Outdoor scenes in the hour's light." }
        elseif who == "bgColour" then
          lines[#lines + 1] = { text = tostring(get("bgColour") or "paper") == "paper"
            and "PAPER's colour, for COLORS." or "This colour, for COLORS." }
        else
          return nil
        end
        -- the sample square sits right of these lines -Elvie
        return { lines = lines, width = gbui.SAMPLE.x - 20 }
      end,
      draw = function(clock, family, spots, who)
        if spots or not (who == "gbcFrame" or who == "gbcTextBox" or who == "gbcHud" or who == "gbcBattleBg") then return end
        pcall(gbui.drawSample, who, select(3, gbui.settings(get)))
      end,
    })
  end

  return function()
    pcall(gbui.precacheFor, mod)
    local okC, Chrome = pcall(require, "src.ui.game3.chrome")
    local okB, BattleChrome = pcall(require, "src.ui.game3.battle_chrome")
    local okG, BattleBg = pcall(require, "src.core.game3.battle.bg")
    local okH, Healthbox = pcall(require, "src.core.game3.battle.healthbox")
    local okF, FrlgFont = pcall(require, "src.ui.game3.frlg_font")
    -- WINDOWS: Crystal's frame n for menus, or a set style's frame -Elvie
    local function frameOn()
      local frame = gbui.settings(get)
      if not frame:match("^[1-8]$") or not gbui.art() then return nil end
      return frame
    end
    local function styleOn()
      local frame = gbui.settings(get)
      if frame:match("^[1-8]$") or frame == "game" then return nil end
      return gbui.styleArt(mod, frame)
    end
    -- TEXT BOX: Crystal's frame n, or a set style's text box -Elvie
    local function textFrameOn()
      local text = gbui.textValue(get)
      if not text:match("^[1-8]$") or not gbui.art() then return nil end
      return text
    end
    local function textStyleOn()
      local text = gbui.textValue(get)
      if text:match("^[1-8]$") or text == "game" then return nil end
      return gbui.styleArt(mod, text)
    end
    local function hudOn()
      local _, hud = gbui.settings(get)
      local a = hud == "gbc" and gbui.art()
      return a and a.hp and true or false
    end
    local function now() return love and love.timer and love.timer.getTime() or 0 end

    -- Battle box sets: the set's pictures in place of the game's while
    -- each piece draws, and the healthboxes' text and fills in its
    -- colours. Installed first, so GBC's wrappers stay outside. -Elvie
    local okX, Extract = pcall(require, "src.import.gba.extract_island1")
    local function uiOn()
      local _, hud = gbui.settings(get)
      if not gbui.UI_SETS[hud] or not (okB and type(BattleChrome) == "table") then return nil end
      local rs = type(BattleChrome.layout) == "function" and BattleChrome.layout() == "rs"
      local m = type(BattleChrome._manifest) == "table" and BattleChrome._manifest or {}
      local base = okX and type(Extract) == "table" and Extract.CACHE_ROOT
      local root = tostring(base) .. "/pokemon/battle/"
      local function read(name)
        local cache = BattleChrome._cache
        if not (base and cache and cache.read) then return nil end
        local okR, d = pcall(cache.read, cache, root .. name .. ".rgba")
        return okR and type(d) == "string" and d or nil
      end
      return gbui.uiArt(mod, hud, read, { healthbox = m.healthboxPal, healthbar = m.healthbarPal, textbox = m.textboxPal },
        { id = tostring(BattleChrome._installKey), w = m.textboxW, h = m.textboxH, rs = rs })
    end
    local function restore(a, saved, ok, ...)
      for field, img in pairs(a.images) do
        -- one the engine loaded meanwhile stays -Elvie
        if BattleChrome[field] == img then BattleChrome[field] = saved[field] end
      end
      if not ok then error((...), 0) end
      return ...
    end
    local function withSet(fn)
      return function(...)
        local a = uiOn()
        if not (a and next(a.images)) then return fn(...) end
        local saved = {}
        for field, img in pairs(a.images) do saved[field] = BattleChrome[field]; BattleChrome[field] = img end
        return restore(a, saved, pcall(fn, ...))
      end
    end
    if okB and type(BattleChrome) == "table" and type(BattleChrome.drawElementTile) == "function" then
      -- R/S lays box tiles under the name over its own box; a set's box
      -- already has its own there -Elvie
      local origTile = BattleChrome.drawElementTile
      BattleChrome.drawElementTile = function(ti, ...)
        if ti == 43 and type(BattleChrome.layout) == "function" and BattleChrome.layout() == "rs" and uiOn() then return end
        return origTile(ti, ...)
      end
    end
    if okB and type(BattleChrome) == "table" then
      for _, name in ipairs({ "drawPanel", "drawEnemyBox", "drawPlayerBox", "drawHpBar", "drawExpBar",
                              "drawElementTile", "drawPartyBall", "drawPartyBar" }) do
        if type(BattleChrome[name]) == "function" then BattleChrome[name] = withSet(BattleChrome[name]) end
      end
      -- these two load their pictures the first time they draw: drawn here -Elvie
      local origSafari, origDoubles = BattleChrome.drawSafariBox, BattleChrome.drawDoublesBox
      if type(origSafari) == "function" then
        BattleChrome.drawSafariBox = function(x, y, ...)
          local a = uiOn()
          local img = a and a.images._safariBox
          if not img then return origSafari(x, y, ...) end
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(img, x, y)
          return true
        end
      end
      if type(origDoubles) == "function" then
        BattleChrome.drawDoublesBox = function(isPlayer, x, y, ...)
          local a = uiOn()
          local img = a and a.images[isPlayer and "_doublesPlayerBox" or "_doublesOpponentBox"]
          if not img then return origDoubles(isPlayer, x, y, ...) end
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(img, x, y)
        end
      end
    end
    local textMap, inText = nil, 0
    if okH and type(Healthbox) == "table" and type(Healthbox.draw) == "function" then
      local origDraw = withSet(Healthbox.draw)
      Healthbox.draw = function(...)
        local a = uiOn()
        if not (a and next(a.text)) then return origDraw(...) end
        local G = love.graphics
        local setColor = G.setColor
        G.setColor = function(r, g, b, al)
          if type(r) == "table" then r, g, b, al = r[1], r[2], r[3], r[4] end
          if inText == 0 and not (r == 1 and g == 1 and b == 1) then
            local c = gbui.mapColour(a.text, r, g, b)
            if c then return setColor(c[1], c[2], c[3], al) end
          end
          return setColor(r, g, b, al)
        end
        -- R/S paints each text row in the box's colour, at its own box's
        -- rows; a set's box has its own shape, so those fills are left out -Elvie
        local rect = G.rectangle
        if type(BattleChrome) == "table" and type(BattleChrome.layout) == "function" and BattleChrome.layout() == "rs" then
          G.rectangle = function(mode, ...)
            if mode == "fill" then return end
            return rect(mode, ...)
          end
        end
        textMap = a.text
        local ok, x, y = pcall(origDraw, ...)
        textMap = nil
        G.rectangle = rect
        G.setColor = setColor
        if not ok then error(x, 0) end
        return x, y
      end
    end
    if okF and type(FrlgFont) == "table" and type(FrlgFont.draw) == "function" then
      local origText = FrlgFont.draw
      FrlgFont.draw = function(text, x, y, opts, ...)
        if not (textMap and type(opts) == "table" and type(opts.colors) == "table") then return origText(text, x, y, opts, ...) end
        local colors = {}
        for k, v in pairs(opts.colors) do
          local c = type(v) == "table" and gbui.mapColour(textMap, v[1], v[2], v[3])
          colors[k] = c and { c[1], c[2], c[3], v[4] or 1 } or v
        end
        local o = {}
        for k, v in pairs(opts) do o[k] = v end
        o.colors = colors
        inText = inText + 1
        local ok, a, b = pcall(origText, text, x, y, o, ...)
        inText = inText - 1
        if not ok then error(a, 0) end
        return a, b
      end
    end

    -- Windows: the game's frames, by their content area -Elvie
    if okC and type(Chrome) == "table" then
      local function wrapContent(name)
        local orig = Chrome[name]
        if type(orig) ~= "function" then return end
        Chrome[name] = function(...)
          local frame, st = frameOn(), styleOn()
          if frame or (st and st.frame) then
            local a, b, c, d = ...
            if name == "userFrame" then a, b, c, d = select(2, ...) end
            local tx, ty, tw, th = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
            if tx and ty and tw and th then
              if frame and gbui.box(frame, (tx - 1) * T, (ty - 1) * T, tw + 2, th + 2) then return end
              if st and st.frame then gbui.nineSlice(st.frame, tx, ty, tw, th, st.fill); return end
            end
          end
          return orig(...)
        end
      end
      wrapContent("stdFrame")
      wrapContent("fixedStdFrame")
      wrapContent("userFrame")
      -- the dialogue and sign boxes: the whole width, rows 14 to 19 -Elvie
      for _, name in ipairs({ "dialogueFrame", "signFrame" }) do
        local orig = Chrome[name]
        if type(orig) == "function" then
          Chrome[name] = function(...)
            local frame = textFrameOn()
            if frame and gbui.box(frame, 0, 14 * T, 30, 6) then return end
            local st = textStyleOn()
            if st then
              local img = name == "signFrame" and st.sign or st.dialogue
              local fill = name == "signFrame" and st.sign and st.signFill or st.fill
              if img then gbui.dialogueBox(img, fill); return end
            end
            return orig(...)
          end
        end
      end
    end

    if okB and type(BattleChrome) == "table" then
      -- the battle text box, in Crystal's frames -Elvie
      local origPanel = BattleChrome.drawPanel
      if type(origPanel) == "function" then
        BattleChrome.drawPanel = function(mode, ...)
          local frame = textFrameOn()
          if frame then
            local rects
            if type(BattleChrome.menuFrameRects) == "function" and type(BattleChrome.layout) == "function" then
              local okR, got = pcall(BattleChrome.menuFrameRects, mode, BattleChrome.layout())
              rects = okR and got or nil
            end
            for _, b in ipairs(gbui.panelBoxes(mode, rects)) do gbui.box(frame, b[1] * T, 112, b[2], 6) end
            recentPanel = now()
            return
          end
          -- TEXT BOX (battle): WINDOWS: the battle's boxes (its message and the
          -- menu beside it) in WINDOWS' frame, as the game's other menus
          -- are, unless BATTLE UI brings a box of its own (TEX BOX, XY,
          -- PLAIN) -Elvie
          local frameSt = get("battleTextBox") == "windows" and styleOn() or nil
          local crystal = get("battleTextBox") == "windows" and not frameSt and gbui.settings(get):match("^[1-8]$") and gbui.art() and gbui.settings(get) or nil
          local _, hud = gbui.settings(get)
          local uiSet = gbui.UI_SETS[hud]
          if ((frameSt and frameSt.frame) or crystal) and hud ~= "plain" and not (uiSet and uiSet.images and uiSet.images.textbox) then
            local rects
            if type(BattleChrome.menuFrameRects) == "function" and type(BattleChrome.layout) == "function" then
              local okR, got = pcall(BattleChrome.menuFrameRects, mode, BattleChrome.layout())
              rects = okR and got or nil
            end
            for _, b in ipairs(gbui.panelBoxes(mode, rects)) do
              if crystal then gbui.box(crystal, b[1] * T, 112, b[2], 6)
              else gbui.nineSlice(frameSt.frame, b[1] + 1, 15, b[2] - 2, 4, frameSt.fill) end
            end
            recentPanel = now()
            local f = frameSt and frameSt.fill or { 1, 1, 1 }
            battleBoxLight = math.min(f[1], f[2], f[3]) > 0.5
            return
          end
          battleBoxLight = false
          return origPanel(mode, ...)
        end
      end
      -- HP boxes: no box; the bracket under the bar instead -Elvie
      local origEnemy, origPlayer = BattleChrome.drawEnemyBox, BattleChrome.drawPlayerBox
      if type(origEnemy) == "function" then
        BattleChrome.drawEnemyBox = function(x, y, ...)
          if hudOn() then
            -- the bar's top-left: 24 across, 16 down from the box's -Elvie
            gbui.enemyBracket(x + 24, y + 16)
            nextBarCapless = false
            return
          end
          return origEnemy(x, y, ...)
        end
      end
      if type(origPlayer) == "function" then
        BattleChrome.drawPlayerBox = function(x, y, ...)
          if hudOn() then
            gbui.playerBracket(x + 32, y + 16)
            nextBarCapless = true
            return
          end
          return origPlayer(x, y, ...)
        end
      end
      local origDoubles = BattleChrome.drawDoublesBox
      if type(origDoubles) == "function" then
        BattleChrome.drawDoublesBox = function(...)
          if hudOn() then nextBarCapless = false; return end
          return origDoubles(...)
        end
      end
      local origHp = BattleChrome.drawHpBar
      if type(origHp) == "function" then
        BattleChrome.drawHpBar = function(x, y, hp, maxHp, statusBorder, ...)
          local capless = nextBarCapless
          nextBarCapless = false
          if hudOn() and gbui.hpBar(x, y, hp, maxHp, capless) then return end
          return origHp(x, y, hp, maxHp, statusBorder, ...)
        end
      end
      local origExp = BattleChrome.drawExpBar
      if type(origExp) == "function" then
        BattleChrome.drawExpBar = function(x, y, ratio, ...)
          if hudOn() and gbui.expBar(x, y, ratio) then return end
          return origExp(x, y, ratio, ...)
        end
      end
    end

    -- The game rubs out a box's placeholder ink with cream (FR/LG and
    -- Emerald), and R/S paints each text row in the box's colour and lays
    -- box tiles under the name; with no box those would show, so a
    -- healthbox's filled rectangles and box tiles are skipped while it
    -- draws. Its bars, icons and text still draw. -Elvie
    local inHealthbox = false
    if okB and type(BattleChrome) == "table" and type(BattleChrome.drawElementTile) == "function" then
      local origTile = BattleChrome.drawElementTile
      BattleChrome.drawElementTile = function(...)
        if inHealthbox then return end
        return origTile(...)
      end
    end
    if okH and type(Healthbox) == "table" and type(Healthbox.draw) == "function" then
      local origDraw = Healthbox.draw
      Healthbox.draw = function(...)
        if not hudOn() then return origDraw(...) end
        local G = love.graphics
        local rect = G.rectangle
        G.rectangle = function(mode, ...)
          if mode == "fill" then return end
          return rect(mode, ...)
        end
        inHealthbox = true
        local ok, a, b = pcall(origDraw, ...)
        inHealthbox = false
        G.rectangle = rect
        if not ok then error(a, 0) end
        return a, b
      end
    end

    local Edges
    -- With a scene in the battle, the window's borders round the GBA
    -- screen carry it on (the same code as the Game Boy games: the same
    -- picture at the same size, lined up, mirrored past its edges, drawn
    -- into the borders only) instead of the engine's flat surround -Elvie
    local okE, EdgesMod = pcall(require, "mods.facets.classic_scenes")
    Edges = okE and type(EdgesMod) == "table" and type(EdgesMod.edges) == "function" and EdgesMod or nil
    if Edges then
      pcall(function()
        mod.hooks:wrap("render.letterbox", function(nextFn, info, ...)
          local results = { nextFn(info, ...) }
          local ok, drew = pcall(Edges.edges, info)
          if not ok then mod.log:warn("scenery round the screen: %s", tostring(drew)) end
          -- SURROUND has the window the rest of the time -Elvie
          if not (ok and drew) then
            local okS, err = pcall(function() require("mods.facets.classic_surround").draw(info) end)
            if not okS then mod.log:warn("SURROUND: %s", tostring(err)) end
          end
          return unpack(results)
        end)
      end)
    end

    -- The hour, for the scenes' light: Ruby, Sapphire and Emerald's own
    -- clock, and the real one in FireRed and LeafGreen, which have none.
    -- Read once a second -Elvie
    local okR, Rtc = pcall(require, "src.core.game3.rtc")
    local okS, Rse = pcall(require, "src.core.game3.rse.init")
    local okV, GameVersion = pcall(require, "src.core.GameVersion")
    local CLOCKED = { ruby = true, sapphire = true, emerald = true }
    local hourNow, hourAt = nil, -1
    local function hour()
      -- (SYSTEM: your own clock, whatever the game's says) -Elvie
      if get("sceneTime") == "system" then return tonumber(os.date("%H")) end
      local now = os.time()
      if now == hourAt then return hourNow end
      hourAt, hourNow = now, tonumber(os.date("%H"))
      local version = okV and type(GameVersion) == "table" and type(GameVersion.get) == "function" and GameVersion.get()
      if CLOCKED[version] and okR and okS and type(Rtc) == "table" and type(Rse) == "table"
          and type(Rse.session) == "function" then
        local ok, t = pcall(function() return Rtc.calcLocalTime(Rse.session()) end)
        if ok and type(t) == "table" and tonumber(t.hours) then hourNow = tonumber(t.hours) end
      end
      return hourNow
    end
    local function lightFor(bg, key)
      if not Edges or get("sceneTime") == "off" then return nil end
      return Edges.lightFor(gbui.sceneName(bg, key), hour())
    end

    -- BATTLE BG: GAME with BORDERS: BLUR or FILL: the game's own scene
    -- (its field, 240x112, off the terrain picture), copied once a terrain,
    -- for the borders to carry on as they do a set's -Elvie
    local gameScenes = setmetatable({}, { __mode = "k" })
    local function gameScene(key)
      if not (okB and type(BattleChrome.terrain) == "function") then return nil end
      local entry = BattleChrome.terrain(key) or BattleChrome.terrain("building") or BattleChrome.terrain("grass")
      local img = entry and (entry.image or entry.bgImage)
      if type(img) ~= "userdata" then return nil end
      local got = gameScenes[img]
      if got ~= nil then return got or nil end
      gameScenes[img] = false
      local ok, c = pcall(function()
        local G = love.graphics
        local c = G.newCanvas(240, 112, { dpiscale = 1 })
        local iw, ih = img:getDimensions()
        G.push("all")
        G.setCanvas(c)
        G.origin()
        G.setScissor()
        G.setShader()
        G.clear(0, 0, 0, 1)
        G.setColor(1, 1, 1, 1)
        G.draw(img, G.newQuad(0, 0, 240, 112, iw, ih), 0, 0)
        G.pop()
        c:setFilter("nearest", "nearest")
        return c
      end)
      gameScenes[img] = ok and c or false
      return gameScenes[img] or nil
    end

    -- A battle background set: the scene for the game's own background,
    -- in place of its terrain and platforms (and behind evolutions) -Elvie
    if okB and type(BattleChrome) == "table" then
      for _, name in ipairs({ "drawTerrain", "drawCleanBg" }) do
        local orig = BattleChrome[name]
        if type(orig) == "function" then
          gbui.ownTerrain = gbui.ownTerrain or {}
          gbui.ownTerrain[name] = function(key, ...)
            local _, _, bg = gbui.settings(get)
            -- WoobleView's Battle Fit draws the battle's background
            -- itself, zoomed to the screen, or its 3D Battle Scene: a
            -- background set steps aside for it (wooble.lua) -Elvie
            if bg ~= "white" and bg ~= "colours" and require("mods.facets.wooble").fitting(mod) then
              if name == "drawTerrain" then gbui.lastTerrain = key end
              return orig(key, ...)
            end
            if name == "drawTerrain" then gbui.lastTerrain = key end -- for achievements.lua -Elvie
            -- the woods, as forests -Elvie
            if gbui.BG_SETS[bg] then key = gbui.forestKey(key, gbui.mapSec()) end
            local img = gbui.BG_SETS[bg] and gbui.scene(mod, bg, key)
            if img then
              -- under the text box: black, as the game has it; with the
              -- text box hidden (Kanto Gear's battle screen), the scene's
              -- ground stretched down into it instead -Elvie
              local hiddenPanel = false
              pcall(function()
                local Ui = package.loaded["src.core.game3.battle.ui"]
                hiddenPanel = type(Ui) == "table" and type(Ui.bottomUIVisible) == "function" and Ui.bottomUIVisible() == false
              end)
              -- (and CLEAR HUD: ALL, which takes the text box away too; the
              -- GBA games' own backgrounds, platforms and all, are
              -- mirrored down instead, clearhud3.lua, so the player's
              -- platform stays under them) -Elvie
              if get("clearHud") == "all" and not gbui.BG_SETS[bg].gba then hiddenPanel = true end
              love.graphics.setColor(0, 0, 0, 1)
              love.graphics.rectangle("fill", 0, 112, 240, 48)
              gbui.groundBelow = hiddenPanel
              local light = lightFor(bg, key)
              -- a scene with a sky map: its sky painted for the hour, the
              -- ground in the hour's light, drawn as it is -Elvie
              local sd = light and gbui.sceneData[img]
              if sd and type(Edges.skyImage) == "function" then
                local skied = Edges.skyImage(mod, sd.dir, sd.file, sd.data, Edges.daytime(hour()))
                if skied then img, light = skied, nil end
              end
              if light then Edges.setLight(light) else love.graphics.setColor(1, 1, 1, 1) end
              -- a GBA background has its surroundings round it, for the
              -- borders: the scene is the 240x112 at pad, pad -Elvie
              local pad = gbui.BG_SETS[bg].gba and require("mods.facets.gba_bg").PAD or 0
              local fillMode = Edges and Edges.borders and Edges.borders() == "fill"
              -- BORDERS: FILL, the screen's part of one big scene -Elvie
              if Edges and Edges.fillDraw(img, 0, 0, 240) then
                -- drawn -Elvie
              elseif hiddenPanel and not fillMode then
                -- the text box hidden: the scene's top as it is, its
                -- ground (the bottom 40 rows) stretched down to the
                -- screen's foot -Elvie
                local iw, ih = img:getDimensions()
                gbui._topQuad = gbui._topQuad or love.graphics.newQuad(0, 0, 240, 72, iw, ih)
                gbui._topQuad:setViewport(pad, pad, 240, 72, iw, ih)
                gbui._lowQuad = gbui._lowQuad or love.graphics.newQuad(0, 0, 240, 40, iw, ih)
                gbui._lowQuad:setViewport(pad, pad + 72, 240, 40, iw, ih)
                love.graphics.draw(img, gbui._topQuad, 0, 0)
                love.graphics.draw(img, gbui._lowQuad, 0, 72, 0, 1, 88 / 40)
              elseif pad > 0 then
                local iw, ih = img:getDimensions()
                gbui._gbaQuad = gbui._gbaQuad or love.graphics.newQuad(pad, pad, 240, 112, iw, ih)
                gbui._gbaQuad:setViewport(pad, pad, 240, 112, iw, ih)
                love.graphics.draw(img, gbui._gbaQuad, 0, 0)
              else
                love.graphics.draw(img, 0, 0)
              end
              love.graphics.setColor(1, 1, 1, 1)
              -- noted, so the window's borders carry it on -Elvie
              if Edges then pcall(Edges._note, img, pad, pad, 0, 0, light) end
              return true
            end
            local mode = Edges and type(Edges.borders) == "function" and Edges.borders() or nil
            if bg == "game" and (mode == "blur" or mode == "fill") then
              local s = gameScene(key)
              if s then
                -- FILL: the screen's part of it, zoomed as the borders
                -- are, once the battle's sliding in is done -Elvie
                local a1, a2 = ...
                local still = name == "drawCleanBg" or ((tonumber(a1) or 0) == 0 and (tonumber(a2) or 0) == 0)
                if mode == "fill" and still then
                  love.graphics.setColor(0, 0, 0, 1)
                  love.graphics.rectangle("fill", 0, 112, 240, 48)
                  love.graphics.setColor(1, 1, 1, 1)
                  if Edges.fillDraw(s, 0, 0, 240) then
                    pcall(Edges._note, s, 0, 0, 0, 0, nil)
                    return true
                  end
                end
                local results = { orig(key, ...) }
                pcall(Edges._note, s, 0, 0, 0, 0, nil)
                return unpack(results)
              end
            end
            return orig(key, ...)
          end
          BattleChrome[name] = gbui.ownTerrain[name]
        end
      end
    end

    -- Battle background: plain white -Elvie
    if okG and type(BattleBg) == "table" and type(BattleBg.draw) == "function" then
      local origBg = BattleBg.draw
      BattleBg.draw = function(...)
        local _, _, bg = gbui.settings(get)
        if bg == "white" or bg == "colours" then
          -- WHITE, or COLORS in BG COLOR's -Elvie
          local c = bg == "colours" and require("mods.facets.filter").bgColour(get) or { 255, 255, 255 }
          love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
          love.graphics.rectangle("fill", 0, 0, 240, 160)
          love.graphics.setColor(1, 1, 1, 1)
          return true
        end
        -- a scene set: drawn by Facets straight, whoever else wraps the
        -- terrain after it (Kanto Gear paints the game's own ground over
        -- the hidden text box's place, over the scene) -Elvie
        local own = gbui.ownTerrain and gbui.ownTerrain.drawTerrain
        if gbui.BG_SETS[bg] and own and okB and BattleChrome.drawTerrain ~= own
            and not require("mods.facets.wooble").fitting(mod)
            and type(BattleBg.sheetKey) == "function" then
          local id, a1, a2, a3 = ...
          local okK, key = pcall(BattleBg.sheetKey, id)
          if okK and key and gbui.scene(mod, bg, gbui.forestKey(key, gbui.mapSec())) then
            return own(key, a1, a2, a3)
          end
        end
        return origBg(...)
      end
    end

    -- White battle text on the dark box, dark on Crystal's white -Elvie
    if okF and type(FrlgFont) == "table" and type(FrlgFont.draw) == "function" then
      local origText = FrlgFont.draw
      FrlgFont.draw = function(text, x, y, opts, ...)
        if type(opts) == "table" and (tonumber(y) or 0) >= 112 and now() - recentPanel < 0.25
            and gbui.lightText(opts.colors) and (textFrameOn() or battleBoxLight) then
          local o = {}
          for k, v in pairs(opts) do o[k] = v end
          o.colors = FrlgFont.COLOR and FrlgFont.COLOR.NORMAL or opts.colors
          return origText(text, x, y, o, ...)
        end
        return origText(text, x, y, opts, ...)
      end
    end

    mod.events:on("mod.options_changed", function(change)
      if type(change) == "table" and change.mod == mod.id and (change.key == "gbcFrame" or change.key == "gbcTextBox" or change.key == "gbcHud") then
        if art == false then gbui.reset() end -- an import since: try again -Elvie
      end
    end)
  end
end

return gbui
