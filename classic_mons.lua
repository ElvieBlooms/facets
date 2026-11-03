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
  for _, set in ipairs(sets) do choices[#choices + 1] = { set.label, set.key } end
  if shared.generation() == 1 then
    choices[#choices + 1] = { crystal.LABEL, crystal.CHOICE }
    -- and Crystal's party icons -Elvie
    classic.ICONS = { classic.ICONS[1], classic.ICONS[2], { crystal.LABEL, "crystal" } }
  end
  for _, c in ipairs(gba.CHOICES) do choices[#choices + 1] = c end
  choices[#choices + 1] = { "OFF", OFF }
  rows[#rows + 1] = { key = "sectionClassicMons", type = "choice", label = "POKEMON",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "classicMons", type = "choice", label = "  SET", choices = choices, default = OFF }
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
    opts.animate = not gen1
    local okA, Assets = pcall(require, "src.render.Assets")
    local sheets = {} -- [path] = { path, side } or false -Elvie
    local function animSheet(pokemon, species, shiny, crystalSheet)
      if gen1 or not okA then return nil end
      opts.set = mod.options:get("classicMons")
      opts.size = mod.options:get("classicSize")
      local def = type(pokemon) == "table" and pokemon[species]
      local dex = type(def) == "table" and tonumber(def.dex) or nil
      if dex == 201 then return nil end
      local anim = dex and gba.isChoice(opts.set) and gba.monAnim(opts.set, dex, shiny)
      if not anim or type(crystalSheet) ~= "string" then return nil end
      local scale = tonumber(opts.size)
      local box = not scale and classic.BOX.front or nil
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
      sheets[path] = { path = path, side = side }
      return sheets[path]
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
    local function partnerPicture(ctx)
      if not partnerOf or type(ctx.kind) ~= "string" or ctx.kind:match("_anim$") then return nil end
      local look = mod.options:get("classicPikachu")
      if type(look) ~= "string" or not look:match("^[%w_]+$") or not partnerOf(ctx.mon) then return nil end
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
      if ctx.kind == "battle_anim" and not gen1 then
        local got = animSheet(type(ctx.data) == "table" and ctx.data.pokemon, ctx.species, ctx.shiny, path)
        if got then
          ctx.trueColor = true
          return got.path
        end
        return nextFn(path, ctx)
      end
      opts.set = mod.options:get("classicMons")
      opts.size = mod.options:get("classicSize")
      opts.side = mod.options:get("classicSide")
      local data = ctx.data
      local def = type(data) == "table" and type(data.pokemon) == "table" and data.pokemon[ctx.species]
      local dex = type(def) == "table" and tonumber(def.dex) or nil
      opts.coloured = coloured()
      local pick = classic.choose(opts, dex, ctx.side, ctx.kind, ctx.shiny)
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
