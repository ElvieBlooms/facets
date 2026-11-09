-- Pokémon pictures on the Game Boy games (Red, Blue, Yellow, Gold, Silver, Crystal)
-- Every Pokémon picture there comes through the pokemon.sprite hook
-- (battle, summary, Pokédex, PC, Hall of Fame, trades...), so one wrap
-- covers them all. A set's 64x64 art is cut to the Pokémon itself and,
-- under FIT, shrunk only if it still doesn't fit the game's own box: 56x56
-- for a front, 48x48 for a back (classic.lua makes the pictures). -Elvie
--
-- Only full-colour sets are offered (and on Red, Blue and Yellow, Crystal's
-- own sprites): the Game Boy ones (GBC-ISH and so on) are these games' own
-- look already. Crystal's animations stay on its own pictures; a replaced
-- one is still, apart from Emerald's on the GBA look. -Elvie
-- --------------------------------------------------

local classic = {}

local MONS_DIR = "assets/mons"
local OFF = "__off"
local PREFIX = "facets/classic/"

local shared = require("mods.facets.classic")
local gba = require("mods.facets.classic_gba")
local gb = require("mods.facets.gb")
local cds = require("mods.facets.classic_ds")
local ds = require("mods.facets.ds")
local crystal = require("mods.facets.classic_crystal")
classic.BOX = { front = shared.BOX.front, back = shared.BOX.back }
classic.SIZES = shared.SIZES
classic.bounds = shared.bounds
classic.fitScale = shared.fitScale
classic.build = shared.build
classic.square = shared.square
-- Emerald's two frames in the slots order asks for: ImageData, side -Elvie
function classic.layOut(f0, f1, order, box)
  return shared.sheet({ f0, f1 }, order, box)
end
classic.SIDES = { { "BACK", "back" }, { "MIRRORED", "mirrored" }, { "FRONT", "front" } }

-- Party icons: the game's own shapes, or the Minidex's one per Pokémon
-- (Chamber, Soloo993, Blue Emerald, Lake, Neslug and Pikachu25), the same
-- icons GBC-ISH uses on Gen 3. They're the Game Boy's own 16x16, two
-- frames, so they drop straight in -Elvie
classic.ICONS = { { "GAME", "game" }, { "MINIDEX", "minidex" } }
classic.ICON_DIR = "assets/mons/gbcish/icons"

-- The icon file for a Pokémon, or nil for the game's own -Elvie
function classic.iconFor(choice, dex, has)
  if choice ~= "minidex" or type(dex) ~= "number" or dex < 1 or dex > 251 then return nil end
  local rel = ("%s/%03d.png"):format(classic.ICON_DIR, dex)
  return has(rel) and rel or nil
end

