-- Achievements
-- Facets' own achievements in Recomp Achievements (ElvieBlooms/
-- recomp_achievements), when it's installed: a FACETS tab of looks to
-- try. Each is earned by winning a battle in that look, judged by the
-- settings when the battle started, so flipping options mid-battle
-- doesn't count. Without the achievements mod this does nothing.
-- docs/PROVIDER_API.md there has the API. -Elvie
-- --------------------------------------------------

local achievements = {}

local OFF = "__off"

-- The sets that make each era's look -Elvie
achievements.GBC_NPCS = { gbc = true, gbc_2x = true }
achievements.GBC_MONS = { gbcish = true, gbc_anim = true }
achievements.MODERN_NPCS = { diego = true, taiga = true, zaffre = true, community = true }
achievements.MODERN_UI = { dp = true, platinum = true, hgss = true, bw = true, b2w2 = true,
  b2w2_black = true, b2w2_white = true, xy = true }
achievements.GEMS = { ruby = true, sapphire = true, emerald = true }

achievements.LIST = {
  { id = "go_back", title = "We have to go Back...", points = 25, category = "LOOKS",
    description = "Win a trainer battle in full Game Boy Color: GBC NPCs, GBC-ISH trainers, "
      .. "Game Boy Pokemon, Crystal's windows and battle boxes, and a white background." },
  { id = "to_the_future", title = "To the Future!", points = 25, category = "LOOKS",
    description = "Win a trainer battle in a Gen 4+ look: DIEGO, TAIGA, ZAFFRE or COMMUNITY "
      .. "NPCs, DS trainers and Pokemon, and DS-era or later battle boxes." },
  { id = "time_traveler", title = "Time Traveler", points = 10, category = "LOOKS", hidden = true,
    description = "Earn both We have to go Back... and To the Future!" },
  { id = "original_recipe", title = "Original Recipe", points = 10, category = "FILTERS",
    description = "Win a battle with the whole screen in Game Boy GREEN, 4 shades, with DOTS on." },
  { id = "pocket_monsters", title = "Pocket Monsters", points = 5, category = "FILTERS",
    description = "Win a battle with the whole screen in Game Boy Pocket GRAY, 4 shades." },
  { id = "gem_collector", title = "Gem Collector", points = 15, category = "FILTERS",
    goal = 3, unit = "GEMS",
    description = "Win a battle under each of the RUBY, SAPPHIRE and EMERALD filters." },
  { id = "face_to_face", title = "Face to Face", points = 10, category = "POKEMON",
    goal = 10, unit = "WINS",
    description = "Win 10 battles with YOUR SIDE on FRONT or MIRRORED." },
  { id = "scenic_route", title = "Scenic Route", points = 15, category = "SCENES",
    goal = 8, unit = "SCENES",
    description = "Win battles in 8 different SCENERY battle backgrounds." },
  { id = "built_to_last", title = "Built to Last", points = 5, category = "SPEED",
    description = "Let PREBUILD build and keep everything your settings need." },
}

-- The settings that matter, read once: { npcs, trainers, mons, side,
-- frame, hud, bg, look, where, dots, shades, gen2 } -Elvie
function achievements.read(get, family, gen2)
  local frame, hud, bg = "game", "game", "game"
  local okG, gbui = pcall(require, "mods.facets.gbui")
  if okG then frame, hud, bg = gbui.settings(get) end
  local look, where, dots, shades = "off", "screen", "off", "4"
  local okF, filter = pcall(require, "mods.facets.filter")
  if okF then look, where, dots, shades = filter.settings(get) end
  return {
    npcs = family and get("set" .. family.suffix) or OFF,
    trainers = get("setTrainers") or OFF,
    mons = get("setMons") or OFF,
    side = get("backMons") == "front" and "front" or "back",
    frame = tostring(frame), hud = hud, bg = bg,
    look = look, where = where, dots = dots, shades = tostring(shades),
    gen2 = gen2 and true or false,
  }
end

-- The full Game Boy Color look, with a Gen 2 game there to draw it. -Elvie
function achievements.isGbc(s)
  return s.gen2 and achievements.GBC_NPCS[s.npcs] and s.trainers == "gbcish"
    and achievements.GBC_MONS[s.mons] and (s.frame or ""):match("^[1-8]$") ~= nil
    and s.hud == "gbc" and s.bg == "white" or false
end

function achievements.isModern(s)
  return achievements.MODERN_NPCS[s.npcs] and s.trainers == "ds" and s.mons == "ds"
    and achievements.MODERN_UI[s.hud] or false
end

-- What a won battle earns: { ids = { id = true }, gem = name, scene = name } -Elvie
function achievements.earned(s, kind, scene)
  local out = { ids = {} }
  if kind == "trainer" then
    if achievements.isGbc(s) then out.ids.go_back = true end
    if achievements.isModern(s) then out.ids.to_the_future = true end
  end
  if s.where == "screen" and s.shades == "4" then
    if s.look == "green" and s.dots == "on" then out.ids.original_recipe = true end
    if s.look == "gray" then out.ids.pocket_monsters = true end
  end
  if achievements.GEMS[s.look] then out.gem = s.look end
  if s.side == "front" then out.side = true end
  out.scene = scene
  return out
