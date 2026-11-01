-- Trainer battle pictures on the Game Boy games (Gold, Silver, Crystal)
-- The game asks BattleState.trainerArt for a trainer class's picture, so
-- one wrap there covers every trainer. A set's art is fitted to the
-- game's own 56x56 box like the Pokémon (classic.lua), and PICTURE SIZE
-- scales both. -Elvie
--
-- A picture is found by the Gen 2 class name first (FALKNER.png,
-- KIMONO_GIRL.png), then by the Gen 3 name in NAMES below, so art for a
-- Johto class only has to be dropped in the set's folder under its own
-- name. Classes without art stay the game's own. -Elvie
--
-- The player and the rival (Silver) are Crystal Lens's, so they're never
-- touched here. -Elvie
-- --------------------------------------------------

local shared = require("mods.facets.classic")

local foes = {}

local DIR = "assets/trainers"
local OFF = "__off"
local PREFIX = "facets/classic/trainers/"

-- Gen 2 class -> the Gen 3 picture that stands for it. Kindler, Channeler
-- and Blue's later look are stand-ins until there's art of the Gen 2 class
-- itself. -Elvie
foes.NAMES = {
  BEAUTY = "BEAUTY", BIKER = "BIKER", BIRD_KEEPER = "BIRD_KEEPER", BLACKBELT_T = "BLACK_BELT",
  BLAINE = "LEADER_BLAINE", BLUE = "RIVAL_LATE", BROCK = "LEADER_BROCK", BRUNO = "ELITE_FOUR_BRUNO",
  BUG_CATCHER = "BUG_CATCHER", BURGLAR = "BURGLAR", CAMPER = "CAMPER", CHAMPION = "ELITE_FOUR_LANCE",
  COOLTRAINERF = "COOLTRAINER_F", COOLTRAINERM = "COOLTRAINER_M", ERIKA = "LEADER_ERIKA",
  FIREBREATHER = "KINDLER", FISHER = "FISHERMAN", GENTLEMAN = "GENTLEMAN",
  GRUNTF = "ROCKET_GRUNT_F", GRUNTM = "ROCKET_GRUNT_M", GUITARIST = "GUITARIST", HIKER = "HIKER",
  JUGGLER = "JUGGLER", KOGA = "LEADER_KOGA", LASS = "LASS", LT_SURGE = "LEADER_LT_SURGE",
  MEDIUM = "CHANNELER", MISTY = "LEADER_MISTY", PICNICKER = "PICNICKER", POKEFANF = "POKEFAN_F",
  POKEFANM = "POKEFAN_M", POKEMANIAC = "POKEMANIAC", POKEMON_PROF = "PROFESSOR_OAK",
  PSYCHIC_T = "PSYCHIC_M", SABRINA = "LEADER_SABRINA", SAILOR = "SAILOR", SCHOOLBOY = "SCHOOL_KID_M",
  SCIENTIST = "SCIENTIST", SUPER_NERD = "SUPER_NERD", SWIMMERF = "SWIMMER_F", SWIMMERM = "SWIMMER_M",
  TWINS = "TWINS", YOUNGSTER = "YOUNGSTER",
}

-- Crystal Lens's -Elvie
foes.SKIP = { RIVAL1 = true, RIVAL2 = true, CAL = true }

-- The picture for a class, or nil for the game's own.
-- opts = { set, size, has = function(rel) } -Elvie
function foes.choose(opts, classId)
  if not opts.set or opts.set == OFF or type(classId) ~= "string" or foes.SKIP[classId] then return nil end
  local rel
  for _, name in ipairs({ classId, foes.NAMES[classId] }) do
    local try = DIR .. "/" .. opts.set .. "/" .. name .. ".png"
    if opts.has(try) then rel = try break end
  end
  if not rel then return nil end
  local scale = tonumber(opts.size)
  local box = not scale and shared.BOX.front or nil
  return { rel = rel, box = box, scale = scale,
    path = PREFIX .. rel:sub(#DIR + 2):gsub("%.png$", "") .. (box and ("@" .. box) or "@cut") .. ".png" }
end

-- Full-colour sets; the Game Boy ones are these games' own look -Elvie
local function findSets(mod)
  local sets = {}
  local okD, decode = pcall(function() return require("mods.facets.npcs").decodeJson end)
  for _, key in ipairs(mod.assets:list(DIR) or {}) do
    local dir = DIR .. "/" .. key
    local info = mod.assets:info(dir)
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

function foes.init(mod, rows)
  local sets = findSets(mod)
  if #sets == 0 then return nil end
  local choices = {}
  for _, set in ipairs(sets) do choices[#choices + 1] = { set.label, set.key } end
  choices[#choices + 1] = { "OFF", OFF }
  rows[#rows + 1] = { key = "sectionClassicTrainers", type = "choice", label = "TRAINERS",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "classicTrainers", type = "choice", label = "  SET", choices = choices, default = OFF }

  return function()
    local pics = shared.setup(mod)
    if not pics then return end
    local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
    if not (okB and type(BattleState) == "table" and type(BattleState.trainerArt) == "function") then
      mod.log:warn("BattleState.trainerArt not found; trainer pictures are off")
      return
    end
    local opts = { has = pics.has }
    local own = BattleState.trainerArt
    BattleState.trainerArt = function(data, classId)
      opts.set = mod.options:get("classicTrainers")
      if opts.set ~= OFF then
        opts.size = mod.options:get("classicSize")
        local pick = foes.choose(opts, classId)
        if pick then return pics.picture(pick), true end
      end
      return own(data, classId)
    end
  end
end

return foes
