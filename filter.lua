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
-- rest -Elvie
filter.PAPERS = { { "WHITE", "off" }, { "CREAM", "cream" }, { "LEMON", "lemon" }, { "PEACH", "peach" },
  { "ROSE", "rose" }, { "LILAC", "lilac" }, { "SKY", "sky" }, { "MINT", "mint" }, { "GREY", "grey" },
  { "DARK", "dark" }, { "COCOA", "cocoa" }, { "OLIVE", "olive" }, { "RUST", "rust" }, { "WINE", "wine" },
  { "PLUM", "plum" }, { "NAVY", "navy" }, { "FOREST", "forest" } }
filter.PAPER = {
  cream = { 248, 240, 216 }, lemon = { 248, 244, 204 }, peach = { 250, 228, 210 },
  rose = { 248, 224, 230 }, lilac = { 234, 226, 248 }, sky = { 218, 234, 250 },
  mint = { 222, 246, 228 }, grey = { 214, 214, 214 },
  -- DARK and the dark colours, each the light one's mirror (GREY's,
  -- CREAM's, LEMON's, PEACH's, ROSE's, LILAC's, SKY's, MINT's): dark paper.
  -- Pictures on it keep their white (see pics below) -Elvie
  dark = { 34, 36, 46 }, cocoa = { 52, 38, 30 }, olive = { 44, 44, 22 }, rust = { 64, 34, 24 },
  wine = { 64, 22, 36 }, plum = { 46, 30, 62 }, navy = { 22, 32, 64 }, forest = { 22, 48, 34 },
}
-- BATTLE BG: COLORS, a battle on plain colour, and BG COLOR, which:
-- PAPER (whatever PAPER is, white when it's off) or any of PAPER's colours
-- -Elvie
filter.BG_COLOURS = { { "PAPER", "paper" } }
for _, c in ipairs(filter.PAPERS) do filter.BG_COLOURS[#filter.BG_COLOURS + 1] = c end
function filter.bgColour(get)
  local pick = tostring(get("bgColour") or "paper")
  if pick == "paper" then pick = select(5, filter.settings(get)) end
  local c = filter.PAPER[pick]
  if not c then return { 255, 255, 255 } end
  return c
end

-- the dark papers, which turn the letters round (white edges, white GBA
-- letters) and keep pictures' white -Elvie
filter.DARKS = { dark = true, cocoa = true, olive = true, rust = true, wine = true, plum = true, navy = true, forest = true }
function filter.isDark(paper)
  return filter.DARKS[paper] == true
end

-- DARK in a battle: only its text box goes dark, so the scene behind, the
-- Pokémon and their animations stay as they are. Where it starts, as a
-- share of the screen's height: Red to Crystal's six tile rows of
-- eighteen, the GBA's 48 pixels of 160 -Elvie
filter.BATTLE_BOX = { [1] = 12 / 18, [2] = 12 / 18, [3] = 112 / 160 }

-- How much the dot grid darkens the line between two pixels. -Elvie
filter.DOT_SHADE = 0.82

-- mode: 0 none, 1 four shades, 2 GBC. dots needs a game pixel at least 3
-- screen pixels wide, or the grid would cover the picture. -Elvie
filter.SHADER = [[
// phones work in lower precision by default, too coarse for where a game
// pixel's middle is on a big screen. The few values that place things on
// the screen ask for LOVE's own "highp where offered" -Elvie
#ifdef LOVE_HIGHP_OR_MEDIUMP
#define FACETS_HP LOVE_HIGHP_OR_MEDIUMP
#else
#define FACETS_HP
#endif
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
extern FACETS_HP vec2 uiOrigin;
extern FACETS_HP vec2 uiSize;
extern float keepOn;
extern Image keep;
extern FACETS_HP vec2 keepOrigin;
extern FACETS_HP vec2 keepSize;
extern float paperDark;
extern FACETS_HP float cellF;
extern FACETS_HP vec2 srcPx;
extern float bandTop;
extern float gba;
// Gold to Crystal: its battle's text band, and the boxes over it (the move's
// type box), both go dark
extern float bandToo;
// whether a pixel is the white or near-white of a menu's paper
float paperish(vec3 c) {
  float hi = max(c.r, max(c.g, c.b));
  float lo = min(c.r, min(c.g, c.b));
  return smoothstep(0.84, 0.92, lo) * (1.0 - smoothstep(0.066, 0.072, hi - lo));
}
extern float boxesOn;
extern Image boxes;
// the eight pixels round one, as steps
vec2 around(int i) {
  if (i == 0) return vec2(1.0, 0.0);
  if (i == 1) return vec2(-1.0, 0.0);
  if (i == 2) return vec2(0.0, 1.0);
  if (i == 3) return vec2(0.0, -1.0);
  if (i == 4) return vec2(1.0, 1.0);
  if (i == 5) return vec2(-1.0, -1.0);
  if (i == 6) return vec2(1.0, -1.0);
  return vec2(-1.0, 1.0);
}
// the screen spot at the middle of the game pixel d game pixels from the
// one at sc. A game pixel is seldom a whole number of screen pixels, so
// the look round goes from game pixel to game pixel, not by a fixed step
// that drifts off them a few pixels out
FACETS_HP vec2 nbAt(FACETS_HP vec2 sc, vec2 d) {
  FACETS_HP vec2 g = floor((sc - uiOrigin) / cellF);
  return uiOrigin + (g + d + 0.5) * cellF;
}
vec3 nbTex(Image tex, FACETS_HP vec2 tc, FACETS_HP vec2 sc, vec2 d) {
  return Texel(tex, tc + (nbAt(sc, d) - sc) / srcPx).rgb;
}
// how much a picture kept this frame covers screen pixel at
float keptAt(FACETS_HP vec2 at) {
  if (keepOn < 0.5) return 0.0;
  FACETS_HP vec2 k = (at - keepOrigin) / keepSize;
  if (k.x < 0.0 || k.y < 0.0 || k.x >= 1.0 || k.y >= 1.0) return 0.0;
  return Texel(keep, k).a;
}
// on Red to Crystal, whether the pixel at t sits in a black bar or box
// (the bag's header and its pocket name): white letters on black, which
// stay as they are. A bar has a solid dark row (nine game pixels across)
// above and below, within seven rows, each with some dark on its inside.
// A one-line window's border is solid too, but has paper on its inside,
// and a black letter is never nine pixels wide. (Dark counts the box's
// border, red on the bag)
// how dark the row dy game pixels off is round this one: the count in
// the nine pixels centred on it (y), and whether nine in a row are all
// dark centred, to the left or to the right (x: a letter by a box's edge)
vec2 rowDark(Image tex, FACETS_HP vec2 t, FACETS_HP vec2 sc, float dy) {
  float l = 0.0;
  float m = 0.0;
  float r = 0.0;
  for (int x = -8; x <= 8; x++) {
    float d = step(dot(nbTex(tex, t, sc, vec2(float(x), dy)), vec3(0.299, 0.587, 0.114)), 0.32);
    if (x <= 0) l += d;
    if (x >= -4 && x <= 4) m += d;
    if (x >= 0) r += d;
  }
  return vec2(step(8.5, max(m, max(l, r))), m);
}
float inBar(Image tex, FACETS_HP vec2 t, FACETS_HP vec2 sc) {
  float up = 0.0;
  float dn = 0.0;
  float innerUp = 9.0;
  float innerDn = 9.0;
  for (int k = 1; k <= 7; k++) {
    vec2 ru = rowDark(tex, t, sc, -float(k));
    vec2 rd = rowDark(tex, t, sc, float(k));
    up = max(up, ru.x * step(0.5, innerUp));
    dn = max(dn, rd.x * step(0.5, innerDn));
    innerUp = ru.y;
    innerDn = rd.y;
  }
  return up * dn;
}
// whether the pixel d game pixels from this one ends up the dark paper:
// the menus' white, where DARK paints (the UI layer, its band or boxes),
// and not a picture's. A letter turns white only with dark round it
float goesDark(Image tex, FACETS_HP vec2 tc, FACETS_HP vec2 sc, vec2 d) {
  vec3 c = nbTex(tex, tc, sc, d);
  FACETS_HP vec2 at = nbAt(sc, d);
  FACETS_HP vec2 p = (at - uiOrigin) / uiSize;
  if (p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) return 0.0;
  float inBox = 0.0;
  if (boxesOn > 0.5) {
    FACETS_HP vec2 b = (at - keepOrigin) / keepSize;
    if (b.x >= 0.0 && b.y >= 0.0 && b.x < 1.0 && b.y < 1.0) inBox = Texel(boxes, b).a;
  }
  float region = boxesOn > 0.5 ? max(inBox, bandToo * step(bandTop, p.y)) : (gba > 0.5 ? inBox : step(bandTop, p.y));
  return paperish(c) * Texel(ui, p).a * region * (1.0 - keptAt(at));
}
// whether a light pixel near this one stays light (a picture's white, the
// battle's scenery, a pale box): a letter beside it stays dark, readable.
// (On the GBA games only near-white counts: a letter's own shadow is a
// light grey)
float staysLight(Image tex, FACETS_HP vec2 tc, FACETS_HP vec2 sc, vec2 d) {
  vec3 c = nbTex(tex, tc, sc, d);
  float light = step(gba > 0.5 ? 0.9 : 0.6, dot(c, vec3(0.299, 0.587, 0.114)));
  return light * (1.0 - goesDark(tex, tc, sc, d));
}
vec4 effect(vec4 color, Image tex, FACETS_HP vec2 tc, FACETS_HP vec2 sc) {
  vec4 c = Texel(tex, tc);
  vec3 o = c.rgb;
  if (paperOn > 0.5) {
    // the menus' own pixels: where the UI layer is drawn, white or nearly
    // (a palette's paper can be a touch off-white), and not a colour
    FACETS_HP vec2 p = (sc - uiOrigin) / uiSize;
    if (p.x >= 0.0 && p.y >= 0.0 && p.x < 1.0 && p.y < 1.0) {
      float hi = max(o.r, max(o.g, o.b));
      float lo = min(o.r, min(o.g, o.b));
      // (white or a touch off it: the Super Game Boy's paper is 255, 239,
      // 255; a pale coloured box, PINK's 255, 236, 246, isn't paper)
      float w = Texel(ui, p).a * smoothstep(0.84, 0.92, lo) * (1.0 - smoothstep(0.066, 0.072, hi - lo));
      // the GBA games' white is only paper in a stretch of it
      // in a battle, DARK covers only its text box (bandTop) and, on Red,
      // Blue and Yellow, the game's own HP boxes (boxes, where the battle
      // drew them, mapped as the pictures' copy is)
      float inBox = 0.0;
      if (boxesOn > 0.5) {
        FACETS_HP vec2 b = (sc - keepOrigin) / keepSize;
        if (b.x >= 0.0 && b.y >= 0.0 && b.x < 1.0 && b.y < 1.0) inBox = Texel(boxes, b).a;
      }
      // (where the boxes are known, they alone: the text box is one). The
      // GBA games' paper is only ever in their windows
      w *= boxesOn > 0.5 ? max(inBox, bandToo * step(bandTop, p.y)) : (gba > 0.5 && paperDark > 0.5 ? 0.0 : step(bandTop, p.y));
      // a picture drawn this frame keeps its white, as drawn, unless a box
      // covers it (the move box over your Pokémon)
      w *= 1.0 - keptAt(sc);
      // DARK on Red to Crystal: a black letter (or a frame's black line) on
      // the paper turns white, and the paper beside it is its outline, a
      // game pixel wide, in a grey a little lighter than the paper, as the
      // GBA games' letters have their shadow. A picture's own black (kept)
      // stays as it is
      float edge = 0.0;
      if (paperDark > 0.5 && w > 0.5 && gba < 0.5) {
        for (int i = 0; i < 8; i++) {
          vec3 c = nbTex(tex, tc, sc, around(i));
          float chi = max(c.r, max(c.g, c.b));
          float clo = min(c.r, min(c.g, c.b));
          float black = step(dot(c, vec3(0.299, 0.587, 0.114)), 0.2) * (1.0 - smoothstep(0.08, 0.14, chi - clo));
          // (not the paper's own colour: COLORS' field, behind the HUDs)
          black *= step(0.1, distance(c, paper));
          edge = max(edge, black * (1.0 - keptAt(nbAt(sc, around(i)))));
        }
        // a white letter on a black bar is the bar's: it stays white. (Not
        // in a battle, whose boxes are known: there a scene's dark round
        // the HUDs would pass for a bar)
        if (edge > 0.5 && boxesOn < 0.5 && inBar(tex, tc, sc) > 0.5) {
          w = 0.0;
          edge = 0.0;
        }
      }
      // the GBA games' letters are dark grey with a light grey shadow, not
      // black: on paper going dark, the letter turns white and its shadow a
      // grey a little lighter than the paper. A colour (the red of a
      // choice) stays
      vec3 before = o;
      vec3 outline = mix(paper, vec3(0.93), 0.22);
      o = edge > 0.5 ? outline : mix(o, paper * hi, w);
      if (gba < 0.5 && paperDark > 0.5 && w < 0.5) {
        float l = dot(before, vec3(0.299, 0.587, 0.114));
        float region = Texel(ui, p).a * (boxesOn > 0.5 ? max(inBox, bandToo * step(bandTop, p.y)) : step(bandTop, p.y)) * (1.0 - keptAt(sc));
        if (step(l, 0.2) * (1.0 - smoothstep(0.08, 0.14, hi - lo)) * region * step(0.1, distance(before, paper)) > 0.5
            && (boxesOn > 0.5 || inBar(tex, tc, sc) < 0.5)) {
          float onPaper = 0.0;
          float light = 0.0;
          for (int i = 0; i < 8; i++) {
            onPaper = max(onPaper, goesDark(tex, tc, sc, around(i)));
            onPaper = max(onPaper, goesDark(tex, tc, sc, 2.0 * around(i)));
            light = max(light, staysLight(tex, tc, sc, around(i)));
          }
          if (onPaper > 0.5 && light < 0.5) o = vec3(0.93, 0.93, 0.94);
        }
      }
      if (gba > 0.5 && paperDark > 0.5 && w < 0.5) {
        float l = dot(before, vec3(0.299, 0.587, 0.114));
        // (black too: FireRed's PP numbers)
        float text = step(l, 0.45);
        float shade = step(0.70, l) * step(l, 0.88);
        if ((text + shade) * (1.0 - smoothstep(0.08, 0.14, hi - lo)) * Texel(ui, p).a > 0.5
            && inBox > 0.5 && keptAt(sc) < 0.5) {
          float onPaper = 0.0;
          float light = 0.0;
          for (int i = 0; i < 8; i++) {
            onPaper = max(onPaper, goesDark(tex, tc, sc, around(i)));
            onPaper = max(onPaper, goesDark(tex, tc, sc, 2.0 * around(i)));
            light = max(light, staysLight(tex, tc, sc, around(i)));
          }
          onPaper *= inBox * (1.0 - light);
          if (onPaper > 0.5) o = text > 0.5 ? vec3(0.93, 0.93, 0.94) : mix(paper, vec3(0.93), 0.22);
        }
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
  local layer = { canvas = nil, origin = { 0, 0 }, size = { 1, 1 }, cell = 1, band = 0 }
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
  -- DARK's pictures this frame: a copy the size of what they were drawn
  -- on (keep), and where that sits on screen -Elvie
  local pics = { keep = nil, drawn = false, fresh = false, origin = nil, size = nil,
    boxes = nil, boxesDrawn = false, boxesFresh = false }
  -- Gold, Silver and Crystal draw the map and the menus into one picture,
  -- so PAPER keeps its own copy of the menus drawn over the map (gen2Mask,
  -- from start below); with no map, the whole picture is menus -Elvie
  local gen2Mask, gen2Drawn, gen2Game, whole = nil, false, nil, nil
  -- the GBA game, from its own update (start, below) -Elvie
  local game3 = nil
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
      -- a full-screen menu: the Game Boy screen only, not what SURROUND
      -- paints round it (GLOW's dark would take a white edge) -Elvie
      local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
      if okC and type(Chrome.fitScale) == "function" and not battleShowing(2, gen2Game) then
        local sc = Chrome.fitScale(ww, wh)
        local ox, oy = Chrome.fitOrigin(ww, wh, sc)
        return wholeImage(), { ox * dpi, oy * dpi }, { 160 * sc * dpi, 144 * sc * dpi }
      end
      return wholeImage(), { 0, 0 }, { ww * dpi, wh * dpi }
    end
    -- a battle with BATTLE BG: WORLD has the map round it, not under it:
    -- the game screen is all battle -Elvie
    if battleShowing(2, gen2Game) then
      local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
      if okC and type(Chrome.fitScale) == "function" then
        local sc = Chrome.fitScale(ww, wh)
        local _, oy = Chrome.fitOrigin(ww, wh, sc)
        -- the screen's height, and the window's width: the battle's boxes
        -- run past the Game Boy screen's sides -Elvie
        return wholeImage(), { 0, oy * dpi }, { ww * dpi, 144 * sc * dpi }
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
    else
      sh:send("paperOn", 0)
    end
    sh:send("paperDark", filter.isDark(paper) and 1 or 0)
    sh:send("bandTop", filter.isDark(paper) and layer.band or 0)
    sh:send("gba", layer.gen == 3 and 1 or 0)
    sh:send("bandToo", layer.gen == 2 and 1 or 0)
    -- a game pixel, in screen pixels, and the screen's size, so the look
    -- round lands on the middle of each game pixel and not between them,
    -- where black and white would blend -Elvie
    local sw, shh = src:getPixelDimensions()
    sh:send("cellF", math.max(1, tonumber(layer.cell) or 1))
    sh:send("srcPx", { math.max(1, sw), math.max(1, shh) })
    if tint and filter.isDark(paper) and (layer.band > 0 or layer.gen == 3) and pics.boxes and pics.boxesDrawn and pics.origin then
      sh:send("boxesOn", 1)
      sh:send("boxes", pics.boxes)
    else
      sh:send("boxesOn", 0)
    end
    if pics.origin then
      sh:send("keepOrigin", pics.origin)
      sh:send("keepSize", pics.size)
    end
    pics.boxesDrawn, pics.boxesFresh = false, false
    if tint and layer.canvas and pics.keep and pics.drawn and pics.origin then
      sh:send("keepOn", 1)
      sh:send("keep", pics.keep)
      sh:send("keepOrigin", pics.origin)
      sh:send("keepSize", pics.size)
    else
      sh:send("keepOn", 0)
    end
    -- the next frame's pictures start afresh (the game can draw one after
    -- render.compose, so this waits till the pass has used them) -Elvie
    pics.drawn, pics.fresh = false, false
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
        -- the GBA games' title and opening, and the recap, aren't menus:
        -- PAPER leaves them be -Elvie
        if ctx.generation == 3 and game3 and (rawget(game3, "phase") == "boot" or rawget(game3, "phase") == "quest_log") then
          canvas = nil
        end
        layer.canvas = canvas
        if canvas then layer.origin, layer.size = origin, size end
        -- screen pixels to a game pixel -Elvie
        if ctx.generation == 2 then
          local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
          if okC and type(Chrome.fitScale) == "function" then
            layer.cell = Chrome.fitScale(tonumber(ctx.ww) or 0, tonumber(ctx.wh) or 0) * (tonumber(ctx.dpiX) or 1)
          end
        elseif canvas and tonumber(ctx.uiw) and ctx.uiw > 0 then
          layer.cell = size[1] / ctx.uiw
        end
        layer.gen = ctx.generation
        -- DARK in a battle: only from its text box down -Elvie
        layer.band = 0
        local gen = ctx.generation
        if canvas and filter.isDark(select(5, filter.settings(get))) and filter.BATTLE_BOX[gen] then
          local game = gen == 1 and package.loaded["src.core.Game"] or renderer
          if battleShowing(gen, game) then
            layer.band = filter.BATTLE_BOX[gen]
            -- Gold to Crystal's whole picture: the band is of the game
            -- screen -Elvie
            if gen == 2 then
              local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
              local ww, wh = tonumber(ctx.ww) or 0, tonumber(ctx.wh) or 0
              if okC and type(Chrome.fitScale) == "function" and wh > 0 then
                local sc = Chrome.fitScale(ww, wh)
                local _, oy = Chrome.fitOrigin(ww, wh, sc)
                local top = (oy + 144 * sc * layer.band) * (tonumber(ctx.dpiX) or 1)
                layer.band = (top - origin[2]) / size[2]
              end
            end
          end
        end
        -- where the pictures' copy sits: the UI layer's place on Red to
        -- Emerald, the whole picture on Gold to Crystal -Elvie
        pics.origin, pics.size = nil, nil
        local copy = pics.keep or pics.boxes
        if pics.keep and pics.boxes and pics.keep:getPixelWidth() ~= pics.boxes:getPixelWidth() then copy = pics.keep end
        if copy then
          local kw, kh = copy:getPixelDimensions()
          local scene = ctx.sceneCanvas
          if ctx.generation == 2 then
            -- only a copy of the whole picture (a battle draws its
            -- Pokémon on a canvas of its own first) -Elvie
            if scene and kw == scene:getPixelWidth() and kh == scene:getPixelHeight() then
              pics.origin, pics.size = { 0, 0 }, { kw, kh }
            end
          elseif canvas == ctx.uiCanvas and canvas and kw == canvas:getPixelWidth() and kh == canvas:getPixelHeight() then
            pics.origin, pics.size = origin, size
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
    -- PAPER knows which pixels are menus. The game draws them through its
    -- stack, or (UI LAYOUT: DYNAMIC, from 0.4.6) through drawDockedStack
    -- -Elvie
    local function captured(ownDraw)
      return function(self, ...)
        local G = love.graphics
        local target = G.getCanvas()
        -- only the game's own menus, over the map (the game, from the last
        -- render.compose) -Elvie
        local game = gen2Game
        if not (target and select(5, filter.settings(get)) ~= "off" and type(game) == "table"
            and (self == game or rawget(game, "stack") == self) and rawget(game, "frameWorldActive")) then
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
        -- with a SHADER FX on that shades the map on its own (the voxel
        -- world), the menus go on a layer of their own that's laid over
        -- after the pass: PAPER is done on that layer, here -Elvie
        local paper = select(5, filter.settings(get))
        if paper ~= "off" and rawget(game, "fxUiLayer") == target then
          pcall(function()
            local pw, ph = target:getPixelDimensions()
            local saved = { layer.canvas, layer.origin, layer.size, pics.origin, pics.size }
            layer.canvas, layer.origin, layer.size = gen2Mask, { 0, 0 }, { pw, ph }
            if pics.keep and pics.keep:getPixelWidth() == pw and pics.keep:getPixelHeight() == ph then
              pics.origin, pics.size = { 0, 0 }, { pw, ph }
            end
            local out = run(target, "ui", "off", false, "4", paper)
            layer.canvas, layer.origin, layer.size, pics.origin, pics.size = saved[1], saved[2], saved[3], saved[4], saved[5]
            if out then
              G.push("all")
              G.setCanvas(target)
              G.origin()
              G.setScissor()
              G.setShader()
              G.setColor(1, 1, 1, 1)
              G.setBlendMode("replace", "premultiplied")
              G.draw(out, 0, 0)
              G.pop()
            end
          end)
        end
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2)
      end
    end
    if require("mods.facets.classic").generation() == 2 then
      local okSS, StateStack = pcall(require, "src.core.StateStack")
      if okSS and type(StateStack) == "table" and type(StateStack.draw) == "function" and not StateStack.facetsPaper then
        StateStack.facetsPaper = true
        StateStack.draw = captured(StateStack.draw)
      end
      local okG2, Game2 = pcall(require, "src.core.Game2")
      if okG2 and type(Game2) == "table" and type(Game2.drawDockedStack) == "function" and not Game2.facetsPaper then
        Game2.facetsPaper = true
        Game2.drawDockedStack = captured(Game2.drawDockedStack)
      end
    end

    -- DARK and pictures. A Pokémon's or trainer's picture is see-through
    -- round it, and on Red to Crystal often inside too, where it's white:
    -- on dark paper that inside would go dark. So, as Emerald Lens fills
    -- its trainers: the see-through the background can't reach, flooding
    -- in from the edges up, down, left and right (never diagonally, which
    -- leaks through an outline's corners), is filled white. A back picture
    -- is cut off at the bottom, so that edge isn't flooded from. The
    -- picture is drawn filled, and where it went is kept, so the pass
    -- leaves its white as it is. The pictures are the ones the game asks
    -- the sprite module for (src.pokemon.Sprites), on Red to Crystal; the
    -- GBA games' full-colour pictures have nothing see-through inside
    -- -Elvie
    local gen = require("mods.facets.classic").generation()
    local okSp, Sprites = pcall(require, "src.pokemon.Sprites")
    if not filter.picturesWrapped then
      filter.picturesWrapped = true
      local G = love.graphics
      local okA, Assets = pcall(require, "src.render.Assets")
      local resolve = okA and type(Assets) == "table" and type(Assets.resolve) == "function" and Assets.resolve or nil
      -- the picture files the game has asked for: path -> { back } -Elvie
      local paths = {}
      local function note(path, back)
        if type(path) ~= "string" or path == "" then return end
        paths[path] = { back = back }
        if resolve then
          local ok, r = pcall(resolve, path)
          if ok and type(r) == "string" then paths[r] = paths[path] end
        end
      end
      -- and the gym leaders' faces on Red, Blue and Yellow's trainer card
      -- (one sheet, drawn a face at a time) -Elvie
      note("assets/generated/trainer_card/badges.png", false)
      for name, fn in pairs(gen <= 2 and okSp and type(Sprites) == "table" and not Sprites.facetsPaper and Sprites or {}) do
        if type(fn) == "function" and name ~= "facetsPaper" then
          Sprites[name] = function(...)
            local results = { fn(...) }
            if type(results[1]) == "string" then
              local back = false
              for i = 1, select("#", ...) do
                local a = select(i, ...)
                if a == "back" or (type(a) == "table" and a.side == "back") then back = true end
              end
              note(results[1], back)
            end
            return unpack(results)
          end
        end
      end
      if gen <= 2 and okSp and type(Sprites) == "table" then Sprites.facetsPaper = true end
      -- each picture image, as it's made from one of those files -Elvie
      local images = setmetatable({}, { __mode = "k" })
      -- also the openings' pictures (Oak and you in Crystal's, and you on
      -- Red, Blue and Yellow's title) and other mods' pictures (Emerald
      -- Lens's), which don't come from the sprite module -Elvie
      local function picturePath(path)
        if paths[path] then return paths[path] end
        local p = path:gsub("\\", "/")
        if p:match("/intro/oak%.png$") or p:match("/intro/kris%.png$") or p:match("/intro/chris%.png$")
            or p:match("/intro/cal%.png$") or p:match("/title/player%.png$") then
          return { back = false }
        end
        if (p:match("^mods/") or p:match("/mods/")) and not p:match("mods/facets/") and not p:lower():match("font")
            and p:lower():match("%.png$") then
          return { back = false }
        end
        return nil
      end
      local function tag(img, path)
        local info = img and type(path) == "string" and picturePath(path)
        if info then images[img] = { path = path, back = info.back } end
        return img
      end
      local ownNew = G.newImage
      G.newImage = function(src, ...)
        return tag(ownNew(src, ...), src)
      end
      -- a battle makes its pictures from their pixels (Assets.imageData,
      -- recoloured), so those are followed too, and filled from them -Elvie
      local datas = setmetatable({}, { __mode = "k" })
      if okA and type(Assets.imageData) == "function" then
        local ownData = Assets.imageData
        Assets.imageData = function(path, ...)
          local d = ownData(path, ...)
          if d and type(path) == "string" and paths[path] then datas[d] = { path = path, back = paths[path].back } end
          return d
        end
      end
      -- another mod's picture read as pixels first (Emerald Lens's) -Elvie
      if love.image and type(love.image.newImageData) == "function" and not love.image.facetsPaper then
        love.image.facetsPaper = true
        local ownImageData = love.image.newImageData
        love.image.newImageData = function(src, ...)
          local d = ownImageData(src, ...)
          local info = d and type(src) == "string" and picturePath(src)
          if info then datas[d] = { path = src, back = info.back } end
          return d
        end
      end
      local ownNewImage = G.newImage
      G.newImage = function(src, ...)
        local img = ownNewImage(src, ...)
        local info = type(src) == "userdata" and datas[src]
        if img and info then images[img] = { path = info.path, back = info.back, data = src } end
        return img
      end
      if okA and type(Assets.image) == "function" then
        local ownImage = Assets.image
        Assets.image = function(path, ...)
          return tag(ownImage(path, ...), path)
        end
      end
      -- the filled copy of each picture. A sheet drawn a part at a time
      -- (the leaders' faces) is filled a part at a time, each from its
      -- own edges -Elvie
      local filled = setmetatable({}, { __mode = "k" })
      local function floodFill(data, x0, y0, w, h, back)
        local seen, queue = {}, {}
        local function push(x, y)
          if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x] then return end
          local _, _, _, a = data:getPixel(x0 + x, y0 + y)
          if a >= 0.5 then return end
          seen[y * w + x] = true
          queue[#queue + 1] = y * w + x
        end
        for x = 0, w - 1 do
          push(x, 0)
          if not back then push(x, h - 1) end
        end
        for y = 0, h - 1 do push(0, y); push(w - 1, y) end
        local i = 1
        while queue[i] do
          local x, y = queue[i] % w, math.floor(queue[i] / w)
          push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1)
          i = i + 1
        end
        for y = 0, h - 1 do
          for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x0 + x, y0 + y)
            if a < 0.5 and not seen[y * w + x] then data:setPixel(x0 + x, y0 + y, 1, 1, 1, 1) end
          end
        end
      end
      local function fill(img, quad)
        local got = filled[img]
        if got == false then return nil end
        local ok, out = pcall(function()
          if not got then
            local info = images[img]
            got = { data = info.data and info.data:clone() or love.image.newImageData(info.path), parts = {} }
            filled[img] = got
          end
          local w, h = got.data:getDimensions()
          local x0, y0, qw, qh = 0, 0, w, h
          if quad then x0, y0, qw, qh = quad:getViewport() end
          local key = ("%d,%d,%d,%d"):format(x0, y0, qw, qh)
          if not got.parts[key] then
            got.parts[key] = true
            local pw, ph = math.min(qw, w - x0), math.min(qh, h - y0)
            -- a picture with no see-through at all has a white background
            -- (you and Kris in the openings): that background is the
            -- paper's. It's drawn as it is, and only what the white
            -- reaching in from the edges doesn't touch is kept -Elvie
            local opaque = true
            for yy = 0, ph - 1 do
              for xx = 0, pw - 1 do
                local _, _, _, a = got.data:getPixel(x0 + xx, y0 + yy)
                if a < 0.5 then opaque = false; break end
              end
              if not opaque then break end
            end
            if opaque then
              got.keepData = got.keepData or got.data:clone()
              local seen, queue = {}, {}
              local function white(xx, yy)
                local r, g, b = got.keepData:getPixel(x0 + xx, y0 + yy)
                return 0.299 * r + 0.587 * g + 0.114 * b > 0.85
              end
              local function push(xx, yy)
                if xx < 0 or yy < 0 or xx >= pw or yy >= ph or seen[yy * pw + xx] or not white(xx, yy) then return end
                seen[yy * pw + xx] = true
                queue[#queue + 1] = yy * pw + xx
              end
              for xx = 0, pw - 1 do push(xx, 0); push(xx, ph - 1) end
              for yy = 0, ph - 1 do push(0, yy); push(pw - 1, yy) end
              local i = 1
              while queue[i] do
                local xx, yy = queue[i] % pw, math.floor(queue[i] / pw)
                push(xx + 1, yy); push(xx - 1, yy); push(xx, yy + 1); push(xx, yy - 1)
                i = i + 1
              end
              for k in pairs(seen) do got.keepData:setPixel(x0 + k % pw, y0 + math.floor(k / pw), 0, 0, 0, 0) end
              got.keepImage = ownNew(got.keepData)
              got.keepImage:setFilter(img:getFilter())
              got.opaque = true
            else
              floodFill(got.data, x0, y0, pw, ph, images[img].back)
            end
            got.image = ownNew(got.data)
            got.image:setFilter(img:getFilter())
          end
          if got.opaque then return img, got.keepImage end
          return got.image, got.image
        end)
        if not ok then filled[img] = false; return nil end
        return out
      end
      local ownDraw = G.draw
      G.draw = function(drawable, x, ...)
        local target = G.getCanvas()
        -- (filter.keeping: everything a menu's preview draws is a picture)
        if filter.keepingAll and target and type(drawable) == "userdata" and not images[drawable]
            and drawable.typeOf and drawable:typeOf("Texture") then
          ownDraw(drawable, x, ...)
          filter.keepDraw(drawable, x, ...)
          return
        end
        if not (images[drawable] and target and filter.isDark(select(5, filter.settings(get)))) then
          return ownDraw(drawable, x, ...)
        end
        local quad = type(x) == "userdata" and x:typeOf("Quad") and x or nil
        if not (quad or type(x) == "number") then return ownDraw(drawable, x, ...) end
        local img, keepImg = fill(drawable, quad)
        img = img or drawable
        ownDraw(img, x, ...)
        filter.keepDraw(keepImg or img, x, ...)
      end
      -- Keeps what's drawn (img, and draw's arguments) as it is, on a copy
      -- the size of what it's drawn on: the pictures, and Facets' own frame
      -- art (classic_windows), whose white is the frame's, not paper -Elvie
      filter.keepDraw = function(img, x, ...)
        local target = G.getCanvas()
        if not (target and filter.isDark(select(5, filter.settings(get)))) then return end
        local w, h = target:getDimensions()
        local dpi = target:getDPIScale()
        if not pics.keep or pics.keep:getWidth() ~= w or pics.keep:getHeight() ~= h or pics.keep:getDPIScale() ~= dpi then
          local okK, k = pcall(G.newCanvas, w, h, { dpiscale = dpi })
          pics.keep = okK and k or nil
          pics.fresh = false
        end
        if pics.keep then
          G.push("all")
          G.setCanvas(pics.keep)
          if not pics.fresh then
            G.push(); G.origin(); G.clear(0, 0, 0, 0); G.pop()
            pics.fresh = true
          end
          G.setShader()
          G.setBlendMode("alpha")
          G.setColor(1, 1, 1, 1)
          ownDraw(img, x, ...)
          G.pop()
          pics.drawn = true
        end
      end
    end

    -- Runs fn with every picture it draws kept as it is: Facets' own
    -- menus' previews (a Pokémon, a trainer), whose outlines would
    -- otherwise turn white like letters -Elvie
    filter.keeping = function(fn, ...)
      if not filter.isDark(select(5, filter.settings(get))) or not filter.keepDraw then return fn(...) end
      filter.keepingAll = true
      local results = { pcall(fn, ...) }
      filter.keepingAll = false
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2)
    end

    -- Facets' frame art keeps its own white (a Liberty frame's inner
    -- line), but not the white inside it, which is the window's paper: a
    -- frame cell's white is kept only beside a colour of the frame (not
    -- beside black, or more white). Worked out once for each frame sheet
    -- -Elvie
    local frameMasks = setmetatable({}, { __mode = "k" })
    local function frameMask(img)
      local got = frameMasks[img]
      if got ~= nil then return got or nil end
      frameMasks[img] = false
      local ok, out = pcall(function()
        local G = love.graphics
        local w, h = img:getPixelDimensions()
        local c = G.newCanvas(w, h, { dpiscale = 1 })
        G.push("all")
        G.setCanvas(c)
        G.origin()
        G.setScissor()
        G.setShader()
        G.clear(0, 0, 0, 0)
        G.setBlendMode("replace", "premultiplied")
        G.setColor(1, 1, 1, 1)
        G.draw(img, 0, 0, 0, w / img:getWidth(), h / img:getHeight())
        G.pop()
        local data = c:newImageData()
        local function kind(x, y)
          if x < 0 or y < 0 or x >= w or y >= h then return "none" end
          local r, g, b, a = data:getPixel(x, y)
          if a < 0.5 then return "none" end
          local hi, lo = math.max(r, g, b), math.min(r, g, b)
          local l = 0.299 * r + 0.587 * g + 0.114 * b
          if l > 0.8 and hi - lo < 0.07 then return "white" end
          if l < 0.2 and hi - lo < 0.12 then return "black" end
          return "colour"
        end
        local cut = {}
        for y = 0, h - 1 do
          for x = 0, w - 1 do
            if kind(x, y) == "white" then
              local beside = false
              for dy = -1, 1 do
                for dx = -1, 1 do
                  if (dx ~= 0 or dy ~= 0) and kind(x + dx, y + dy) == "colour" then beside = true end
                end
              end
              if not beside then cut[#cut + 1] = { x, y } end
            end
          end
        end
        for _, p in ipairs(cut) do data:setPixel(p[1], p[2], 0, 0, 0, 0) end
        local m = G.newImage(data, { dpiscale = img:getDPIScale() })
        m:setFilter("nearest", "nearest")
        return m
      end)
      frameMasks[img] = ok and out or false
      return frameMasks[img] or nil
    end
    filter.keepFrame = function(img, ...)
      if not filter.isDark(select(5, filter.settings(get))) then return end
      return filter.keepDraw(frameMask(img) or img, ...)
    end

    -- DARK in Red, Blue and Yellow's battles: the game's own boxes (the HP
    -- boxes, the text box) go dark with the text box, so where each box is
    -- drawn is kept on a copy the size of what it's drawn on -Elvie
    -- Marks a box (x, y, w, h, in the pixels of what's being drawn on) as
    -- paper DARK may darken, on a copy the size of what it's drawn on -Elvie
    filter.markPaper = function(x, y, w, h)
      local G = love.graphics
      local target = G.getCanvas()
      if not (target and tonumber(x) and tonumber(w)) then return end
      local dark = filter.isDark(select(5, filter.settings(get)))
      pcall(function()
        local cw, ch = target:getDimensions()
        local dpi = target:getDPIScale()
        G.push("all")
        G.setScissor()
        G.setShader()
        if dark then
          if not pics.boxes or pics.boxes:getWidth() ~= cw or pics.boxes:getHeight() ~= ch or pics.boxes:getDPIScale() ~= dpi then
            pics.boxes = G.newCanvas(cw, ch, { dpiscale = dpi })
            pics.boxesFresh = false
          end
          G.setCanvas(pics.boxes)
          if not pics.boxesFresh then
            G.push(); G.origin(); G.clear(0, 0, 0, 0); G.pop()
            pics.boxesFresh = true
          end
          G.setBlendMode("alpha")
          G.setColor(1, 1, 1, 1)
          G.rectangle("fill", x, y, w, h)
          pics.boxesDrawn = true
        end
        -- a box drawn over a picture covers it: that part of the picture's
        -- copy goes (the move box over your Pokémon, a menu over another
        -- window's frame) -Elvie
        if pics.keep and pics.fresh and pics.keep:getWidth() == cw and pics.keep:getHeight() == ch then
          G.setCanvas(pics.keep)
          G.setBlendMode("replace", "premultiplied")
          G.setColor(0, 0, 0, 0)
          G.rectangle("fill", x, y, w, h)
        end
        G.pop()
      end)
    end

    -- Red to Crystal: every box the game draws (Font.drawBox), marked
    -- before it's drawn, so its own frame's copy stays; the pass uses them
    -- in battles only -Elvie
    local okF, Font = pcall(require, "src.render.Font")
    if (gen == 1 or gen == 2) and okF and type(Font) == "table" and type(Font.drawBox) == "function" and not Font.facetsPaperBoxes then
      Font.facetsPaperBoxes = true
      local ownBox = Font.drawBox
      Font.drawBox = function(tx, ty, tw, th, ...)
        if type(tx) == "number" and type(tw) == "number" then filter.markPaper(tx * 8, ty * 8, tw * 8, th * 8) end
        return ownBox(tx, ty, tw, th, ...)
      end
    end

    -- Gold, Silver and Crystal: on a BATTLE BG behind the battle (a scene,
    -- a colour, a fill), the HUDs' white tiles show as plates round the
    -- names and bars; on dark paper they go dark with the text box. On the
    -- game's own white field they stay, as the field does -Elvie
    if gen == 2 and not filter.hudPlates then
      local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
      if okB and type(BattleState) == "table" and type(BattleState.drawEnemyHud) == "function"
          and type(BattleState.drawPlayerHud) == "function" then
        filter.hudPlates = true
        local function plates(self)
          local bg = get("classicBattleBg")
          return bg ~= nil and bg ~= "game"
        end
        local ownEnemy, ownPlayer = BattleState.drawEnemyHud, BattleState.drawPlayerHud
        BattleState.drawEnemyHud = function(self, ...)
          if plates(self) then filter.markPaper(8, 0, 80, 32) end
          return ownEnemy(self, ...)
        end
        BattleState.drawPlayerHud = function(self, ...)
          if plates(self) then filter.markPaper(72, 56, 88, 40) end
          return ownPlayer(self, ...)
        end
      end
    end

    -- The GBA games: their white is only paper inside their windows, so
    -- white letters on their own coloured boxes (the battle's teal, the
    -- party's blue) and pictures stay as they are. The windows are the
    -- game's frames (by their content), its text box, FireRed and
    -- LeafGreen's battle menu boxes (drawn in one picture with the text
    -- box), and Facets' own frames (gbui) -Elvie
    local okW, Chrome3 = false, nil
    if gen == 3 then okW, Chrome3 = pcall(require, "src.ui.game3.chrome") end
    if okW and type(Chrome3) == "table" and not Chrome3.facetsPaper then
      Chrome3.facetsPaper = true
      local T = 8
      for _, name in ipairs({ "stdFrame", "fixedStdFrame", "userFrame" }) do
        local own = Chrome3[name]
        if type(own) == "function" then
          Chrome3[name] = function(...)
            local results = { own(...) }
            local a, b, c, d = ...
            if name == "userFrame" then a, b, c, d = select(2, ...) end
            if tonumber(a) and tonumber(c) then filter.markPaper(a * T, b * T, c * T, d * T) end
            return unpack(results)
          end
        end
      end
      for _, name in ipairs({ "dialogueFrame", "signFrame" }) do
        local own = Chrome3[name]
        if type(own) == "function" then
          Chrome3[name] = function(...)
            local results = { own(...) }
            local L, Top, W, H = 2, 15, 26, 4
            if type(Chrome3.dialogueWindow) == "function" then
              local ok, l, t, w, h = pcall(Chrome3.dialogueWindow)
              if ok and tonumber(l) then L, Top, W, H = l, t, w, h end
            end
            filter.markPaper(L * T, Top * T, W * T, H * T)
            return unpack(results)
          end
        end
      end
      local okB, BattleChrome = pcall(require, "src.ui.game3.battle_chrome")
      if okB and type(BattleChrome) == "table" and type(BattleChrome.drawPanel) == "function" then
        local ownPanel = BattleChrome.drawPanel
        BattleChrome.drawPanel = function(mode, ...)
          local results = { ownPanel(mode, ...) }
          local hoenn = type(BattleChrome.isHoenn) == "function" and BattleChrome.isHoenn()
          if not hoenn then
            -- FireRed and LeafGreen: the FIGHT box on the right half, the
            -- moves and PP boxes across the whole panel -Elvie
            if mode == "menu" then filter.markPaper(120, 112, 120, 48)
            elseif mode == "moves" then filter.markPaper(0, 112, 240, 48) end
          end
          return unpack(results)
        end
      end
    end

    -- the GBA game itself, for its phase (title or play) -Elvie
    local okG3, Game3 = false, nil
    if gen == 3 then okG3, Game3 = pcall(require, "src.core.Game3") end
    if okG3 and type(Game3) == "table" and type(Game3.update) == "function" and not Game3.facetsPaper then
      Game3.facetsPaper = true
      local ownUpdate = Game3.update
      Game3.update = function(self, ...)
        game3 = self
        return ownUpdate(self, ...)
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
