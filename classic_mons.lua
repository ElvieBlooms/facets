-- Pokémon pictures on the Game Boy games (Gold, Silver, Crystal)
-- Every Pokémon picture there comes through the pokemon.sprite hook
-- (battle, summary, Pokédex, PC, Hall of Fame, trades...), so one wrap
-- covers them all. A set's 64x64 art is cut to the Pokémon itself and,
-- under FIT, shrunk only if it still doesn't fit the game's own box: 56x56
-- for a front, 48x48 for a back (classic.lua makes the pictures). -Elvie
--
-- Only full-colour sets are offered: the Game Boy ones (GBC-ISH and so on)
-- are these games' own look already. Crystal's animations stay on its own
-- pictures; a replaced one is still. -Elvie
-- --------------------------------------------------

local classic = {}

local MONS_DIR = "assets/mons"
local OFF = "__off"
local PREFIX = "facets/classic/"

local shared = require("mods.facets.classic")
local gba = require("mods.facets.classic_gba")
classic.BOX = { front = shared.BOX.front, back = shared.BOX.back }
classic.SIZES = shared.SIZES
classic.bounds = shared.bounds
classic.fitScale = shared.fitScale
classic.build = shared.build
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
  local rel, load
  if gba.isChoice(opts.set) then
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
  local stem = load and rel or rel:sub(#MONS_DIR + 2)
  return { rel = rel, load = load, box = box, mirror = mirror, scale = scale,
    path = PREFIX .. stem:gsub("%.png$", "")
      .. (box and ("@" .. box) or "@cut") .. (mirror and "m" or "") .. ".png" }
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
  if shared.generation() == 1 then classic.BOX = { front = 56, back = 64 } end
  local choices = {}
  for _, set in ipairs(sets) do choices[#choices + 1] = { set.label, set.key } end
  for _, c in ipairs(gba.CHOICES) do choices[#choices + 1] = c end
  choices[#choices + 1] = { "OFF", OFF }
  rows[#rows + 1] = { key = "sectionClassicMons", type = "choice", label = "POKEMON",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "classicMons", type = "choice", label = "  SET", choices = choices, default = OFF }
  rows[#rows + 1] = { key = "classicSide", type = "choice", label = "  YOUR SIDE", choices = classic.SIDES, default = "back" }
  rows[#rows + 1] = { key = "classicIcons", type = "choice", label = "  ICONS", choices = classic.ICONS, default = "game" }

  return function()
    local pics = shared.setup(mod)
    if not pics then return end
    local opts = { has = pics.has }
    -- next runs at most once per call, as the hook contract asks: not at
    -- all when the picture is ours, on the front when YOUR SIDE asks -Elvie
    mod.hooks:wrap("pokemon.sprite", function(nextFn, path, ctx)
      if type(ctx) ~= "table" or not ctx.species then return nextFn(path, ctx) end
      opts.set = mod.options:get("classicMons")
      opts.size = mod.options:get("classicSize")
      opts.side = mod.options:get("classicSide")
      local data = ctx.data
      local def = type(data) == "table" and type(data.pokemon) == "table" and data.pokemon[ctx.species]
      local dex = type(def) == "table" and tonumber(def.dex) or nil
      local pick = classic.choose(opts, dex, ctx.side, ctx.kind, ctx.shiny)
      if pick then
        ctx.trueColor = true
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
    mod.hooks:wrap("pokemon.icon", function(nextFn, path, ctx)
      local choice = mod.options:get("classicIcons")
      local data = type(ctx) == "table" and ctx.data
      local def = type(data) == "table" and type(data.pokemon) == "table" and ctx.species and data.pokemon[ctx.species]
      local rel = choice ~= "game" and classic.iconFor(choice, type(def) == "table" and tonumber(def.dex) or nil, pics.has)
      if not rel then return nextFn(path, ctx) end
      ctx.trueColor = true
      return mod.assets:path(rel)
    end)
    -- a game imported since: look again -Elvie
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id and change.key == "classicMons" then gba.reset() end
      end)
    end
  end
end

return classic
