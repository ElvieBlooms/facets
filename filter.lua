-- The GB filter
-- Game Boy looks for the whole game. FILTER picks one: GRAY, GREEN, RUBY,
-- SAPPHIRE or EMERALD (shades of one colour: 4 like a Game Boy, or 8 or 16 with
-- SHADES), or GBC (colour, cut down to a few levels a channel).
-- FILTER ON chooses where: the whole SCREEN, or just the MAP (menus and
-- battles keep their colours). DOTS draws a dot-matrix grid between the
-- game's pixels, with or without a filter. -Elvie
--
-- The whole-screen work is an engine render pipeline with a `present` pass,
-- which is handed the finished frame and gives back a filtered copy. The
-- map-only filter goes through the render.compose hook, which sees the map
-- before the menus are drawn over it. Neither needs anything from the
-- games. The engine keeps the pipeline's on/off with the game's own
-- options. -Elvie
-- --------------------------------------------------

local filter = {}

filter.ID = "facets_filter"
filter.LOOKS = { { "OFF", "off" }, { "GRAY", "gray" }, { "GREEN", "green" }, { "RUBY", "ruby" },
  { "SAPPHIRE", "sapphire" }, { "EMERALD", "emerald" }, { "GBC", "gbc" } }
filter.WHERE = { { "SCREEN", "screen" }, { "MAP", "map" } }
filter.DOTS = { { "OFF", "off" }, { "ON", "on" } }
filter.STEPS = { { "4", "4" }, { "8", "8" }, { "16", "16" } }

-- Lightest first. GRAY is the Game Boy Pocket's greys, softened a little;
-- GREEN the usual emulator greens, further apart than the original
-- screen's so the four shades stay easy to tell apart. -Elvie
filter.SHADES = {
  gray = { { 238, 238, 238 }, { 168, 168, 168 }, { 96, 96, 96 }, { 32, 32, 32 } },
  green = { { 224, 248, 208 }, { 136, 192, 112 }, { 52, 104, 86 }, { 8, 24, 32 } },
  -- RUBY, SAPPHIRE and EMERALD, for the games themselves: a pale tint at the light
  -- end down to the gem's deep colour, built like GREEN -Elvie
  ruby = { { 252, 228, 228 }, { 228, 120, 132 }, { 152, 28, 56 }, { 40, 6, 18 } },
  sapphire = { { 226, 236, 252 }, { 112, 152, 228 }, { 32, 60, 156 }, { 8, 14, 44 } },
  -- bluer and deeper than GREEN's Game Boy greens -Elvie
  emerald = { { 222, 248, 236 }, { 92, 200, 150 }, { 14, 118, 80 }, { 4, 32, 24 } },
}

-- Brightness cut-offs between the four shades. Gen 3 is bright: half of a
-- typical scene is brighter than 0.85, so the cuts sit high, or nearly
-- everything would land in the lightest shade. -Elvie
-- With 8 or 16 SHADES the same cuts make a smooth ramp (each band a
-- quarter of it), which is split into that many steps; the steps' colours
-- are blended between the four palette shades. At 4 it's exactly the four
-- shades above. -Elvie
filter.CUTS = { 0.85, 0.64, 0.37 }

-- GBC: each channel cut to this many levels, after this much extra
-- saturation. Four levels reads most like a Game Boy Color game; more
-- starts shifting colours (pale floors go peach). -Elvie
filter.GBC_LEVELS = 4
filter.GBC_SATURATION = 1.15

-- How much the dot grid darkens the line between two pixels. -Elvie
filter.DOT_SHADE = 0.82

-- mode: 0 none, 1 four shades, 2 GBC. dots needs a game pixel at least 3
-- screen pixels wide, or the grid would cover the picture. -Elvie
filter.SHADER = [[
extern float mode;
extern vec3 s0; extern vec3 s1; extern vec3 s2; extern vec3 s3;
extern vec3 cut;
extern float steps;
extern float levels;
extern float sat;
extern float dots;
extern float dotShade;
extern float cell;
extern vec2 origin;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec4 c = Texel(tex, tc);
  vec3 o = c.rgb;
  if (mode > 0.5 && mode < 1.5) {
    float l = dot(o, vec3(0.299, 0.587, 0.114));
    // brightness to a 0..1 ramp, a quarter per band between the cuts
    float t;
    if (l < cut.z) t = 0.25 * l / cut.z;
    else if (l < cut.y) t = 0.25 + 0.25 * (l - cut.z) / (cut.y - cut.z);
    else if (l < cut.x) t = 0.5 + 0.25 * (l - cut.y) / (cut.x - cut.y);
    else t = 0.75 + 0.25 * (l - cut.x) / (1.0 - cut.x);
    float k = min(steps - 1.0, floor(t * steps));
    float v = k / (steps - 1.0) * 3.0; // 0 darkest .. 3 lightest
    if (v <= 1.0) o = mix(s3, s2, v);
    else if (v <= 2.0) o = mix(s2, s1, v - 1.0);
    else o = mix(s1, s0, v - 2.0);
  } else if (mode > 1.5) {
    float l = dot(o, vec3(0.299, 0.587, 0.114));
    o = clamp(mix(vec3(l), o, sat), 0.0, 1.0);
    o = floor(o * (levels - 1.0) + 0.5) / (levels - 1.0);
  }
  if (dots > 0.5 && cell >= 3.0) {
    vec2 p = mod(sc - origin, cell);
    if (p.x < 1.0 || p.y < 1.0) o = o * dotShade;
  }
  return vec4(o, c.a) * color;
}
]]

