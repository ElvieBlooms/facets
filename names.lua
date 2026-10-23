-- Which sprites Facets leaves alone, and the Ruby names that share an
-- Emerald sprite. Names are OBJ_EVENT_GFX_ names without the prefix. -Elvie
local names = {}

-- The player, the rival and the link stand-ins (other players in the
-- Union Room and link rooms). Emerald Lens owns the first two; the last
-- are someone else's character. Never replaced, whatever files a set has. -Elvie
local SKIP = {
  frlg = {
    prefixes = { "RED_", "GREEN_" },
    exact = { BLUE = true, RS_BRENDAN = true, RS_MAY = true },
  },
  rse = {
    prefixes = { "BRENDAN_", "MAY_", "RIVAL_" },
    -- By name, not a LINK_ prefix: LINK_RECEPTIONIST is the Pokemon
    -- Center's upstairs receptionist, an ordinary NPC. -Elvie
    exact = { RED = true, LEAF = true, LINK_BRENDAN = true, LINK_MAY = true,
      LINK_RS_BRENDAN = true, LINK_RS_MAY = true },
  },
}

function names.skipped(family, name)
  local skip = SKIP[family]
  if not skip then return true end
  if skip.exact[name] then return true end
  for _, prefix in ipairs(skip.prefixes) do
    if name:sub(1, #prefix) == prefix then return true end
  end
  return false
end

-- Ruby and Sapphire call some people by other names than Emerald. The
-- first eleven are the same sprite pixel for pixel, the next six the same
-- people redrawn, the rest the same drawing in another palette (Mauville's
-- man in his different jobs). So a set's rse/ folder needs only the
-- Emerald file. -Elvie
local ALIASES = {
  rse = {
    BOY_4 = "RICH_BOY",
    BOY_5 = "GAMEBOY_KID",
    LITTLE_BOY_1 = "NINJA_BOY",
    LITTLE_BOY_2 = "LITTLE_BOY",
    LITTLE_GIRL_1 = "TWIN",
    LITTLE_GIRL_2 = "LITTLE_GIRL",
    MAN_6 = "MAN_5",
    WOMAN_6 = "LINK_RECEPTIONIST",
    KECLEON_1 = "KECLEON",
    KECLEON_2 = "KECLEON",
    ZIGZAGOON = "ZIGZAGOON_2",
    -- Same people, redrawn for Emerald (same id or same role). -Elvie
    OLD_MAN_1 = "EXPERT_M",
    OLD_WOMAN_1 = "EXPERT_F",
    OLD_MAN_2 = "OLD_MAN",
    OLD_WOMAN_2 = "OLD_WOMAN",
    MAN_7 = "DEVON_EMPLOYEE",
    WOMAN_7 = "WOMAN_5",
    GIDDY = "BARD",
    HIPSTER = "BARD",
    STORYTELLER = "BARD",
    TRADER = "BARD",
  },
}

-- The file names to look for, in order: the sprite's own name, then the
-- other game's name for it. -Elvie
function names.candidates(family, name)
  local alias = ALIASES[family] and ALIASES[family][name]
  if alias then return { name, alias } end
  return { name }
end

return names
