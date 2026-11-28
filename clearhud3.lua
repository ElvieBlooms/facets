-- CLEAR HUD on the GBA games (FireRed, LeafGreen, Emerald)
-- The battle's HP boxes without their boxes: the name, level, HP bar, HP
-- numbers and EXP bar standing over the battle on their own, each letter
-- and line with a thin white edge so it reads over the scene, as Gold,
-- Silver and Crystal's CLEAR HUD does (classic_scenes.lua). It works with
-- the game's own boxes and with a BATTLE UI set's alike. -Elvie
--
-- Each box is drawn aside without its box picture, then put down with its
-- pale paper (the cream behind the letters, a set's white) taken out but
-- for that edge. -Elvie
-- --------------------------------------------------

local clear = {}

-- HUD: the HP boxes. ALL: the battle's text boxes too, the message and
-- the menus' words left over the scene on their own -Elvie
clear.CHOICES = { { "OFF", "off" }, { "HUD", "hud" }, { "ALL", "all" } }

-- what a setting clears: hud, text (an early test build's ON is HUD) -Elvie
function clear.parts(v)
  if v == "all" then return true, true end
  if v == "hud" or v == "on" then return true, false end
  return false, false
end

-- The edge round words left on their own: a see-through pixel next to a
-- letter takes a dark edge round light letters (the battle's white
-- words), a white one round dark -Elvie
clear.EDGE_SHADER = [[
  extern vec2 size;
  vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 at) {
    vec4 c = Texel(tex, uv);
    if (c.a > 0.01) return c * colour;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        vec4 n = Texel(tex, uv + vec2(float(dx), float(dy)) / size);
        if (n.a > 0.5) {
          float lum = dot(n.rgb / n.a, vec3(0.3, 0.59, 0.11));
          return (lum > 0.55 ? vec4(0.13, 0.13, 0.16, 1.0) : vec4(1.0)) * colour.a;
        }
      }
    }
    return vec4(0.0);
  }
]]

-- paper: see-through, or nothing; pale and greyish (the cream behind the
-- letters, their pale shadow, a set's white). ink: dark, the letters and
-- lines. Paper next to ink is the white edge -Elvie
clear.SHADER = [[
  extern vec2 size;
  bool paper(vec4 c) {
    if (c.a < 0.01) return true;
    float hi = max(c.r, max(c.g, c.b));
    float lo = min(c.r, min(c.g, c.b));
    return lo > 0.68 && hi - lo < 0.25;
  }
  bool ink(vec4 c) { return c.a > 0.5 && (c.r + c.g + c.b) < 1.5; }
  vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 at) {
    vec4 c = Texel(tex, uv);
    if (!paper(c)) return c * colour;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (ink(Texel(tex, uv + vec2(float(dx), float(dy)) / size))) return vec4(1.0) * colour.a;
      }
    }
    return vec4(0.0);
  }
]]

-- Whether a colour is paper, as the shader has it (for tests) -Elvie
function clear.isPaper(r, g, b, a)
  if (a or 1) < 0.01 then return true end
  local hi, lo = math.max(r, g, b), math.min(r, g, b)
  return lo > 0.68 and hi - lo < 0.25
end

