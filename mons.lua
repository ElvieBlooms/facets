-- Pokémon pictures (battle, summary, Pokédex, PC, evolution, trades...)
-- Every Gen 3 Pokémon picture is fetched through Pokemon.frontPic and
-- Pokemon.backPic, so wrapping those two covers every screen, the same way
-- gen3.lua wraps OwSprites.get for NPCs. Emerald's two-frame front
-- animations come through MonAnim.framePic, which is wrapped too, so a
-- replaced Pokémon never flickers back to the game's own. Game Boy fronts
-- play Crystal's own frames instead, and FR/LG can borrow Emerald's
-- animations (FR/LG ANIMS). -Elvie
--
-- A set is a folder under assets/mons/ with a meta.json ("label",
-- "credit"). It can hold 64x64 PNGs named by national number:
-- front/006.png, back/006.png, front_shiny/006.png, back_shiny/006.png,
-- Unown as 201_b.png and so on, the egg as egg.png, forms as 351_sunny,
-- 351_rainy, 351_snowy, 386_attack, 386_defense, 386_speed. Every picture
-- is stood on the game's own ground line for that Pokémon, so where the
-- art sits in its frame doesn't matter. A set with
-- "source": "gb" also reads Crystal's battle sprites (then Gold's, then
-- Silver's) from the player's own install, coloured with Crystal's own
-- palettes, shiny included. Its files win over the Game Boy ones. A Pokémon
-- a set doesn't have stays the game's own. -Elvie
--
-- This file, mon_names.lua and assets/mons/ are the whole Pokémon side;
-- main.lua lists it. An NPC-only build drops those and that one line. -Elvie
-- --------------------------------------------------

local gb = require("mods.facets.gb")
local NAMES = require("mods.facets.mon_names")

local mons = {}

local MONS_DIR = "assets/mons"
local OFF = "__off"
local SIZE = 64
local GB_GAMES = { "crystal", "gold", "silver" }
local WHITE, BLACK = { 255, 255, 255 }, { 0, 0, 0 }
local CASTFORM = { "_sunny", "_rainy", "_snowy" }
local DEOXYS = { firered = "_attack", leafgreen = "_defense", emerald = "_speed" }

