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
classic.BOX = shared.BOX
classic.SIZES = shared.SIZES
classic.bounds = shared.bounds
classic.fitScale = shared.fitScale
classic.build = shared.build
classic.SIDES = { { "BACK", "back" }, { "MIRRORED", "mirrored" }, { "FRONT", "front" } }

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
  local name = ("%03d.png"):format(dex)
  local rel
  for _, dir in ipairs(shiny and { face .. "_shiny", face } or { face }) do
    local try = MONS_DIR .. "/" .. opts.set .. "/" .. dir .. "/" .. name
    if opts.has(try) then rel = try break end
  end
  if not rel then return nil end
  local scale = battle and tonumber(opts.size) or nil
  local box = not scale and classic.BOX[side] or nil
  return { rel = rel, box = box, mirror = mirror, scale = scale,
    path = PREFIX .. rel:sub(#MONS_DIR + 2):gsub("%.png$", "")
      .. (box and ("@" .. box) or "@cut") .. (mirror and "m" or "") .. ".png" }
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
  local choices = {}
  for _, set in ipairs(sets) do choices[#choices + 1] = { set.label, set.key } end
  choices[#choices + 1] = { "OFF", OFF }
  rows[#rows + 1] = { key = "sectionClassicMons", type = "choice", label = "POKEMON",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "classicMons", type = "choice", label = "  SET", choices = choices, default = OFF }
  rows[#rows + 1] = { key = "classicSide", type = "choice", label = "  YOUR SIDE", choices = classic.SIDES, default = "back" }

  return function()
    local pics = shared.setup(mod)
    if not pics then return end
    local opts = { has = pics.has }
    mod.hooks:wrap("pokemon.sprite", function(nextFn, path, ctx)
      local got = nextFn(path, ctx)
      if type(ctx) ~= "table" or not ctx.species then return got end
      opts.set = mod.options:get("classicMons")
      if opts.set == OFF then return got end
      opts.size = mod.options:get("classicSize")
      opts.side = mod.options:get("classicSide")
      local data = ctx.data
      local def = type(data) == "table" and type(data.pokemon) == "table" and data.pokemon[ctx.species]
      local dex = type(def) == "table" and tonumber(def.dex) or nil
      local pick = classic.choose(opts, dex, ctx.side, ctx.kind, ctx.shiny)
      if not pick then return got end
      ctx.trueColor = true
      return pics.picture(pick)
    end)
  end
end

return classic