-- Which picture a request gets: the file to read, the box (nil = cut but
-- not shrunk), the mirror, and the battle scale. nil = the game's own. -Elvie
-- opts = { set, size, side, has = function(rel) } -Elvie
function classic.choose(opts, dex, side, kind, shiny)
  if not opts.set or opts.set == OFF or not dex then return nil end
  if type(kind) == "string" and kind:match("_anim$") then return nil end
  local battle = kind == "battle"
  local mirror = false
  local face = side
  if side == "back" and battle and opts.side ~= "back" then
    face = "front"
    mirror = opts.side == "mirrored"
  end
  local rel, load, grey
  if opts.set == crystal.CHOICE then
    -- Crystal's, from the player's install: grey for the game to tint, or
    -- in Crystal's colours on RED++ -Elvie
    if not crystal.picturePath(dex, face) then return nil end
    local coloured = opts.coloured and true or false
    rel = ("crystal/%s/%03d%s.png"):format(face, dex, coloured and (shiny and "cs" or "c") or "")
    load = function() return crystal.picture(dex, face, shiny, coloured) end
    grey = not coloured
  elseif gba.isChoice(opts.set) then
    -- the GBA look: from the player's own FireRed or Emerald. Unown stays
    -- the game's own, since its letters are kept apart there -Elvie
    if dex == 201 then return nil end
    local found = (opts.gbaFind or gba.monPicture)(opts.set, dex, face, shiny)
    if not found then return nil end
    rel = opts.set .. "/" .. found.game .. "/" .. found.rel:gsub("%.rgba$", ".png")
    load = function() return gba.load(found) end
  else
    local name = ("%03d.png"):format(dex)
    for _, dir in ipairs(shiny and { face .. "_shiny", face } or { face }) do
      local try = MONS_DIR .. "/" .. opts.set .. "/" .. dir .. "/" .. name
      if opts.has(try) then rel = try break end
    end
  end
  if not rel then return nil end
  local scale = battle and tonumber(opts.size) or nil
  -- a front on your side keeps a front's size: it stands 8 px taller than
  -- the back box, into empty screen -Elvie
  local box = not scale and classic.BOX[face == "front" and "front" or side] or nil
  -- Gen 1's HALL OF FAME doubles the back's top-left 28x28 -Elvie
  if kind == "hof" and side == "back" and classic.BOX.hofBack then box = classic.BOX.hofBack end
  -- Gen 2's enemy, from Emerald: the still frame laid out the way its
  -- animation is (animSheet), so the two line up -Elvie
  local raw
  local anim = opts.animate and battle and side == "front" and face == "front" and gba.isChoice(opts.set)
    and gba.monAnim(opts.set, dex, shiny)
  if anim then
    rel = rel:gsub("%.png$", "@a.png")
    load = function()
      local f0, f1 = gba.animFrames(anim)
      return f0 and (classic.layOut(f0, f1, { 1 }, box))
    end
    raw = true
  end
  -- CRYSTAL's enemy the same way, from Crystal's own frames -Elvie
  if not anim and opts.animate and battle and side == "front" and face == "front"
      and opts.set == crystal.CHOICE and crystal.anim(dex) then
    local coloured = opts.coloured and true or false
    rel = rel:gsub("%.png$", "@a.png")
    load = function()
      local frames = crystal.animFrames(dex, shiny, coloured)
      return frames and (shared.sheet(frames, { 1 }, box))
    end
    raw = true
  end
  -- outside battle Gold/Silver/Crystal place a picture by its width, so
  -- it goes in the box's square -Elvie
  local square = not battle and box ~= nil and not raw and shared.generation() == 2
  local stem = load and rel or rel:sub(#MONS_DIR + 2)
  return { rel = rel, load = load, raw = raw, grey = grey, box = box, mirror = mirror, scale = scale,
    square = square or nil,
    path = PREFIX .. stem:gsub("%.png$", "")
      .. (box and ("@" .. box) or "@cut") .. (mirror and "m" or "") .. (square and "sq" or "") .. ".png" }
end

-- The game's own front for the back picture it asked for, Unown's letter
-- included: nil when there isn't one -Elvie
function classic.frontFor(def, backPath)
  if type(def) ~= "table" then return nil end
  for _, form in pairs(type(def.letters) == "table" and def.letters or {}) do
    if type(form) == "table" and form.spriteBack == backPath and type(form.spriteFront) == "string" then
      return form.spriteFront
    end
  end
  return type(def.spriteFront) == "string" and def.spriteFront or nil
end

-- Whether this is a game without Pokémon animations of its own: Red, Blue,
-- Yellow, Gold and Silver. They borrow Crystal's, from the player's
-- Crystal -Elvie
function classic.borrowsAnims()
  if shared.generation() == 1 then return true end
  local okV, GameVersion = pcall(require, "src.core.GameVersion")
  if not (okV and type(GameVersion) == "table" and type(GameVersion.get) == "function") then return false end
  local ok, version = pcall(GameVersion.get)
  return ok and (version == "gold" or version == "silver") or false
end

-- Sets that suit the Game Boy games: full colour, with a front folder -Elvie
local function findSets(mod)
  local sets = {}
  local okD, decode = pcall(function() return require("mods.facets.npcs").decodeJson end)
  for _, key in ipairs(mod.assets:list(MONS_DIR) or {}) do
    local dir = MONS_DIR .. "/" .. key
    local info = mod.assets:info(dir .. "/front")
    if info and info.type == "directory" then
      local meta = {}
      if okD and mod.assets:info(dir .. "/meta.json") then
        local ok, got = pcall(decode, mod:read(dir .. "/meta.json"))
        if ok and type(got) == "table" then meta = got end
      end
      if meta.source ~= "gb" then
        sets[#sets + 1] = { key = key, label = type(meta.label) == "string" and meta.label or key:upper() }
      end
    end
  end
  table.sort(sets, function(a, b) return a.label < b.label end)
  return sets
end

function classic.init(mod, rows)
  local sets = findSets(mod)
  if #sets == 0 then return nil end
  -- Gen 1's back box is 32x32 drawn at 2x -Elvie
  if shared.generation() == 1 then classic.BOX = { front = 56, back = 64, hofBack = 28 } end
  local choices = {}
  -- the DS games, from the player's own dumps through Prism Importer -Elvie
  for _, c in ipairs(cds.choices(ds.api(mod))) do choices[#choices + 1] = c end
  for _, set in ipairs(sets) do choices[#choices + 1] = { set.label, set.key } end
  if shared.generation() == 1 then
    choices[#choices + 1] = { crystal.LABEL, crystal.CHOICE }
    -- and Crystal's party icons -Elvie
    classic.ICONS = { classic.ICONS[1], classic.ICONS[2], { crystal.LABEL, "crystal" } }
  elseif classic.borrowsAnims() then
    -- Gold and Silver: Crystal's art, with Crystal's animations -Elvie
    choices[#choices + 1] = { crystal.LABEL, crystal.CHOICE }
  end
  for _, c in ipairs(gba.CHOICES) do choices[#choices + 1] = c end
  choices[#choices + 1] = { "OFF", OFF }
  rows[#rows + 1] = { key = "sectionClassicMons", type = "choice", label = "POKEMON",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "classicMons", type = "choice", label = "  SET", choices = choices, default = OFF }
  -- Yellow's partner Pikachu in battle: MATCH (its overworld look's, as
  -- before, else the SET), GAME (Yellow's own whatever the SET), any SET,
  -- or one of its looks -Elvie
  local npcs = require("mods.facets.classic_npcs")
  local looks = npcs.yellow() and npcs.pikachuLooks(mod) or {}
  if #looks > 0 then
    local pika = { { "MATCH", "match" }, { "GAME", "game" } }
    for _, c in ipairs(choices) do
      if c[2] ~= OFF then pika[#pika + 1] = c end
    end
    for _, look in ipairs(looks) do pika[#pika + 1] = { look.label, "look:" .. look.key } end
    rows[#rows + 1] = { key = "classicPikachuBattle", type = "choice", label = "  PIKACHU", choices = pika,
      default = "match" }
  end
  rows[#rows + 1] = { key = "classicSide", type = "choice", label = "  YOUR SIDE", choices = classic.SIDES, default = "back" }
  rows[#rows + 1] = { key = "classicIcons", type = "choice", label = "  ICONS", choices = classic.ICONS, default = "game" }
  shared.sizeRow(rows, "classicSize")

  return function()
    local pics = shared.setup(mod)
    if not pics then return end
    local opts = { has = pics.has }
    local gen1 = shared.generation() == 1
    -- whether Gen 1 shows full colour as it is (COLORS on RED++) -Elvie
    local okF, PaletteFX = pcall(require, "src.render.PaletteFX")
    local function coloured()
      if not gen1 then return true end
      if not (okF and type(PaletteFX) == "table" and type(PaletteFX.honorsTrueColor) == "function") then return false end
      local ok, yes = pcall(PaletteFX.honorsTrueColor)
      return ok and yes and true or false
    end
    -- next runs at most once per call, as the hook contract asks: not at
    -- all when the picture is ours, on the front when YOUR SIDE asks -Elvie
    -- Emerald's animation on Gen 2: Crystal's script for the Pokémon, its
    -- still frame Emerald's first and every other frame Emerald's second.
    -- The sheet is made as many frames long as Crystal's; animData gives
    -- the script the sheet's frame size, so the picture keeps its size
    -- while it moves -Elvie
    -- every game animates now; Gen 1's frames are drawn at their still
    -- picture's size (classic_gen1_anim) -Elvie
    local function animating() return true end
    local okA, Assets = pcall(require, "src.render.Assets")
    local sheets = {} -- [path] = { path, side } or false -Elvie
    local function animSheet(pokemon, species, shiny, crystalSheet)
      if not okA then return nil end
      opts.set = mod.options:get("classicMons")
      opts.size = mod.options:get("classicSize")
      local def = type(pokemon) == "table" and pokemon[species]
      local dex = type(def) == "table" and tonumber(def.dex) or nil
      if dex == 201 then return nil end
      local scale = tonumber(opts.size)
      local box = not scale and classic.BOX.front or nil
      -- CRYSTAL: Crystal's own frames, cut and laid out together -Elvie
      if dex and opts.set == crystal.CHOICE then
        local tint = coloured()
        local path = ("facets/classic/anim/crystal/%d%s%s@%s.png"):format(dex, shiny and "s" or "", tint and "c" or "", box or "cut")
        local hit = sheets[path]
        if hit ~= nil then return hit or nil end
        sheets[path] = false
        local frames = crystal.animFrames(dex, shiny, tint)
        if not frames then return nil end
        local order = {}
        for i = 1, #frames do order[i] = i end
        local sheet, side = shared.sheet(frames, order, box)
        if not sheet then return nil end
        Assets.compose(path, function() return sheet end)
        sheets[path] = { path = path, side = side, trueColor = tint }
        return sheets[path]
      end
      local anim = dex and gba.isChoice(opts.set) and gba.monAnim(opts.set, dex, shiny)
      if not anim or type(crystalSheet) ~= "string" then return nil end
      local path = ("facets/classic/anim/%s/%d%s@%s.png"):format(opts.set, dex, shiny and "s" or "", box or "cut")
      local hit = sheets[path]
      if hit ~= nil then return hit or nil end
      sheets[path] = false
      local okC, crystalData = pcall(Assets.imageData, crystalSheet)
      if not (okC and crystalData) then return nil end
      local cw, ch = crystalData:getDimensions()
      local count = math.max(1, math.floor(ch / math.max(1, cw)))
      local order = { 1 }
      for i = 2, count do order[i] = 2 end
      local f0, f1 = gba.animFrames(anim)
      if not (f0 and f1) then return nil end
      local sheet, side = classic.layOut(f0, f1, order, box)
      if not sheet then return nil end
      Assets.compose(path, function() return sheet end)
      sheets[path] = { path = path, side = side, trueColor = true }
      return sheets[path]
    end
    -- DPPT, HGSS and B2W2: the dump's animation, laid out for the game's
    -- box, its first frame the still picture (classic_ds) -Elvie
    local partnerChoice -- Yellow's partner's battle look, set further down -Elvie
    local dsPics = cds.new(mod)
    local dsByPath = {}
    local function dsPick(game, dex, side, kind, shiny)
      local battle = kind == "battle"
      local face, mirror = side, false
      if side == "back" and battle and opts.side ~= "back" then
        face, mirror = "front", opts.side == "mirrored"
      end
      local scale = battle and tonumber(opts.size) or nil
      local box = not scale and classic.BOX[face == "front" and "front" or side] or nil
      if kind == "hof" and side == "back" and classic.BOX.hofBack then box = classic.BOX.hofBack end
      local rec = dsPics.record(game, dex, face, shiny, mirror, box)
      if not rec then return nil end
      local path = rec.path:gsub("%.png$", "@still.png")
      dsByPath[path] = rec
      return { rel = rec.path, raw = true, box = box, scale = scale, path = path, rec = rec,
        load = function() return cds.slot(rec.sheet, rec.side, 0) end }
    end
    -- in battle they keep moving: the frame showing in place of the still
    -- one, whichever side it's on -Elvie
    if not gen1 then
      local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
      if okB and type(BattleState) == "table" and type(BattleState.pic) == "function" then
        local ownPic = BattleState.pic
        BattleState.pic = function(self, mon, back, ...)
          local image, trueColor, path = ownPic(self, mon, back, ...)
          local rec = type(path) == "string" and dsByPath[path]
          if not rec or self.showPlayerTrainer then return image, trueColor, path end
          local ok, img = pcall(dsPics.image, rec, dsPics.frameAt(rec))
          if ok and img then return img, trueColor, path end
          return image, trueColor, path
        end
      end
    end
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id and change.key == "classicMons" then dsPics.reset(); dsByPath = {} end
      end)
    end

    -- Crystal's script for a game without one, for the sets that bring
    -- their own frames (CRYSTAL and the EMERALD looks); its sheet is
    -- Crystal's, read from the player's install, for its frame count -Elvie
    local borrowed = {}
    local function borrow(pokemon, species)
      if not classic.borrowsAnims() then return nil end
      local set = mod.options:get("classicMons")
      if not (set == crystal.CHOICE or gba.isChoice(set)) then return nil end
      local def = type(pokemon) == "table" and pokemon[species]
      local dex = type(def) == "table" and tonumber(def.dex) or nil
      if not dex or dex == 201 then return nil end
      local hit = borrowed[dex]
      if hit ~= nil then return hit or nil end
      borrowed[dex] = false
      local anim = crystal.anim(dex)
      if not (anim and okA) then return nil end
      local copy = {}
      for k, v in pairs(anim) do copy[k] = v end
      local from = anim.sheet
      copy.sheet = ("facets/classic/crystal_anim/%d.png"):format(dex)
      Assets.compose(copy.sheet, function() return gb.readImage(from, { "crystal" }) end)
      borrowed[dex] = copy
      return copy
    end
    -- Red, Blue and Yellow: the DS choices loop on both sides, and CRYSTAL
    -- and the EMERALD looks play Crystal's animation once when the foe's
    -- comes out (classic_gen1_anim) -Elvie
    if gen1 then
      local okB, BattleState = pcall(require, "src.battle.BattleState")
      local okM, MonAnim = pcall(require, "src.render.MonAnim")
      local okG, g1 = pcall(require, "mods.facets.classic_gen1_anim")
      local function sheetFrame(sheetPath, size, n, scale)
        local path = sheetPath:gsub("%.png$", "") .. "@f" .. n .. ".png"
        return pics.frame(path, scale, function()
          local okS, sheet = pcall(Assets.imageData, sheetPath)
          local data = okS and sheet and g1.slot(sheet, size, n)
          return data or love.image.newImageData(1, 1)
        end)
      end
      local function source(battle, b)
        local set = mod.options:get("classicMons")
        local choice = partnerChoice and partnerChoice(b.mon)
        if choice then
          if not choice.set then return nil end
          set = choice.set
        end
        local scale = tonumber(mod.options:get("classicSize"))
        local pokemon = type(battle.data) == "table" and battle.data.pokemon
        local def = type(pokemon) == "table" and pokemon[b.mon.species]
        local dex = type(def) == "table" and tonumber(def.dex) or nil
        if not dex then return nil end
        local isPlayer = b == battle.player
        local game = cds.game(set)
        if game then
          opts.set, opts.size, opts.side = set, mod.options:get("classicSize"), mod.options:get("classicSide")
          local pick = dsPick(game, dex, isPlayer and "back" or "front", "battle", false)
          local rec = pick and pick.rec
          if not rec or rec.count < 2 then return nil end
          return { trueColor = true,
            frameAt = function() return dsPics.frameAt(rec) end,
            framePath = function(n) return sheetFrame(rec.path, rec.side, n, scale) end }
        end
        -- Crystal's, on the foe's side only, where its still picture is
        -- laid out like its animation -Elvie
        if isPlayer then return nil end
        local script = borrow(pokemon, b.mon.species)
        if not script then return nil end
        local got = animSheet(pokemon, b.mon.species, false, script.sheet)
        if not got then return nil end
        local copy = {}
        for k, v in pairs(script) do copy[k] = v end
        copy.tiles = got.side / 8
        local frameAt = g1.once(MonAnim, copy)
        if not frameAt then return nil end
        return { trueColor = got.trueColor, once = true, frameAt = frameAt,
          framePath = function(n) return sheetFrame(got.path, got.side, n, scale) end }
      end
      if okB and okM and okG then
        local done = g1.install(BattleState, source, function(...) mod.log:warn(...) end)
        if not done then mod.log:warn("Gen 1's battle pictures weren't found; Pokémon stay still") end
      end
    end
    if not gen1 then
      -- pictures bigger than their box under the move animations -Elvie
      local okBands, bands = pcall(require, "mods.facets.classic_bands")
      if okBands and type(bands) == "table" then
        local done = bands.install(function()
          local m, t = mod.options:get("classicMons"), mod.options:get("classicTrainers")
          return (m ~= nil and m ~= OFF) or (t ~= nil and t ~= OFF)
        end)
        if not done then mod.log:warn("the battle animation view wasn't found; big pictures may tear in animations") end
      end
      local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
      if okB and type(BattleState) == "table" and type(BattleState.animData) == "function" then
        local own = BattleState.animData
        local copies = setmetatable({}, { __mode = "k" })
        BattleState.animData = function(self, mon, ...)
          local def = own(self, mon, ...)
          -- Gold and Silver have none: Crystal's, for a set with frames -Elvie
          if def == nil and type(mon) == "table" then def = borrow(self.pokemon, mon.species) end
          if type(def) ~= "table" or type(mon) ~= "table" then return def end
          local got = animSheet(self.pokemon, mon.species, mon.shiny and true or false, def.sheet)
          if not got then return def end
          local bySide = copies[def] or {}
          copies[def] = bySide
          local copy = bySide[got.side]
          if not copy then
            copy = {}
            for k, v in pairs(def) do copy[k] = v end
            copy.tiles = got.side / 8
            bySide[got.side] = copy
          end
          return copy
        end
      end
      -- YOUR SIDE on FRONT or MIRRORED: your Pokémon plays its front
      -- animation when it comes out, as the foe's does -Elvie
      local okS, sideAnim = pcall(require, "mods.facets.classic_side_anim")
      local okM, MonAnim = pcall(require, "src.render.MonAnim")
      if okS and okB and okM then
        local done = sideAnim.install(BattleState, MonAnim, function() return mod.options:get("classicSide") end,
          function(...) mod.log:warn(...) end)
        if not done then mod.log:warn("Gen 2's battle front animation wasn't found; YOUR SIDE stays still") end
      end
    end
    -- Yellow's partner Pikachu in its PIKACHU look's front and back
    -- (leParagon's), whatever the POKEMON set is. The partner is the
    -- engine's: a Pikachu with your trainer ID and name -Elvie
    local partnerOf
    if gen1 then
      local okY, GameVersion = pcall(require, "src.core.GameVersion")
      local okV, version = false, nil
      if okY and type(GameVersion) == "table" and type(GameVersion.get) == "function" then okV, version = pcall(GameVersion.get) end
      local okP, Follower = pcall(require, table.concat({ "src", "world", "PikachuFollower" }, "."))
      if okV and version == "yellow" and okP and type(Follower) == "table"
          and type(Follower.isStarterPikachu) == "function" then
        partnerOf = function(mon)
          local okG, game = pcall(function() return mod.game end)
          local save = okG and type(game) == "table" and game.save
          if type(save) ~= "table" or type(mon) ~= "table" then return false end
          local ok, yes = pcall(Follower.isStarterPikachu, save, mon)
          return ok and yes
        end
      end
    end
    -- What the partner shows in battle: { look = key } for one of its
    -- looks, { set = value } for a SET (OFF for Yellow's own), or nil to
    -- follow the SET like any Pokémon -Elvie
    partnerChoice = function(mon)
      if not partnerOf or not partnerOf(mon) then return nil end
      local pick = mod.options:get("classicPikachuBattle") or "match"
      if pick == "match" then
        local look = mod.options:get("classicPikachu")
        if type(look) == "string" and look:match("^[%w_]+$") and look ~= "game" and look ~= "hgss" then
          return { look = look }
        end
        return nil
      end
      -- GAME: Yellow's own pictures, through the same road as SET OFF, so
      -- YOUR SIDE still turns them round as it does any other -Elvie
      if pick == "game" then return { set = OFF } end
      local look = type(pick) == "string" and pick:match("^look:([%w_]+)$")
      if look then return { look = look } end
      return { set = pick }
    end
    local function partnerPicture(ctx)
      if not partnerOf or type(ctx.kind) ~= "string" or ctx.kind:match("_anim$") then return nil end
      local choice = partnerChoice(ctx.mon)
      if not (choice and choice.look) then return nil end
      local look = choice.look
      local battle = ctx.kind == "battle"
      local side = ctx.side == "back" and "back" or "front"
      local face, mirror = side, false
      local yourSide = mod.options:get("classicSide")
      if side == "back" and battle and yourSide ~= "back" then face, mirror = "front", yourSide == "mirrored" end
      local rel = "assets/pikachu/battle/" .. look .. (face == "back" and "_back" or "") .. ".png"
      if not pics.has(rel) then return nil end
      local scale = battle and tonumber(mod.options:get("classicSize")) or nil
      local box = not scale and classic.BOX[face == "front" and "front" or side] or nil
      if ctx.kind == "hof" and side == "back" and classic.BOX.hofBack then box = classic.BOX.hofBack end
      local grey = not coloured()
      local pick = { rel = rel, box = box, mirror = mirror, scale = scale, grey = grey,
        path = ("facets/classic/pikachu/%s%s@%s%s%s.png"):format(look, face == "back" and "_back" or "",
          box or "cut", mirror and "m" or "", grey and "g" or "") }
      if grey then
        pick.load = function()
          local data = love.image.newImageData(mod.assets:path(rel))
          return shared.greys(data)
        end
      end
      ctx.trueColor = not grey
      if not battle then return pics.file(pick) or pics.picture(pick) end
      return pics.picture(pick)
    end

    mod.hooks:wrap("pokemon.sprite", function(nextFn, path, ctx)
      if type(ctx) ~= "table" or not ctx.species then return nextFn(path, ctx) end
      local partner = partnerPicture(ctx)
      if partner then return partner end
      local choice = partnerOf and type(ctx.kind) == "string" and not ctx.kind:match("_anim$") and partnerChoice(ctx.mon)
      if ctx.kind == "battle_anim" and not gen1 then
        local got = animSheet(type(ctx.data) == "table" and ctx.data.pokemon, ctx.species, ctx.shiny, path)
        if got then
          ctx.trueColor = true
          return got.path
        end
        return nextFn(path, ctx)
      end
      opts.set = choice and choice.set or mod.options:get("classicMons")
      opts.size = mod.options:get("classicSize")
      opts.side = mod.options:get("classicSide")
      local data = ctx.data
      local def = type(data) == "table" and type(data.pokemon) == "table" and data.pokemon[ctx.species]
      local dex = type(def) == "table" and tonumber(def.dex) or nil
      opts.coloured = coloured()
      opts.animate = animating()
      local pick
      if cds.game(opts.set) then
        pick = dsPick(cds.game(opts.set), dex, ctx.side, ctx.kind, ctx.shiny and true or false)
        -- what the dump doesn't have comes from the DS set -Elvie
        if not pick then
          local was = opts.set
          opts.set = pics.has(MONS_DIR .. "/ds/front/001.png") and "ds" or OFF
          pick = classic.choose(opts, dex, ctx.side, ctx.kind, ctx.shiny)
          opts.set = was
        end
      else
        pick = classic.choose(opts, dex, ctx.side, ctx.kind, ctx.shiny)
      end
      if pick then
        ctx.trueColor = not pick.grey
        -- Gen 1 loads pictures outside battle straight from a file
        -- (summary, HALL OF FAME, POKéDEX, evolution, trade), so those
        -- get one written out -Elvie
        if gen1 and ctx.kind ~= "battle" then return pics.file(pick) or pics.picture(pick) end
        return pics.picture(pick)
      end
      -- YOUR SIDE with no set art: the front whoever draws it (the game, or
      -- another mod like SPRITE SWAPPER), mirrored if asked -Elvie
      local front = ctx.side == "back" and ctx.kind == "battle" and opts.side ~= "back"
        and classic.frontFor(def, path)
      if not front then return nextFn(path, ctx) end
      local fctx = {}
      for k, v in pairs(ctx) do fctx[k] = v end
      fctx.side = "front"
      local fpath = nextFn(front, fctx)
      ctx.trueColor = fctx.trueColor and true or false
      if type(fpath) ~= "string" or fpath == "" then return path end
      if opts.side == "mirrored" then return pics.flipped(fpath) end
      return fpath
    end)
    -- ICONS: party and naming screen icons -Elvie
    -- Gen 1's party menu keeps the game's icon class (MON, BIRD...) after
    -- the hook, and draws by it: the left half mirrored, and the class's
    -- own frames, some past the end of a two-frame sheet. While one of ours
    -- is being drawn it gets neither: frames 0 and 1, drawn whole -Elvie
    local iconOurs = false
    if gen1 then
      local okP, PartyMenu = pcall(require, table.concat({ "src", "ui", "PartyMenu" }, "."))
      if okP and type(PartyMenu) == "table" and type(PartyMenu.frameFor) == "function"
          and type(PartyMenu.mirrorsIcon) == "function" then
        local frameFor, mirrors = PartyMenu.frameFor, PartyMenu.mirrorsIcon
        PartyMenu.frameFor = function(name, alt, ih)
          if iconOurs then return alt and 1 or 0 end
          return frameFor(name, alt, ih)
        end
        PartyMenu.mirrorsIcon = function(name)
          if iconOurs then return false end
          return mirrors(name)
        end
      end
    end
    mod.hooks:wrap("pokemon.icon", function(nextFn, path, ctx)
      iconOurs = false
      local choice = mod.options:get("classicIcons")
      local data = type(ctx) == "table" and ctx.data
      local def = type(data) == "table" and type(data.pokemon) == "table" and ctx.species and data.pokemon[ctx.species]
      local dex = type(def) == "table" and tonumber(def.dex) or nil
      if choice == "crystal" and dex then
        -- Crystal's icon, written out: the party menu loads it from a file -Elvie
        local tint = coloured()
        local file = pics.fileOf(("crystal/icons/%03d%s.png"):format(dex, tint and "c" or ""), function()
          return crystal.icon(dex, tint)
        end)
        if not file then return nextFn(path, ctx) end
        ctx.trueColor = tint
        iconOurs = true
        return file
      end
      local rel = choice ~= "game" and classic.iconFor(choice, dex, pics.has)
      if not rel then return nextFn(path, ctx) end
      ctx.trueColor = true
      iconOurs = true
      return mod.assets:path(rel)
    end)
    -- a game imported since: look again -Elvie
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id and change.key == "classicMons" then gba.reset(); crystal.reset() end
      end)
    end
  end
end

return classic
