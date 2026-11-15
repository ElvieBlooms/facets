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
filter.LOOKS = { { "OFF", "off" }, { "GRAY", "gray" }, { "GREEN", "green" }, { "YELLOW", "yellow" },
  { "GOLD", "gold" }, { "CRYSTAL", "crystal" }, { "RUBY", "ruby" }, { "SAPPHIRE", "sapphire" },
  { "EMERALD", "emerald" }, { "GBC", "gbc" } }
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
  -- YELLOW, GOLD and CRYSTAL, for the Game Boy games. Red, Blue and Silver
  -- would sit too close to RUBY, SAPPHIRE and GRAY. YELLOW is Pikachu's
  -- lemon, GOLD a warmer brown-gold, CRYSTAL ice blue down to indigo -Elvie
  yellow = { { 252, 248, 214 }, { 236, 204, 56 }, { 150, 112, 10 }, { 44, 34, 6 } },
  gold = { { 248, 238, 214 }, { 212, 170, 86 }, { 132, 90, 30 }, { 40, 24, 8 } },
  crystal = { { 232, 248, 252 }, { 132, 206, 226 }, { 70, 100, 170 }, { 22, 20, 62 } },
}

-- What each FILTER choice does, for its info line -Elvie
filter.ABOUT = {
  off = "The game's own colours.", gray = "Four Game Boy greys.", green = "Four Game Boy greens.",
  yellow = "Shades of yellow.", gold = "Shades of gold.", crystal = "Shades of crystal.",
  ruby = "Shades of ruby.", sapphire = "Shades of sapphire.", emerald = "Shades of emerald.",
  gbc = "Game Boy Color colours.",
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

-- PAPER: the white of menus, text boxes and battles in a soft colour, for
-- eyes the bright white tires. Only the white changes, and only where the
-- menus are drawn: the map, the letters and the pictures' other colours
-- stay as they are. With a FILTER on the whole screen it's shaded with the
-- rest. DARK turns menus round: dark paper with white letters, the greys
-- between swapped too. In a battle only its text box goes dark, since the
-- Pokémon's outlines are the same black as the letters -Elvie
filter.PAPERS = { { "WHITE", "off" }, { "CREAM", "cream" }, { "LEMON", "lemon" }, { "PEACH", "peach" },
  { "ROSE", "rose" }, { "LILAC", "lilac" }, { "SKY", "sky" }, { "MINT", "mint" }, { "GREY", "grey" },
  { "DARK", "dark" } }
-- DARK's paper and letters -Elvie
filter.DARK = { paper = { 34, 36, 46 }, ink = { 236, 236, 240 } }
-- where a battle's text box starts, as a share of the screen's height:
-- Red to Crystal's six tile rows of eighteen, the GBA's 48 pixels of 160 -Elvie
filter.BATTLE_BOX = { [1] = 12 / 18, [2] = 12 / 18, [3] = 112 / 160 }
filter.PAPER = {
  cream = { 248, 240, 216 }, lemon = { 248, 244, 204 }, peach = { 250, 228, 210 },
  rose = { 248, 224, 230 }, lilac = { 234, 226, 248 }, sky = { 218, 234, 250 },
  mint = { 222, 246, 228 }, grey = { 214, 214, 214 }, dark = filter.DARK.paper,
}

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
extern float paperOn;
extern vec3 paper;
extern Image ui;
extern vec2 uiOrigin;
extern vec2 uiSize;
extern float paperDark;
extern vec3 ink;
extern float bandTop;
extern vec2 texStep;
// whether a pixel is the white or near-white of a menu's paper
float paperish(vec3 c) {
  float hi = max(c.r, max(c.g, c.b));
  float lo = min(c.r, min(c.g, c.b));
  return smoothstep(0.84, 0.92, lo) * (1.0 - smoothstep(0.08, 0.14, hi - lo));
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec4 c = Texel(tex, tc);
  vec3 o = c.rgb;
  if (paperOn > 0.5) {
    // the menus' own pixels: where the UI layer is drawn, white or nearly
    // (a palette's paper can be a touch off-white), and not a colour
    vec2 p = (sc - uiOrigin) / uiSize;
    if (p.x >= 0.0 && p.y >= bandTop && p.x < 1.0 && p.y < 1.0) {
      float hi = max(o.r, max(o.g, o.b));
      float lo = min(o.r, min(o.g, o.b));
      float grey = 1.0 - smoothstep(0.08, 0.14, hi - lo);
      if (paperDark > 0.5) {
        // the greys turned round: white to the dark paper, black to the
        // letters' white. A darker grey only turns where it's on white
        // paper (some within two game pixels), so letters in a coloured
        // box, Pokémon's outlines and black screens stay as they are
        float l = dot(o, vec3(0.299, 0.587, 0.114));
        float onPaper = paperish(o);
        if (onPaper < 0.5) {
          for (int i = 1; i <= 2; i++) {
            vec2 d = texStep * float(i);
            onPaper = max(onPaper, paperish(Texel(tex, tc + vec2(d.x, 0.0)).rgb));
            onPaper = max(onPaper, paperish(Texel(tex, tc - vec2(d.x, 0.0)).rgb));
            onPaper = max(onPaper, paperish(Texel(tex, tc + vec2(0.0, d.y)).rgb));
            onPaper = max(onPaper, paperish(Texel(tex, tc - vec2(0.0, d.y)).rgb));
            onPaper = max(onPaper, paperish(Texel(tex, tc + d).rgb));
            onPaper = max(onPaper, paperish(Texel(tex, tc - d).rgb));
            onPaper = max(onPaper, paperish(Texel(tex, tc + vec2(d.x, -d.y)).rgb));
            onPaper = max(onPaper, paperish(Texel(tex, tc + vec2(-d.x, d.y)).rgb));
          }
        }
        o = mix(o, mix(ink, paper, l), Texel(ui, p).a * grey * onPaper);
      } else {
        float w = Texel(ui, p).a * smoothstep(0.84, 0.92, lo) * grey;
        o = mix(o, paper * hi, w);
      }
    }
  }
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
    // the first screen pixel of each game pixel, so the lines sit on the
    // game's pixel edges even when a game pixel isn't a whole number of
    // screen pixels wide
    vec2 q = floor((sc - origin) / cell);
    vec2 r = floor((sc - origin - 1.0) / cell);
    if (q.x != r.x || q.y != r.y) o = o * dotShade;
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

-- The game's pixel grid on screen from the engine's frame numbers: cell
-- is screen pixels per game pixel, origin where the picture starts, in
-- screen pixels. The engine's scale is already in screen pixels (only the
-- origin is in LÖVE units, so only it takes the DPI); a battle drawn to
-- fill the screen uses the UI's own scale and origin. -Elvie
function filter.gridFor(ctx)
  if type(ctx) ~= "table" then return nil end
  local dpiX = tonumber(ctx.dpiX) or 1
  local dpiY = tonumber(ctx.dpiY) or dpiX
  local cell, ox, oy = tonumber(ctx.scale) or 0, tonumber(ctx.ox) or 0, tonumber(ctx.oy) or 0
  if ctx.worldActive == false and type(ctx.renderer) == "table" and type(ctx.renderer.frameRects) == "function" then
    local ok, r = pcall(ctx.renderer.frameRects, ctx.renderer)
    if ok and type(r) == "table" and tonumber(r.Up) then
      cell, ox, oy = tonumber(r.Up), tonumber(r.uox) or ox, tonumber(r.uoy) or oy
    end
  end
  return cell, { ox * dpiX, oy * dpiY }
end

-- PRISM's corner for SCREEN: the look's shades as a row of swatches,
-- dark to light (GBC: a few of its colours), on the faceted panel. -Elvie
local GBC_SWATCH = { { 0, 0, 0 }, { 85, 85, 170 }, { 170, 85, 85 }, { 85, 170, 85 }, { 255, 255, 170 } }
function filter.drawSwatch(area, get)
  if type(area) ~= "table" or not (love and love.graphics) then return end
  local look = filter.settings(get)
  local list
  if filter.SHADES[look] then
    list = {}
    for i = 4, 1, -1 do list[#list + 1] = filter.SHADES[look][i] end
  elseif look == "gbc" then
    list = GBC_SWATCH
  else
    return
  end
  local size, gap = 14, 3
  local w = #list * size + (#list - 1) * gap
  local x0 = math.floor((area.x0 + 30 + area.x1 - 6) / 2 - w / 2)
  local y = math.floor((area.y0 + area.y1) / 2 - size / 2)
  for i, c in ipairs(list) do
    local x = x0 + (i - 1) * (size + gap)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x - 1, y - 1, size + 2, size + 2)
    love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
    love.graphics.rectangle("fill", x, y, size, size)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- What the options ask for: look, where, dots, shades, paper. -Elvie
function filter.settings(get)
  return valueOf(filter.LOOKS, get("filter"), "off"), valueOf(filter.WHERE, get("filterOn"), "screen"),
    valueOf(filter.DOTS, get("dots"), "off"), valueOf(filter.STEPS, get("shades"), "4"),
    valueOf(filter.PAPERS, get("paper"), "off")
end

-- Whether the whole-screen pass has anything to do. -Elvie
function filter.screenOn(look, where, dots, _, paper)
  return (look ~= "off" and where == "screen") or dots == "on" or (paper ~= nil and paper ~= "off")
end

-- Where the UI layer sits on screen, in screen pixels, from the engine's
-- frame numbers: origin and size, or nil -Elvie
function filter.uiRectFor(ctx)
  if type(ctx) ~= "table" or type(ctx.renderer) ~= "table" or type(ctx.renderer.frameRects) ~= "function" then return nil end
  local ok, r = pcall(ctx.renderer.frameRects, ctx.renderer)
  if not (ok and type(r) == "table" and tonumber(r.Up) and tonumber(r.uiw) and tonumber(r.uih)) then return nil end
  local dpiX = tonumber(ctx.dpiX) or 1
  local dpiY = tonumber(ctx.dpiY) or dpiX
  return { (tonumber(r.uox) or 0) * dpiX, (tonumber(r.uoy) or 0) * dpiY }, { r.uiw * r.Up, r.uih * r.Up }
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
  -- the game's pixel grid on screen, and the UI layer and where it sits,
  -- from the last render.compose -Elvie
  local grid = { origin = { 0, 0 }, cell = 0 }
  local layer = { canvas = nil, origin = { 0, 0 }, size = { 1, 1 }, band = 0, cell = 1 }
  -- Gold, Silver and Crystal draw the map and the menus into one picture,
  -- so PAPER keeps its own copy of the menus drawn over the map (gen2Mask,
  -- from start below); with no map, the whole picture is menus -Elvie
  local gen2Mask, gen2Drawn, gen2Game, whole = nil, false, nil, nil
  -- Whether the battle itself is what's showing (not a menu over it):
  -- game is the one with the state stack on Red to Crystal -Elvie
  local battleKinds
  local function battleShowing(gen, game)
    if gen == 3 then
      local ok, active = pcall(function() return require("src.core.game3.battle").isActive() end)
      if not (ok and active) then return false end
      local okS, over = pcall(function() return require("src.ui.game3.stack").fullscreen() end)
      return not (okS and over)
    end
    if not battleKinds then
      battleKinds = {}
      for _, name in ipairs({ "src.battle.BattleState", "src.ui.gen2.BattleState" }) do
        local ok, m = pcall(require, name)
        if ok and type(m) == "table" then battleKinds[m] = true end
      end
    end
    local stack = type(game) == "table" and rawget(game, "stack")
    local okT, top = pcall(function() return stack:top() end)
    return okT and type(top) == "table" and battleKinds[getmetatable(top)] == true or false
  end
  local function wholeImage()
    if whole == nil then
      local ok, img = pcall(function()
        local data = love.image.newImageData(1, 1)
        data:setPixel(0, 0, 1, 1, 1, 1)
        return love.graphics.newImage(data)
      end)
      whole = ok and img or false
    end
    return whole or nil
  end
  local function gen2Layer(ctx)
    local drawn = gen2Drawn
    gen2Drawn = false
    local ww, wh = tonumber(ctx.ww) or 0, tonumber(ctx.wh) or 0
    local dpi = tonumber(ctx.dpiX) or 1
    if not ctx.worldActive then
      return wholeImage(), { 0, 0 }, { ww * dpi, wh * dpi }
    end
    -- a battle with BATTLE BG: WORLD has the map round it, not under it:
    -- the game screen is all battle -Elvie
    if battleShowing(2, gen2Game) then
      local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
      if okC and type(Chrome.fitScale) == "function" then
        local sc = Chrome.fitScale(ww, wh)
        local ox, oy = Chrome.fitOrigin(ww, wh, sc)
        return wholeImage(), { ox * dpi, oy * dpi }, { 160 * sc * dpi, 144 * sc * dpi }
      end
    end
    if drawn and gen2Mask then
      local pw, ph = gen2Mask:getPixelDimensions()
      return gen2Mask, { 0, 0 }, { pw, ph }
    end
    return nil
  end

  local function getShader()
    if shader ~= nil then return shader or nil end
    if not (love and love.graphics and love.graphics.newShader) then return nil end
    local ok, made = pcall(love.graphics.newShader, filter.SHADER)
    shader = ok and made or false
    if not ok then mod.log:warn("the GB filter's shader couldn't be made: %s", tostring(made)) end
    return shader or nil
  end

  -- Draws src through the shader into a canvas the same size. -Elvie
  local function run(src, slot, look, dots, steps, paper)
    local sh = getShader()
    if not sh then return nil end
    local w, h = src:getDimensions()
    local cv = canvases[slot]
    local dpi = src.getDPIScale and src:getDPIScale() or 1
    if not cv or cv:getWidth() ~= w or cv:getHeight() ~= h or (cv.getDPIScale and cv:getDPIScale() ~= dpi) then
      -- the source's own DPI, so a high-DPI screen gets the same pixels -Elvie
      cv = love.graphics.newCanvas(w, h, { dpiscale = dpi })
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
    local tint = paper and filter.PAPER[paper]
    if tint and layer.canvas then
      sh:send("paperOn", 1)
      sh:send("paper", { tint[1] / 255, tint[2] / 255, tint[3] / 255 })
      sh:send("ui", layer.canvas)
      sh:send("uiOrigin", layer.origin)
      sh:send("uiSize", layer.size)
      sh:send("paperDark", paper == "dark" and 1 or 0)
      sh:send("ink", { filter.DARK.ink[1] / 255, filter.DARK.ink[2] / 255, filter.DARK.ink[3] / 255 })
      sh:send("bandTop", paper == "dark" and layer.band or 0)
      local pw, ph = src:getPixelDimensions()
      local cell = math.max(1, tonumber(layer.cell) or 1)
      sh:send("texStep", { cell / math.max(1, pw), cell / math.max(1, ph) })
    else
      sh:send("paperOn", 0)
    end
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
      local look, where, dots, steps, paper = filter.settings(get)
      if not filter.screenOn(look, where, dots, steps, paper) then return input end
      if grid.cell <= 0 and type(ctx) == "table" then
        grid.cell = tonumber(ctx.scale) or 0
      end
      return run(input, "screen", where == "screen" and look or "off", dots == "on", steps, paper) or input
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
        grid.cell, grid.origin = filter.gridFor(ctx)
        local canvas, origin, size
        if ctx.generation == 2 then
          gen2Game = renderer
          canvas, origin, size = gen2Layer(ctx)
        else
          origin, size = filter.uiRectFor(ctx)
          canvas = origin and ctx.uiCanvas or nil
        end
        layer.canvas = canvas
        if canvas then layer.origin, layer.size = origin, size end
        layer.band = 0
        -- screen pixels to a game pixel, for DARK's look round -Elvie
        if ctx.generation == 2 then
          local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
          if okC and type(Chrome.fitScale) == "function" then
            layer.cell = Chrome.fitScale(tonumber(ctx.ww) or 0, tonumber(ctx.wh) or 0) * (tonumber(ctx.dpiX) or 1)
          end
        elseif canvas and tonumber(ctx.uiw) and ctx.uiw > 0 then
          layer.cell = size[1] / ctx.uiw
        end
        local gen = ctx.generation
        if canvas and select(5, filter.settings(get)) == "dark" and filter.BATTLE_BOX[gen] then
          local game = gen == 1 and package.loaded["src.core.Game"] or renderer
          if battleShowing(gen, game) then
            layer.band = filter.BATTLE_BOX[gen]
            -- Gold to Crystal's whole picture: the band is of the game screen -Elvie
            if gen == 2 then
              local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
              local ww, wh = tonumber(ctx.ww) or 0, tonumber(ctx.wh) or 0
              if okC and type(Chrome.fitScale) == "function" and wh > 0 then
                local sc = Chrome.fitScale(ww, wh)
                local _, oy = Chrome.fitOrigin(ww, wh, sc)
                local top = (oy + 144 * sc * layer.band) * (tonumber(ctx.dpiX) or 1)
                layer.band = top / size[2] - origin[2] / size[2]
              end
            end
          end
        end
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
  rows[#rows + 1] = { key = "paper", type = "choice", label = "  PAPER", choices = filter.PAPERS, default = "off" }

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
        out[#out + 1] = { key = "paper", label = "PAPER", who = "paper", choices = filter.PAPERS,
          value = select(5, filter.settings(get)) }
        return out
      end,
      preview = function(who)
        local look, where, dots = filter.settings(get)
        if who == "filter" then
          return { lines = { { text = filter.ABOUT[look] or filter.ABOUT.off } } }
        elseif who == "where" then
          if where == "map" then return { lines = { { text = "The map; menus and battles" }, { text = "keep their colours." } } } end
          return { lines = { { text = "The whole screen." } } }
        elseif who == "shades" then
          return { lines = { { text = ("%s shades, from dark to light."):format(select(4, filter.settings(get))) } } }
        elseif who == "dots" then
          if dots == "on" then return { lines = { { text = "A dot-matrix screen." } } } end
          return { lines = { { text = "No grid." } } }
        elseif who == "paper" then
          if select(5, filter.settings(get)) == "off" then return { lines = { { text = "Menus on white." } } } end
          if select(5, filter.settings(get)) == "dark" then return { lines = { { text = "Dark menus, white letters." } } } end
          return { lines = { { text = "Menus on softer paper." } } }
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

    -- The game's own GB FILTER row (its OPTION screen) and the filter's
    -- hotkey switch the pass with Pipelines.cycle, behind FILTER's back.
    -- Without this FILTER stayed on, so the next load switched the pass
    -- back on, and turning it off there never lasted. Now that row moves
    -- FILTER and DOTS with it: OFF turns off what was on, ON brings back
    -- the last look (GRAY at first) -Elvie
    local lastLook = "gray"
    local function remember()
      local look = filter.settings(get)
      if look ~= "off" then lastLook = look end
    end
    remember()
    -- the newest start's: a game loaded later brings its own options -Elvie
    filter.follow = function(level)
      local look, where, dots, _, paper = filter.settings(get)
      if level <= 0 then
        if look ~= "off" and where == "screen" then mod.options:set("filter", "off") end
        if dots == "on" then mod.options:set("dots", "off") end
        if paper ~= "off" then mod.options:set("paper", "off") end
      elseif not filter.screenOn(look, where, dots) then
        if look == "off" then mod.options:set("filter", lastLook) end
        if where ~= "screen" then mod.options:set("filterOn", "screen") end
      end
    end
    -- PAPER on Gold, Silver and Crystal: the menus over the map are drawn
    -- into a picture of their own first, then onto the map as before, so
    -- PAPER knows which pixels are menus -Elvie
    local okSS, StateStack = pcall(require, "src.core.StateStack")
    if require("mods.facets.classic").generation() == 2 and okSS and type(StateStack) == "table"
        and type(StateStack.draw) == "function" and not StateStack.facetsPaper then
      StateStack.facetsPaper = true
      local ownDraw = StateStack.draw
      StateStack.draw = function(self, ...)
        local G = love.graphics
        local target = G.getCanvas()
        -- only the game's own stack, over the map (the game, from the last
        -- render.compose) -Elvie
        local game = gen2Game
        if not (target and select(5, filter.settings(get)) ~= "off" and type(game) == "table"
            and rawget(game, "stack") == self and rawget(game, "frameWorldActive")) then
          return ownDraw(self, ...)
        end
        local w, h = target:getDimensions()
        local dpi = target.getDPIScale and target:getDPIScale() or 1
        if not gen2Mask or gen2Mask:getWidth() ~= w or gen2Mask:getHeight() ~= h or gen2Mask:getDPIScale() ~= dpi then
          local ok, made = pcall(G.newCanvas, w, h, { dpiscale = dpi })
          gen2Mask = ok and made or nil
          if not gen2Mask then return ownDraw(self, ...) end
        end
        G.setCanvas({ gen2Mask, stencil = true })
        G.push()
        G.origin()
        G.clear(0, 0, 0, 0)
        G.pop()
        local results = { pcall(ownDraw, self, ...) }
        G.setCanvas(target)
        G.push("all")
        G.origin()
        G.setScissor()
        G.setShader()
        G.setColor(1, 1, 1, 1)
        G.setBlendMode("alpha", "premultiplied")
        G.draw(gen2Mask, 0, 0)
        G.pop()
        gen2Drawn = true
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2)
      end
    end

    -- wrapped once; the wrap asks filter.follow -Elvie
    if Pipelines and type(Pipelines.cycle) == "function" and not Pipelines.facetsFilterCycle then
      local cycle = Pipelines.cycle
      Pipelines.facetsFilterCycle = cycle
      Pipelines.cycle = function(id, ...)
        local level = cycle(id, ...)
        if id == filter.ID and filter.follow then
          local ok, err = pcall(filter.follow, level)
          if not ok then mod.log:warn("FILTER couldn't follow the game's GB FILTER row: %s", tostring(err)) end
        end
        return level
      end
    end

    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id
            and (change.key == "filter" or change.key == "filterOn" or change.key == "dots" or change.key == "shades"
              or change.key == "paper") then
          remember()
          apply()
        end
      end)
      mod.events:on("game.ready", apply)
      mod.events:on("save.loaded", apply)
    end
  end
end

return filter
