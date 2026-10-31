-- Pokémon pictures on the Game Boy games (Gold, Silver, Crystal)
-- Every Pokémon picture there comes through the pokemon.sprite hook
-- (battle, summary, Pokédex, PC, Hall of Fame, trades...), so one wrap
-- covers them all. A set's 64x64 art is cut to the Pokémon itself and,
-- under FIT, shrunk only if it still doesn't fit the game's own box: 56x56
-- for a front, 48x48 for a back. Pictures are made in memory under
-- "facets/classic/..." paths (Assets.compose), so the game loads them like
-- its own files. -Elvie
--
-- Only full-colour sets are offered: the Game Boy ones (GBC-ISH and so on)
-- are these games' own look already. Crystal's animations stay on its own
-- pictures; a replaced one is still. -Elvie
-- --------------------------------------------------

local classic = {}

local MONS_DIR = "assets/mons"
local OFF = "__off"
local PREFIX = "facets/classic/"

-- The game's own boxes: hlcoord 12,0 7x7 tiles and hlcoord 2,6 6x6 -Elvie
classic.BOX = { front = 56, back = 48 }

-- Nothing past 1X: a bigger picture runs off the top of the screen -Elvie
classic.SIZES = { { "FIT", "fit" }, { "0.5X", "0.5" }, { "0.75X", "0.75" }, { "1X", "1" } }
classic.SIDES = { { "BACK", "back" }, { "MIRRORED", "mirrored" }, { "FRONT", "front" } }

-- The see-through edge around the art: x0, y0, x1, y1 (inclusive), or
-- nil when nothing is drawn -Elvie
function classic.bounds(data)
  local w, h = data:getDimensions()
  local x0, y0, x1, y1
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local _, _, _, a = data:getPixel(x, y)
      if a > 0 then
        if not x0 or x < x0 then x0 = x end
        if not x1 or x > x1 then x1 = x end
        if not y0 then y0 = y end
        y1 = y
      end
    end
  end
  if not x0 then return nil end
  return x0, y0, x1, y1
end

-- How much a w x h picture shrinks to fit a box; never grows -Elvie
function classic.fitScale(w, h, box)
  if not box then return 1 end
  return math.min(1, box / w, box / h)
end

-- The art cut to its edge, shrunk to fit box (nearest pixel) when there is
-- one, and flipped when mirror is set. Returns new ImageData, or nil for
-- an empty picture. -Elvie
function classic.build(src, box, mirror)
  local x0, y0, x1, y1 = classic.bounds(src)
  if not x0 then return nil end
  local w, h = x1 - x0 + 1, y1 - y0 + 1
  local s = classic.fitScale(w, h, box)
  local ow, oh = math.max(1, math.floor(w * s + 0.5)), math.max(1, math.floor(h * s + 0.5))
  local out = love.image.newImageData(ow, oh)
  for oy = 0, oh - 1 do
    -- sample from the bottom up, so the feet stay on the ground line -Elvie
    local sy = y1 - math.min(h - 1, math.floor((oh - 1 - oy + 0.5) / s))
    for ox = 0, ow - 1 do
      local sx = x0 + math.min(w - 1, math.floor((ox + 0.5) / s))
      local r, g, b, a = src:getPixel(sx, sy)
      if a > 0 then out:setPixel(mirror and (ow - 1 - ox) or ox, oy, r, g, b, a) end
    end
  end
  return out
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
  rows[#rows + 1] = { key = "classicSize", type = "choice", label = "  SIZE", choices = classic.SIZES, default = "fit" }
  rows[#rows + 1] = { key = "classicSide", type = "choice", label = "  YOUR SIDE", choices = classic.SIDES, default = "back" }

  return function()
    local okA, Assets = pcall(require, "src.render.Assets")
    if not (okA and type(Assets) == "table" and type(Assets.compose) == "function") then
      mod.log:warn("Assets.compose not found; Pokémon pictures are off")
      return
    end
    local found = {}
    local function has(rel)
      local got = found[rel]
      if got == nil then
        got = mod.assets:info(rel) ~= nil
        found[rel] = got
      end
      return got
    end
    local scaleFor, made = {}, {}
    local function picture(pick)
      if not made[pick.path] then
        made[pick.path] = true
        Assets.compose(pick.path, function()
          local ok, src = pcall(love.image.newImageData, mod.assets:path(pick.rel))
          local out = ok and classic.build(src, pick.box, pick.mirror)
          if out then return out end
          mod.log:warn("%s couldn't be read", pick.rel)
          return love.image.newImageData(1, 1)
        end)
      end
      if pick.scale then scaleFor[pick.path] = pick.scale end
      return pick.path
    end

    local opts = { has = has }
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
      return picture(pick)
    end)

    -- SIZE's fixed scales, for our battle pictures only; the engine keeps
    -- them on the ground line and centred in the box -Elvie
    local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
    if okB and type(BattleState) == "table" and type(BattleState.picScale) == "function" then
      local own = BattleState.picScale
      BattleState.picScale = function(self, path, mon, back)
        local s = scaleFor[path]
        if s then return s end
        return own(self, path, mon, back)
      end
    else
      mod.log:warn("BattleState.picScale not found; SIZE only fits")
    end
  end
end

return classic
