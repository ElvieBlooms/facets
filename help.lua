-- ABOUT: what every setting does
-- SELECT on a row opens its ABOUT page (classic_about.lua on Red to
-- Crystal, screen.lua on the GBA games): what the setting changes, each
-- of its choices, and which of your games a choice needs. The words live
-- here, in one place, for both. -Elvie
-- --------------------------------------------------

local help = {}

local OFF = "__off"

-- Which imported game a choice needs: a name to show and the games that
-- count. ds = a Prism Importer dump instead -Elvie
help.NEEDS = {
  firered = { name = "FireRed or LeafGreen", games = { "firered", "leafgreen" } },
  frames = { name = "FireRed, LeafGreen or Emerald", games = { "firered", "leafgreen", "emerald" } },
  emerald = { name = "Emerald", games = { "emerald" } },
  rs = { name = "Ruby or Sapphire", games = { "ruby", "sapphire" } },
  crystal = { name = "Crystal, Gold or Silver", games = { "crystal", "gold", "silver" } },
  gen12 = { name = "a Game Boy game", games = { "crystal", "gold", "silver", "yellow", "red", "blue" } },
  dppt = { name = "a Diamond, Pearl or Platinum dump (Prism Importer)", ds = "dppt" },
  hgss = { name = "a HeartGold or SoulSilver dump (Prism Importer)", ds = "hgss" },
  bw2 = { name = "a Black 2 or White 2 dump (Prism Importer)", ds = "bw2" },
}

-- What a choice's value needs, for any setting: a help.NEEDS key or nil -Elvie
function help.needsOf(key, value)
  value = tostring(value or "")
  if value == "gba_firered" then return "firered" end
  if value == "gba_emerald" then return "emerald" end
  if value == "gba_frlg" then return "firered" end
  if value == "gba_rs" then return "rs" end
  if value == "ds_dppt" then return "dppt" end
  if value == "ds_hgss" then return "hgss" end
  if value == "ds_bw2" then return "bw2" end
  if value == "gb_crystal" then return "crystal" end
  if key == "classicIcons" and value == "crystal" then return "crystal" end
  if (key == "classicPikachu" or key == "classicClefairy") and value == "hgss" then return "hgss" end
  if key == "classicClefairy" and value == "bw2" then return "bw2" end
  if (key == "classicWindows" or key == "classicTextBox") and (value == "fr" or value:match("^fr:")) then return "frames" end
  -- its words are in FireRed's small font, from FireRed, LeafGreen or Emerald -Elvie
  if key == "classicBattleUi" and value ~= "game" then return "frames" end
  if key == "animMons" and value == "emerald" then return "emerald" end
  if (key == "setFrlg" or key == "setRse") and (value == "gbc" or value == "gbc_2x") then return "gen12" end
  if key == "setTrainers" and (value == "gameboy" or value == "gbcish") then return "gen12" end
  if key == "setMons" and (value == "gb_emerald") then return "emerald" end
  if key == "setMons" and (value == "gbc_anim" or value == "gbcish") then return "crystal" end
  if (key == "gbcFrame" or key == "gbcTextBox") and value:match("^%d+$") then return "crystal" end
  if key == "gbcHud" and value == "gbc" then return "crystal" end
  return nil
end

