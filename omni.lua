-- OmniUI (omni_ui, by Lady Gaia / Good Girl Software), when it's
-- installed and its MODERN HIGH-RES UI is on.
--
-- OmniUI draws the menus, the text boxes and the battle's HP boxes and
-- commands in its own modern look, and in Red, Blue, Yellow, Gold, Silver
-- and Crystal battles its own themed arena behind the Pokémon. Where the
-- two would draw the same thing, Facets steps aside for it: BATTLE UI's
-- sets, and BATTLE BG with SURROUND and BORDERS in those battles. The
-- Pokémon, trainers and people Facets draws are left as they are, and
-- OmniUI shows Facets' Pokémon in its own screens through pokemon.sprite
-- -Elvie

local omni = {}

omni.ID = "omni_ui"

-- Whether OmniUI is installed, running and drawing its UI: its option
-- MODERN HIGH-RES UI (overlay) isn't switched off. game is optional (its
-- settings are read from game.mods, the loader) -Elvie
function omni.on(mod, game)
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return false end
  local ok, handle = pcall(mod.find, omni.ID)
  if not (ok and type(handle) == "table") then return false end
  game = game or mod.game
  local loader = type(game) == "table" and game.mods
  local stored = type(loader) == "table" and type(loader.modOptions) == "table" and loader.modOptions[omni.ID]
  if type(stored) == "table" and stored.overlay == false then return false end
  return true
end

return omni
