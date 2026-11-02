-- BATTLE UI on the Game Boy games, in wide battles only
-- With the engine's wide battle layout there's room for a Gen 3 battle
-- box, so a set's boxes are drawn in place of the game's own: the enemy's
-- top left, yours bottom right. Everything else in the battle stays the
-- game's. The normal 160x144 screen keeps its own boxes, since a Gen 3
-- box is wider than the space it has there. -Elvie
--
-- The boxes are laid out as FireRed lays out its own (pokefirered
-- battle_interface.c): the name and level along the top, the HP bar under
-- them, your HP and EXP below that. Text is in FireRed's small font, read
-- from the player's own FireRed, LeafGreen or Emerald, so a GBA game has
-- to be imported for this to show; without one the game's boxes stay. -Elvie
-- --------------------------------------------------

local hud = {}

local GAME = "game"
local DIR = "assets/battleui"
local gba = require("mods.facets.classic_gba")
local classic = require("mods.facets.classic")

-- FireRed's healthbox geometry, from the box's top left -Elvie
hud.GEO = {
  enemy = { name = { 8, 3 }, level = 64, bar = { 24, 16 } },
  player = { name = { 16, 3 }, level = 72, bar = { 32, 16 }, hpText = { 60, 80, 21 },
    hpWindow = { 56, 21, 40, 11 }, exp = { 32, 32 } },
}
-- the "Lv" baked into the sheets, painted over before the real one -Elvie
hud.INK = {
  enemy = { { 56, 10, 8, 6 } },
  player = { { 64, 10, 8, 6 } },
}
-- Element tiles (pret B_INTERFACE_GFX_*) -Elvie
hud.HP_TEXT_TILE, hud.HP_BAR_BASE = 1, { green = 3, yellow = 47, red = 56 }
hud.EXP_BAR_TILE = 12
hud.LV_GLYPH = 0x105

-- FireRed's healthbox colours: text, cream, text shadow (15-bit) -Elvie
hud.FR = { text = 8456, cream = 28671, shadow = 23387 }
-- the gender marks keep FireRed's own blue and red -Elvie
hud.MALE = { text = { 65 / 255, 205 / 255, 1, 1 }, shadow = { 0, 98 / 255, 148 / 255, 1 } }
hud.FEMALE = { text = { 1, 156 / 255, 148 / 255, 1 }, shadow = { 156 / 255, 65 / 255, 57 / 255, 1 } }

-- A 15-bit GBA colour as 0-1 RGB -Elvie
function hud.rgb(c)
  c = tonumber(c) or 0
  return { (c % 32) / 31, (math.floor(c / 32) % 32) / 31, (math.floor(c / 1024) % 32) / 31, 1 }
end

-- A set's text, cream and shadow, through its healthbox palette when it
-- recolours FireRed's -Elvie
function hud.colours(meta)
  local pal = type(meta) == "table" and type(meta.palettes) == "table" and meta.palettes.healthbox
  local out = {}
  for key, fr in pairs(hud.FR) do
    local c = fr
    if type(pal) == "table" and type(pal.from) == "table" and type(pal.to) == "table" then
      for i, v in ipairs(pal.from) do
        if v == fr and pal.to[i] then c = pal.to[i] break end
      end
    end
    out[key] = hud.rgb(c)
  end
  return out
end

-- Text as FireRed's glyph ids (pokefirered charmap): letters, digits and
-- the few marks names use; anything else is left out -Elvie
local MARKS = { [" "] = 0x00, ["!"] = 0xAB, ["?"] = 0xAC, ["."] = 0xAD, ["-"] = 0xAE, [","] = 0xB8,
  ["/"] = 0xBA, [":"] = 0xF0, ["'"] = 0xB4, ["\xe2\x99\x82"] = 0xB5, ["\xe2\x99\x80"] = 0xB6,
  ["\xc3\xa9"] = 0x1B }
