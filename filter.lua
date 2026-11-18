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
-- GAME WOOD's colours, to match its boxes: each game's pale one and its
-- DARK one, in the order they step in WINDOWS -Elvie
for _, c in ipairs({
  { "RED", "red" }, { "DARK RED", "dark_red" },
  { "BLUE", "blue" }, { "DARK BLUE", "dark_blue" },
  { "YELLOW", "yellow" }, { "DARK YELLOW", "dark_yellow" },
  { "GOLD", "gold" }, { "DARK GOLD", "dark_gold" },
  { "SILVER", "silver" }, { "DARK SILVER", "dark_silver" },
  { "CRYSTAL", "crystal" }, { "DARK CRYSTAL", "dark_crystal" },
  { "EMERALD", "emerald" }, { "DARK EMERALD", "dark_emerald" },
  { "LEAFGREEN", "leafgreen" }, { "DARK LEAFGREEN", "dark_leafgreen" },
}) do
  filter.PAPERS[#filter.PAPERS + 1] = c
end
filter.PAPER = {
  cream = { 248, 240, 216 }, lemon = { 248, 244, 204 }, peach = { 250, 228, 210 },
  rose = { 248, 224, 230 }, lilac = { 234, 226, 248 }, sky = { 218, 234, 250 },
  mint = { 222, 246, 228 }, grey = { 214, 214, 214 },
  -- DARK and the dark colours, each the light one's mirror (GREY's,
  -- CREAM's, LEMON's, PEACH's, ROSE's, LILAC's, SKY's, MINT's): dark paper.
  -- Pictures on it keep their white (see pics below) -Elvie
  dark = { 34, 36, 46 }, cocoa = { 52, 38, 30 }, olive = { 44, 44, 22 }, rust = { 64, 34, 24 },
  wine = { 64, 22, 36 }, plum = { 46, 30, 62 }, navy = { 22, 32, 64 }, forest = { 22, 48, 34 },
  -- GAME WOOD's (assets/windows/gamewood, tools/make_game_wood.py): the
  -- same colours as its boxes' insides -Elvie
  red = { 255, 226, 220 },
  dark_red = { 192, 32, 40 },
  blue = { 226, 236, 255 },
  dark_blue = { 40, 64, 176 },
  yellow = { 255, 248, 200 },
  dark_yellow = { 240, 200, 32 },
  gold = { 250, 236, 192 },
  dark_gold = { 200, 148, 24 },
  silver = { 236, 240, 246 },
  dark_silver = { 72, 82, 100 },
  crystal = { 224, 248, 252 },
  dark_crystal = { 16, 104, 144 },
  emerald = { 220, 248, 232 },
  dark_emerald = { 16, 120, 72 },
  leafgreen = { 236, 250, 212 },
  dark_leafgreen = { 64, 140, 24 },
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
-- (and GAME WOOD's DARK ones whose letters read best white; its DARK
-- YELLOW, GOLD and LEAFGREEN read best black, so they're light papers,
-- strong ones) -Elvie
for _, k in ipairs({ "dark_red", "dark_blue", "dark_silver", "dark_crystal", "dark_emerald" }) do filter.DARKS[k] = true end
function filter.isDark(paper)
  return filter.DARKS[paper] == true
end
-- the strong light papers: GAME WOOD's DARK YELLOW, GOLD and LEAFGREEN,
-- black-lettered like any light paper, but too strong a colour for a
-- whole battle field or the GBA games' HUDs. In a battle they're kept to
-- the battle's boxes, as the dark papers are -Elvie
filter.STRONG = { dark_yellow = true, dark_gold = true, dark_leafgreen = true }
function filter.boxed(paper)
  return filter.DARKS[paper] == true or filter.STRONG[paper] == true
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
extern float mapTintOn;
extern vec3 mapTint;
extern Image ui;
extern vec2 uiOrigin;
extern vec2 uiSize;
extern float keepOn;
extern Image keep;
extern vec2 keepOrigin;
extern vec2 keepSize;
extern float paperDark;
extern float lite;
extern float cellF;
extern vec2 srcPx;
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
vec2 nbAt(vec2 sc, vec2 d) {
  vec2 g = floor((sc - uiOrigin) / cellF);
  return uiOrigin + (g + d + 0.5) * cellF;
}
vec3 nbTex(Image tex, vec2 tc, vec2 sc, vec2 d) {
  return Texel(tex, tc + (nbAt(sc, d) - sc) / srcPx).rgb;
}
// how much a picture kept this frame covers screen pixel at
float keptAt(vec2 at) {
  if (keepOn < 0.5) return 0.0;
  vec2 k = (at - keepOrigin) / keepSize;
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
vec2 rowDark(Image tex, vec2 t, vec2 sc, float dy) {
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
float inBar(Image tex, vec2 t, vec2 sc) {
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
float goesDark(Image tex, vec2 tc, vec2 sc, vec2 d) {
  vec3 c = nbTex(tex, tc, sc, d);
  vec2 at = nbAt(sc, d);
  vec2 p = (at - uiOrigin) / uiSize;
  if (p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) return 0.0;
  float inBox = 0.0;
  if (boxesOn > 0.5) {
    vec2 b = (at - keepOrigin) / keepSize;
    if (b.x >= 0.0 && b.y >= 0.0 && b.x < 1.0 && b.y < 1.0) inBox = Texel(boxes, b).a;
  }
  float region = boxesOn > 0.5 ? max(inBox, bandToo * step(bandTop, p.y)) : (gba > 0.5 ? inBox : step(bandTop, p.y));
  return paperish(c) * Texel(ui, p).a * region * (1.0 - keptAt(at));
}
// whether a light pixel near this one stays light (a picture's white, the
// battle's scenery, a pale box): a letter beside it stays dark, readable.
// (On the GBA games only near-white counts: a letter's own shadow is a
// light grey)
float staysLight(Image tex, vec2 tc, vec2 sc, vec2 d) {
  vec3 c = nbTex(tex, tc, sc, d);
  float light = step(gba > 0.5 ? 0.9 : 0.6, dot(c, vec3(0.299, 0.587, 0.114)));
  // (not a frame's own kept white, or a picture's: a letter right under a
  // window's edge would keep its top row dark, cut off)
  return light * (1.0 - goesDark(tex, tc, sc, d)) * (1.0 - keptAt(nbAt(sc, d)));
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec4 c = Texel(tex, tc);
  vec3 o = c.rgb;
  if (paperOn > 0.5) {
    // the menus' own pixels: where the UI layer is drawn, white or nearly
    // (a palette's paper can be a touch off-white), and not a colour
    vec2 p = (sc - uiOrigin) / uiSize;
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
        vec2 b = (sc - keepOrigin) / keepSize;
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
      if (paperDark > 0.5 && w > 0.5 && gba < 0.5 && lite < 0.5) {
        for (int i = 0; i < 8; i++) {
          vec3 c = nbTex(tex, tc, sc, around(i));
          float chi = max(c.r, max(c.g, c.b));
          float clo = min(c.r, min(c.g, c.b));
          float black = step(dot(c, vec3(0.299, 0.587, 0.114)), 0.2) * (1.0 - smoothstep(0.08, 0.14, chi - clo));
          // (not the paper's own colour: COLORS' field, behind the HUDs. Only
          // near it: Yellow's black, 25, 25, 25, is close to DARK) -Elvie
          black *= step(0.03, distance(c, paper));
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
        // (POTATO: a black touching the paper's ground on one side is a
        // letter, with only its four next pixels looked at. A black with no
        // paper beside it, a screen wipe's or a battle's dark, stays) -Elvie
        if (lite > 0.5) {
          if (step(l, 0.2) * (1.0 - smoothstep(0.08, 0.14, hi - lo)) * region * step(0.03, distance(before, paper)) > 0.5) {
            float touch = 0.0;
            for (int i = 0; i < 4; i++) touch = max(touch, goesDark(tex, tc, sc, around(i)));
            if (touch > 0.5) o = vec3(0.93, 0.93, 0.94);
          }
        } else if (step(l, 0.2) * (1.0 - smoothstep(0.08, 0.14, hi - lo)) * region * step(0.03, distance(before, paper)) > 0.5
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
        if (lite > 0.5) {
          if ((text + shade) * (1.0 - smoothstep(0.08, 0.14, hi - lo)) * Texel(ui, p).a > 0.5 && inBox > 0.5 && keptAt(sc) < 0.5)
            o = text > 0.5 ? vec3(0.93, 0.93, 0.94) : mix(paper, vec3(0.93), 0.22);
        } else if ((text + shade) * (1.0 - smoothstep(0.08, 0.14, hi - lo)) * Texel(ui, p).a > 0.5
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
  // MAP TIME: the map in the hour's light, where no menu is drawn over it
  if (mapTintOn > 0.5) {
    vec2 mp = (sc - uiOrigin) / uiSize;
    float menu = 0.0;
    if (mp.x >= 0.0 && mp.y >= 0.0 && mp.x < 1.0 && mp.y < 1.0) menu = Texel(ui, mp).a;
    o = mix(o * mapTint, o, menu);
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

filter.boxRects = {}

-- What the options ask for: look, where, dots, shades, paper. -Elvie
function filter.settings(get)
  return valueOf(filter.LOOKS, get("filter"), "off"), valueOf(filter.WHERE, get("filterOn"), "screen"),
    valueOf(filter.DOTS, get("dots"), "off"), valueOf(filter.STEPS, get("shades"), "4"),
    valueOf(filter.PAPERS, get("paper"), "off")
end

-- Whether the whole-screen pass has anything to do. -Elvie
function filter.screenOn(look, where, dots, _, paper)
  return (look ~= "off" and where == "screen") or dots == "on" or (paper ~= nil and paper ~= "off")
    -- (MAP TIME on Red, Blue and Yellow is drawn in the pass too) -Elvie
    or (type(filter.mapTimeWanted) == "function" and filter.mapTimeWanted() or false)
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
  -- Whether Red to Crystal's opening is showing: the intro movie, the
  -- title and Oak's speech (and naming from it). PAPER leaves them be, as
  -- the GBA games' -Elvie
  local introKinds
  local function introShowing(game)
    if not introKinds then
      introKinds = {}
      for _, name in ipairs({ "src.ui.IntroMovie", "src.ui.YellowIntro", "src.ui.TitleState", "src.ui.OakSpeech",
          "src.ui.gen2.CrystalIntro", "src.ui.gen2.GoldSilverIntro", "src.ui.gen2.IntroFade",
          "src.ui.gen2.CopyrightSplash", "src.ui.gen2.GameFreakPresents", "src.ui.gen2.CrystalSplash",
          "src.ui.gen2.TitleState", "src.ui.gen2.OakSpeech" }) do
        local ok, m = pcall(require, name)
        if ok and type(m) == "table" then introKinds[m] = true end
      end
    end
    local stack = type(game) == "table" and rawget(game, "stack")
    local states = type(stack) == "table" and rawget(stack, "states")
    if type(states) ~= "table" then return false end
    for _, st in ipairs(states) do
      local mt = type(st) == "table" and getmetatable(st)
      if mt and (introKinds[mt] or (type(mt.__index) == "table" and introKinds[mt.__index])) then return true end
    end
    return false
  end
  -- DARK's pictures this frame: a copy the size of what they were drawn
  -- on (keep), and where that sits on screen -Elvie
  local pics = { keep = nil, drawn = false, fresh = false, origin = nil, size = nil,
    boxes = nil, boxesDrawn = false, boxesFresh = false }
  -- The copies, one for each size of thing drawn on in a frame (the
  -- game's own screen, a battle's canvas, the window), made once and
  -- kept: a frame that draws on two sizes no longer makes a new copy each
  -- time it goes from one to the other, which ran small devices out of
  -- memory (a crash on entering a battle) and lost what the first had
  -- kept (letters flashing, sprites patched dark). The pass picks the one
  -- the size of the screen it reads -Elvie
  local keepPool, boxesPool = {}, {}
  local function poolEntry(pool, target, make)
    if not target then return nil end
    local w, h = target:getDimensions()
    local dpi = target:getDPIScale()
    local key = w .. "x" .. h .. "@" .. dpi
    local e = pool[key]
    if not e and make then
      local ok, c = pcall(love.graphics.newCanvas, w, h, { dpiscale = dpi })
      if not ok or not c then return nil end
      e = { canvas = c, fresh = false, drawn = false, idle = 0 }
      pool[key] = e
    end
    if e then e.idle = 0 end
    return e
  end
  -- the copy the size (in pixels) of pw x ph, if one was drawn on -Elvie
  local function poolMatch(pool, pw, ph)
    for _, e in pairs(pool) do
      if e.canvas:getPixelWidth() == pw and e.canvas:getPixelHeight() == ph then return e end
    end
    return nil
  end
  -- after the pass: every copy starts afresh next frame, and one not
  -- drawn on for a while (a size gone, the window resized) is let go -Elvie
  local function poolReset(pool)
    for key, e in pairs(pool) do
      e.fresh, e.drawn, e.ops = false, false, {}
      e.idle = e.idle + 1
      if e.idle > 600 then
        pcall(function() e.canvas:release() end)
        pool[key] = nil
      end
    end
  end
  -- the copy of target's size, cleared once a frame, to draw on -Elvie
  -- What's kept is written down as it's drawn and put on the copies in
  -- one go, just before the pass reads them: going to a copy and back for
  -- each letter and picture (dozens of times a frame) tripled a battle's
  -- cost, on a small device a slideshow -Elvie
  local function keepOn(target)
    local e = poolEntry(keepPool, target, true)
    if e and not e.fresh then
      e.fresh, e.needClear, e.ops = true, true, {}
    end
    return e
  end
  -- the transform now, as a Transform -Elvie
  local function transformNow()
    local G = love.graphics
    local a, b = G.transformPoint(0, 0)
    local c, d = G.transformPoint(1, 0)
    local e, f = G.transformPoint(0, 1)
    local t = love.math.newTransform()
    t:setMatrix(c - a, e - a, 0, a, d - b, f - b, 0, b, 0, 0, 1, 0, 0, 0, 0, 1)
    return t
  end
  -- writes down one thing to keep (or, erase, to take away) on e -Elvie
  local function keepOp(e, op)
    op.tf = transformNow()
    op.sc = op.noScissor and false or { love.graphics.getScissor() }
    e.ops[#e.ops + 1] = op
  end
  -- puts everything written down on the copies -Elvie
  local function keepFlush()
    local G = love.graphics
    for _, pool in ipairs({ keepPool, boxesPool }) do
    for _, e in pairs(pool) do
      if e.needClear or (e.ops and #e.ops > 0) then
        G.push("all")
        G.setCanvas(e.canvas)
        G.origin()
        G.setShader()
        if e.needClear then G.clear(0, 0, 0, 0); e.needClear = false end
        for _, op in ipairs(e.ops or {}) do
          G.replaceTransform(op.tf)
          if op.sc and op.sc[1] then G.setScissor(op.sc[1], op.sc[2], op.sc[3], op.sc[4]) else G.setScissor() end
          if op.erase then
            G.setBlendMode("replace", "premultiplied")
            G.setColor(0, 0, 0, 0)
          else
            G.setBlendMode("alpha")
            G.setColor(1, 1, 1, 1)
          end
          if op.rect then
            G.rectangle("fill", op.rect[1], op.rect[2], op.rect[3], op.rect[4])
          elseif op.draw then
            pcall(op.draw, unpack(op.args, 1, op.n))
          end
        end
        e.ops = {}
        G.pop()
      end
    end
    end
  end
  -- Gold, Silver and Crystal draw the map and the menus into one picture,
  -- so PAPER keeps its own copy of the menus drawn over the map (gen2Mask,
  -- from start below); with no map, the whole picture is menus -Elvie
  local gen2Mask, gen2Drawn, gen2Game, whole = nil, false, nil, nil
  local gen2Masks = nil
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
    -- a phone's driver may drop a value the shader doesn't strictly need,
    -- and sending to one it dropped is an error: only what's there -Elvie
    local function send(name, ...)
      if sh:hasUniform(name) then sh:send(name, ...) end
    end
    if slot ~= "map" then keepFlush() end
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
      send("s" .. (i - 1), { c[1] / 255, c[2] / 255, c[3] / 255 })
    end
    send("mode", filter.SHADES[look] and 1 or look == "gbc" and 2 or 0)
    send("cut", filter.CUTS)
    send("steps", tonumber(steps) or 4)
    send("levels", filter.GBC_LEVELS)
    send("sat", filter.GBC_SATURATION)
    send("dots", dots and 1 or 0)
    send("dotShade", filter.DOT_SHADE)
    send("cell", grid.cell)
    send("origin", grid.origin)
    local tint = paper and filter.PAPER[paper]
    local mt = slot == "screen" and filter.mapTintNow or nil
    if mt and layer.canvas then
      send("mapTintOn", 1)
      send("mapTint", { mt[1], mt[2], mt[3] })
      send("ui", layer.canvas)
      send("uiOrigin", layer.origin)
      send("uiSize", layer.size)
    else
      send("mapTintOn", 0)
    end
    if tint and layer.canvas then
      send("paperOn", 1)
      send("paper", { tint[1] / 255, tint[2] / 255, tint[3] / 255 })
      send("ui", layer.canvas)
      send("uiOrigin", layer.origin)
      send("uiSize", layer.size)
    else
      send("paperOn", 0)
    end
    send("paperDark", filter.isDark(paper) and 1 or 0)
    send("lite", get("paperDetail") == "light" and 1 or 0)
    send("bandTop", filter.boxed(paper) and layer.band or 0)
    send("gba", layer.gen == 3 and 1 or 0)
    send("bandToo", layer.gen == 2 and 1 or 0)
    -- a game pixel, in screen pixels, and the screen's size, so the look
    -- round lands on the middle of each game pixel and not between them,
    -- where black and white would blend -Elvie
    local sw, shh = src:getPixelDimensions()
    send("cellF", math.max(1, tonumber(layer.cell) or 1))
    send("srcPx", { math.max(1, sw), math.max(1, shh) })
    -- (a strong light paper: only in a battle, on every game; the GBA
    -- games' own menus outside one take it as any light paper) -Elvie
    local boxedNow = filter.isDark(paper) and (layer.band > 0 or layer.gen == 3)
      or filter.STRONG[paper] and layer.band > 0
    if tint and boxedNow and pics.boxes and pics.boxesDrawn and pics.origin then
      send("boxesOn", 1)
      send("boxes", pics.boxes)
    else
      send("boxesOn", 0)
    end
    if pics.origin then
      send("keepOrigin", pics.origin)
      send("keepSize", pics.size)
    end
    if tint and layer.canvas and pics.keep and pics.drawn and pics.origin then
      send("keepOn", 1)
      send("keep", pics.keep)
      send("keepOrigin", pics.origin)
      send("keepSize", pics.size)
    else
      send("keepOn", 0)
    end
    -- the next frame's pictures start afresh (the game can draw one after
    -- render.compose, so this waits till the pass has used them) -Elvie
    -- PAPER's new pictures written out a few seconds after the last one
    -- was made, in one go, so a crash or a quit doesn't lose them -Elvie
    if filter.paperPutAt and love.timer and love.timer.getTime() - filter.paperPutAt > 3 then
      filter.paperPutAt = nil
      local disk = require("mods.facets.diskcache")
      if disk.dirty() then pcall(disk.flush) end
    end
    if slot ~= "map" then
      poolReset(keepPool)
      poolReset(boxesPool)
      pics.drawn, pics.boxesDrawn = false, false
    end
    filter.boxRects = {}
    if slot ~= "map" and filter.ownedReset then filter.ownedReset() end
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
      if not filter.screenOn(look, where, dots, steps, paper) and not filter.mapTintNow then return input end
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
  -- MAP TIME's light for Red, Blue and Yellow's map now, or nil: on the
  -- outdoor maps only (as Gold, Silver and Crystal's houses and caves keep
  -- their colours), read once a second. Morning a soft gold, evening a
  -- rose, night a deep blue, a little lighter than the battle scenes'
  -- so the map still reads -Elvie
  filter.MAP_LIGHT = { MORN = { 1, 0.94, 0.84 }, EVE = { 0.97, 0.8, 0.74 }, NITE = { 0.58, 0.64, 0.9 } }
  filter.MAP_OUTDOORS = { OVERWORLD = true, PLATEAU = true }
  local mapAt, mapTint = -1, nil
  filter.mapTimeWanted = function() return get("mapTime") == "on" end
  function filter.mapLight()
    if get("mapTime") ~= "on" then return nil end
    local now = os.time()
    if now == mapAt then return mapTint end
    mapAt, mapTint = now, nil
    local tiles
    pcall(function()
      local ow = require("src.world.WorldAPI").new(mod.game):overworld()
      local def = type(ow) == "table" and type(ow.map) == "table" and ow.map.def or nil
      tiles = def and def.tileset
    end)
    if not filter.MAP_OUTDOORS[tostring(tiles)] then return nil end
    local okS, sc = pcall(require, "mods.facets.classic_scenes")
    local daytime = okS and type(sc.daytime) == "function" and sc.daytime(tonumber(os.date("%H"))) or "DAY"
    mapTint = filter.MAP_LIGHT[daytime]
    return mapTint
  end
  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("render.compose", function(nextFn, renderer, ctx)
      if type(filter.precacheStep) == "function" then pcall(filter.precacheStep) end
      if type(ctx) == "table" then
        grid.cell, grid.origin = filter.gridFor(ctx)
        -- where the menus' layer goes in the window, in its units, for
        -- BORDERS: FILL to line its scene up with (classic_scenes) -Elvie
        do
          local o, sz = filter.uiRectFor(ctx)
          local dx, dy = tonumber(ctx.dpiX) or 1, tonumber(ctx.dpiY) or tonumber(ctx.dpiX) or 1
          filter.uiPlace = o and ctx.uiCanvas and { canvas = ctx.uiCanvas, x = o[1] / dx, y = o[2] / dy,
            w = sz[1] / dx, h = sz[2] / dy, at = love.timer and love.timer.getTime() or 0 } or nil
        end
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
        if ctx.generation == 1 or ctx.generation == 2 then
          local g = ctx.generation == 1 and package.loaded["src.core.Game"] or renderer
          filter.introNow = introShowing(g)
          if filter.introNow then canvas = nil end
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
        -- (and a strong light paper the same, GAME WOOD's DARK GOLD) -Elvie
        if canvas and filter.boxed(select(5, filter.settings(get))) and filter.BATTLE_BOX[gen] then
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
        pics.keep, pics.drawn, pics.boxes, pics.boxesDrawn = nil, false, nil, false
        do
          -- the copies the size of the screen the pass reads: the whole
          -- picture on Gold to Crystal (a battle draws its Pokémon on a
          -- canvas of its own first), the UI layer on Red to Emerald -Elvie
          local scene = ctx.sceneCanvas
          local read = nil
          if ctx.generation == 2 then read = scene
          elseif canvas == ctx.uiCanvas then read = canvas end
          if read then
            local kw, kh = read:getPixelDimensions()
            local ke, be = poolMatch(keepPool, kw, kh), poolMatch(boxesPool, kw, kh)
            if ke then pics.keep, pics.drawn = ke.canvas, ke.drawn end
            if be then pics.boxes, pics.boxesDrawn = be.canvas, be.drawn end
            if ke or be then
              if ctx.generation == 2 then pics.origin, pics.size = { 0, 0 }, { kw, kh }
              else pics.origin, pics.size = origin, size end
            end
          end
        end
        local look, where, _, steps = filter.settings(get)
        local world = ctx.worldOverride or ctx.worldCanvas
        -- MAP TIME: the map's light now, for the pass -Elvie
        filter.mapTintNow = ctx.generation == 1 and ctx.worldActive and filter.mapLight() or nil
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
  -- For small devices: PAPER DETAIL: POTATO skips dark paper's look round
  -- each letter (its outline, and telling a letter from a picture's dark
  -- by what's round it); PRECACHE makes PAPER's pictures ahead, a little
  -- each frame, and keeps them on the install -Elvie
  rows[#rows + 1] = { key = "paperDetail", type = "choice", label = "  PAPER DETAIL",
    choices = { { "FULL", "full" }, { "POTATO", "light" } }, default = "full" }
  rows[#rows + 1] = { key = "paperPrecache", type = "choice", label = "  PRECACHE",
    choices = { { "OFF", "off" }, { "ON", "on" } }, default = "off" }
  -- MAP TIME: Red, Blue and Yellow's outdoor maps in the light of the
  -- hour, as Gold, Silver and Crystal's are, by your clock -Elvie
  local okCl, Cl = pcall(require, "mods.facets.classic")
  if okCl and type(Cl.generation) == "function" and Cl.generation() == 1 then
    rows[#rows + 1] = { key = "mapTime", type = "choice", label = "MAP TIME",
      choices = { { "OFF", "off" }, { "ON", "on" } }, default = "off" }
  end

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
        if get("mapTime") == "on" then mod.options:set("mapTime", "off") end
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
          -- (one kept for each size, as the keeps are) -Elvie
          local key = w .. "x" .. h .. "@" .. dpi
          gen2Masks = gen2Masks or {}
          if not gen2Masks[key] then
            local ok, made = pcall(G.newCanvas, w, h, { dpiscale = dpi })
            gen2Masks[key] = ok and made or nil
          end
          gen2Mask = gen2Masks[key]
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
            local ke = poolMatch(keepPool, pw, ph)
            if ke then
              pics.keep, pics.drawn = ke.canvas, ke.drawn
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
        -- (filter.swapNow: a GBA game's own window drawn on PAPER, its
        -- frame art with its paper map in the paper's colour) -Elvie
        if filter.swapNow and type(drawable) == "userdata" and filter.swapImg then
          drawable = filter.swapImg(drawable) or drawable
        end
        -- (filter.inkBar: an HP bar's tile in a window drawn dark) -Elvie
        if filter.inkBar and type(drawable) == "userdata" and drawable.typeOf and drawable:typeOf("Texture") then
          -- (not while the variants are made: that draws too) -Elvie
          local bar = filter.inkBar
          filter.inkBar = nil
          local lines, fill = filter.barInked(drawable, bar)
          filter.inkBar = bar
          if lines and fill then
            local sh = G.getShader and G.getShader() or nil
            local r, g, b, a = G.getColor()
            if sh then G.setShader() end
            G.setColor(1, 1, 1, a)
            ownDraw(lines, x, ...)
            G.setColor(r, g, b, a)
            ownDraw(fill, x, ...)
            G.setColor(r, g, b, a)
            if sh then G.setShader(sh) end
            return
          end
        end
        -- (filter.inkNow: a letter in a window drawn dark, in its dark
        -- colours, as they are: no palette shader over it) -Elvie
        if filter.inkNow and type(drawable) == "userdata" and drawable.typeOf and drawable:typeOf("Texture") then
          local cr, cg, cb = G.getColor()
          local inked = filter.inked(drawable, 0.299 * cr + 0.587 * cg + 0.114 * cb < 0.5, filter.inkNow)
          if inked then
            local sh = G.getShader and G.getShader() or nil
            local r, g, b, a = G.getColor()
            if sh then G.setShader() end
            G.setColor(1, 1, 1, a)
            ownDraw(inked, x, ...)
            G.setColor(r, g, b, a)
            if sh then G.setShader(sh) end
            return
          end
        end
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
      -- (keepArt: the same on any paper, for a light paper's window drawn
      -- with its map) -Elvie
      filter.keepDraw = function(img, x, ...)
        if not filter.isDark(select(5, filter.settings(get))) then return end
        return filter.keepArt(img, x, ...)
      end
      filter.keepArt = function(img, x, ...)
        local target = G.getCanvas()
        if not target then return end
        local e = keepOn(target)
        if e then
          keepOp(e, { draw = ownDraw, args = { img, x, ... }, n = 2 + select("#", ...) })
          e.drawn = true
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
        -- (kept on the install, as the paper's other pictures are) -Elvie
        local disk = require("mods.facets.diskcache")
        local h0 = type(filter.hashOf) == "function" and filter.hashOf(data) or nil
        local kept = h0 and disk.get("paper", h0 .. ":frameMask") or nil
        if kept and kept:getWidth() == w and kept:getHeight() == h then
          local m = G.newImage(kept, { dpiscale = img:getDPIScale() })
          m:setFilter("nearest", "nearest")
          return m
        end
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
        if h0 then disk.put("paper", h0 .. ":frameMask", data); filter.paperPutAt = love.timer and love.timer.getTime() or 0 end
        local m = G.newImage(data, { dpiscale = img:getDPIScale() })
        m:setFilter("nearest", "nearest")
        return m
      end)
      frameMasks[img] = ok and out or false
      return frameMasks[img] or nil
    end
    filter.frameMaskOf = frameMask
    filter.keepFrame = function(img, ...)
      if not filter.isDark(select(5, filter.settings(get))) then return end
      return filter.keepDraw(frameMask(img) or img, ...)
    end

    -- DARK, drawn rather than worked out. The windows Facets draws, and
    -- the boxes the game draws through Font.drawBox, are drawn dark to
    -- begin with: the inside in the paper's colour, the frame's inside
    -- white too, and the letters white with a grey outline. Each such
    -- window is "owned" for the frame: kept, so the pass leaves it as
    -- drawn, and its letters are inked as they're drawn -Elvie
    local function paperNow()
      if filter.introNow then return nil end
      local p = select(5, filter.settings(get))
      if not filter.isDark(p) then return nil end
      local t = filter.PAPER[p]
      return { t[1] / 255, t[2] / 255, t[3] / 255 }, p
    end
    filter.paperNow = paperNow
    -- a light PAPER's colour (not WHITE), or nil: for the window art with
    -- a paper map, whose painted part takes it, drawn -Elvie
    local function paperLight()
      if filter.introNow then return nil end
      local p = select(5, filter.settings(get))
      if not p or p == "off" or filter.isDark(p) then return nil end
      local t = filter.PAPER[p]
      if not t then return nil end
      return { t[1] / 255, t[2] / 255, t[3] / 255 }, p
    end
    filter.paperLight = paperLight
    function filter.outlineOf(pp)
      return { pp[1] * 0.78 + 0.93 * 0.22, pp[2] * 0.78 + 0.93 * 0.22, pp[3] * 0.78 + 0.94 * 0.22 }
    end
    -- an image's pixels, read once (drawn to a canvas and read back) -Elvie
    local pixels = setmetatable({}, { __mode = "k" })
    local function pixelsOf(img)
      local got = pixels[img]
      if got ~= nil then return got or nil end
      pixels[img] = false
      local ok, data = pcall(function()
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
        return c:newImageData()
      end)
      pixels[img] = ok and data or false
      return pixels[img] or nil
    end
    local function kindOf(data, x, y, w, h)
      if x < 0 or y < 0 or x >= w or y >= h then return "none" end
      local r, g, b, a = data:getPixel(x, y)
      if a < 0.5 then return "none" end
      local hi, lo = math.max(r, g, b), math.min(r, g, b)
      local l = 0.299 * r + 0.587 * g + 0.114 * b
      if l > 0.8 and hi - lo < 0.07 then return "white" end
      if l < 0.2 and hi - lo < 0.12 then return "black" end
      return "colour"
    end
    -- a variant of an image made once per paper -Elvie
    -- Each is kept on the install too (diskcache, group "paper"), under
    -- its picture's own pixels and what was made of it, so a small device
    -- makes it once, not every start. A new PAPER clears them (below);
    -- a new Facets or gen1recomp starts afresh -Elvie
    local disk = require("mods.facets.diskcache")
    disk.always("paper")
    disk.ensure(mod)
    -- written out at the same moments PREBUILD writes, on every game -Elvie
    if mod.events and type(mod.events.on) == "function" then
      local function flush() if disk.dirty() then pcall(disk.flush) end end
      mod.events:on("map.entered", flush)
      mod.events:on("battle.ended", flush)
      mod.events:on("save.writing", flush)
      -- (only for a PAPER that's really new, not one set again) -Elvie
      local paperWas = get("paper")
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id and change.key == "paper" and get("paper") ~= paperWas then
          paperWas = get("paper")
          disk.clearGroup("paper")
        end
      end)
    end
    local hashes = setmetatable({}, { __mode = "k" })
    local function hashOf(data)
      local got = hashes[data]
      if got then return got end
      local ok, h = pcall(function()
        return love.data.encode("string", "hex", love.data.hash("md5", data))
      end)
      hashes[data] = ok and h or false
      return hashes[data] or nil
    end
    filter.hashOf = hashOf
    local variants = setmetatable({}, { __mode = "k" })
    local function variant(img, key, make)
      local per = variants[img]
      if not per then per = {}; variants[img] = per end
      if per[key] ~= nil then return per[key] or nil end
      per[key] = false
      local data = pixelsOf(img)
      if not data then return nil end
      local ok, out = pcall(function()
        local h = hashOf(data)
        local diskKey = h and (h .. ":" .. key) or nil
        local d = diskKey and disk.get("paper", diskKey) or nil
        if d and (d:getWidth() ~= data:getWidth() or d:getHeight() ~= data:getHeight()) then d = nil end
        if not d then
          d = data:clone()
          make(d, data, d:getWidth(), d:getHeight())
          if diskKey then disk.put("paper", diskKey, d); filter.paperPutAt = love.timer and love.timer.getTime() or 0 end
        end
        local m = love.graphics.newImage(d, { dpiscale = img:getDPIScale() })
        m:setFilter("nearest", "nearest")
        return m
      end)
      per[key] = ok and out or false
      return per[key] or nil
    end
    -- frame art drawn dark: the white inside it (white not beside one of
    -- the frame's colours) is the paper's colour -Elvie
    -- (also: a colour of its own inside, { r, g, b } 0-1, a text box's
    -- fill, taken as its white) -Elvie
    -- an art file's own paper map (<art>.paper.png, painted by hand: white
    -- where the paper's colour goes), registered as the art is loaded.
    -- Where there's a map it alone says what's paper -Elvie
    local artMasks = setmetatable({}, { __mode = "k" })
    function filter.setArtMask(img, data)
      if type(img) == "userdata" and type(data) == "userdata" then artMasks[img] = data end
    end
    function filter.hasArtMask(img)
      return type(img) == "userdata" and artMasks[img] ~= nil
    end
    local function maskArt(img, pp, key)
      local mask = artMasks[img]
      return variant(img, "mask:" .. key .. ":" .. tostring(hashOf(mask)), function(d, src, w, h)
        local mw, mh = mask:getWidth(), mask:getHeight()
        for y = 0, math.min(h, mh) - 1 do
          for x = 0, math.min(w, mw) - 1 do
            local _, _, _, a = mask:getPixel(x, y)
            if a > 0.5 then d:setPixel(x, y, pp[1], pp[2], pp[3], 1) end
          end
        end
      end) or img
    end
    -- the art with its paper map in a light paper's colour, or nil when
    -- there's no map or no light paper -Elvie
    function filter.paperArt(img)
      local lp, key = paperLight()
      if not lp or not filter.hasArtMask(img) then return nil end
      return maskArt(img, lp, key)
    end
    -- the art in the paper on now (dark or light) when it has a map -Elvie
    function filter.swapImg(img)
      if not artMasks[img] then return nil end
      local pp, key = paperNow()
      if not pp then pp, key = paperLight() end
      if not pp then return nil end
      return maskArt(img, pp, key)
    end
    function filter.darkArt(img, also)
      local pp, key = paperNow()
      if not pp or type(img) ~= "userdata" then return img end
      if artMasks[img] then return maskArt(img, pp, key) end
      local tag = "art:" .. key
      if type(also) == "table" then tag = tag .. (":%.3f,%.3f,%.3f"):format(also[1], also[2], also[3]) end
      local function inside(src, x, y, w, h)
        local k = kindOf(src, x, y, w, h)
        if k == "white" then return true end
        if k == "colour" and type(also) == "table" then
          local r, g, b = src:getPixel(x, y)
          return math.abs(r - also[1]) + math.abs(g - also[2]) + math.abs(b - also[3]) < 0.06
        end
        return false
      end
      return variant(img, tag, function(d, src, w, h)
        for y = 0, h - 1 do
          for x = 0, w - 1 do
            if inside(src, x, y, w, h) then
              local beside = false
              for dy = -1, 1 do
                for dx = -1, 1 do
                  if (dx ~= 0 or dy ~= 0) and kindOf(src, x + dx, y + dy, w, h) == "colour"
                      and not inside(src, x + dx, y + dy, w, h) then beside = true end
                end
              end
              if not beside then d:setPixel(x, y, pp[1], pp[2], pp[3], 1) end
            end
          end
        end
      end) or img
    end
    -- a letter sheet inked: black is white, white (a letter's own paper,
    -- on Gold to Crystal) the paper's colour, grey the outline, and the
    -- see-through beside a letter (in its own 8x8 cell) the outline -Elvie
    -- (tinted: a sheet of white letters drawn in a dark colour, as Red,
    -- Blue and Yellow's are, whose white is the ink) -Elvie
    function filter.inked(img, tinted, pp)
      if type(pp) ~= "table" then pp = paperNow() end
      if not pp then return nil end
      local key = ("%.3f,%.3f,%.3f"):format(pp[1], pp[2], pp[3])
      local ol = filter.outlineOf(pp)
      local function kindAt(src, x, y, w, h)
        local k = kindOf(src, x, y, w, h)
        if tinted and k ~= "none" then return "black" end
        return k
      end
      return variant(img, (tinted and "inkT:" or "ink:") .. key, function(d, src, w, h)
        for y = 0, h - 1 do
          for x = 0, w - 1 do
            local k = kindAt(src, x, y, w, h)
            if k == "black" then d:setPixel(x, y, 0.93, 0.93, 0.94, 1)
            elseif k == "white" then d:setPixel(x, y, pp[1], pp[2], pp[3], 1)
            elseif k == "none" then
              local cx, cy, near = math.floor(x / 8), math.floor(y / 8), false
              for dy = -1, 1 do
                for dx = -1, 1 do
                  local nx, ny = x + dx, y + dy
                  if math.floor(nx / 8) == cx and math.floor(ny / 8) == cy and kindAt(src, nx, ny, w, h) == "black" then near = true end
                end
              end
              if near then d:setPixel(x, y, ol[1], ol[2], ol[3], 1) end
            else
              local r, g, b = src:getPixel(x, y)
              local l = 0.299 * r + 0.587 * g + 0.114 * b
              if math.max(r, g, b) - math.min(r, g, b) < 0.1 then d:setPixel(x, y, ol[1], ol[2], ol[3], 1)
              elseif l < 0.45 then d:setPixel(x, y, r, g, b, 1) end
            end
          end
        end
      end)
    end
    -- Red, Blue and Yellow's HP bar tiles inked: (1) black white, white
    -- (the bar's empty part) a grey well lighter than the paper, so what's
    -- lost reads, and its grey fill left out; (2) the grey fill alone, to
    -- be drawn in the bar's colour as the game tints it, lifted -Elvie
    function filter.barInked(img, pp)
      if type(pp) ~= "table" then return nil end
      local key = ("%.3f,%.3f,%.3f"):format(pp[1], pp[2], pp[3])
      local function grey(src, x, y, w, h)
        local k = kindOf(src, x, y, w, h)
        if k == "black" or k == "white" or k == "none" then return false, k end
        local r, g, b = src:getPixel(x, y)
        return math.max(r, g, b) - math.min(r, g, b) < 0.1, k
      end
      local lines = variant(img, "barA:" .. key, function(d, src, w, h)
        for y = 0, h - 1 do
          for x = 0, w - 1 do
            local isGrey, k = grey(src, x, y, w, h)
            if k == "black" then d:setPixel(x, y, 0.93, 0.93, 0.94, 1)
            elseif k == "white" then
              d:setPixel(x, y, pp[1] + (0.93 - pp[1]) * 0.35, pp[2] + (0.93 - pp[2]) * 0.35, pp[3] + (0.94 - pp[3]) * 0.35, 1)
            elseif isGrey then d:setPixel(x, y, 0, 0, 0, 0) end
          end
        end
      end)
      local fill = variant(img, "barF", function(d, src, w, h)
        for y = 0, h - 1 do
          for x = 0, w - 1 do
            -- (at full: drawn in the bar's colour, it comes out at the
            -- colour itself, not a third of it, so it reads on the dark) -Elvie
            if grey(src, x, y, w, h) then d:setPixel(x, y, 1, 1, 1, 1) else d:setPixel(x, y, 0, 0, 0, 0) end
          end
        end
      end)
      return lines, fill
    end
    -- PRECACHE: what PAPER makes for the settings now, made ahead, a few
    -- milliseconds a frame, and kept on the install (variant above), so a
    -- small device doesn't stall the first time a window or a battle comes
    -- up. The parts that draw windows each say what they'll draw
    -- (filter.precacheAdd); the fonts are filter's own -Elvie
    filter.precacheProviders = filter.precacheProviders or {}
    function filter.precacheAdd(fn)
      if type(fn) == "function" then filter.precacheProviders[#filter.precacheProviders + 1] = fn end
    end
    -- Red to Crystal's letter sheets, as the game loads them -Elvie
    filter.precacheAdd(function()
      if gen ~= 1 and gen ~= 2 then return {} end
      local okA, Assets = pcall(require, "src.render.Assets")
      if not (okA and type(Assets) == "table" and type(Assets.image) == "function") then return {} end
      local out = {}
      for _, rel in ipairs({ "font.png", "font_extra.png", "font_battle_extra.png", "frames.png", "bold_p.png" }) do
        local ok, img = pcall(Assets.image, "assets/generated/fonts/" .. rel)
        if ok and img then out[#out + 1] = { img = img, font = true } end
      end
      return out
    end)
    local queue, queueAt = nil, 0
    filter.precacheTotal, filter.precacheDone = 0, 0
    function filter.precacheStart()
      queue, queueAt = {}, 0
      local pp = paperNow()
      local lp = paperLight()
      if not (pp or lp) then filter.precacheTotal, filter.precacheDone = 0, 0; return end
      for _, provider in ipairs(filter.precacheProviders) do
        local ok, items = pcall(provider)
        for _, it in ipairs(ok and type(items) == "table" and items or {}) do
          local img = it.img
          if type(img) == "userdata" then
            if it.font then
              if pp then
                queue[#queue + 1] = function() filter.inked(img, true, pp) end
                queue[#queue + 1] = function() filter.inked(img, false, pp) end
              end
            else
              if pp then
                queue[#queue + 1] = function() filter.darkArt(img, it.also) end
                queue[#queue + 1] = function() frameMask(img) end
              elseif lp and filter.hasArtMask(img) then
                queue[#queue + 1] = function() filter.paperArt(img) end
              end
            end
          end
        end
      end
      filter.precacheTotal, filter.precacheDone = #queue, 0
    end
    function filter.precacheStep(budget)
      if not queue then return end
      local start = os.clock()
      repeat
        queueAt = queueAt + 1
        local unit = queue[queueAt]
        if not unit then break end
        queue[queueAt] = nil
        pcall(unit)
        filter.precacheDone = math.min(queueAt, #queue)
      until os.clock() - start >= (budget or 0.004)
      if queueAt >= #queue then
        queue = nil
        if disk.dirty() then pcall(disk.flush) end
      end
    end
    -- started with the game, and again for a new PAPER or new windows -Elvie
    if mod.events and type(mod.events.on) == "function" then
      local WATCH = { paper = true, paperPrecache = true, classicWindows = true, classicTextBox = true,
        gbcFrame = true, gbcTextBox = true }
      local function maybe()
        if get("paperPrecache") == "on" then filter.precacheStart() end
      end
      mod.events:on("game.ready", maybe)
      mod.events:on("map.entered", function()
        if get("paperPrecache") == "on" and filter.precacheTotal == 0 and not queue then maybe() end
      end)
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id and WATCH[change.key] then maybe() end
      end)
    end

    -- the windows owned this frame: { canvas, x0, y0, x1, y1 } in the
    -- pixels of what they're drawn on -Elvie
    local owned = {}
    filter.ownedReset = function() owned = {} end
    local function targetOf()
      local c = love.graphics.getCanvas()
      if type(c) == "table" then c = c[1] and (c[1].texture or c[1]) end
      return c
    end
    -- Owns a window (x, y, w, h in what's being drawn on, under the current
    -- transform): kept, and its letters inked. False when not dark -Elvie
    -- (colour: the window's own inside, { r, g, b } 0-1, for a dark
    -- window of its own whatever PAPER is; the paper's when not given)
    -- (tiles: nothing kept now; what's drawn in it keeps its own tiles, for
    -- a HUD with the battle showing between its parts) -Elvie
    -- (light: a light paper's window, kept as drawn, its letters left
    -- black; "black": a window in a strong colour of its own that reads
    -- best with black letters, GAME WOOD's DARK GOLD, whose letters are
    -- inked black on the GBA games, where the game's are grey with a light
    -- shadow) -Elvie
    function filter.own(x, y, w, h, colour, tiles, light)
      local pp = type(colour) == "table" and colour or paperNow()
      if not pp or not (tonumber(x) and tonumber(w)) then return false end
      local G = love.graphics
      local target = targetOf()
      if not target then return false end
      local x0, y0 = G.transformPoint(x, y)
      local x1, y1 = G.transformPoint(x + w, y + h)
      owned[#owned + 1] = { target, math.min(x0, x1), math.min(y0, y1), math.max(x0, x1), math.max(y0, y1), pp, tiles or nil, light or nil }
      if filter.keepRect and not tiles then filter.keepRect(x, y, w, h) end
      return true
    end
    -- Lets go of what was owned inside x, y, w, h (a box Font.drawBox's wrap
    -- owned that a window set then draws in its own colour) -Elvie
    function filter.disown(x, y, w, h)
      if #owned == 0 or not (tonumber(x) and tonumber(w)) then return end
      local G = love.graphics
      local target = targetOf()
      local x0, y0 = G.transformPoint(x, y)
      local x1, y1 = G.transformPoint(x + w, y + h)
      x0, x1 = math.min(x0, x1) - 1, math.max(x0, x1) + 1
      y0, y1 = math.min(y0, y1) - 1, math.max(y0, y1) + 1
      for i = #owned, 1, -1 do
        local o = owned[i]
        if o[1] == target and o[2] >= x0 and o[3] >= y0 and o[4] <= x1 and o[5] <= y1 then table.remove(owned, i) end
      end
      -- and when it sits inside a dark window (PINK WOOD on the FACETS
      -- page), it's a light hole in that one: its letters stay as drawn -Elvie
      for i = #owned, 1, -1 do
        local o = owned[i]
        if o[1] == target and o[6] and o[2] <= x0 + 1 and o[3] <= y0 + 1 and o[4] >= x1 - 1 and o[5] >= y1 - 1 then
          owned[#owned + 1] = { target, x0 + 1, y0 + 1, x1 - 1, y1 - 1, false }
          break
        end
      end
    end
    -- the owned window's colour at x, y, or nil; and true when what's drawn
    -- there keeps its own tiles -Elvie
    function filter.ownedAt(x, y)
      if #owned == 0 then return nil end
      local target = targetOf()
      local sx, sy = love.graphics.transformPoint(x, y)
      for i = #owned, 1, -1 do
        local o = owned[i]
        if o[1] == target and sx >= o[2] and sy >= o[3] and sx < o[4] and sy < o[5] then return o[6] or nil, o[7], o[8] end
      end
      return nil
    end
    -- whether pixel x, y of canvas target (its own pixels) is in a window
    -- owned there -Elvie
    function filter.ownedOn(target, x, y)
      for i = #owned, 1, -1 do
        local o = owned[i]
        if o[1] == target and x >= o[2] and y >= o[3] and x < o[4] and y < o[5] then return o[6] and true or false end
      end
      return false
    end
    -- the keep, for a whole rectangle -Elvie
    filter.keepRect = function(x, y, w, h)
      local G = love.graphics
      local target = G.getCanvas()
      if not target then return end
      local e = keepOn(target)
      if not e then return end
      keepOp(e, { rect = { x, y, w, h }, noScissor = true })
      e.drawn = true
    end

    -- DARK in Red, Blue and Yellow's battles: the game's own boxes (the HP
    -- boxes, the text box) go dark with the text box, so where each box is
    -- drawn is kept on a copy the size of what it's drawn on -Elvie
    -- Marks a box (x, y, w, h, in the pixels of what's being drawn on) as
    -- paper DARK may darken, on a copy the size of what it's drawn on -Elvie
    -- the boxes marked this frame, in the pixels of what they're on, for
    -- keepScene -Elvie
    -- A battle scene drawn on what's being drawn on, all of it: kept, so
    -- PAPER leaves the scene's own white (snow, clouds) as painted, but
    -- not the boxes marked on it this frame (the game's text box, its HUD
    -- boxes), which are the paper's. Boxes Facets owns keep their own -Elvie
    -- (from: a canvas the battle was drawn into first, at the game's own
    -- size, then copied here under the current transform: Gold, Silver and
    -- Crystal's intro slide and move animations. Its boxes count too) -Elvie
    filter.keepScene = function(from)
      local p = select(5, filter.settings(get))
      if not p or p == "off" then return end
      local G = love.graphics
      local target = G.getCanvas()
      if not target then return end
      local w, h = target:getDimensions()
      local clear = {}
      for _, r in ipairs(filter.boxRects) do
        if from and r[1] == from and not filter.ownedOn(from, r[2] + 1, r[3] + 1) then
          local x0, y0 = G.transformPoint(r[2], r[3])
          local x1, y1 = G.transformPoint(r[4], r[5])
          clear[#clear + 1] = { target, math.min(x0, x1), math.min(y0, y1), math.max(x0, x1), math.max(y0, y1) }
        end
      end
      G.push()
      G.origin()
      filter.keepRect(0, 0, w, h)
      for _, r in ipairs(filter.boxRects) do
        if r[1] == target and not filter.ownedAt(r[2] + 1, r[3] + 1) then clear[#clear + 1] = r end
      end
      local ke = poolEntry(keepPool, target, false)
      if ke and ke.fresh then
        for _, r in ipairs(clear) do
          keepOp(ke, { rect = { r[2], r[3], r[4] - r[2], r[5] - r[3] }, erase = true, noScissor = true })
        end
      end
      G.pop()
    end
    -- (partial: a box with the battle showing between its parts, the HUD's
    -- plates: not kept from a scene drawn after, which shows there) -Elvie
    filter.markPaper = function(x, y, w, h, partial)
      local G = love.graphics
      local target = G.getCanvas()
      if not (target and tonumber(x) and tonumber(w)) then return end
      if not partial then
        local x0, y0 = G.transformPoint(x, y)
        local x1, y1 = G.transformPoint(x + w, y + h)
        filter.boxRects[#filter.boxRects + 1] = { target, math.min(x0, x1), math.min(y0, y1), math.max(x0, x1), math.max(y0, y1) }
      end
      local dark = filter.boxed(select(5, filter.settings(get)))
      -- (both written down and drawn with the keeps, before the pass) -Elvie
      local be = dark and poolEntry(boxesPool, target, true) or nil
      if be then
        if not be.fresh then be.fresh, be.needClear, be.ops = true, true, {} end
        keepOp(be, { rect = { x, y, w, h }, noScissor = true })
        be.drawn = true
      end
      -- a box drawn over a picture covers it: that part of the picture's
      -- copy goes (the move box over your Pokémon, a menu over another
      -- window's frame) -Elvie
      local ke = poolEntry(keepPool, target, false)
      if ke and ke.fresh then
        keepOp(ke, { rect = { x, y, w, h }, erase = true, noScissor = true })
      end
    end

    -- Red to Crystal: every box the game draws (Font.drawBox), marked
    -- before it's drawn, so its own frame's copy stays; the pass uses them
    -- in battles only -Elvie
    local okF, Font = pcall(require, "src.render.Font")
    if (gen == 1 or gen == 2) and okF and type(Font) == "table" and type(Font.drawBox) == "function" and not Font.facetsPaperBoxes then
      Font.facetsPaperBoxes = true
      local ownBox = Font.drawBox
      local okPF, PaletteFX = pcall(require, "src.render.PaletteFX")
      Font.drawBox = function(tx, ty, tw, th, fill, ...)
        if type(tx) == "number" and type(tw) == "number" then filter.markPaper(tx * 8, ty * 8, tw * 8, th * 8) end
        -- DARK: a white box is drawn dark, as it is: its inside the
        -- paper's colour (no palette shader over it) and owned, so its
        -- letters and border are inked. A box of another colour (the
        -- Pokégear's cream) is left to the pass -Elvie
        local pp = paperNow()
        local white = fill == nil or (type(fill) == "table" and (tonumber(fill[1]) or 0) >= 200
          and (tonumber(fill[2]) or 0) >= 200 and (tonumber(fill[3]) or 0) >= 200)
        if pp and white and type(tx) == "number" and type(tw) == "number"
            and filter.own(tx * 8, ty * 8, tw * 8, th * 8) then
          local G = love.graphics
          local sh = G.getShader and G.getShader() or nil
          if sh then G.setShader() end
          local results = { pcall(ownBox, tx, ty, tw, th,
            { math.floor(pp[1] * 255 + 0.5), math.floor(pp[2] * 255 + 0.5), math.floor(pp[3] * 255 + 0.5) }, ...) }
          if sh then G.setShader(sh) end
          -- Red, Blue and Yellow recolour the screen afterwards: the box
          -- keeps its own colours -Elvie
          if gen == 1 and okPF and type(PaletteFX) == "table" and type(PaletteFX.markTrueColor) == "function" then
            pcall(PaletteFX.markTrueColor, tx * 8, ty * 8, tw * 8, th * 8)
          end
          if not results[1] then error(results[2], 0) end
          return unpack(results, 2)
        end
        return ownBox(tx, ty, tw, th, fill, ...)
      end
    end
    -- and their letters (and the border, the cursor), inked where a box is
    -- owned -Elvie
    if (gen == 1 or gen == 2) and okF and type(Font) == "table" and type(Font.drawCode) == "function" and not Font.facetsInk then
      Font.facetsInk = true
      local ownCode = Font.drawCode
      Font.drawCode = function(code, x, y, ...)
        local pp, tiles, light = nil, nil, nil
        if type(x) == "number" and type(y) == "number" then pp, tiles, light = filter.ownedAt(x + 4, y + 4) end
        if not pp or light then
          return ownCode(code, x, y, ...)
        end
        if tiles then filter.keepRect(x, y, 8, 8) end
        local G = love.graphics
        local r, g, b, a = G.getColor()
        if type(code) == "number" and code >= (Font.TTF_BASE or math.huge) then G.setColor(0.93, 0.93, 0.94, a)
        elseif 0.299 * r + 0.587 * g + 0.114 * b >= 0.5 then
          -- (a tile drawn in a light colour is still black, its tiles being
          -- black: PRISM's cursor, drawn in the white the gems left. Inked
          -- as the black it is) -Elvie
          G.setColor(0, 0, 0, a)
        end
        filter.inkNow = pp
        local ok, err = pcall(ownCode, code, x, y, ...)
        filter.inkNow = nil
        G.setColor(r, g, b, a)
        if not ok then error(err, 0) end
      end
    end
    -- Red, Blue and Yellow's HP bar ("HP:", its outline and end) in a
    -- window drawn dark (the wide battle's HUD boxes): inked as the
    -- letters are, white on the dark -Elvie
    local okT, HudTiles = pcall(require, "src.render.HudTiles")
    if okT and type(HudTiles) == "table" and type(HudTiles.drawHPBar) == "function" then
      local ownBar = HudTiles.drawHPBar
      HudTiles.drawHPBar = function(data, tx, ty, ...)
        local pp, _, light = nil, nil, nil
        if type(tx) == "number" and type(ty) == "number" then pp, _, light = filter.ownedAt(tx * 8 + 4, ty * 8 + 4) end
        if not pp or light then return ownBar(data, tx, ty, ...) end
        filter.inkBar = pp
        local ok, err = pcall(ownBar, data, tx, ty, ...)
        filter.inkBar = nil
        if not ok then error(err, 0) end
      end
    end
    -- Gold, Silver and Crystal print their letters on a strip of the
    -- palette's paper: in an owned box that strip is the paper's colour
    -- (the letters themselves are inked as above) -Elvie
    local okC2, Chrome2 = false, nil
    if gen == 2 then okC2, Chrome2 = pcall(require, "src.ui.gen2.Chrome") end
    if okC2 and type(Chrome2) == "table" and type(Chrome2.throughPalette) == "function" and not Chrome2.facetsInk then
      Chrome2.facetsInk = true
      local inking, inkLight = false, false
      local function dark(pal)
        if not inking or type(pal) ~= "table" then return pal end
        local pp = inking
        local out = {}
        for i, v in ipairs(pal) do out[i] = v end
        out[1] = { math.floor(pp[1] * 255 + 0.5), math.floor(pp[2] * 255 + 0.5), math.floor(pp[3] * 255 + 0.5) }
        -- (a light paper's window keeps its black letters) -Elvie
        if not inkLight then out[4] = { 237, 237, 240 } end
        return out
      end
      for _, name in ipairs({ "throughPalette", "rawPalette" }) do
        local ownP = Chrome2[name]
        if type(ownP) == "function" then
          Chrome2[name] = function(...) return dark(ownP(...)) end
        end
      end
      local function atTile(ownF, textFirst)
        return function(...)
          local tx, ty
          if textFirst then tx, ty = select(2, ...) else tx, ty = ... end
          local pp, _, light = nil, nil, nil
          if type(tx) == "number" and type(ty) == "number" then pp, _, light = filter.ownedAt(tx * 8 + 2, ty * 8 + 4) end
          if not pp then
            return ownF(...)
          end
          local was, wasL = inking, inkLight
          inking, inkLight = pp, light or false
          local results = { pcall(ownF, ...) }
          inking, inkLight = was, wasL
          if not results[1] then error(results[2], 0) end
          return unpack(results, 2)
        end
      end
      if type(Chrome2.printThrough) == "function" then Chrome2.printThrough = atTile(Chrome2.printThrough, true) end
      if type(Chrome2.printRightThrough) == "function" then
        local ownR = Chrome2.printRightThrough
        Chrome2.printRightThrough = function(text, txEnd, ty, ...)
          local pp, _, light = nil, nil, nil
          if type(txEnd) == "number" and type(ty) == "number" then pp, _, light = filter.ownedAt(txEnd * 8 - 4, ty * 8 + 4) end
          if not pp then
            return ownR(text, txEnd, ty, ...)
          end
          local was, wasL = inking, inkLight
          inking, inkLight = pp, light or false
          local results = { pcall(ownR, text, txEnd, ty, ...) }
          inking, inkLight = was, wasL
          if not results[1] then error(results[2], 0) end
          return unpack(results, 2)
        end
      end
      if type(Chrome2.cursorThrough) == "function" then Chrome2.cursorThrough = atTile(Chrome2.cursorThrough, false) end
      -- and the text box's letters, placed one by one -Elvie
      if type(Chrome2.paletteGlyphs) == "function" then
        local ownG = Chrome2.paletteGlyphs
        Chrome2.paletteGlyphs = function(...)
          local pal, drawGlyph, finish = ownG(...)
          if not pal then return pal, drawGlyph, finish end
          return pal, function(code, x, y, ...)
            if type(x) == "number" and type(y) == "number" then
              local pp, _, light = filter.ownedAt(x + 4, y + 4)
              if pp and not light then
                Font.drawCode(code, x, y)
                return
              end
            end
            return drawGlyph(code, x, y, ...)
          end, finish
        end
      end
    end
    -- the GBA games: letters in an owned window (Facets' windows) inked,
    -- dark grey (the game's black) to white with a grey shadow; coloured
    -- letters stay -Elvie
    local okFF, FrlgFont = false, nil
    if gen == 3 then okFF, FrlgFont = pcall(require, "src.ui.game3.frlg_font") end
    if okFF and type(FrlgFont) == "table" and type(FrlgFont.draw) == "function" and not FrlgFont.facetsInk then
      FrlgFont.facetsInk = true
      local ownFD = FrlgFont.draw
      local function plain(c)
        if type(c) ~= "table" then return false end
        local r, g, b = tonumber(c[1]) or 0, tonumber(c[2]) or 0, tonumber(c[3]) or 0
        if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
        return 0.299 * r + 0.587 * g + 0.114 * b <= 0.45 and math.max(r, g, b) - math.min(r, g, b) < 0.15
      end
      -- a strong light paper (GAME WOOD's DARK GOLD) under the game's own
      -- windows: their letters, the game's dark grey with its light grey
      -- shadow (only ever drawn on white), inked black, their shadow a
      -- deeper shade of the paper. Out of a battle, and in one only from
      -- its text box down, where the paper is -Elvie
      local function strongPaper(y, opts)
        local p = select(5, filter.settings(get))
        if not filter.STRONG[p] or filter.introNow then return nil end
        opts = type(opts) == "table" and opts or {}
        local base = opts.colors
        if not base and opts.color then base = { fg = opts.color, shadow = opts.shadow, bg = opts.bg } end
        if not base and not opts.gfxId and not opts.npcColor then
          base = (opts.small and FrlgFont.COLOR and FrlgFont.COLOR.PARTY) or (FrlgFont.COLOR and FrlgFont.COLOR.NORMAL)
        end
        if not (type(base) == "table" and plain(base.fg) and type(base.shadow) == "table") then return nil end
        local sr, sg, sb = tonumber(base.shadow[1]) or 0, tonumber(base.shadow[2]) or 0, tonumber(base.shadow[3]) or 0
        if sr > 1 or sg > 1 or sb > 1 then sr, sg, sb = sr / 255, sg / 255, sb / 255 end
        if 0.299 * sr + 0.587 * sg + 0.114 * sb < 0.6 then return nil end
        local okB, active = pcall(function() return require("src.core.game3.battle").isActive() end)
        if okB and active and (tonumber(y) or 0) < 112 then return nil end
        local t = filter.PAPER[p]
        return { t[1] / 255, t[2] / 255, t[3] / 255 }
      end
      local function inkOpts(x, y, opts)
        local pp, _, light = nil, nil, nil
        if type(x) == "number" and type(y) == "number" then pp, _, light = filter.ownedAt(x + 2, y + 2) end
        -- (and in a light paper's own window, the game's drawn papered) -Elvie
        if not pp or light == true then
          local strong = strongPaper(y, opts)
          if strong then pp, light = strong, "black" end
        end
        if not pp or (light and light ~= "black") then return nil end
        opts = opts or {}
        local base = opts.colors
        if not base and opts.color then base = { fg = opts.color, shadow = opts.shadow, bg = opts.bg } end
        if not base and not opts.gfxId and not opts.npcColor then
          base = (opts.small and FrlgFont.COLOR and FrlgFont.COLOR.PARTY) or (FrlgFont.COLOR and FrlgFont.COLOR.NORMAL)
        end
        if not (base and type(base.fg) == "table") then return nil end
        -- (a white behind the letters, FireRed's title menu's, would sit
        -- on the dark as a box round each word: left out) -Elvie
        local bg = base.bg
        if type(bg) == "table" and (tonumber(bg[4]) or 1) > 0 then bg = { 0, 0, 0, 0 } end
        local ol = filter.outlineOf(pp)
        local fg, shadow = nil, { ol[1], ol[2], ol[3], 1 }
        if light == "black" then
          -- black letters, their shadow a deeper shade of the window's
          -- own colour; a coloured letter (the PP's red) keeps its own -Elvie
          local r, g, b = tonumber(base.fg[1]) or 0, tonumber(base.fg[2]) or 0, tonumber(base.fg[3]) or 0
          if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
          if math.max(r, g, b) - math.min(r, g, b) >= 0.15 then return nil end
          fg, shadow = { 0.1, 0.1, 0.1, 1 }, { pp[1] * 0.72, pp[2] * 0.72, pp[3] * 0.72, 1 }
        elseif plain(base.fg) then
          fg = { 0.93, 0.93, 0.94, 1 }
        else
          -- a coloured letter keeps its colour; a blue one, which sinks
          -- into the dark (the party menu's HM moves, the title menu's
          -- PLAYER and TIME), lightened. Its shadow stays its own, unless
          -- it's the game's light grey -Elvie
          local r, g, b = tonumber(base.fg[1]) or 0, tonumber(base.fg[2]) or 0, tonumber(base.fg[3]) or 0
          if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
          local l = 0.299 * r + 0.587 * g + 0.114 * b
          local blue = b > r and b > g and l < 0.45
          local sh = base.shadow
          local greyShadow = false
          if type(sh) == "table" then
            local sr, sg, sb = tonumber(sh[1]) or 0, tonumber(sh[2]) or 0, tonumber(sh[3]) or 0
            if sr > 1 or sg > 1 or sb > 1 then sr, sg, sb = sr / 255, sg / 255, sb / 255 end
            greyShadow = plain({ 1 - sr, 1 - sg, 1 - sb })
          end
          if not blue and not greyShadow and bg == base.bg then return nil end
          fg = { r, g, b, 1 }
          if blue then
            local t = 0.45
            fg = { r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t, 1 }
          end
          if not greyShadow then shadow = sh end
        end
        local o = {}
        for k, v in pairs(opts) do o[k] = v end
        o.colors = { fg = fg, shadow = shadow, bg = bg }
        o.color, o.shadow, o.gfxId, o.npcColor = nil, nil, nil, nil
        o.facetsBlack = light == "black" or nil
        return o
      end
      -- (black: the game's own text carries colour codes that put its grey
      -- back part-way, the start menu's labels: while a text inked black
      -- draws, a plain letter they switch to stays black) -Elvie
      local inkBlack = nil
      if type(FrlgFont.scanTokens) == "function" then
        local ownScan = FrlgFont.scanTokens
        FrlgFont.scanTokens = function(text, colors, ...)
          local it, st, init = ownScan(text, colors, ...)
          local want = inkBlack
          if not want then return it, st, init end
          return function(...)
            local a, b, c = it(...)
            if type(c) == "table" and c.fg ~= want.fg and plain(c.fg) and type(c.shadow) == "table" then
              local sr, sg, sb = tonumber(c.shadow[1]) or 0, tonumber(c.shadow[2]) or 0, tonumber(c.shadow[3]) or 0
              if sr > 1 or sg > 1 or sb > 1 then sr, sg, sb = sr / 255, sg / 255, sb / 255 end
              if 0.299 * sr + 0.587 * sg + 0.114 * sb >= 0.6 then c.fg, c.shadow = want.fg, want.shadow end
            end
            return a, b, c
          end, st, init
        end
      end
      FrlgFont.draw = function(text, x, y, opts, ...)
        local o = inkOpts(x, y, opts)
        if not (o and o.facetsBlack) then return ownFD(text, x, y, o or opts, ...) end
        local was = inkBlack
        inkBlack = o.colors
        local results = { pcall(ownFD, text, x, y, o, ...) }
        inkBlack = was
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2)
      end
      if type(FrlgFont.drawGlyph) == "function" then
        local ownGlyph = FrlgFont.drawGlyph
        FrlgFont.drawGlyph = function(id, x, y, opts, ...)
          return ownGlyph(id, x, y, inkOpts(x, y, opts) or opts, ...)
        end
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
        -- drawn dark, not worked out: the HUD's tiles and letters are owned
        -- tile by tile, white to the paper and black to white, so the
        -- battle shows between them as it is -Elvie
        local function plate(x, y, w, h)
          if paperNow() and filter.own(x, y, w, h, nil, true) then return end
          filter.markPaper(x, y, w, h, true)
        end
        local ownEnemy, ownPlayer = BattleState.drawEnemyHud, BattleState.drawPlayerHud
        BattleState.drawEnemyHud = function(self, ...)
          if plates(self) then plate(8, 0, 88, 32) end
          return ownEnemy(self, ...)
        end
        BattleState.drawPlayerHud = function(self, ...)
          if plates(self) then plate(72, 56, 88, 40) end
          return ownPlayer(self, ...)
        end
        -- Gold, Silver and Crystal's POKéDEX is dark already (white on
        -- black, in an orange frame), so dark paper leaves it as drawn:
        -- worked out, its letters went hollow and its edges white -Elvie
        local okD, Dex = pcall(require, "src.ui.gen2.PokedexMenu")
        if okD and type(Dex) == "table" and type(Dex.drawPanel) == "function" then
          local ownPanel = Dex.drawPanel
          Dex.drawPanel = function(self, ...)
            local results = { ownPanel(self, ...) }
            if paperNow() then filter.keepRect(0, 0, 20 * 8 + 8, 18 * 8) end
            return unpack(results)
          end
        end
        local okH, BattleHud = pcall(require, "src.ui.gen2.BattleHud")
        if okH and type(BattleHud) == "table" and type(BattleHud.drawTile) == "function" then
          local ownTile = BattleHud.drawTile
          local DMG = { { 255, 255, 255 }, { 170, 170, 170 }, { 85, 85, 85 }, { 0, 0, 0 } }
          local LABEL = BattleHud.TILE_HP_LABEL or 0x60
          BattleHud.drawTile = function(this, key, first, tile, tx, ty, colors, mirror)
            local pp, tiles = nil, nil
            if type(tx) == "number" and type(ty) == "number" then pp, tiles = filter.ownedAt(tx * 8 + 4, ty * 8 + 4) end
            if not (pp and tiles) then return ownTile(this, key, first, tile, tx, ty, colors, mirror) end
            filter.keepRect(tx * 8, ty * 8, 8, 8)
            -- the HP: badge keeps its letters black, the balls their own colours -Elvie
            local label = key == "hpBar" and (tile == LABEL or tile == LABEL + 1)
            if key ~= "balls" then
              local out = {}
              for i, v in ipairs(type(colors) == "table" and colors or DMG) do out[i] = v end
              out[1] = { math.floor(pp[1] * 255 + 0.5), math.floor(pp[2] * 255 + 0.5), math.floor(pp[3] * 255 + 0.5) }
              if not label then out[4] = { 237, 237, 240 } end
              colors = out
            end
            return ownTile(this, key, first, tile, tx, ty, colors, mirror)
          end
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
      -- The games' own frames with a paper map (assets/windows/game3, by
      -- game, painted by hand: shapes only, no art) are drawn on PAPER
      -- rather than worked out: owned, the map's part of the art and the
      -- inside in the paper's colour -Elvie
      local mapped = setmetatable({}, { __mode = "k" })
      local function version()
        local okV, GV = pcall(require, "src.core.GameVersion")
        local v = okV and type(GV) == "table" and type(GV.get) == "function" and GV.get() or nil
        return type(v) == "string" and v or nil
      end
      local function mapAtlas(atlas)
        if type(atlas) ~= "table" or type(atlas.image) ~= "userdata" then return nil end
        local img = atlas.image
        if mapped[img] == nil then
          mapped[img] = false
          local file = type(atlas.path) == "string" and atlas.path:match("([^/]+)%.rgba$")
          local v = version()
          if file and v then
            local okM, data = pcall(love.image.newImageData,
              mod.assets:path("assets/windows/game3/" .. v .. "/" .. file .. ".paper.png"))
            if okM and data and filter.setArtMask then
              filter.setArtMask(img, data)
              mapped[img] = true
            end
          end
        end
        return mapped[img] and img or nil
      end
      local function atlasFor(name, frameType)
        local count = type(Chrome3.userFrameCount) == "function" and Chrome3.userFrameCount() or 10
        local function user(n)
          n = tonumber(n) or 0
          if n < 0 or n >= count or n ~= math.floor(n) then n = 0 end
          return type(Chrome3._user) == "table" and Chrome3._user[n] or nil
        end
        if name == "userFrame" then return user(frameType) end
        if name == "stdFrame" then return user(Chrome3._frameType) or Chrome3._std end
        if name == "fixedStdFrame" then
          local spec = type(Chrome3.frames) == "function" and Chrome3.frames() or nil
          if spec and spec.std == "user" then return user(Chrome3._frameType) end
          return Chrome3._std
        end
        if name == "dialogueFrame" then return Chrome3._dlg end
        if name == "signFrame" then return Chrome3._sign or Chrome3._dlg end
      end
      -- own (x, y, w, h: the whole window) and draw it with its map, then
      -- its inside (ix, iy, iw, ih) in the paper's colour; false when it
      -- isn't drawn so -Elvie
      local function drawnOn(atlas, x, y, w, h, ix, iy, iw, ih, call, ...)
        if not mapAtlas(atlas) then return false end
        local pp = paperNow()
        local light = false
        if not pp then pp, light = paperLight(), true end
        if not pp then return false end
        if not filter.own(x, y, w, h, pp, nil, light or nil) then return false end
        filter.swapNow = true
        local ok, err = pcall(call, ...)
        filter.swapNow = nil
        if not ok then error(err, 0) end
        if iw then
          local r, g, b, a = love.graphics.getColor()
          love.graphics.setColor(pp[1], pp[2], pp[3], 1)
          love.graphics.rectangle("fill", ix, iy, iw, ih)
          love.graphics.setColor(r, g, b, a)
        end
        return true
      end
      for _, name in ipairs({ "stdFrame", "fixedStdFrame", "userFrame" }) do
        local own = Chrome3[name]
        if type(own) == "function" then
          Chrome3[name] = function(...)
            -- (marked first: a window drawn dark inside it is owned and
            -- kept, and marking clears what's kept) -Elvie
            local a, b, c, d = ...
            if name == "userFrame" then a, b, c, d = select(2, ...) end
            if tonumber(a) and tonumber(c) then
              filter.markPaper(a * T, b * T, c * T, d * T)
              if drawnOn(atlasFor(name, (...)), (a - 1) * T, (b - 1) * T, (c + 2) * T, (d + 2) * T,
                  a * T, b * T, c * T, d * T, own, ...) then return end
            end
            return own(...)
          end
        end
      end
      for _, name in ipairs({ "dialogueFrame", "signFrame" }) do
        local own = Chrome3[name]
        if type(own) == "function" then
          Chrome3[name] = function(...)
            local L, Top, W, H = 2, 15, 26, 4
            if type(Chrome3.dialogueWindow) == "function" then
              local ok, l, t, w, h = pcall(Chrome3.dialogueWindow)
              if ok and tonumber(l) then L, Top, W, H = l, t, w, h end
            end
            filter.markPaper(L * T, Top * T, W * T, H * T)
            local atlas = atlasFor(name)
            -- (Ruby and Sapphire's lays its inside in tiles, mapped too) -Elvie
            local rs = type(atlas) == "table" and atlas.layout == "rs_dialogue"
            local x, y, w, h = (L - 2) * T, (Top - 1) * T, (W + 4) * T, (H + 2) * T
            if rs then x, y, w, h = 0, 14 * T, 30 * T, 6 * T end
            if drawnOn(atlas, x, y, w, h, L * T, Top * T, not rs and W * T or nil, H * T, own, ...) then return end
            return own(...)
          end
        end
      end
      local okB, BattleChrome = pcall(require, "src.ui.game3.battle_chrome")
      if okB and type(BattleChrome) == "table" and type(BattleChrome.drawPanel) == "function" then
        local ownPanel = BattleChrome.drawPanel
        BattleChrome.drawPanel = function(mode, ...)
          local hoenn = type(BattleChrome.isHoenn) == "function" and BattleChrome.isHoenn()
          if not hoenn then
            -- FireRed and LeafGreen: the FIGHT box on the right half, the
            -- moves and PP boxes across the whole panel -Elvie
            if mode == "menu" then filter.markPaper(120, 112, 120, 48)
            elseif mode == "moves" then filter.markPaper(0, 112, 240, 48) end
          end
          return ownPanel(mode, ...)
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
              or change.key == "paper" or change.key == "mapTime") then
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