-- Crystal's palettes
-- Read once from the install's palettes.lua (crystal/data/generated). Mods
-- can't load() Lua, so the pokemon = { ... } block is read as text: each
-- NAME = { normal = { {r,g,b}, {r,g,b} }, shiny = { ... } }, colours 1-2
-- (0 is white and 3 black). -Elvie
-- --------------------------------------------------
function mons.parsePalettes(text)
  if type(text) ~= "string" then return nil end
  local start = text:find("\n  pokemon = {", 1, true)
  if not start then return nil end
  local stop = text:find("\n  [%a_]+ = {", start + 1)
  local section = text:sub(start, stop or #text)
  local out, n = {}, 0
  for name, body in section:gmatch("\n    ([%w_]+) = {(.-)\n    }") do
    local normalAt, shinyAt = body:find("normal", 1, true), body:find("shiny", 1, true)
    local v = {}
    for num in body:gmatch("%d+") do v[#v + 1] = tonumber(num) end
    if normalAt and shinyAt and normalAt < shinyAt and #v == 12 then
      out[name] = {
        normal = { { v[1], v[2], v[3] }, { v[4], v[5], v[6] } },
        shiny = { { v[7], v[8], v[9] }, { v[10], v[11], v[12] } },
      }
      n = n + 1
    end
  end
  return n > 0 and out or nil
end

-- Pictures
-- --------------------------------------------------

-- Lays a sprite (any size up to 64x64) into a 64x64 picture: centred, with
-- its lowest drawn row on `bottom`, the row the game's own picture ends on
-- (64 minus the species' y offset), so it stands where the game's would.
-- colour(r, g, b, a) gives the colour to draw, or nil for see-through; it's
-- called once per pixel, row by row. place, if given, keeps the spot: an
-- empty table gets this sprite's, a filled one is reused, so every frame of
-- an animation sits where its first frame did. -Elvie
function mons.layOut(src, bottom, colour, place)
  local sw, sh = src:getDimensions()
  if sw > SIZE or sh > SIZE then return nil, ("%dx%d is bigger than 64x64"):format(sw, sh) end
  local px, top, low = {}, nil, nil
  for y = 0, sh - 1 do
    for x = 0, sw - 1 do
      local c = colour(src:getPixel(x, y))
      if c then
        px[#px + 1] = { x, y, c }
        top = top or y
        low = y
      end
    end
  end
  if not low and not (place and place.ox) then return nil, "the sprite is empty" end
  local ox, oy
  if place and place.ox then
    ox, oy = place.ox, place.oy
  else
    ox = math.floor((SIZE - sw) / 2)
    oy = (bottom or SIZE) - 1 - low
    if oy + top < 0 then oy = -top end
    if oy + low > SIZE - 1 then oy = SIZE - 1 - low end
    if place then place.ox, place.oy = ox, oy end
  end
  local out = love.image.newImageData(SIZE, SIZE)
  for _, p in ipairs(px) do
    local c = p[3]
    local x, y = ox + p[1], oy + p[2]
    if x >= 0 and y >= 0 and x < SIZE and y < SIZE then
      out:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, c[4] or 1)
    end
  end
  return out
end

-- Crystal's front animations
-- Crystal's pokemon.lua gives each Pokémon an anim = { ... } block: a
-- sheet of whole pictures (base first) and a play script. Mods can't load()
-- Lua, so the block is read with this small reader for plain table
-- literals (numbers, strings, true/false, name = and [n] = keys). -Elvie
-- --------------------------------------------------
local function literal(s, i)
  i = s:find("%S", i)
  if not i then error("unexpected end") end
  local c = s:sub(i, i)
  if c == "{" then
    local t, n = {}, 0
    i = i + 1
    while true do
      i = s:find("%S", i)
      if not i then error("unclosed {") end
      if s:sub(i, i) == "}" then return t, i + 1 end
      local key
      local _, e, name = s:find("^([%a_][%w_]*)%s*=", i)
      if e then
        key, i = name, e + 1
      else
        local _, e2, num = s:find("^%[%s*(%-?%d+)%s*%]%s*=", i)
        if e2 then key, i = tonumber(num), e2 + 1 end
      end
      local v
      v, i = literal(s, i)
      if key == nil then n = n + 1; key = n end
      t[key] = v
      i = s:find("%S", i)
      local sep = i and s:sub(i, i)
      if sep == "," or sep == ";" then i = i + 1 end
    end
  elseif c == '"' then
    local j = s:find('"', i + 1, true)
    if not j then error("unclosed string") end
    return s:sub(i + 1, j - 1), j + 1
  end
  local a, b = s:find("^%-?[%w_%.]+", i)
  if not a then error("unexpected " .. c) end
  local word = s:sub(a, b)
  if word == "true" then return true, b + 1 elseif word == "false" then return false, b + 1 end
  local v = tonumber(word)
  if v == nil then error("unexpected " .. word) end
  return v, b + 1
end
mons.literal = function(s) return (literal(s, 1)) end

-- The anim block for a Crystal sprite name (chikorita), or nil. index is a
-- table kept between calls. -Elvie
function mons.crystalAnim(text, stem, index)
  if type(text) ~= "string" or type(stem) ~= "string" then return nil end
  if not index.starts then
    index.starts = {}
    for at in text:gmatch("()\n    anim = {") do index.starts[#index.starts + 1] = at end
  end
  local sheet = gb.path("assets", "battle/anim/" .. stem .. ".png")
  if not sheet then return nil end
  local at = text:find('sheet = "' .. sheet .. '"', 1, true)
  if not at then return nil end
  local from
  for _, s in ipairs(index.starts) do
    if s < at then from = s else break end
  end
  if not from then return nil end
  local brace = text:find("{", from, true)
  local ok, anim = pcall(literal, text, brace)
  if not ok or type(anim) ~= "table" or type(anim.play) ~= "table" or not tonumber(anim.tiles) then return nil end
  return anim
end

-- A Crystal anim as Gen 3 sprite commands, played by the engine's own Gen 2
-- runner (the battle scene: setup, then play) and written down tick by tick.
-- nil if it never leaves the base picture. -Elvie
function mons.animCommands(anim, Runner)
  if not (anim and Runner and type(Runner.new) == "function") then return nil end
  local runner = Runner.new(anim, "battle")
  if not runner then return nil end
  local cmds, last, run, moved = {}, nil, 0, false
  for _ = 1, 3600 do
    runner:update()
    if runner:finished() then break end
    local f = runner:currentFrame() or 0
    if f ~= 0 then moved = true end
    if f == last then
      run = run + 1
    else
      if last then cmds[#cmds + 1] = { frame = last, duration = run } end
      last, run = f, 1
    end
  end
  if not moved then return nil end
  if last then cmds[#cmds + 1] = { frame = last, duration = run } end
  cmds[#cmds + 1] = { frame = 0, duration = 1 }
  cmds[#cmds + 1] = { op = "end" }
  return cmds
end

-- Game Boy battle sprites are greyscale with see-through outside: white,
-- 170, 85 and black are palette colours 0-3. -Elvie
-- A few (Unown, Ursaring's back) come with no see-through pixels at all;
-- for those the white touching the edge is the outside. -Elvie
local function outsideOf(src)
  local w, h = src:getDimensions()
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local _, _, _, a = src:getPixel(x, y)
      if not a or a <= 0 then return nil end
    end
  end
  local out, stack = {}, {}
  local function push(x, y)
    if x < 0 or y < 0 or x >= w or y >= h or out[y * w + x] then return end
    local r = src:getPixel(x, y)
    if r > 0.83 then out[y * w + x] = true; stack[#stack + 1] = { x, y } end
  end
  for x = 0, w - 1 do push(x, 0); push(x, h - 1) end
  for y = 0, h - 1 do push(0, y); push(w - 1, y) end
  while #stack > 0 do
    local p = table.remove(stack)
    push(p[1] + 1, p[2]); push(p[1] - 1, p[2]); push(p[1], p[2] + 1); push(p[1], p[2] - 1)
  end
  return out
end

local function gbColour(pal, src)
  local outside, w = outsideOf(src), (src:getDimensions())
  local x, y = -1, 0
  return function(r, _, _, a)
    -- layOut reads pixels in order, row by row -Elvie
    x = x + 1
    if x == w then x, y = 0, y + 1 end
    if not a or a <= 0 or (outside and outside[y * w + x]) then return nil end
    local k = r > 0.83 and 0 or r > 0.5 and 1 or r > 0.17 and 2 or 3
    return k == 0 and WHITE or k == 3 and BLACK or pal[k]
  end
end

local function ownColour(r, g, b, a)
  if not a or a <= 0 then return nil end
  return { r * 255, g * 255, b * 255, a }
end

-- Crystal's party icons: icons.lua names an icon for each species
-- (NAME = "ICON_BIRD") and an image for each icon. Read as text. -Elvie
function mons.parseIcons(text)
  if type(text) ~= "string" then return nil end
  local out = { species = {}, image = {} }
  for name, id in text:gmatch('\n    ([%w_]+) = "(ICON_[%w_]+)"') do out.species[name] = id end
  for id, body in text:gmatch("\n    (ICON_[%w_]+) = {(.-)\n    }") do
    local image = body:match('image = "([^"]+)"')
    if image then out.image[id] = image end
  end
  if next(out.species) == nil or next(out.image) == nil then return nil end
  return out
end

-- Crystal's party-menu palette, colours 1 and 2 (orange and red); the
-- usual ones if palettes.lua doesn't have it. -Elvie
function mons.parsePartyPalette(text)
  local fallback = { { 255, 156, 82 }, { 255, 58, 33 } }
  if type(text) ~= "string" then return fallback end
  local at = text:find("\n  partyMenu = {", 1, true)
  if not at then return fallback end
  local v = {}
  for num in text:sub(at, at + 600):gmatch("%d+") do
    v[#v + 1] = tonumber(num)
    if #v == 9 then break end
  end
  if #v < 9 then return fallback end
  return { { v[4], v[5], v[6] }, { v[7], v[8], v[9] } }
end

mons.BACKS = { { "BACK", "back" }, { "FRONT", "front" } }
mons.MIRROR = { { "OFF", OFF }, { "ON", "on" } }
-- the FACETS screen's one row for both -Elvie
mons.SIDES = { { "BACK", "back" }, { "MIRRORED", "mirrored" }, { "FRONT", "front" } }
function mons.sideOf(backs, mirror)
  if backs ~= "front" then return "back" end
  return mirror == OFF and "front" or "mirrored"
end

-- Gen 3's own picture as a Game Boy one, for what a Game Boy set has no
-- art for: the pixels sorted into shades by brightness (the darkest 12%
-- black, the brightest 7% white, the rest split evenly between them; with
-- 4 shades, at the middle), and each middle shade the colour it covers
-- most. shades is 4 (RGB, like a Game Boy sprite), 8 or 16 (GBC, closer
-- to Crystal's shading). colour (the shiny picture, or the normal one
-- again) gives those colours; the shading always follows the normal one,
-- so a shiny matches it pixel for pixel. Pixels are { r, g, b, a } lists,
-- 0-255. Returns the pixels and the plan (cut points and colours); pass
-- that plan back in for an animation's other frames, so every frame is
-- shaded and coloured like the first. -Elvie
local function lum(p) return p[1] * 299 + p[2] * 587 + p[3] * 114 end
function mons.toGbc(normal, colour, shades, plan)
  colour = colour or normal
  local cuts, middle, pal
  if plan then
    cuts, middle, pal = plan.cuts, #plan.cuts - 1, plan.pal
  else
    shades = tonumber(shades) or 4
    if shades ~= 8 and shades ~= 16 then shades = 4 end
    local ls = {}
    for _, p in ipairs(normal) do if p[4] > 0 then ls[#ls + 1] = lum(p) end end
    if #ls == 0 then return nil end
    table.sort(ls)
    local function q(f) return ls[math.floor(f * (#ls - 1)) + 1] end
    -- cuts[k]: the brightest a pixel of shade k (1 = black, then darker to
    -- lighter middles; brighter than the last is white) -Elvie
    middle = shades - 2
    cuts = { q(0.12) }
    if shades == 4 then
      cuts[2], cuts[3] = q(0.55), q(0.93)
    else
      for k = 1, middle do cuts[#cuts + 1] = q(0.12 + 0.81 * k / middle) end
    end
  end
  local bands, counts = {}, {}
  for k = 1, middle do counts[k] = {} end
  for i, p in ipairs(normal) do
    local b = -1
    if p[4] > 0 then
      local l = lum(p)
      b = 0
      for k = 1, #cuts do
        if l <= cuts[k] then b = k; break end
      end
      -- b: 0 white, 1 black, 2.. the middles from dark to light -Elvie
      if b >= 2 then
        local c = colour[i]
        local key = c[1] .. "," .. c[2] .. "," .. c[3]
        counts[b - 1][key] = (counts[b - 1][key] or 0) + 1
      end
    end
    bands[i] = b
  end
  -- most-used colour, snapped to the Game Boy Color's 5 bits -Elvie
  local function most(t, fallback)
    local best, n = nil, 0
    for k, c in pairs(t) do
      if c > n or (c == n and best and k < best) then best, n = k, c end
    end
    if not best then return fallback end
    local out = {}
    for v in best:gmatch("%d+") do out[#out + 1] = math.min(248, math.floor(tonumber(v) / 8) * 8) end
    return out
  end
  if not pal then
    -- an empty middle borrows its neighbour's colour -Elvie
    pal = { [0] = { 248, 248, 248 }, [1] = { 0, 0, 0 } }
    for k = 1, middle do pal[k + 1] = most(counts[k], nil) end
    for k = 3, middle + 1 do pal[k] = pal[k] or pal[k - 1] end
    for k = middle, 2, -1 do pal[k] = pal[k] or pal[k + 1] end
    for k = 2, middle + 1 do pal[k] = pal[k] or { 128, 128, 128 } end
    if shades == 4 then
      -- the old fallbacks, so 4 shades stay exactly as they were -Elvie
      pal[2] = most(counts[1], { 96, 96, 96 })
      pal[3] = most(counts[2], { 192, 192, 192 })
    end
  end
  local out = {}
  for i, b in ipairs(bands) do
    local c = pal[b]
    out[i] = c and { c[1], c[2], c[3], 255 } or { 0, 0, 0, 0 }
  end
  return out, { cuts = cuts, pal = pal }
end

-- How far a front picture moves to stand where the back one would: its
-- own ground line (front offset, less any float) against the back's.
-- coords is the game's pic_coords (front, back, elev by species). -Elvie
function mons.frontAsBackShift(coords, species)
  if type(coords) ~= "table" then return 0 end
  local ok, shift = pcall(function()
    local front = coords.front and coords.front[species] or 0
    local back = coords.back and coords.back[species] or 0
    local elev = coords.elev and coords.elev[species] or 0
    return front - elev - back
  end)
  return ok and tonumber(shift) or 0
end

-- menu (menu.lua), if given, gets the POKEMON rows for the FACETS screen. -Elvie
function mons.init(mod, rows, menu)
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if not okP or type(Pokemon) ~= "table" or type(Pokemon.frontPic) ~= "function"
      or type(Pokemon.backPic) ~= "function" then
    mod.log:warn("Pokemon.frontPic not found; Pokémon pictures are off")
    return nil
  end

  local function isDirectory(rel)
    local info = mod.assets:info(rel)
    return info and info.type == "directory"
  end
  local function readMeta(key)
    local rel = MONS_DIR .. "/" .. key .. "/meta.json"
    if not mod.assets:info(rel) then return {} end
    local ok, decoded = pcall(require("mods.facets.npcs").decodeJson, mod:read(rel))
    if ok and type(decoded) == "table" then return decoded end
    mod.log:warn("mons/%s/meta.json couldn't be read, using defaults", key)
    return {}
  end

  -- Sets, in label order. -Elvie
  local sets = {}
  for _, key in ipairs(mod.assets:list(MONS_DIR)) do
    if isDirectory(MONS_DIR .. "/" .. key) then
      local meta = readMeta(key)
      local label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper()
      local fallback = type(meta.fallback) == "string" and meta.fallback:match("^[%w_%-]+$") or nil
      sets[#sets + 1] = { key = key, label = label, gb = meta.source == "gb", credit = meta.credit,
        fallback = fallback, gbSource = meta.crystal ~= false and "crystal" or nil,
        builtFrom = meta.builtFrom == "emerald" and "emerald" or nil,
        builtShades = tonumber(meta.builtShades) }
    end
  end
  table.sort(sets, function(a, b) return a.label < b.label end)
  if #sets == 0 then return nil end

  -- Options: a POKEMON heading and its SET, OFF by default, so Facets
  -- leaves Pokémon alone until asked. One choice covers every game. -Elvie
  local choices = {}
  for _, set in ipairs(sets) do choices[#choices + 1] = { set.label, set.key } end
  choices[#choices + 1] = { "OFF", OFF }
  rows[#rows + 1] = { key = "sectionMons", type = "choice", label = "POKEMON",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "setMons", type = "choice", label = "  SET", choices = choices, default = OFF }
  -- FireRed and LeafGreen have no front animations of their own; this
  -- plays Emerald's, read from the player's imported Emerald. -Elvie
  rows[#rows + 1] = { key = "animMons", type = "choice", label = "  FR/LG ANIMS",
    choices = { { "EMERALD", "emerald" }, { "OFF", OFF } }, default = OFF }
  -- Your own Pokémon by its front picture instead of its back, mirrored
  -- to face the foe unless MIRROR FRONTS is off. Any set, or the
  -- game's own. -Elvie
  rows[#rows + 1] = { key = "backMons", type = "choice", label = "  YOUR SIDE",
    choices = mons.BACKS, default = "back" }
  rows[#rows + 1] = { key = "mirrorMons", type = "choice", label = "  MIRROR FRONTS",
    choices = mons.MIRROR, default = "on" }
  if menu then mons.screenPart(mod, menu, sets, choices, Pokemon) end

  return function()
    local okC, PicCoords = pcall(require, "src.core.game3.battle.pic_coords")
    if not okC or type(PicCoords) ~= "table" then PicCoords = nil end

    local current      -- the selected set, or nil for OFF
    local cache = {}   -- [kind:species(:s)] = picture entry, or false
    local palettes     -- Crystal's, read when first needed; false if missing

    -- Where the game's own picture ends: 64 minus the species' y offset. -Elvie
    local function bottomFor(kind, species)
      local t = PicCoords and PicCoords[kind]
      local yo = type(t) == "table" and tonumber(t[species]) or 0
      return SIZE - (yo or 0)
    end

    -- National number and Unown letter (0 = A) for an engine species. -Elvie
    local function identify(species)
      if species == tonumber(Pokemon.SPECIES_EGG) then return "egg" end
      local base, letter = species, nil
      if type(Pokemon.picBaseSpecies) == "function" then base, letter = Pokemon.picBaseSpecies(species) end
      local nat = type(Pokemon.national) == "function" and tonumber(Pokemon.national(base)) or tonumber(base)
      return nat, letter
    end

    -- A set, then the set its meta.json "fallback" names (GBC ANIM falls
    -- back to GBC for what it doesn't have), as a list. -Elvie
    local function chainOf(set)
      local out, seen = {}, {}
      while set and not seen[set.key] do
        seen[set.key] = true
        out[#out + 1] = set
        local next
        for _, s in ipairs(sets) do
          if s.key == set.fallback then next = s end
        end
        set = next
      end
      return out
    end

    -- A file of a set's own (a set, then its fallback): its path and the
    -- set it came from, or nil. -Elvie
    local function ownRel(set, sub)
      for _, s in ipairs(chainOf(set)) do
        local rel = MONS_DIR .. "/" .. s.key .. "/" .. sub
        if mod.assets:info(rel) then return rel, s end
      end
      return nil
    end

    -- A PNG of the set's own, as ImageData, and the set it came from, or
    -- nil. variant is "" or a form's suffix (_sunny, _attack...). -Elvie
    local function ownFile(set, kind, shiny, nat, letter, variant)
      local name
      if nat == "egg" then name = "egg"
      else
        name = ("%03d"):format(nat)
        if nat == 201 and (letter or 0) > 0 then name = name .. "_" .. ("bcdefghijklmnopqrstuvwxyz!?"):sub(letter, letter) end
      end
      if name:find("[!?]") then name = name:gsub("!", "emark"):gsub("%?", "qmark") end
      name = name .. (variant or "")
      local rel, from = ownRel(set, kind .. (shiny and "_shiny" or "") .. "/" .. name .. ".png")
      if not rel then return nil end
      local ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
      if not ok or not data then
        mod.log:warn("could not load %s", rel)
        return nil
      end
      local w, h = data:getDimensions()
      if w ~= SIZE or h ~= SIZE then
        mod.log:warn("%s is %dx%d; Pokémon pictures need to be 64x64", rel, w, h)
        return nil
      end
      return data, from
    end

    -- Crystal's sprite and palette for a Pokémon, or nil. -Elvie
    local function crystalPalettes()
      if palettes == nil then
        palettes = mons.parsePalettes(gb.readAt(gb.path("data", "palettes.lua"), { "crystal" })) or false
        if not palettes then mod.log:warn("Crystal's palettes weren't found; GBC Pokémon need Crystal imported") end
      end
      return palettes or nil
    end
    local function crystalSprite(kind, shiny, nat, letter)
      local file, palName
      if nat == "egg" then
        if kind ~= "front" then return nil end
        file, palName = "egg", "EGG"
      else
        local row = type(nat) == "number" and NAMES[nat]
        if not row then return nil end
        palName = row[2]
        if row[1] == "unown" then
          letter = letter or 0
          if letter > 25 then return nil end -- ! and ? are Gen 3's own
          file = "unown_" .. string.char(97 + letter)
        else
          file = kind == "front" and row[1] or (row[1] .. "_back")
        end
      end
      local all = crystalPalettes()
      local pal = all and all[palName]
      if not pal then return nil end
      local src = gb.readImage(gb.path("assets", "battle/" .. kind .. "/" .. file .. ".png"), GB_GAMES)
      if not src then return nil end
      return src, shiny and pal.shiny or pal.normal
    end

    -- A Game Boy set's sprite from the player's install: Crystal's. -Elvie
    local function gbSprite(source, kind, shiny, nat, letter)
      if source ~= "crystal" then return nil end
      return crystalSprite(kind, shiny, nat, letter)
    end

    -- Whether the set, or a set it falls back to, has "builtFrom":
    -- "emerald" (GBC-ISH): then the pictures it makes for what Crystal
    -- doesn't have (Hoenn) come from Emerald, with Emerald's animations. -Elvie
    local function fromEmeraldChain(set)
      for _, s in ipairs(chainOf(set)) do
        if s.gb and s.builtFrom == "emerald" then return true end
      end
      return false
    end

    -- The game's own picture (gameKey: "277", "385_1", "410_handled"),
    -- read from the running game's install and made Game Boy by
    -- mons.toGbc, as ImageData. -Elvie
    -- the game's own name for a picture, as Pokemon.lua names it -Elvie
    local function gameKeyOf(species, form)
      local suffix = ""
      if type(Pokemon.deoxysFormSuffix) == "function" then
        local okS, got = pcall(Pokemon.deoxysFormSuffix, species)
        suffix = okS and type(got) == "string" and got or ""
      end
      form = tonumber(form) or 0
      return form > 0 and (species .. "_" .. form) or (species .. suffix)
    end

    local placements = {} -- [species] = where a Game Boy front sits, for its frames
    local plans = {} -- [kind:gameKey(:s)] = frame 0's plan, for the other frames -Elvie
    local function gameAsGb(kind, shiny, gameKey, species, frame)
      if not (love and love.image and type(gameKey) == "string") then return nil end
      local okV, GameVersion = pcall(require, "src.core.GameVersion")
      local game = okV and type(GameVersion) == "table" and GameVersion.get() or nil
      if not game then return nil end
      -- frame f of a sheet of pictures stacked (Emerald's front_anim), or
      -- the one picture -Elvie
      local function pixels(from, sub, f)
        local bytes = gb.readAt(gb.path("monData", sub .. "/" .. gameKey .. ".rgba"), { from })
        local size = SIZE * SIZE * 4
        if type(bytes) ~= "string" or #bytes < size * ((f or 0) + 1) then return nil end
        local base, out = size * (f or 0), {}
        for i = 1, SIZE * SIZE do
          local o = base + (i - 1) * 4
          out[i] = { bytes:byte(o + 1, o + 4) }
        end
        return out
      end
      -- GBC-ISH: Emerald's pictures, fronts from its animation sheet
      -- (both frames); anything Emerald has no sheet for (Castform's
      -- weather), and the rest, from the running game -Elvie
      local fromEmerald = fromEmeraldChain(current)
      local normal, colour, emerald
      if fromEmerald then
        local sub = kind == "front" and "front_anim" or kind
        normal = pixels("emerald", sub, kind == "front" and (frame or 0) or nil)
        if normal then
          emerald = true
          colour = shiny and pixels("emerald", sub .. "_shiny", kind == "front" and (frame or 0) or nil) or normal
        end
      end
      if not normal then
        if (frame or 0) > 0 then return nil end
        normal = pixels(game, kind)
        if not normal then return nil end
        colour = shiny and pixels(game, kind .. "_shiny") or normal
      end
      -- the set's "builtShades" (or its fallback's): 4, 8 or 16 -Elvie
      local shades
      for _, s in ipairs(chainOf(current)) do
        if s.builtShades then shades = s.builtShades; break end
      end
      local planKey = kind .. ":" .. gameKey .. (shiny and ":s" or "")
      local plan
      if (frame or 0) > 0 then
        plan = plans[planKey]
        if not plan then
          gameAsGb(kind, shiny, gameKey, species, 0)
          plan = plans[planKey]
          if not plan then return nil end
        end
      end
      local px, made = mons.toGbc(normal, colour, shades, plan)
      if not px then return nil end
      if (frame or 0) == 0 then plans[planKey] = made end
      local data = love.image.newImageData(SIZE, SIZE)
      for i, p in ipairs(px) do
        local x, y = (i - 1) % SIZE, math.floor((i - 1) / SIZE)
        data:setPixel(x, y, p[1] / 255, p[2] / 255, p[3] / 255, p[4] / 255)
      end
      -- Emerald's art in FireRed and LeafGreen stands on their ground line,
      -- every frame where the first does (as FR/LG ANIMS does) -Elvie
      if emerald and (game == "firered" or game == "leafgreen") and species then
        local place
        if kind == "front" then
          placements[species] = placements[species] or {}
          place = placements[species]
        end
        data = mons.layOut(data, bottomFor(kind, species), ownColour, place)
      end
      return data, false
    end
    mons.gameAsGb = gameAsGb


    -- The picture, true when it's a Game Boy one, and the set a file of
    -- its own came from. -Elvie
    local function build(kind, species, shiny, nat, letter, variant, gameKey)
      local data, from = ownFile(current, kind, shiny, nat, letter, variant)
      if data then
        -- Stood on the game's own ground line, like everything else; a
        -- front keeps its spot for its animation frames. -Elvie
        local place
        if kind == "front" and variant == "" then
          placements[species] = placements[species] or {}
          place = placements[species]
        end
        local out, why = mons.layOut(data, bottomFor(kind, species), ownColour, place)
        if not out then mod.log:warn("%s %s: %s", kind, tostring(nat), tostring(why)) end
        return out, false, from
      end
      -- From the install: Crystal's, for a set (or its fallback) that
      -- reads Crystal; those get Crystal's animations too. A set with
      -- "crystal": false (GB EMERALD) makes everything instead, even with
      -- a fallback that reads Crystal (it only borrows its icons). -Elvie
      if current.gb and variant == "" and current.gbSource then
        for _, s in ipairs(chainOf(current)) do
          if s.gb then
            local src, pal = gbSprite(s.gbSource, kind, shiny, nat, letter)
            if src then
              local place
              if kind == "front" then
                placements[species] = placements[species] or {}
                place = placements[species]
              end
              local out, why = mons.layOut(src, bottomFor(kind, species), gbColour(pal, src), place)
              if not out then mod.log:warn("GBC %s %s: %s", kind, tostring(nat), tostring(why)) end
              return out, true
            end
          end
        end
      end
      -- No art at all (most Hoenn backs, Unown ! and ?): the game's own
      -- picture made Game Boy, from the player's install, where it
      -- already stands. -Elvie
      if current.gb then return gameAsGb(kind, shiny, gameKey, species, 0) end
      return nil
    end

    local function lookup(kind, species, form, shiny)
      if not current then return nil end
      species = tonumber(species)
      if not species or species < 1 then return nil end
      local nat, letter = identify(species)
      if nat == nil then return nil end
      -- Forms: Castform's weather forms by form number, and the Deoxys
      -- each game shows (FireRed's Attack, LeafGreen's Defense, Emerald's
      -- Speed) when the game asks for it. A set without the form's file
      -- leaves it the game's own. -Elvie
      form = tonumber(form) or 0
      local variant = ""
      if nat == 351 and form > 0 then
        variant = CASTFORM[form]
        if not variant then return nil end
      elseif form > 0 then
        return nil
      end
      if nat == 386 and type(Pokemon.deoxysFormSuffix) == "function" and Pokemon.deoxysFormSuffix(species) ~= "" then
        local okV, GameVersion = pcall(require, "src.core.GameVersion")
        variant = okV and DEOXYS[GameVersion.get()] or ""
      end
      -- Spinda's front is drawn by the game with each Spinda's own spots. -Elvie
      if nat == 327 and kind == "front" then return nil end
      shiny = shiny and nat ~= "egg" or false
      local key = kind .. ":" .. species .. variant .. (shiny and ":s" or "")
      local hit = cache[key]
      if hit ~= nil then return hit or nil end
      local gameKey = gameKeyOf(species, form)
      local ok, data, fromGb, fromSet = pcall(build, kind, species, shiny, nat, letter, variant, gameKey)
      if not ok then
        mod.log:warn("%s %d: %s", kind, species, tostring(data))
        data = nil
      end
      local entry = false
      if data and love and love.graphics then
        local image = love.graphics.newImage(data)
        image:setFilter("nearest", "nearest")
        entry = { image = image, imageData = data, w = SIZE, h = SIZE, gb = fromGb or nil,
          set = fromSet or nil }
      end
      cache[key] = entry
      return entry or nil
    end
    mons.lookup = lookup

    -- Party icons
    -- A set's own icons/NNN.png (two 16x16 frames stacked, or two 32x32),
    -- else for a Game Boy set Crystal's own icon, coloured with Crystal's
    -- party-menu palette. 16x16 icons stand at the bottom of Gen 3's
    -- 32x32 icon. -Elvie
    -- --------------------------------------------------
    local crystalIcons -- { species = { NAME = ICON_ID }, image = { ICON_ID = path } }; false if missing
    local partyPal     -- Crystal's party-menu colours 1 and 2
    local function crystalIconFile(nat)
      if crystalIcons == nil then
        crystalIcons = mons.parseIcons(gb.readAt(gb.path("data", "icons.lua"), GB_GAMES)) or false
        partyPal = mons.parsePartyPalette(gb.readAt(gb.path("data", "palettes.lua"), { "crystal" }))
      end
      if not crystalIcons then return nil end
      local id
      if nat == "egg" then id = "ICON_EGG"
      else
        local row = type(nat) == "number" and NAMES[nat]
        id = row and crystalIcons.species[row[2]]
      end
      return id and crystalIcons.image[id]
    end

    local function buildIcon(nat)
      local src, colour
      local name = nat == "egg" and "egg" or ("%03d"):format(nat)
      local rel = ownRel(current, "icons/" .. name .. ".png")
      if rel then
        local ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
        if ok and data then src, colour = data, ownColour end
      end
      -- Crystal's own icon, for a set that reads Crystal (GB EMERALD keeps
      -- the game's icons) -Elvie
      if not src and current.gb and current.gbSource then
        local file = crystalIconFile(nat)
        src = file and gb.readImage(file, GB_GAMES)
        if src then colour = gbColour(partyPal, src) end
      end
      if not src then return nil end
      local w, h = src:getDimensions()
      local small = w == 16 and h == 32
      if not (small or (w == 32 and h == 64)) then
        mod.log:warn("%s icon is %dx%d; icons need two 16x16 or 32x32 frames, stacked", name, w, h)
        return nil
      end
      -- 16x16 frames keep the Game Boy size, at the bottom-centre of
      -- Gen 3's 32x32 frame, where its icons have their feet. -Elvie
      local frameH = h / 2
      local ox, oy = small and 8 or 0, small and 16 or 0
      local out = love.image.newImageData(32, 64)
      for y = 0, h - 1 do
        local f, ly = math.floor(y / frameH), y % frameH
        for x = 0, w - 1 do
          local c = colour(src:getPixel(x, y))
          if c then out:setPixel(ox + x, f * 32 + oy + ly, c[1] / 255, c[2] / 255, c[3] / 255, c[4] or 1) end
        end
      end
      return out
    end

    local function iconLookup(species)
      if not current then return nil end
      species = tonumber(species)
      if not species or species < 1 then return nil end
      local nat = identify(species)
      if nat == nil then return nil end
      local key = "icon:" .. species
      local hit = cache[key]
      if hit ~= nil then return hit or nil end
      local ok, data = pcall(buildIcon, nat)
      if not ok then
        mod.log:warn("icon %d: %s", species, tostring(data))
        data = nil
      end
      local entry = false
      if data and love and love.graphics then
        local image = love.graphics.newImage(data)
        image:setFilter("nearest", "nearest")
        entry = { image = image, imageData = data, w = 32, h = 32, sheetH = 64, frames = 2,
          quads = { [0] = love.graphics.newQuad(0, 0, 32, 32, 32, 64), [1] = love.graphics.newQuad(0, 32, 32, 32, 32, 64) } }
      end
      cache[key] = entry
      return entry or nil
    end
    mons.iconLookup = iconLookup

    -- Crystal's animations, for Game Boy fronts
    -- --------------------------------------------------
    local okR, Gen2Anim = pcall(require, "src.render.MonAnim")
    if not okR or type(Gen2Anim) ~= "table" then Gen2Anim = nil end
    local crystalText            -- Crystal's pokemon.lua; false if missing
    local animIndex, anims, commands = {}, {}, {}

    local function crystalAnimFor(nat)
      local row = type(nat) == "number" and NAMES[nat]
      if not row or row[1] == "unown" then return nil end -- Unown never animates in Gen 3 -Elvie
      local hit = anims[row[1]]
      if hit ~= nil then return hit or nil end
      if crystalText == nil then crystalText = gb.readAt(gb.path("data", "pokemon.lua"), GB_GAMES) or false end
      local anim = crystalText and mons.crystalAnim(crystalText, row[1], animIndex)
      anims[row[1]] = anim or false
      return anim or nil
    end

    -- A set's own animation (GBC ANIM's Hoenn): anim/NNN.json, Crystal's
    -- script format ({ tiles, play, idle }), with anim/NNN.png and
    -- anim_shiny/NNN.png, every picture stacked, base first. Only from the
    -- set the front came from, so frames always match their front. -Elvie
    local ownAnims = {}
    local function ownAnimFor(set, nat)
      if not set or type(nat) ~= "number" then return nil end
      local key = set.key .. ":" .. nat
      local hit = ownAnims[key]
      if hit ~= nil then return hit or nil end
      ownAnims[key] = false
      local rel = MONS_DIR .. "/" .. set.key .. ("/anim/%03d.json"):format(nat)
      if not mod.assets:info(rel) then return nil end
      local ok, anim = pcall(require("mods.facets.npcs").decodeJson, mod:read(rel))
      if not ok or type(anim) ~= "table" or type(anim.play) ~= "table" or not tonumber(anim.tiles) then
        mod.log:warn("%s couldn't be read", rel)
        return nil
      end
      anim.sheetRel = MONS_DIR .. "/" .. set.key .. ("/anim/%03d.png"):format(nat)
      anim.shinyRel = MONS_DIR .. "/" .. set.key .. ("/anim_shiny/%03d.png"):format(nat)
      ownAnims[key] = anim
      return anim
    end

    -- The front's script as Gen 3 sprite commands: the set's own, or
    -- Crystal's for a Game Boy front. -Elvie
    local function gbCommands(species)
      local front = lookup("front", species, nil, false)
      if not front then return nil end
      local hit = commands[species]
      if hit ~= nil then return hit or nil end
      local anim = ownAnimFor(front.set, (identify(species)))
      if not anim and front.gb then anim = crystalAnimFor((identify(species))) end
      local cmds = anim and mons.animCommands(anim, Gen2Anim) or nil
      commands[species] = cmds or false
      return cmds
    end

    -- Frame n of a set's own sheet, placed like the front: the sheet's
    -- pictures sit at the bottom centre of a 64x64 frame, as its front
    -- does. -Elvie
    local function ownFrame(front, species, frame, shiny)
      local anim = ownAnimFor(front.set, (identify(species)))
      if not (anim and placements[species]) then return nil end
      local rel = shiny and anim.shinyRel or anim.sheetRel
      if not mod.assets:info(rel) then return nil end
      local ok, sheet = pcall(love.image.newImageData, mod.assets:path(rel))
      if not ok or not sheet then return nil end
      local size = tonumber(anim.tiles) * 8
      local w, h = sheet:getDimensions()
      if w ~= size or (frame + 1) * size > h then return nil end
      local ox, oy = math.floor((SIZE - size) / 2), SIZE - size
      local view = {
        getDimensions = function() return SIZE, SIZE end,
        getPixel = function(_, x, y)
          local sx, sy = x - ox, y - oy
          if sx < 0 or sy < 0 or sx >= size or sy >= size then return 0, 0, 0, 0 end
          return sheet:getPixel(sx, sy + frame * size)
        end,
      }
      return mons.layOut(view, bottomFor("front", species), ownColour, placements[species])
    end

    -- Frame n: the set's own sheet, or Crystal's for a Game Boy front,
    -- coloured and placed like the front. -Elvie
    local function gbFrame(species, frame, shiny)
      local front = lookup("front", species, nil, shiny)
      if not front then return nil end
      local key = "frame:" .. species .. ":" .. frame .. (shiny and ":s" or "")
      local hit = cache[key]
      if hit ~= nil then return hit or nil end
      cache[key] = false
      if front.set then
        local data = ownFrame(front, species, frame, shiny)
        if not (data and love and love.graphics) then return nil end
        local image = love.graphics.newImage(data)
        image:setFilter("nearest", "nearest")
        local entry = { image = image, imageData = data, w = SIZE, h = SIZE, set = front.set }
        cache[key] = entry
        return entry
      end
      if not front.gb then
        -- made from Emerald's pictures: Emerald's own frame, made the same
        -- way as the front -Elvie
        if not fromEmeraldChain(current) then return nil end
        local data = gameAsGb("front", shiny, gameKeyOf(species, 0), species, frame)
        if not (data and love and love.graphics) then return nil end
        local image = love.graphics.newImage(data)
        image:setFilter("nearest", "nearest")
        local entry = { image = image, imageData = data, w = SIZE, h = SIZE }
        cache[key] = entry
        return entry
      end
      local nat = identify(species)
      local anim = crystalAnimFor(nat)
      local size = anim and tonumber(anim.tiles) and tonumber(anim.tiles) * 8
      local sheet = size and type(anim.sheet) == "string" and gb.readImage(anim.sheet, GB_GAMES)
      local _, pal = crystalSprite("front", shiny, nat)
      if not (sheet and pal and placements[species]) then return nil end
      local w, h = sheet:getDimensions()
      if w < size or (frame + 1) * size > h then return nil end
      local view = {
        getDimensions = function() return size, size end,
        getPixel = function(_, x, y) return sheet:getPixel(x, y + frame * size) end,
      }
      local data = mons.layOut(view, bottomFor("front", species), gbColour(pal, view), placements[species])
      if not (data and love and love.graphics) then return nil end
      local image = love.graphics.newImage(data)
      image:setFilter("nearest", "nearest")
      local entry = { image = image, imageData = data, w = SIZE, h = SIZE, gb = true }
      cache[key] = entry
      return entry
    end

    -- Emerald's animations in FireRed and LeafGreen
    -- The engine reads Gen 3 animation data through MonAnimData.cache(),
    -- which for FR/LG has none. With the option on, that read goes to the
    -- player's Emerald instead (the species numbers are the same). Where
    -- FR/LG's own picture differs from Emerald's (most of Kanto was
    -- redrawn), the front uses Emerald's art, so both frames match. -Elvie
    -- --------------------------------------------------
    local okV, GameVersion = pcall(require, "src.core.GameVersion")
    local function game() return okV and type(GameVersion) == "table" and GameVersion.get() or nil end
    local FRLG = { firered = true, leafgreen = true }
    local borrow = false
    -- GBC-ISH (and GBC ANIM through it) plays Emerald's animations
    -- too, so it borrows them -Elvie
    local function borrowing()
      return (borrow or (current ~= nil and fromEmeraldChain(current))) and FRLG[game()] == true
    end
    local okD, AnimData = pcall(require, "src.core.game3.mon_anim_data")
    if not okD or type(AnimData) ~= "table" then AnimData = nil end
    local emerald = { read = function(_, rel) return (gb.readAt(rel, { "emerald" })) end }
    if AnimData and type(AnimData.cache) == "function" then
      local origCache = AnimData.cache
      AnimData.cache = function(...)
        if borrowing() then return emerald end
        return origCache(...)
      end
    end
    if AnimData and type(AnimData.anims) == "function" then
      local origAnims = AnimData.anims
      AnimData.anims = function(species, ...)
        local out = origAnims(species, ...)
        local sp = tonumber(species)
        if type(out) == "table" and sp and current then
          local cmds = gbCommands(sp)
          if cmds then
            local copy = {}
            for k, v in pairs(out) do copy[k] = v end
            copy[1] = cmds -- anim 1 plays with the cry -Elvie
            return copy
          end
        end
        return out
      end
    end

    local same = {} -- [species(:s)] = FR/LG's picture is Emerald's
    local function sameArt(species, shiny)
      local key = species .. (shiny and ":s" or "")
      if same[key] == nil then
        local own = gb.readAt(gb.path("monData", ("%s/%d.rgba"):format(shiny and "front_shiny" or "front", species)), { game() })
        local em = gb.readAt(gb.path("monData", ("%s/%d.rgba"):format(shiny and "front_anim_shiny" or "front_anim", species)), { "emerald" })
        same[key] = type(own) == "string" and type(em) == "string" and #own > 0 and em:sub(1, #own) == own
      end
      return same[key]
    end

    -- Emerald's art for the Pokémon FR/LG redrew, so they get Emerald's
    -- second frame too. Each frame is re-stood on FR/LG's ground line for
    -- that Pokémon (FR/LG's offsets suit its own art), both frames in the
    -- same spot. Spinda (spots), Castform's forms, Deoxys and the egg
    -- stay FR/LG's. -Elvie
    local emPics, emPlace = {}, {}
    local emeraldPic
    function emeraldPic(species, frame, shiny)
      if species == tonumber(Pokemon.SPECIES_EGG) or species == (tonumber(Pokemon.SPECIES_SPINDA) or 308)
          or species == (tonumber(Pokemon.SPECIES_DEOXYS) or 410) then return nil end
      if sameArt(species, shiny) then return nil end
      -- frame 0 sets the spot the other frames use -Elvie
      if frame > 0 and not emeraldPic(species, 0, shiny) then return nil end
      local key = species .. ":" .. frame .. (shiny and ":s" or "")
      local hit = emPics[key]
      if hit ~= nil then return hit or nil end
      emPics[key] = false
      local sheet = gb.readAt(gb.path("monData", ("%s/%d.rgba"):format(shiny and "front_anim_shiny" or "front_anim", species)), { "emerald" })
      local size = SIZE * SIZE * 4
      if type(sheet) ~= "string" or #sheet < size * (frame + 1) or not (love and love.graphics) then return nil end
      local ok, data = pcall(love.image.newImageData, SIZE, SIZE, "rgba8", sheet:sub(size * frame + 1, size * (frame + 1)))
      if not ok or not data then return nil end
      emPlace[species] = emPlace[species] or {}
      local out = mons.layOut(data, bottomFor("front", species), ownColour, emPlace[species])
      if not out then return nil end
      local image = love.graphics.newImage(out)
      image:setFilter("nearest", "nearest")
      local entry = { image = image, imageData = out, w = SIZE, h = SIZE, emerald = true }
      emPics[key] = entry
      return entry
    end
    mons.emeraldPic = emeraldPic

    local origFront, origBack = Pokemon.frontPic, Pokemon.backPic
    Pokemon.frontPic = function(species, form, shiny, personality, ...)
      local e = lookup("front", species, form, shiny)
      if e then return e end
      local sp = tonumber(species)
      if sp and (tonumber(form) or 0) == 0 and borrowing() then
        e = emeraldPic(sp, 0, shiny and true or false)
        if e then return e end
      end
      return origFront(species, form, shiny, personality, ...)
    end
    -- YOUR SIDE: FRONT. The front picture (from the set, Emerald's or
    -- the game's), moved to the back's ground line and, with MIRROR
    -- FRONTS on, flipped to face the foe. Drawn once into a picture of
    -- its own, then kept. -Elvie
    local backs, mirrored, asBack = "back", false, {}
    local function frontAsBack(species, form, shiny, frame)
      local sp = tonumber(species)
      frame = tonumber(frame) or 0
      if not sp or not (love and love.graphics and love.graphics.newCanvas) then return nil end
      local suffix = ""
      if type(Pokemon.deoxysFormSuffix) == "function" then
        local okS, got = pcall(Pokemon.deoxysFormSuffix, sp)
        suffix = okS and type(got) == "string" and got or ""
      end
      local key = sp .. suffix .. ":" .. (tonumber(form) or 0) .. ":" .. frame .. (shiny and ":s" or "")
      local hit = asBack[key]
      if hit ~= nil then return hit or nil end
      local ok, front = false, nil
      if frame ~= 0 then
        local MonAnim = package.loaded["src.core.game3.mon_anim"]
        if type(MonAnim) == "table" and type(MonAnim.framePic) == "function" then
          ok, front = pcall(MonAnim.framePic, sp, frame, shiny)
        end
        -- a frame the set doesn't have: the still picture -Elvie
        if not (ok and type(front) == "table" and front.image) then return frontAsBack(sp, form, shiny, 0) end
      else
        ok, front = pcall(Pokemon.frontPic, sp, form, shiny)
      end
      if not (ok and type(front) == "table" and front.image) then
        asBack[key] = false
        return nil
      end
      local w, h = SIZE, SIZE
      local shift = mons.frontAsBackShift(PicCoords, sp)
      local made, entry = pcall(function()
        local canvas = love.graphics.newCanvas(w, h)
        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(front.image, mirrored and w or 0, shift, 0, mirrored and -1 or 1, 1)
        love.graphics.pop()
        local data = canvas:newImageData()
        canvas:release()
        local image = love.graphics.newImage(data)
        image:setFilter("nearest", "nearest")
        return { image = image, imageData = data, w = w, h = h }
      end)
      if not made then
        mod.log:warn("front as back for %d: %s", sp, tostring(entry))
        entry = false
      end
      asBack[key] = entry
      return entry or nil
    end
    mons.frontAsBack = frontAsBack

    -- Front animations on your side too. The battle starts a back
    -- animation for your Pokémon; with YOUR SIDE: FRONT it starts the
    -- front one instead (no cry: the battle plays that itself), and its
    -- picture follows the animation's frame. Mirrored, its moves are
    -- mirrored too, so a lunge goes toward the foe. -Elvie
    local okB, Battle = pcall(require, "src.core.game3.battle.mon_anim_battle")
    if okB and type(Battle) == "table" and type(Battle.start) == "function" and type(Battle.apply) == "function" then
      local origStart, origApply = Battle.start, Battle.apply
      Battle.start = function(key, kind, opts, ...)
        if kind == "back" and backs == "front" then
          local copy = {}
          for k, v in pairs(type(opts) == "table" and opts or {}) do copy[k] = v end
          copy.noCry = true
          local sprite = origStart(key, "front", copy, ...)
          if type(sprite) == "table" then sprite.facetsSide = true end
          return sprite
        end
        return origStart(key, kind, opts, ...)
      end
      Battle.apply = function(p, sprite, ...)
        local out = origApply(p, sprite, ...)
        if type(p) == "table" and type(sprite) == "table" and sprite.facetsSide and mirrored then
          p.ox = -(tonumber(p.ox) or 0)
          p.rotation = -(tonumber(p.rotation) or 0)
        end
        return out
      end
    end
    -- the frame your side's front animation is on, 0 when none plays -Elvie
    local function sideFrame(species)
      local B = package.loaded["src.core.game3.battle.mon_anim_battle"]
      if type(B) ~= "table" or type(B._active) ~= "table" then return 0 end
      for p, sprite in pairs(B._active) do
        if type(sprite) == "table" and sprite.facetsSide and tonumber(sprite.species) == species and type(p) == "table" then
          return tonumber(p.monFrame) or 0
        end
      end
      return 0
    end
    mons.sideFrame = sideFrame

    Pokemon.backPic = function(species, form, shiny, ...)
      if backs == "front" then
        local sp = tonumber(species)
        local e = frontAsBack(species, form, shiny, sp and sideFrame(sp) or 0)
        if e then return e end
      end
      return lookup("back", species, form, shiny) or origBack(species, form, shiny, ...)
    end
    Pokemon.frontSprite = Pokemon.frontPic
    if type(Pokemon.icon) == "function" then
      local origIcon = Pokemon.icon
      Pokemon.icon = function(species, ...)
        return iconLookup(species) or origIcon(species, ...)
      end
    end
    local okA, MonAnim = pcall(require, "src.core.game3.mon_anim")
    if okA and type(MonAnim) == "table" and type(MonAnim.framePic) == "function" then
      local origFrame = MonAnim.framePic
      MonAnim.framePic = function(species, frame, shiny, ...)
        local f = tonumber(frame) or 0
        local sp = tonumber(species)
        if f ~= 0 and sp then
          if current then
            local e = gbFrame(sp, f, shiny)
            if e then return e end
          end
          local e = lookup("front", sp, nil, shiny)
          if e then return e end
          if borrowing() then
            local em = emeraldPic(sp, f, shiny and true or false)
            if em then return em end
          end
        end
        return origFrame(species, frame, shiny, ...)
      end
    end

    local function configure()
      local selected = mod.options:get("setMons")
      current = nil
      for _, set in ipairs(sets) do
        if set.key == selected then current = set end
      end
      cache, placements, commands = {}, {}, {}
      asBack, plans = {}, {}
      -- GBC-ISH changes whether FR/LG borrows Emerald's animations -Elvie
      if AnimData and type(AnimData.reset) == "function" then AnimData.reset() end
    end
    local function configureAnims()
      borrow = mod.options:get("animMons") == "emerald"
      emPics, emPlace = {}, {}
      asBack = {}
      if AnimData and type(AnimData.reset) == "function" then AnimData.reset() end
    end
    local function configureBacks()
      backs = mod.options:get("backMons") == "front" and "front" or "back"
      mirrored = mod.options:get("mirrorMons") ~= OFF
      asBack = {}
    end
    configure()
    configureAnims()
    configureBacks()
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) ~= "table" or change.mod ~= mod.id then return end
        if change.key == "setMons" then configure() end
        if change.key == "animMons" then configureAnims() end
        if change.key == "backMons" or change.key == "mirrorMons" then configureBacks() end
      end)
    end
  end
end

-- The FACETS screen
-- POKEMON: the SET; ANIMS: FR/LG ANIMS, in FireRed and LeafGreen only. The
-- preview shows a starter from each region in turn through
-- Pokemon.frontPic, the way the game draws them, and plays its front
-- animation's frames when the game has one (Emerald, FR/LG with ANIMS
-- on), so a GBC Pokémon flips through Crystal's. -Elvie
-- --------------------------------------------------
-- Engine species: Bulbasaur, Charmander, Squirtle, Pikachu, Chikorita,
-- Cyndaquil, Totodile, Treecko, Torchic, Mudkip. -Elvie
local SHOWCASE = { 1, 4, 7, 25, 152, 155, 158, 277, 280, 283 }
local SLOT_TIME, ANIM_DELAY = 3, 0.5
local FRONT_X, FRONT_Y = 160, 24
mons.SHOWCASE, mons.SLOT_TIME = SHOWCASE, SLOT_TIME

-- The frame a sprite command list shows `tick` ticks in (0 after it ends). -Elvie
function mons.frameAt(cmds, tick)
  if type(cmds) ~= "table" then return 0 end
  local t = 0
  for _, c in ipairs(cmds) do
    if c.op == "end" then return 0 end
    if c.frame ~= nil then
      local d = math.max(1, tonumber(c.duration) or 1)
      if tick < t + d then return c.frame end
      t = t + d
    end
  end
  return 0
end

-- Which showcase Pokémon and frame the preview shows at `clock`. -Elvie
function mons.showcaseAt(clock, anims)
  local slot = math.floor(clock / SLOT_TIME) % #SHOWCASE + 1
  local species = SHOWCASE[slot]
  local t = clock % SLOT_TIME - ANIM_DELAY
  local frame = 0
  if t >= 0 and type(anims) == "function" then
    local ok, list = pcall(anims, species)
    if ok and type(list) == "table" then frame = mons.frameAt(list[1], math.floor(t * 60)) end
  end
  return species, frame
end

function mons.screenPart(mod, menu, sets, choices, Pokemon)
  local emeraldThere
  local function hasEmerald()
    if emeraldThere == nil then
      emeraldThere = gb.readAt(gb.path("monData", "front_anims.lua"), { "emerald" }) ~= nil
    end
    return emeraldThere
  end
  local function selected()
    local value = mod.options:get("setMons")
    for _, set in ipairs(sets) do
      if set.key == value then return set end
    end
    return nil
  end
  menu.register({
    rows = function(family)
      local out = { { key = "setMons", label = "POKéMON", who = "mons", choices = choices,
        value = (selected() or {}).key or OFF } }
      if family.id == "frlg" then
        out[2] = { key = "animMons", label = "ANIMS", who = "anims",
          choices = { { "EMERALD", "emerald" }, { "OFF", OFF } },
          value = mod.options:get("animMons") == "emerald" and "emerald" or OFF }
      end
      -- YOUR SIDE and MIRROR FRONTS share one row here, to save room -Elvie
      out[#out + 1] = { key = "backMons", label = "YOUR SIDE", who = "backs", choices = mons.SIDES,
        value = mons.sideOf(mod.options:get("backMons"), mod.options:get("mirrorMons")),
        set = function(game, value)
          menu.set(game, "backMons", value == "back" and "back" or "front")
          -- BACK leaves MIRROR FRONTS as it was, for next time -Elvie
          if value ~= "back" then menu.set(game, "mirrorMons", value == "mirrored" and "on" or OFF) end
        end }
      return out
    end,
    preview = function(who)
      if who == "mons" then
        local set = selected()
        if not set then return { lines = { { text = "The game's own POKéMON." } } } end
        return { lines = require("mods.facets.menu").creditLines(set.credit) }
      elseif who == "anims" then
        if mod.options:get("animMons") ~= "emerald" then
          return { lines = { { text = "FR/LG's still pictures." } } }
        end
        if not hasEmerald() then
          return { lines = { { text = "Needs Emerald imported.", red = true } } }
        end
        return { lines = { { text = "Emerald's animations," }, { text = "from your Emerald." },
          { text = "Redrawn Kanto: Emerald's art." } } }
      elseif who == "backs" then
        local side = mons.sideOf(mod.options:get("backMons"), mod.options:get("mirrorMons"))
        -- one short line: FR/LG's list leaves room for little else -Elvie
        if side == "back" then
          return { lines = { { text = "Your side from behind." } } }
        elseif side == "front" then
          return { lines = { { text = "Fronts, as drawn." } } }
        end
        return { lines = { { text = "Fronts, facing the foe." } } }
      end
      return nil
    end,
    -- spots.mon = { x, y } moves it (PRISM's corner). On the YOUR SIDE
    -- row it shows your side's picture instead. -Elvie
    draw = function(clock, family, spots, who)
      if not (love and love.graphics) then return end
      local at = type(spots) == "table" and spots.mon or nil
      local okD, AnimData = pcall(require, "src.core.game3.mon_anim_data")
      local species, frame = mons.showcaseAt(clock, okD and type(AnimData) == "table" and AnimData.anims or nil)
      local pic
      if who == "backs" then
        local ok, got = pcall(Pokemon.backPic, species, 0, false)
        pic = ok and got or nil
        frame = 0
      end
      if frame ~= 0 then
        local okA, MonAnim = pcall(require, "src.core.game3.mon_anim")
        if okA and type(MonAnim) == "table" and type(MonAnim.framePic) == "function" then
          local ok, got = pcall(MonAnim.framePic, species, frame, false)
          pic = ok and got or nil
        end
      end
      if not pic then
        local ok, got = pcall(Pokemon.frontPic, species, 0, false, 0)
        pic = ok and got or nil
      end
      if type(pic) == "table" and pic.image then
        love.graphics.draw(pic.image, at and at.x or FRONT_X, at and at.y or FRONT_Y)
      end
    end,
    credits = function()
      local out = {}
      for _, set in ipairs(sets) do
        out[#out + 1] = { text = "POKEMON: " .. set.label, heading = true }
        local lines = require("mods.facets.menu").creditLines(set.credit)
        if #lines == 0 then lines[1] = { text = "No credit listed." } end
        for _, line in ipairs(lines) do out[#out + 1] = { text = line.text } end
      end
      return out
    end,
  })
end

return mons