function clear.init(mod, rows, menu)
  rows[#rows + 1] = { key = "clearHud", type = "choice", label = "  CLEAR HUD", choices = clear.CHOICES, default = "off" }
  -- (on the FACETS screen beside BATTLE UI, gbui.lua) -Elvie
  local function hudOn() return (clear.parts(mod.options:get("clearHud"))) end
  local function textOn() return select(2, clear.parts(mod.options:get("clearHud"))) end
  return function()
    local okH, Healthbox = pcall(require, "src.core.game3.battle.healthbox")
    local okB, Chrome = pcall(require, "src.ui.game3.battle_chrome")
    if not (okH and type(Healthbox) == "table" and type(Healthbox.draw) == "function"
        and okB and type(Chrome) == "table") then
      mod.log:warn("Gen 3's healthboxes not found; CLEAR HUD is off")
      return
    end
    local okS, shader = pcall(love.graphics.newShader, clear.SHADER)
    if not okS then
      mod.log:warn("CLEAR HUD: %s", tostring(shader))
      return
    end
    local MX, MY = 120, 80 -- room round the screen -Elvie
    local W, H = 240 + 2 * MX, 160 + 2 * MY
    local aside
    -- the box pictures, left out while a box draws (the safari box draws a
    -- strip of its own: left out too) -Elvie
    local BOXES = { "drawPlayerBox", "drawEnemyBox", "drawSafariBox", "drawDoublesBox" }
    local own = Healthbox.draw
    Healthbox.draw = function(...)
      if not hudOn() then return own(...) end
      local G = love.graphics
      if not aside then
        aside = G.newCanvas(W, H)
        aside:setFilter("nearest", "nearest")
      end
      local kept = {}
      for _, name in ipairs(BOXES) do
        kept[name] = Chrome[name]
        if type(kept[name]) == "function" then Chrome[name] = function() return true end end
      end
      G.push("all")
      G.setCanvas(aside)
      G.origin()
      G.setScissor()
      G.clear(0, 0, 0, 0)
      G.translate(MX, MY)
      -- the box's own fills (the cream it lays over its picture's baked
      -- letters, behind the HP numbers, a row's colour on R/S): no box,
      -- no fills -Elvie
      local rect = G.rectangle
      G.rectangle = function(mode, ...)
        if mode == "fill" then return end
        return rect(mode, ...)
      end
      local results = { pcall(own, ...) }
      G.rectangle = rect
      G.pop()
      for name, fn in pairs(kept) do Chrome[name] = fn end
      if not results[1] then error(results[2], 0) end
      G.push("all")
      shader:send("size", { W, H })
      G.setShader(shader)
      G.setColor(1, 1, 1, 1)
      G.setBlendMode("alpha", "premultiplied")
      G.draw(aside, -MX, -MY)
      G.pop()
      return unpack(results, 2)
    end

    -- ALL: no text box, no menu frames; the words drawn on the bottom of
    -- the screen just after (the message, the menus, the move's PP and
    -- type) each drawn aside and put down with an edge -Elvie
    local okE, edge = pcall(love.graphics.newShader, clear.EDGE_SHADER)
    local okF, FrlgFont = pcall(require, "src.ui.game3.frlg_font")
    if not (okE and okF and type(FrlgFont) == "table") then
      mod.log:warn("CLEAR HUD: ALL's text: %s", tostring(okE and "font not found" or edge))
      return
    end
    local panelAt = -1
    local function now() return love.timer and love.timer.getTime() or 0 end
    for _, name in ipairs({ "drawPanel", "drawMenuFrames" }) do
      local ownPanel = Chrome[name]
      if type(ownPanel) == "function" then
        Chrome[name] = function(...)
          if textOn() then panelAt = now() return end
          return ownPanel(...)
        end
      end
    end
    -- With no text box, the battle's scene carries on to the bottom of
    -- the screen: its last 32 rows above the box, mirrored (the player's
    -- platform rounding off in its reflection), then the 16 above the
    -- player's platform, clear of the foe's higher up -Elvie
    local scene, mirror
    local okG, BattleBg = pcall(require, "src.core.game3.battle.bg")
    local ownTerrain = okG and type(BattleBg) == "table" and BattleBg.draw
    if type(ownTerrain) == "function" then
      BattleBg.draw = function(...)
        if not textOn() then return ownTerrain(...) end
        local G = love.graphics
        if not scene then
          scene = G.newCanvas(240, 160)
          scene:setFilter("nearest", "nearest")
          mirror = { G.newQuad(0, 80, 240, 32, 240, 160), G.newQuad(0, 84, 240, 16, 240, 160) }
        end
        G.push("all")
        G.setCanvas(scene)
        G.origin()
        G.setScissor()
        G.clear(0, 0, 0, 0)
        local results = { pcall(ownTerrain, ...) }
        G.pop()
        if not results[1] then error(results[2], 0) end
        G.push("all")
        G.setColor(1, 1, 1, 1)
        G.setBlendMode("alpha", "premultiplied")
        G.draw(scene, 0, 0)
        G.draw(scene, mirror[1], 0, 144, 0, 1, -1)
        G.draw(scene, mirror[2], 0, 144)
        G.pop()
        return unpack(results, 2)
      end
    end
    local words
    local function edged(own)
      return function(a, x, y, ...)
        if not (textOn() and (tonumber(y) or 0) >= 112 and now() - panelAt < 0.25) then
          return own(a, x, y, ...)
        end
        local G = love.graphics
        if not words then
          words = G.newCanvas(W, H)
          words:setFilter("nearest", "nearest")
        end
        G.push("all")
        G.setCanvas(words)
        G.origin()
        G.setScissor()
        G.clear(0, 0, 0, 0)
        G.translate(MX, MY)
        local results = { pcall(own, a, x, y, ...) }
        G.pop()
        if not results[1] then error(results[2], 0) end
        G.push("all")
        edge:send("size", { W, H })
        G.setShader(edge)
        G.setColor(1, 1, 1, 1)
        G.setBlendMode("alpha", "premultiplied")
        G.draw(words, -MX, -MY)
        G.pop()
        return unpack(results, 2)
      end
    end
    if type(FrlgFont.draw) == "function" then FrlgFont.draw = edged(FrlgFont.draw) end
    if type(FrlgFont.drawGlyph) == "function" then FrlgFont.drawGlyph = edged(FrlgFont.drawGlyph) end
  end
end

return clear