-- The settings. about: what it changes. choices: a line for a choice,
-- by value; prefix: a line for every value starting with that (window
-- sets and their numbers); other: the line for any choice not named -Elvie
help.TEXT = {
  style = {
    about = "Sets the people, trainers, Pokémon and battle scene together, in one look. Change any of them afterwards and STYLE shows CUSTOM.",
    choices = {
      custom = "Your own mix. Pick a style to replace it.",
      original = "Everything as the game drew it.",
      firered = "FireRed's people, trainers, Pokémon and battle backgrounds.",
      emerald = "Emerald's people, trainers, Pokémon and battle backgrounds.",
      ds = "DS-style trainers and Pokémon, HeartGold's battle boxes and a scene behind each battle.",
      gbc = "Game Boy Color people, trainers and Pokémon, with Crystal's frames and battle boxes on white.",
    },
  },
  classicNpcs = {
    about = "The people you meet on the map. Anyone a set doesn't have is drawn from the others, so everyone gets new art.",
    choices = {
      community = "Custom sprites by KyleDove, Jext, Hyo and friends.",
      diego = "DiegoWT's Black and White-style people.",
      taiga = "Taiga's ORAS-style people.",
      zaffre = "PurpleZaffre's named characters.",
      gba_firered = "FireRed's own people, from your FireRed.",
      gba_emerald = "Emerald's own people, from your Emerald.",
      [OFF] = "The game's own people.",
    },
  },
  classicPikachu = {
    about = "Your Pikachu, following you on the map.",
    choices = {
      game = "Yellow's own Pikachu.",
      hgss = "HeartGold's walking Pikachu.",
    },
    other = "A dressed-up Pikachu look.",
  },
  classicClefairy = {
    about = "Your Clefairy, following you on the map, with Pokémon Pink's mods.",
    choices = {
      pink = "Pokémon Pink's own Clefairy.",
      hgss = "HeartGold's walking Clefairy.",
      bw2 = "Black 2 and White 2's walking Clefairy.",
      badassbill = "Badassbill's GBA-style Clefairy.",
    },
  },
  classicTrainers = {
    about = "The trainers you battle, in their battle pictures. Also on the Hall of Fame and trainer card screens.",
    choices = {
      ds = "DS-style pictures for every trainer.",
      gba_firered = "FireRed's own pictures, from your FireRed.",
      gba_emerald = "Emerald's own pictures, from your Emerald.",
      [OFF] = "The game's own trainers.",
    },
  },
  classicTrainerSize = {
    about = "How big trainers stand in battle.",
    choices = {
      fit = "Fits the game's own box.",
      ["1"] = "The art's own size.",
      ["0.75"] = "Three quarters size.",
      ["0.5"] = "Half size.",
    },
  },
  classicSize = {
    about = "How big Pokémon stand in battle.",
    choices = {
      fit = "Fits the game's own box.",
      ["1"] = "The art's own size; big ones run past the box.",
      ["0.75"] = "Three quarters size.",
      ["0.5"] = "Half size.",
    },
  },
  classicMons = {
    about = "Pokémon pictures: in battle, the summary, the Pokédex, the PC and the rest.",
    choices = {
      ds_dppt = "Diamond, Pearl and Platinum's, animated.",
      ds_hgss = "HeartGold and SoulSilver's, animated.",
      ds_bw2 = "Black 2 and White 2's, fully animated.",
      ds = "DS-style pictures, drawn by fans.",
      gb_crystal = "Crystal's own pictures and animations.",
      gba_firered = "FireRed's own pictures.",
      gba_emerald = "Emerald's own pictures.",
      [OFF] = "The game's own Pokémon.",
    },
  },
  classicPikachuBattle = {
    about = "Your Pikachu in battle, its summary and the Hall of Fame.",
    choices = {
      match = "Follows the map look, then POKEMON.",
      game = "Yellow's own Pikachu.",
    },
    other = "That set's Pikachu, or a dressed-up look.",
  },
  classicClefairyBattle = {
    about = "Your Clefairy in battle, with Pokémon Pink's mods.",
    choices = {
      match = "Follows POKEMON, like any Pokémon.",
      game = "Yellow's own Clefairy.",
    },
    other = "That set's Clefairy.",
  },
  animMode = {
    about = "How animated Pokémon pictures move.",
    choices = {
      loop = "Over and over while they're out.",
      intro = "Once as they come out, then still.",
      off = "Never; just the still picture.",
    },
  },
  classicSide = {
    about = "Your own Pokémon in battle: from behind, as usual, or from the front so you see the whole Pokémon.",
    choices = {
      back = "From behind, as usual.",
      mirrored = "From the front, turned to face the foe.",
      front = "From the front.",
    },
  },
  backMons = {
    about = "Your own Pokémon in battle and contests: from behind, as usual, or from the front so you see the whole Pokémon.",
    choices = {
      back = "From behind, as usual.",
      mirrored = "From the front, turned to face the foe.",
      front = "From the front.",
    },
  },
  classicIcons = {
    about = "The little Pokémon in your party list.",
    choices = {
      game = "The game's own icons.",
      minidex = "A different icon for every Pokémon.",
      crystal = "Crystal's icons.",
    },
  },
  classicBattleBg = {
    about = "What stands behind the battle.",
    choices = {
      game = "The game's own plain field.",
      scenery = "A painted scene for where you are: caves, forests, gyms, the sea.",
      gba_frlg = "FireRed's battle backgrounds.",
      gba_emerald = "Emerald's battle backgrounds.",
      gba_rs = "Ruby and Sapphire's battle backgrounds.",
      colours = "Plain colour: BG COLOR's.",
    },
  },
  bgColour = {
    about = "BATTLE BG: COLORS's colour.",
    choices = { paper = "PAPER's colour (white when PAPER's off), so a battle matches your menus." },
    other = "That colour, as PAPER has it.",
  },
  classicSceneColours = {
    about = "The colours of the battle scenes.",
    choices = {
      original = "As the art was drawn.",
      gbc = "Brighter and flatter, like a Game Boy Color.",
    },
  },
  sceneBorders = {
    about = "The space round the game screen in battle, when your screen is wider or taller than the game.",
    choices = {
      blur = "The battle scene, soft and blurred.",
      fill = "One big sharp scene filling the screen.",
      off = "The game's own plain border.",
    },
  },
  sceneTime = {
    about = "Outdoor battle scenes follow the game's clock.",
    choices = {
      on = "Morning gold, evening rose, night blue.",
      off = "Always as drawn, by day.",
    },
  },
  classicBattleUi = {
    about = "The battle boxes with each Pokémon's name and health, in GBA style, in wide battles. The normal screen keeps the game's own.",
    choices = {
      game = "The game's own boxes.",
    },
    other = "A set of battle boxes in that game's style.",
  },
  classicWindows = {
    about = "The frame round every menu and box.",
    choices = { game = "The game's own frame." },
    prefix = {
      ["fr:"] = "One of FireRed's own frames.",
      ["libertytwins:"] = "One of LibertyTwins' frames.",
      ["pink:"] = "One of the PINK frames.",
    },
  },
  classicTextBox = {
    about = "The box the game's words appear in, at the bottom of the screen.",
    choices = {
      match = "Goes with WINDOWS.",
      game = "The game's own text box.",
      fr = "FireRed's own text box.",
    },
    prefix = {
      ["libertytwins:"] = "LibertyTwins' text box.",
      ["pink:"] = "A PINK text box.",
      ["pinkwood:"] = "Tito's Woody box, in PINK's colours.",
      ["tito:"] = "One of Tito's text boxes.",
    },
  },
  classicColors = {
    about = "Facets' art is drawn in full colour, so while anything in Facets is on, the game stays in full colour.",
    choices = {
      full = "Full colour while Facets is on.",
      game = "The game's own COLORS setting, always.",
    },
  },
  surround = {
    about = "What fills the space round the game screen, outside battle. On Red to Crystal, OPTION's UI LETTERBOX has plain colours; these are more.",
    choices = {
      game = "The game's own (on Red to Crystal, OPTION's UI LETTERBOX).",
      world = "The map you're on, dimmed round the menu, as BATTLE BG: WORLD does round a battle.",
      glow = "Soft lights drifting slowly, in your menus' colour, on a darker shade of it.",
      scene = "The blurred battle scene for where you are (on the GBA games, for the ground of your last battle).",
      windows = "Your WINDOWS frame's colour.",
      dots = "Soft dots in your colours.",
      checks = "Soft checks in your colours.",
      stripes = "Soft stripes in your colours.",
    },
  },
  filter = {
    about = "Gives the screen an old handheld's colours.",
    choices = {
      off = "The game's own colours.",
      gray = "The Game Boy Pocket's four greys.",
      green = "The first Game Boy's four greens.",
      yellow = "Four shades of yellow.",
      gold = "Four shades of gold.",
      crystal = "Four shades of crystal blue.",
      ruby = "Four shades of ruby.",
      sapphire = "Four shades of sapphire.",
      emerald = "Four shades of emerald.",
      gbc = "Bright, flat Game Boy Color colours.",
    },
  },
  filterOn = {
    about = "Where FILTER goes.",
    choices = {
      screen = "Everything on the screen.",
      map = "Only the map; menus and battles keep their colours.",
    },
  },
  dots = {
    about = "A grid between the pixels, like an old handheld's screen.",
    choices = { off = "No grid.", on = "A dot-matrix grid." },
  },
  shades = {
    about = "How many shades FILTER uses.",
    choices = { ["4"] = "Four, like a Game Boy.", ["8"] = "Eight, a little smoother.", ["16"] = "Sixteen, smoothest." },
  },
  paper = {
    about = "The white of menus, text boxes and battles, in a softer colour. Only the white changes: the map, the letters and the pictures stay as they are.",
    choices = {
      off = "Plain white, as the game draws it.",
      cream = "Warm cream.", lemon = "Pale lemon.", peach = "Soft peach.", rose = "Pale rose.",
      lilac = "Pale lilac.", sky = "Pale sky blue.", mint = "Pale mint.", grey = "Light grey, the dimmest.",
      dark = "Dark paper, with a white edge round the letters. Pictures keep their white; in a battle, only its boxes go dark.",
      cocoa = "Dark cocoa, as DARK.", olive = "Dark olive, as DARK.", rust = "Dark rust, as DARK.",
      wine = "Rich wine, as DARK.", plum = "Dark plum, as DARK.", navy = "Navy blue, as DARK.",
      forest = "Dark forest green, as DARK.",
    },
  },
  -- the GBA games' own -Elvie
  setTrainers = {
    about = "The trainers you battle, in their battle pictures. Also the Hall of Fame, PokéNav and Battle Dome.",
    choices = {
      ds = "DS-style pictures for every trainer.",
      gameboy = "Game Boy-style pictures.",
      gbcish = "Crystal's and Yellow's trainers, and Gen 2-style art for Hoenn.",
      [OFF] = "The game's own trainers.",
    },
  },
  setMons = {
    about = "Pokémon pictures: in battle, the summary, the Pokédex, the PC and the rest.",
    choices = {
      bw_anim = "Black and White's animated pictures.",
      ds_dppt = "Diamond, Pearl and Platinum's, animated.",
      ds_hgss = "HeartGold and SoulSilver's, animated.",
      ds_bw2 = "Black 2 and White 2's, fully animated.",
      ds = "DS-style pictures, drawn by fans.",
      gb_emerald = "Emerald's pictures in Game Boy shades.",
      gbc_anim = "Crystal's pictures and animations.",
      gbcish = "Crystal's pictures, with Gen 2-style Hoenn.",
      [OFF] = "The game's own Pokémon.",
    },
  },
  animMons = {
    about = "Gives FireRed and LeafGreen Emerald's hops and shakes when a Pokémon comes out.",
    choices = { emerald = "Emerald's animations.", [OFF] = "None, as FireRed has." },
  },
  npcs = {
    about = "The people you meet on the map. Anyone a set doesn't have is drawn from the others, so everyone gets new art.",
    choices = {
      community = "Custom sprites by KyleDove, Jext, Hyo and friends.",
      diego = "DiegoWT's Black and White-style people.",
      taiga = "Taiga's ORAS-style people.",
      zaffre = "PurpleZaffre's named characters.",
      gbc = "Game Boy Color people.",
      gbc_2x = "Game Boy Color people, twice the size.",
      [OFF] = "The game's own people.",
    },
  },
  gbcFrame = {
    about = "The frame round every menu and box.",
    choices = { game = "The game's own frame." },
    other = "A Game Boy Color frame, or a window set's.",
  },
  gbcTextBox = {
    about = "The box the game's words appear in.",
    choices = { match = "Goes with WINDOWS.", game = "The game's own text box." },
    other = "A Game Boy Color text box, or a window set's.",
  },
  gbcHud = {
    about = "The battle boxes with each Pokémon's name and health.",
    choices = { game = "The game's own boxes.", gbc = "Crystal's boxes." },
    other = "That set's battle boxes.",
  },
  gbcBattleBg = {
    about = "What stands behind the battle.",
    choices = { game = "The game's own background.", white = "Plain white, like a Game Boy.",
      colours = "Plain colour: BG COLOR's.",
      scenery = "A painted scene for where you are: caves, forests, gyms, the sea." },
    other = "That game's battle backgrounds.",
  },
  prebuild = {
    about = "Builds Facets' pictures ahead of time, so slower devices don't stutter. Uses more memory.",
    choices = { [OFF] = "Builds each picture when it's first needed.", on = "Builds them in the background, and keeps them." },
  },
  buildNow = {
    about = "Builds everything your settings need, right now, with a progress bar.",
  },
  clearKept = {
    about = "Deletes the pictures PREBUILD kept, so they're built fresh next time. For when anything looks wrong.",
  },
}