function hud.glyphs(text)
  local out = {}
  for ch in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    local b = ch:byte()
    local id
    if #ch == 1 and b >= 65 and b <= 90 then id = 0xBB + b - 65
    elseif #ch == 1 and b >= 97 and b <= 122 then id = 0xD5 + b - 97
    elseif #ch == 1 and b >= 48 and b <= 57 then id = 0xA1 + b - 48
    else id = MARKS[ch] end
    if id then out[#out + 1] = id end
  end
  return out
end

-- HP bar fill: pixels of 48 and colour, as FireRed works them out
-- (battle_interface.c:2155, 2168) -Elvie
function hud.hpBar(hp, maxHp)
  hp, maxHp = tonumber(hp) or 0, tonumber(maxHp) or 0
  if maxHp <= 0 or hp <= 0 then return 0, "red" end
  if hp > maxHp then hp = maxHp end
  local px = math.floor(hp * 48 / maxHp)
  if px == 0 then px = 1 end
  if hp >= maxHp then return px, "green" end
  if px > 24 then return px, "green" end
  if px > 9 then return px, "yellow" end
  return px, "red"
end

-- Sets with everything a box needs: both boxes and the HP bar tiles -Elvie
local function findSets(mod)
  local sets = {}
  local decode = require("mods.facets.npcs").decodeJson
  for _, key in ipairs(mod.assets:list(DIR) or {}) do
    local dir = DIR .. "/" .. key
    if key:match("^[%w_%-]+$") and mod.assets:info(dir .. "/meta.json")
        and mod.assets:info(dir .. "/healthbox_enemy.png") and mod.assets:info(dir .. "/healthbox_player.png")
        and mod.assets:info(dir .. "/elements.png") then
      local ok, meta = pcall(decode, mod:read(dir .. "/meta.json"))
      meta = ok and type(meta) == "table" and meta or {}
      sets[#sets + 1] = { key = key, meta = meta,
        label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper() }
    end
  end
  table.sort(sets, function(a, b) return a.label < b.label end)
  return sets
end

function hud.init(mod, rows)
  local sets = findSets(mod)
  if #sets == 0 then return nil end
  local byKey = {}
  local choices = { { "GAME", GAME } }
  for _, set in ipairs(sets) do
    byKey[set.key] = set
    choices[#choices + 1] = { set.label, set.key }
  end
  rows[#rows + 1] = { key = "classicBattleUi", type = "choice", label = "BATTLE UI", choices = choices, default = GAME }

  return function()
    local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
    if not (okB and type(BattleState) == "table" and type(BattleState.drawEnemyHud) == "function"
        and type(BattleState.drawPlayerHud) == "function") then
      mod.log:warn("the battle HUD wasn't found; BATTLE UI is off")
      return
    end
    local okH, BattleHud = pcall(require, "src.ui.gen2.BattleHud")
    local EXP_PX = okH and type(BattleHud) == "table" and tonumber(BattleHud.EXP_LENGTH_PX) or 64
    local okS, Strings = pcall(require, "src.core.Strings")

    -- FireRed's small font, from whichever GBA game is there -Elvie
    local font
    local function getFont()
      if font ~= nil then return font or nil end
      font = false
      for _, game in ipairs({ "firered", "leafgreen", "emerald" }) do
        local fg = gba.image(gba.read(game, "chrome/fonts/latin_small_fg.rgba"), 256, 512)
        local sh = gba.image(gba.read(game, "chrome/fonts/latin_small_shadow.rgba"), 256, 512)
        local text = gba.read(game, "chrome/fonts/latin_small_widths.lua")
        if fg and sh and text then
          local widths = {}
          for id, w in text:gmatch("%[(%d+)%]%s*=%s*(%d+)") do widths[tonumber(id)] = tonumber(w) end
          local fgI, shI = love.graphics.newImage(fg), love.graphics.newImage(sh)
          fgI:setFilter("nearest", "nearest")
          shI:setFilter("nearest", "nearest")
          font = { fg = fgI, sh = shI, widths = widths, quads = {} }
          break
        end
      end
      return font or nil
    end
    local function quad(id)
      local q = font.quads[id]
      if not q then
        local w = font.widths[id] or font.widths[0] or 5
        q = love.graphics.newQuad((id % 16) * 16, math.floor(id / 16) * 16, math.max(1, math.min(16, w)), 16, 256, 512)
        font.quads[id] = q
      end
      return q
    end
    local function width(ids)
      local w = 0
      for _, id in ipairs(ids) do w = w + (font.widths[id] or font.widths[0] or 5) end
      return w
    end
    local function text(ids, x, y, colours)
      local G = love.graphics
      local cx = x
      for _, id in ipairs(ids) do
        G.setColor(colours.shadow)
        G.draw(font.sh, quad(id), cx, y)
        G.setColor(colours.text)
        G.draw(font.fg, quad(id), cx, y)
        cx = cx + (font.widths[id] or font.widths[0] or 5)
      end
      G.setColor(1, 1, 1, 1)
      return cx
    end

    -- A set's pictures and colours, loaded once -Elvie
    local loaded = {}
    local function art(key)
      local hit = loaded[key]
      if hit ~= nil then return hit or nil end
      loaded[key] = false
      local set = byKey[key]
      local function img(name)
        local rel = DIR .. "/" .. key .. "/" .. name
        if not mod.assets:info(rel) then return nil end
        local ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
        if not ok then return nil end
        local image = love.graphics.newImage(data)
        image:setFilter("nearest", "nearest")
        return image, data
      end
      local enemy, enemyData = img("healthbox_enemy.png")
      local player, playerData = img("healthbox_player.png")
      local elements = img("elements.png")
      if not (enemy and player and elements) then
        mod.log:warn("battleui/%s is missing a picture; BATTLE UI keeps the game's", key)
        return nil
      end
      local ex0, ey0, ex1, ey1 = classic.bounds(enemyData)
      local px0, py0, px1, py1 = classic.bounds(playerData)
      local a = { enemy = enemy, player = player, elements = elements,
        exp = img("elements_exp.png") or elements, colours = hud.colours(set.meta),
        enemyBox = { ex0 or 0, ey0 or 0, ex1 or 127, ey1 or 31 },
        playerBox = { px0 or 0, py0 or 0, px1 or 127, py1 or 63 }, quads = {} }
      loaded[key] = a
      return a
    end
    local function tile(a, sheet, id, x, y)
      local key = tostring(sheet) .. id
      local q = a.quads[key]
      if not q then
        q = love.graphics.newQuad((id % 40) * 8, math.floor(id / 40) * 8, 8, 8, 320, 24)
        a.quads[key] = q
      end
      love.graphics.draw(sheet, q, x, y)
    end
    local function hpBar(a, x, y, hp, maxHp)
      local px, colour = hud.hpBar(hp, maxHp)
      local base = hud.HP_BAR_BASE[colour]
      love.graphics.setColor(1, 1, 1, 1)
      tile(a, a.elements, hud.HP_TEXT_TILE, x, y)
      tile(a, a.elements, hud.HP_TEXT_TILE + 1, x + 8, y)
      for i = 0, 5 do
        tile(a, a.elements, base + math.max(0, math.min(8, px - i * 8)), x + 16 + i * 8, y)
      end
    end
    local function expBar(a, x, y, ratio)
      local px = math.floor(math.max(0, math.min(1, ratio)) * 64)
      if px < 1 and ratio > 0 then px = 1 end
      for i = 0, 7 do
        tile(a, a.exp, hud.EXP_BAR_TILE + math.max(0, math.min(8, px - i * 8)), x + i * 8, y)
      end
    end
    local function fill(colour, rects, x, y)
      love.graphics.setColor(colour)
      for _, r in ipairs(rects) do love.graphics.rectangle("fill", x + r[1], y + r[2], r[3], r[4]) end
      love.graphics.setColor(1, 1, 1, 1)
    end
    local function str(s)
      if type(s) == "string" then return s end
      if okS and s ~= nil then
        local ok, got = pcall(Strings, s)
        if ok and type(got) == "string" then return got end
      end
      return tostring(s or "")
    end

    -- the name, gender and level (or status) along the top -Elvie
    local function topLine(self, a, mon, side, x, y)
      local geo = hud.GEO[side]
      local c = a.colours
      fill(c.cream, hud.INK[side], x, y)
      local nx = text(hud.glyphs(self:name(mon)), x + geo.name[1], y + geo.name[2], c)
      local g = self:genderSymbol(mon)
      if g then text(hud.glyphs(g), nx, y + geo.name[2], g == "\xe2\x99\x82" and hud.MALE or hud.FEMALE) end
      local tag = self:statusTag(mon, side)
      local lx = x + geo.level
      if tag then
        text(hud.glyphs(str(tag)), lx, y + geo.name[2], c)
      else
        local digits = tostring(math.max(1, math.min(999, math.floor(tonumber(mon.level) or 1))))
        local dx = lx + 5 * (3 - #digits)
        local after = text({ hud.LV_GLYPH }, dx, y + geo.name[2], c)
        text(hud.glyphs(digits), after, y + geo.name[2], c)
      end
    end

    local function chosen(self)
      local key = mod.options:get("classicBattleUi")
      if key == GAME or not byKey[key] then return nil end
      if not (type(self.isWideBattleLayout) == "function" and self:isWideBattleLayout()) then return nil end
      if not getFont() then return nil end
      return art(key)
    end

    local ownEnemy = BattleState.drawEnemyHud
    BattleState.drawEnemyHud = function(self, ...)
      local a = chosen(self)
      local mon = self:activeMon("enemy")
      if not a or not mon or not self:statusHUDVisible() or not self.showEnemyHud
          or self:hudCleared("enemy") or (self.ballRows and self.ballRows.enemy) then
        return ownEnemy(self, ...)
      end
      local b = a.enemyBox
      local x, y = 2 - b[1], 2 - b[2]
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(a.enemy, x, y)
      topLine(self, a, mon, "enemy", x, y)
      local maxHp = mon.maxHp or (mon.stats and mon.stats.hp) or 1
      hpBar(a, x + hud.GEO.enemy.bar[1], y + hud.GEO.enemy.bar[2], self:hudHp(mon, "enemy"), maxHp)
    end

    local ownPlayer = BattleState.drawPlayerHud
    BattleState.drawPlayerHud = function(self, ...)
      local a = chosen(self)
      local mon = self:activeMon("player")
      if not a or not mon or not self:statusHUDVisible() or not self.showPlayerHud
          or self:hudCleared("player") or (self.ballRows and self.ballRows.player) then
        return ownPlayer(self, ...)
      end
      -- bottom right of the game's own HUD space, which ends at 160, 96 -Elvie
      local b = a.playerBox
      local x, y = 158 - b[3], 95 - b[4]
      local geo = hud.GEO.player
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(a.player, x, y)
      topLine(self, a, mon, "player", x, y)
      local maxHp = mon.maxHp or (mon.stats and mon.stats.hp) or 1
      local hp = self:hudHp(mon, "player")
      hpBar(a, x + geo.bar[1], y + geo.bar[2], hp, maxHp)
      fill(a.colours.cream, { geo.hpWindow }, x, y)
      text(hud.glyphs(("%3d/"):format(math.floor(hp or 0))), x + geo.hpText[1], y + geo.hpText[3], a.colours)
      text(hud.glyphs(("%3d"):format(math.floor(maxHp))), x + geo.hpText[2], y + geo.hpText[3], a.colours)
      expBar(a, x + geo.exp[1], y + geo.exp[2], (self.shownExp or 0) / EXP_PX)
    end
  end
end

return hud
