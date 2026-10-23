-- Facets
-- A time machine for Gen 3's people and Pokémon: NPC overworld sprites
-- (npcs.lua) and Pokémon pictures (mons.lua), each from any era's art,
-- falling back to the game's own. Emerald Lens keeps the player and the
-- rival. -Elvie
--
-- Each part adds its option rows, then starts once the rows are defined.
-- An NPC-only build drops "mons" from this list (and mons.lua,
-- mon_names.lua and assets/mons/). -Elvie
local PARTS = { "npcs", "mons" }

return function(mod)
  local rows, starts = {}, {}
  for _, name in ipairs(PARTS) do
    local start = require("mods.facets." .. name).init(mod, rows)
    if start then starts[#starts + 1] = start end
  end
  if #rows > 0 then mod.options:define(rows) end
  for _, start in ipairs(starts) do start() end
end