-- NPCS on the GBA games has a key per family -Elvie
help.TEXT.setFrlg = help.TEXT.npcs
help.TEXT.setRse = help.TEXT.npcs

-- A choice's line, or nil -Elvie
function help.choiceLine(key, value)
  local t = help.TEXT[key]
  if not t then return nil end
  value = tostring(value)
  if t.choices and t.choices[value] then return t.choices[value] end
  for pre, line in pairs(t.prefix or {}) do
    if value:sub(1, #pre) == pre then return line end
  end
  return t.other
end

-- Whether the player has what a NEEDS entry asks for: true, false, or nil
-- (can't tell). dsApi: Prism Importer's api, if there is one -Elvie
function help.have(need, dsApi)
  local n = help.NEEDS[need]
  if not n then return nil end
  if n.ds then
    if not dsApi then return false end
    local ok, ds = pcall(require, "mods.facets.ds")
    if not ok then return nil end
    return ds.state(dsApi, n.ds) == "ready"
  end
  local ok, gb = pcall(require, "mods.facets.gb")
  if not ok then return nil end
  local okI, got = pcall(gb.imported, n.games)
  if not okI then return nil end
  return got ~= nil
end

-- The ABOUT page's text for a row: { about, choices = { { label, value,
-- line, need, have, current } } } -Elvie
function help.page(row, dsApi)
  local key = row.key
  local t = help.TEXT[key] or {}
  local out = { title = row.label, about = t.about or "", choices = {} }
  for _, c in ipairs(row.choices or {}) do
    local value = c[2]
    local need = help.needsOf(key, value)
    -- have is true, false or nil: an "and ... or nil" would turn false
    -- (not imported) into nil (can't tell) -Elvie
    local have = nil
    if need then have = help.have(need, dsApi) end
    out.choices[#out.choices + 1] = {
      label = c[1], value = value, line = help.choiceLine(key, value),
      need = need and help.NEEDS[need].name or nil,
      have = have,
      current = value == row.value,
    }
  end
  return out
end

-- The page as lines of at most n letters each (measure: a function for
-- the width of a line, or nil for letters). kinds: text (what it does),
-- gap, choice, line (the choice's) and need -Elvie
function help.lines(page, n, measure)
  local wrap = require("mods.facets.classic_credits").wrap
  local function wrapped(text, width)
    if not measure then return wrap(text, width) end
    local out, line = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      local try = line == "" and word or (line .. " " .. word)
      if measure(try) <= width then line = try
      else
        if line ~= "" then out[#out + 1] = line end
        line = word
      end
    end
    if line ~= "" then out[#out + 1] = line end
    return out
  end
  local lines = {}
  for _, part in ipairs(wrapped(page.about, n)) do lines[#lines + 1] = { text = part, kind = "text" } end
  for _, c in ipairs(page.choices) do
    lines[#lines + 1] = { text = "", kind = "gap" }
    lines[#lines + 1] = { text = c.label, kind = "choice", current = c.current, value = c.value }
    if c.line then
      for _, part in ipairs(wrapped(c.line, n)) do lines[#lines + 1] = { text = part, kind = "line" } end
    end
    if c.need then
      local text = (c.have == false and "Needs " or "Uses ") .. c.need
        .. (c.have == false and ", not imported yet." or ".")
      for _, part in ipairs(wrapped(text, n)) do
        lines[#lines + 1] = { text = part, kind = "need", missing = c.have == false }
      end
    end
  end
  return lines
end

return help
