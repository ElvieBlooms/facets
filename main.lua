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
-- (PREBUILD) builds the other parts' pictures ahead of time.
-- An NPC-only build drops "mons" from this list (and mons.lua,
-- mon_names.lua and assets/mons/). -Elvie
local PARTS = { "npcs", "foes", "mons", "filter", "gbui", "prebuild" }

return function(mod)
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
