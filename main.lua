-- Facets
-- A time machine for Gen 3's people and Pokémon: NPC overworld sprites
-- (npcs.lua), trainer battle pictures (foes.lua) and Pokémon
-- pictures (mons.lua), each from any era's art,
-- falling back to the game's own. Emerald Lens keeps the player and the
-- rival. -Elvie
--
-- Each part adds its option rows and its rows on the FACETS screen
-- (menu.lua, screen.lua), then starts once the rows are defined. filter.lua
-- is the GB FILTER, a screen shader over the whole game; gbui.lua gives
-- windows and battle boxes Crystal's look; prebuild.lua
-- (PREBUILD) builds the other parts' pictures ahead of time, and
-- achievements.lua adds a FACETS tab to Recomp Achievements when it's there.
-- An NPC-only build drops "mons" from this list (and mons.lua,
-- mon_names.lua and assets/mons/). -Elvie
local PARTS = { "npcs", "foes", "mons", "filter", "gbui", "prebuild", "achievements" }

-- The Game Boy games get their own parts, set from the Mods manager: the
-- Gen 3 ones above reach into Gen 3's engine and screens. -Elvie
local CLASSIC_PARTS = { "classic_npcs", "classic_foes", "classic_mons", "classic_scenes", "classic_hud", "filter" }

-- 1, 2 or 3 for the running game -Elvie
local function generation()
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if not ok or type(GameVersion) ~= "table" then return 3 end
  if type(GameVersion.generation) == "function" then
    local okG, gen = pcall(GameVersion.generation)
    if okG and type(gen) == "number" then return gen end
  end
  return 3
end

local function startClassic(mod)
  local rows, starts = {}, {}
  for _, name in ipairs(CLASSIC_PARTS) do
    local start = require("mods.facets." .. name).init(mod, rows)
    if start then starts[#starts + 1] = start end
  end
  if #rows > 0 then
    require("mods.facets.classic").sizeRow(rows)
    mod.options:define(rows)
  end
  for _, start in ipairs(starts) do start() end
  -- the same settings on the game's own OPTION menu -Elvie
  local ok, err = pcall(require("mods.facets.classic_menu").start, mod, rows)
  if not ok then mod.log:warn("FACETS isn't on the OPTION menu: %s", tostring(err)) end
end

return function(mod)
  if generation() ~= 3 then return startClassic(mod) end
  local rows, starts = {}, {}
  local menuMod = require("mods.facets.menu")
  local menu = menuMod.new(mod)
  -- SCREEN: the filter's rows, on a page of their own in PRISM, since the
  -- FACETS screen has no room for them as well -Elvie
  local screenPage = menuMod.new(mod, { title = "SCREEN", layer = "facets_screen", credits = false })
  screenPage.entry = { id = "facets_screen", label = "SCREEN", short = "SCREEN",
    about = "The whole picture, Game Boy style.", colour = { 42, 82, 176 }, -- sapphire -Elvie
    draw = function(area)
      require("mods.facets.filter").drawSwatch(area, function(k) return mod.options:get(k) end)
    end }
  menu.pages[#menu.pages + 1] = screenPage
  local PAGE = { filter = screenPage, gbui = screenPage }
  for _, name in ipairs(PARTS) do
    local start = require("mods.facets." .. name).init(mod, rows, PAGE[name] or menu)
    if start then starts[#starts + 1] = start end
  end
  if #rows > 0 then mod.options:define(rows) end
  for _, start in ipairs(starts) do start() end
  local ok, err = pcall(menu.start)
  if not ok then mod.log:warn("FACETS screen is off: %s", tostring(err)) end
end