end

function achievements.init(mod)
  return function()
    if type(mod.find) ~= "function" then return end
    local okFind, found = pcall(mod.find, "recomp_achievements")
    if not (okFind and type(found) == "table" and type(found.exports) == "table") then return end
    local ach = found.exports
    local major = tonumber(tostring(ach.apiVersion or ""):match("^(%d+)"))
    if major ~= 1 or type(ach.connect) ~= "function" then
      mod.log:warn("achievements: API %s isn't one Facets knows", tostring(ach.apiVersion))
      return
    end
    local handle, code = ach.connect(mod, { tab = "FACETS" })
    if not handle then
      mod.log:warn("achievements: couldn't connect (%s)", tostring(code))
      return
    end
    local okCount, errors = handle:registerMany(achievements.LIST)
    for i, err in pairs(errors or {}) do
      mod.log:warn("achievements: %s rejected: %s", tostring(achievements.LIST[i] and achievements.LIST[i].id),
        tostring(type(err) == "table" and (err.message or err[2]) or err))
    end

    local get = function(k) return mod.options:get(k) end
    local function gen2()
      local okG, gbui = pcall(require, "mods.facets.gbui")
      local art = okG and gbui.art()
      return art and art.hp and true or false
    end

    -- The scenes and filters already won in, for this playthrough: kept
    -- with the save (mod.storage) so a count never goes back -Elvie
    local seen = { scenes = {}, gems = {} }
    local function game() local ok, g = pcall(function() return mod.game end); return ok and g or nil end
    local function load()
      seen = { scenes = {}, gems = {} }
      if type(mod.storage) ~= "table" then return end
      local ok, got = pcall(mod.storage.read, mod.storage, game(), "achievements")
      if ok and type(got) == "table" then
        seen.scenes = type(got.scenes) == "table" and got.scenes or {}
        seen.gems = type(got.gems) == "table" and got.gems or {}
      end
    end
    local function save()
      if type(mod.storage) ~= "table" then return end
      pcall(mod.storage.write, mod.storage, game(), "achievements", seen)
    end
    local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
    -- progress only ever goes up -Elvie
    local function raise(id, n)
      local have = select(1, handle:getProgress(id)) or 0
      if n > (tonumber(have) or 0) then handle:setProgress(id, n) end
    end
    local function checkBoth()
      if handle:isUnlocked("go_back") and handle:isUnlocked("to_the_future") then handle:unlock("time_traveler") end
    end
    local function checkPrebuild()
      local okP, prebuild = pcall(require, "mods.facets.prebuild")
      if not (okP and type(prebuild.status) == "function") then return end
      local okS, st = pcall(prebuild.status)
      if okS and type(st) == "table" and st.on and st.finished and (st.total or 0) > 0 and st.kept then
        handle:unlock("built_to_last")
      end
    end

    local atStart, kind = nil, nil
    mod.events:on(ach.events.ready, function()
      load()
      raise("scenic_route", count(seen.scenes))
      raise("gem_collector", count(seen.gems))
      checkBoth()
    end)
    mod.events:on("battle.started", function(ev)
      local okM, menu = pcall(require, "mods.facets.menu")
      atStart = achievements.read(get, okM and menu.family() or nil, gen2())
      kind = type(ev) == "table" and ev.kind or nil
      local okG, gbui = pcall(require, "mods.facets.gbui")
      if okG then gbui.lastTerrain = nil end
    end)
    mod.events:on("battle.ended", function(ev)
      local s = atStart
      atStart = nil
      local result = type(ev) == "table" and ev.result or nil
      if not s or not (result == "win" or result == "caught") then return end
      local scene
      local okG, gbui = pcall(require, "mods.facets.gbui")
      if okG and gbui.BG_SETS[s.bg] and gbui.lastTerrain then scene = gbui.sceneName(s.bg, gbui.lastTerrain) end
      local e = achievements.earned(s, kind, scene)
      for id in pairs(e.ids) do handle:unlock(id) end
      if e.side then handle:addProgress("face_to_face", 1) end
      local changed = false
      if e.gem and not seen.gems[e.gem] then seen.gems[e.gem] = true; changed = true end
      if e.scene and not seen.scenes[e.scene] then seen.scenes[e.scene] = true; changed = true end
      if changed then
        save()
        raise("gem_collector", count(seen.gems))
        raise("scenic_route", count(seen.scenes))
      end
      checkBoth()
      checkPrebuild()
    end)
    mod.events:on("map.entered", function() checkPrebuild() end)
    mod.log:info("achievements: %d registered", okCount or 0)
  end
end

return achievements
