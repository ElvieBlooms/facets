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
  local at = text:find('sheet = "assets/generated/battle/anim/' .. stem .. '.png"', 1, true)
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

function mons.init(mod, rows)
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
      sets[#sets + 1] = { key = key, label = label, gb = meta.source == "gb" }
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

    -- A PNG of the set's own, as ImageData, or nil. variant is "" or a
    -- form's suffix (_sunny, _attack...). -Elvie
    local function ownFile(set, kind, shiny, nat, letter, variant)
      local name
      if nat == "egg" then name = "egg"
      else
        name = ("%03d"):format(nat)
        if nat == 201 and (letter or 0) > 0 then name = name .. "_" .. ("bcdefghijklmnopqrstuvwxyz!?"):sub(letter, letter) end
      end
      if name:find("[!?]") then name = name:gsub("!", "emark"):gsub("%?", "qmark") end
      name = name .. (variant or "")
      local rel = MONS_DIR .. "/" .. set.key .. "/" .. kind .. (shiny and "_shiny" or "") .. "/" .. name .. ".png"
      if not mod.assets:info(rel) then return nil end
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
      return data
    end

    -- Crystal's sprite and palette for a Pokémon, or nil. -Elvie
    local function gbSprite(kind, shiny, nat, letter)
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
      if palettes == nil then
        palettes = mons.parsePalettes(gb.readAt("data/generated/palettes.lua", { "crystal" })) or false
        if not palettes then mod.log:warn("Crystal's palettes weren't found; GBC Pokémon need Crystal imported") end
      end
      local pal = palettes and palettes[palName]
      if not pal then return nil end
      local src = gb.readImage("assets/generated/battle/" .. kind .. "/" .. file .. ".png", GB_GAMES)
      if not src then return nil end
      return src, shiny and pal.shiny or pal.normal
    end

    local placements = {} -- [species] = where a Game Boy front sits, for its frames

    -- The picture, and true when it's a Game Boy one. -Elvie
    local function build(kind, species, shiny, nat, letter, variant)
      local data = ownFile(current, kind, shiny, nat, letter, variant)
      if data then
        -- Stood on the game's own ground line, like everything else. -Elvie
        local out, why = mons.layOut(data, bottomFor(kind, species), ownColour)
        if not out then mod.log:warn("%s %s: %s", kind, tostring(nat), tostring(why)) end
        return out
      end
      if current.gb and variant == "" then
        local src, pal = gbSprite(kind, shiny, nat, letter)
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
      local ok, data, fromGb = pcall(build, kind, species, shiny, nat, letter, variant)
      if not ok then
        mod.log:warn("%s %d: %s", kind, species, tostring(data))
        data = nil
      end
      local entry = false
      if data and love and love.graphics then
        local image = love.graphics.newImage(data)
        image:setFilter("nearest", "nearest")
        entry = { image = image, imageData = data, w = SIZE, h = SIZE, gb = fromGb or nil }
      end
      cache[key] = entry
      return entry or nil
    end
    mons.lookup = lookup

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
      if crystalText == nil then crystalText = gb.readAt("data/generated/pokemon.lua", GB_GAMES) or false end
      local anim = crystalText and mons.crystalAnim(crystalText, row[1], animIndex)
      anims[row[1]] = anim or false
      return anim or nil
    end

    -- Crystal's script as Gen 3 sprite commands, for a Game Boy front. -Elvie
    local function gbCommands(species)
      local front = lookup("front", species, nil, false)
      if not (front and front.gb) then return nil end
      local hit = commands[species]
      if hit ~= nil then return hit or nil end
      local cmds = mons.animCommands(crystalAnimFor((identify(species))), Gen2Anim)
      commands[species] = cmds or false
      return cmds
    end

    -- Frame n of Crystal's sheet, coloured and placed like the front. -Elvie
    local function gbFrame(species, frame, shiny)
      local front = lookup("front", species, nil, shiny)
      if not (front and front.gb) then return nil end
      local key = "frame:" .. species .. ":" .. frame .. (shiny and ":s" or "")
      local hit = cache[key]
      if hit ~= nil then return hit or nil end
      cache[key] = false
      local nat = identify(species)
      local anim = crystalAnimFor(nat)
      local size = anim and tonumber(anim.tiles) and tonumber(anim.tiles) * 8
      local sheet = size and type(anim.sheet) == "string" and gb.readImage(anim.sheet, GB_GAMES)
      local _, pal = gbSprite("front", shiny, nat)
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
    -- FR/LG's own picture differs from Emerald's (most of Kanto was redrawn),
    -- the second frame stays FR/LG's picture, so only the movement plays. -Elvie
    -- --------------------------------------------------
    local okV, GameVersion = pcall(require, "src.core.GameVersion")
    local function game() return okV and type(GameVersion) == "table" and GameVersion.get() or nil end
    local FRLG = { firered = true, leafgreen = true }
    local borrow = false
    local function borrowing() return borrow and FRLG[game()] == true end
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
        if type(out) == "table" and sp and current and current.gb then
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
        local own = gb.readAt(("data/generated/gba/pokemon/%s/%d.rgba"):format(shiny and "front_shiny" or "front", species), { game() })
        local em = gb.readAt(("data/generated/gba/pokemon/%s/%d.rgba"):format(shiny and "front_anim_shiny" or "front_anim", species), { "emerald" })
        same[key] = type(own) == "string" and type(em) == "string" and #own > 0 and em:sub(1, #own) == own
      end
      return same[key]
    end

    local origFront, origBack = Pokemon.frontPic, Pokemon.backPic
    Pokemon.frontPic = function(species, form, shiny, personality, ...)
      return lookup("front", species, form, shiny) or origFront(species, form, shiny, personality, ...)
    end
    Pokemon.backPic = function(species, form, shiny, ...)
      return lookup("back", species, form, shiny) or origBack(species, form, shiny, ...)
    end
    Pokemon.frontSprite = Pokemon.frontPic
    local okA, MonAnim = pcall(require, "src.core.game3.mon_anim")
    if okA and type(MonAnim) == "table" and type(MonAnim.framePic) == "function" then
      local origFrame = MonAnim.framePic
      MonAnim.framePic = function(species, frame, shiny, ...)
        local f = tonumber(frame) or 0
        local sp = tonumber(species)
        if f ~= 0 and sp then
          if current and current.gb then
            local e = gbFrame(sp, f, shiny)
            if e then return e end
          end
          local e = lookup("front", sp, nil, shiny)
          if e then return e end
          if borrowing() and not sameArt(sp, shiny) then
            local own = origFront(sp, nil, shiny)
            if own then return own end
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
    end
    local function configureAnims()
      borrow = mod.options:get("animMons") == "emerald"
      if AnimData and type(AnimData.reset) == "function" then AnimData.reset() end
    end
    configure()
    configureAnims()
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) ~= "table" or change.mod ~= mod.id then return end
        if change.key == "setMons" then configure() end
        if change.key == "animMons" then configureAnims() end
      end)
    end
  end
end

return mons