local function valueOf(list, value, default)
  for _, c in ipairs(list) do
    if c[2] == value then return value end
  end
  return default
end

-- What the options ask for: look, where, dots, shades. -Elvie
function filter.settings(get)
  return valueOf(filter.LOOKS, get("filter"), "off"), valueOf(filter.WHERE, get("filterOn"), "screen"),
    valueOf(filter.DOTS, get("dots"), "off"), valueOf(filter.STEPS, get("shades"), "4")
end

-- Whether the whole-screen pass has anything to do. -Elvie
function filter.screenOn(look, where, dots)
  return (look ~= "off" and where == "screen") or dots == "on"
end

-- Adds the SCREEN rows, registers the pipeline and the map hook. menu
-- (menu.lua), if given, gets FILTER, WHERE and DOTS for the FACETS
-- screen. -Elvie
function filter.init(mod, rows, menu)
  local content = mod.content and mod.content.render_pipelines
  if not (type(content) == "table" and type(content.register) == "function") then
    mod.log:info("no render pipelines in this engine; FILTER is off")
    return nil
  end
  local okP, Pipelines = pcall(require, "src.render.Pipelines")
  if not okP or type(Pipelines) ~= "table" then Pipelines = nil end
  local function get(key) return mod.options:get(key) end

  local shader -- compiled when first used; false if it couldn't be
  local canvases = {}
  -- the game's pixel grid on screen, from the last render.compose -Elvie
  local grid = { origin = { 0, 0 }, cell = 0 }

  local function getShader()
    if shader ~= nil then return shader or nil end
    if not (love and love.graphics and love.graphics.newShader) then return nil end
    local ok, made = pcall(love.graphics.newShader, filter.SHADER)
    shader = ok and made or false
    if not ok then mod.log:warn("the GB filter's shader couldn't be made: %s", tostring(made)) end
    return shader or nil
  end

  -- Draws src through the shader into a canvas the same size. -Elvie
  local function run(src, slot, look, dots, steps)
    local sh = getShader()
    if not sh then return nil end
    local w, h = src:getDimensions()
    local cv = canvases[slot]
    if not cv or cv:getWidth() ~= w or cv:getHeight() ~= h then
      cv = love.graphics.newCanvas(w, h)
      canvases[slot] = cv
    end
    local pal = filter.SHADES[look] or filter.SHADES.gray
    for i = 1, 4 do
      local c = pal[i]
      sh:send("s" .. (i - 1), { c[1] / 255, c[2] / 255, c[3] / 255 })
    end
    sh:send("mode", filter.SHADES[look] and 1 or look == "gbc" and 2 or 0)
    sh:send("cut", filter.CUTS)
    sh:send("steps", tonumber(steps) or 4)
    sh:send("levels", filter.GBC_LEVELS)
    sh:send("sat", filter.GBC_SATURATION)
    sh:send("dots", dots and 1 or 0)
    sh:send("dotShade", filter.DOT_SHADE)
    sh:send("cell", grid.cell)
    sh:send("origin", grid.origin)
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(sh)
    love.graphics.draw(src, 0, 0)
    love.graphics.pop()
    return cv
  end
  filter.run = run

  local def = {
    label = "GB FILTER",
    levels = { "OFF", "ON" },
    -- after any other pipeline, so it shades their result too -Elvie
    priority = -100,
    -- (canvas, ctx) -> canvas: the finished frame in, the filtered copy
    -- out; the frame itself when there's nothing to do -Elvie
    present = function(input, ctx)
      local look, where, dots, steps = filter.settings(get)
      if not filter.screenOn(look, where, dots) then return input end
      if grid.cell <= 0 and type(ctx) == "table" then
        grid.cell = (tonumber(ctx.scale) or 0) * (tonumber(ctx.dpiX) or 1)
      end
      return run(input, "screen", where == "screen" and look or "off", dots == "on", steps) or input
    end,
    invalidate = function() canvases = {} end,
  }
  local okR, err = pcall(content.register, content, filter.ID, def)
  if not okR then
    mod.log:warn("FILTER couldn't be registered: %s", tostring(err))
    return nil
  end
  filter.def = def

  -- MAP: the map is shaded in place before the menus go over it, then the
  -- frame carries on as usual. render.compose is also where the pixel grid
  -- is read for DOTS. -Elvie
  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("render.compose", function(nextFn, renderer, ctx)
      if type(ctx) == "table" then
        local dpi = tonumber(ctx.dpiX) or 1
        grid.cell = (tonumber(ctx.scale) or 0) * dpi
        grid.origin = { (tonumber(ctx.ox) or 0) * dpi, (tonumber(ctx.oy) or 0) * dpi }
        local look, where, _, steps = filter.settings(get)
        local world = ctx.worldOverride or ctx.worldCanvas
        if look ~= "off" and where == "map" and ctx.worldActive and world and world.getDimensions then
          local out = run(world, "map", look, false, steps)
          if out then
            love.graphics.push("all")
            love.graphics.setCanvas(world)
            love.graphics.setBlendMode("replace", "premultiplied")
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(out, 0, 0)
            love.graphics.pop()
          end
        end
      end
      return nextFn()
    end)
  end

  rows[#rows + 1] = { key = "sectionScreen", type = "choice", label = "SCREEN",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "filter", type = "choice", label = "  FILTER", choices = filter.LOOKS, default = "off" }
  rows[#rows + 1] = { key = "filterOn", type = "choice", label = "  FILTER ON", choices = filter.WHERE, default = "screen" }
  rows[#rows + 1] = { key = "dots", type = "choice", label = "  DOTS", choices = filter.DOTS, default = "off" }
  rows[#rows + 1] = { key = "shades", type = "choice", label = "  SHADES", choices = filter.STEPS, default = "4" }

  if menu then
    menu.register({
      rows = function()
        local look, where, dots, steps = filter.settings(get)
        local out = {
          { key = "filter", label = "FILTER", who = "filter", choices = filter.LOOKS, value = look },
        }
        -- SHADES only means something for the shade palettes -Elvie
        if filter.SHADES[look] then
          out[#out + 1] = { key = "shades", label = "SHADES", who = "shades", choices = filter.STEPS, value = steps }
        end
        out[#out + 1] = { key = "filterOn", label = "WHERE", who = "where", choices = filter.WHERE, value = where }
        out[#out + 1] = { key = "dots", label = "DOTS", who = "dots", choices = filter.DOTS, value = dots }
        return out
      end,
      preview = function(who)
        local look, where, dots = filter.settings(get)
        if who == "filter" then
          if look == "gray" then return { lines = { { text = "Four Game Boy greys." } } } end
          if look == "green" then return { lines = { { text = "Four Game Boy greens." } } } end
          if look == "ruby" then return { lines = { { text = "Shades of ruby." } } } end
          if look == "sapphire" then return { lines = { { text = "Shades of sapphire." } } } end
          if look == "emerald" then return { lines = { { text = "Shades of emerald." } } } end
          if look == "gbc" then return { lines = { { text = "Game Boy Color colours." } } } end
          return { lines = { { text = "The game's own colours." } } }
        elseif who == "where" then
          if where == "map" then return { lines = { { text = "The map; menus and battles" }, { text = "keep their colours." } } } end
          return { lines = { { text = "The whole screen." } } }
        elseif who == "shades" then
          return { lines = { { text = ("%s shades, from dark to light."):format(select(4, filter.settings(get))) } } }
        elseif who == "dots" then
          if dots == "on" then return { lines = { { text = "A dot-matrix screen." } } } end
          return { lines = { { text = "No grid." } } }
        end
        return nil
      end,
    })
  end

  return function()
    -- The engine restores pipeline levels from the game's options when a
    -- game loads, so the level is set again then, and written back to
    -- those options so the next load restores it too. -Elvie
    local function apply()
      if not (Pipelines and type(Pipelines.setLevel) == "function") then return end
      Pipelines.setLevel(filter.ID, filter.screenOn(filter.settings(get)) and 1 or 0)
      local ok, game = pcall(function() return mod.game end)
      if ok and type(game) == "table" and type(game.options) == "table" and type(Pipelines.syncOptions) == "function" then
        pcall(Pipelines.syncOptions, game.options)
      end
    end
    apply()
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id
            and (change.key == "filter" or change.key == "filterOn" or change.key == "dots" or change.key == "shades") then
          apply()
        end
      end)
      mod.events:on("game.ready", apply)
      mod.events:on("save.loaded", apply)
    end
  end
end

return filter
