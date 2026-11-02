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
local gba = require("mods.facets.classic_gba")

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
  -- Gen 1's own classes (OPP_ without the prefix) -Elvie
  JR_TRAINER_M = "CAMPER", JR_TRAINER_F = "PICNICKER", PSYCHIC_TR = "PSYCHIC_M", BLACKBELT = "BLACK_BELT",
  PROF_OAK = "PROFESSOR_OAK", GIOVANNI = "LEADER_GIOVANNI", ROCKET = "ROCKET_GRUNT_M", CUE_BALL = "CUE_BALL",
  GAMBLER = "GAMER", SWIMMER = "SWIMMER_M", ENGINEER = "ENGINEER", TAMER = "TAMER", ROCKER = "ROCKER",
  CHANNELER = "CHANNELER", COOLTRAINER_M = "COOLTRAINER_M", COOLTRAINER_F = "COOLTRAINER_F",
  LORELEI = "ELITE_FOUR_LORELEI", AGATHA = "ELITE_FOUR_AGATHA", LANCE = "ELITE_FOUR_LANCE",
}

-- Where the GBA look finds its fill-ins: Heart & Soul's GBA-style
-- pictures (gb_hns/) first, then the DS set's own Game Boy classes -Elvie
foes.FILL = "ds"
foes.FILL_DIRS = { "gb_hns", "gb" }

-- Crystal Lens's -Elvie
foes.SKIP = { RIVAL1 = true, RIVAL2 = true, RIVAL3 = true, CAL = true }

-- The picture for a class, or nil for the game's own.
-- opts = { set, size, has = function(rel) } -Elvie
function foes.choose(opts, classId)
  if not opts.set or opts.set == OFF or type(classId) ~= "string" or foes.SKIP[classId] then return nil end
  local rel, load
  if gba.isChoice(opts.set) then
    -- the GBA look: the Gen 3 picture from the player's own game -Elvie
    local found = (opts.gbaFind or gba.trainerPicture)(opts.set, { foes.NAMES[classId] or classId, classId })
    if found then
      rel = opts.set .. "/" .. found.game .. "/" .. found.rel:gsub("%.rgba$", ".png")
      load = function() return gba.load(found) end
    else
      -- a class neither game has: Heart & Soul's picture, GBA-style
      -- already, from the DS set's gb/ folder -Elvie
      for _, sub in ipairs(foes.FILL_DIRS) do
        local try = DIR .. "/" .. foes.FILL .. "/" .. sub .. "/" .. classId .. ".png"
        if not rel and opts.has(try) then rel = try end
      end
    end
  else
    -- the set's gb/ folder first: art under the Game Boy class's own name,
    -- kept apart so Gen 3 never picks it up (RED, BLUE) -Elvie
    -- then gb_hns/ (Heart & Soul's) for anyone the set has no picture of -Elvie
    local tries = { DIR .. "/" .. opts.set .. "/gb/" .. classId .. ".png" }
    for _, name in ipairs({ classId, foes.NAMES[classId] }) do
      tries[#tries + 1] = DIR .. "/" .. opts.set .. "/" .. name .. ".png"
    end
    tries[#tries + 1] = DIR .. "/" .. opts.set .. "/gb_hns/" .. classId .. ".png"
    for _, try in ipairs(tries) do
      if opts.has(try) then rel = try break end
    end
  end
  if not rel then return nil end
  local scale = tonumber(opts.size)
  local box = not scale and shared.BOX.front or nil
  local stem = load and rel or rel:sub(#DIR + 2)
  return { rel = rel, load = load, box = box, scale = scale,
    path = PREFIX .. stem:gsub("%.png$", "") .. (box and ("@" .. box) or "@cut") .. ".png" }
end

-- Gen 1's class for a trainer: OPP_ without the prefix, and Yellow's
-- Jessie and James (Rocket's parties from 42 on) as JESSIE_JAMES, so
-- they never get a Grunt's picture -Elvie
function foes.gen1Class(trainer, oppClass, partyIndex)
  if type(oppClass) ~= "string" then return nil end
  if oppClass == "OPP_ROCKET" and (partyIndex or 1) >= 42
      and type(trainer) == "table" and trainer.picJessieJames then
    return "JESSIE_JAMES"
  end
  return (oppClass:gsub("^OPP_", ""))
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
  for _, c in ipairs(gba.CHOICES) do choices[#choices + 1] = c end
  choices[#choices + 1] = { "OFF", OFF }
  rows[#rows + 1] = { key = "sectionClassicTrainers", type = "choice", label = "TRAINERS",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "classicTrainers", type = "choice", label = "  SET", choices = choices, default = OFF }

  return function()
    local pics = shared.setup(mod)
    if not pics then return end
    local opts = { has = pics.has }
    local function pick(classId)
      opts.set = mod.options:get("classicTrainers")
      if opts.set == OFF then return nil end
      opts.size = mod.options:get("classicSize")
      return foes.choose(opts, classId)
    end
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id and change.key == "classicTrainers" then gba.reset() end
      end)
    end
    if shared.generation() == 1 then
      -- Gen 1 asks for a trainer's picture by its OPP_ class, and its
      -- colour flag separately; ours are full colour -Elvie
      -- Gen 1's own module, named here at run time: the Gen 2 compatibility
      -- scan can't see the generation check above and asks Gen 2's -Elvie
      local okB1, Battle1 = pcall(require, table.concat({ "src", "battle", "BattleState" }, "."))
      if not (okB1 and type(Battle1) == "table" and type(Battle1.trainerPicPath) == "function") then
        mod.log:warn("BattleState.trainerPicPath not found; trainer pictures are off")
        return
      end
      local ours = setmetatable({}, { __mode = "k" })
      local ownPath, ownColour = Battle1.trainerPicPath, Battle1.trainerTrueColor
      Battle1.trainerPicPath = function(data, trainer, oppClass, partyIndex)
        local class = foes.gen1Class(trainer, oppClass, partyIndex)
        local p = class and pick(class)
        if type(trainer) == "table" then ours[trainer] = p and true or nil end
        if p then return pics.picture(p) end
        return ownPath(data, trainer, oppClass, partyIndex)
      end
      Battle1.trainerTrueColor = function(data, trainer)
        if type(trainer) == "table" and ours[trainer] then return true end
        return ownColour(data, trainer)
      end
      return
    end
    local okB, BattleState = pcall(require, "src.ui.gen2.BattleState")
    if not (okB and type(BattleState) == "table" and type(BattleState.trainerArt) == "function") then
      mod.log:warn("BattleState.trainerArt not found; trainer pictures are off")
      return
    end
    local own = BattleState.trainerArt
    BattleState.trainerArt = function(data, classId)
      local p = pick(classId)
      if p then return pics.picture(p), true end
      return own(data, classId)
    end
  end
end

return foes
