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

clear.CHOICES = { { "OFF", "off" }, { "ON", "on" } }

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
      if mod.options:get("clearHud") ~= "on" then return own(...) end
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
  end
end

return clear
