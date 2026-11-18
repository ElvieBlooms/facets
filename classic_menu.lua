-- FACETS on the START and OPTION menus of the Game Boy games
-- FACETS (or PRISM, shared with Emerald Lens) opens a page of the same
-- settings as the Mods manager, set the same way, so everything listening
-- reacts as it would there. -Elvie
-- --------------------------------------------------

local cmenu = {}

local OFF = "__off"
-- The page's rows, from the Mods manager's: a section heading names its
-- SET, anything else keeps its own name -Elvie
function cmenu.entries(rows)
  local out, section = {}, nil
  for _, row in ipairs(rows) do
    local label = tostring(row.label or ""):gsub("^%s+", "")
    if row.key:match("^section") then
      section = label
    elseif type(row.choices) == "table" and #row.choices > 1 then
      -- SIZE takes its section's name too: POKEMON SIZE, TRAINER SIZE -Elvie
      if label == "SET" then label = section
      elseif label == "SIZE" and section then label = section:gsub("S$", "") .. " SIZE" end
      out[#out + 1] = { key = row.key, label = label, choices = row.choices }
    end
  end
  return out
end

-- The next choice along, wrapping; with key, past any that need a game
-- you haven't imported (help.step) -Elvie
function cmenu.step(choices, value, dir, key)
  if key then return require("mods.facets.help").step(choices, key, value, dir) end
  local at = 1
  for i, c in ipairs(choices) do if c[2] == value then at = i end end
  return choices[(at - 1 + (dir or 1)) % #choices + 1][2]
end

-- FACETS opens a short list of topics, each a page of its own, so no one
-- page is a wall of settings. lead: the setting whose choice the topic's
-- row shows -Elvie
cmenu.TOPICS = {
  { id = "people", label = "PEOPLE", lead = "classicNpcs",
    about = "The people on the map, and the trainers you battle.",
    keys = { "classicNpcs", "classicTrainers", "classicTrainerSize" } },
  { id = "pokemon", label = "POKEMON", lead = "classicMons",
    about = "Pokémon pictures, how they move and how big they stand, and the Pokémon following you.",
    keys = { "classicMons", "classicPikachuBattle", "classicClefairyBattle", "animMode", "classicSide",
      "classicSize", "classicIcons", "classicPikachu", "classicClefairy" } },
  { id = "battle", label = "BATTLE", lead = "classicBattleBg",
    about = "What stands behind each battle, and the battle boxes.",
    keys = { "classicBattleBg", "sceneBorders", "classicSceneColours", "bgColour", "sceneTime", "classicBattleUi" } },
  { id = "menus", label = "MENUS", lead = "classicWindows",
    about = "Window frames, the text box, PAPER, and what fills the space round the game.",
    keys = { "classicWindows", "classicTextBox", "surround", "paper", "paperDetail", "paperPrecache" } },
  { id = "effects", label = "EFFECTS", lead = "classicColors",
    about = "The game's colors, the map's time of day, and old-handheld looks: the filter, its dots and shades.",
    keys = { "classicColors", "mapTime", "filter", "filterOn", "dots", "shades" } },
}

-- The topics with the settings this game has, each with its entries in
-- the topic's order; a setting no topic names goes on the last -Elvie
function cmenu.topics(entries)
  local byKey, placed, out = {}, {}, {}
  for _, e in ipairs(entries) do byKey[e.key] = e end
  for _, t in ipairs(cmenu.TOPICS) do
    local list = {}
    for _, key in ipairs(t.keys) do
      if byKey[key] then list[#list + 1] = byKey[key]; placed[key] = true end
    end
    if #list > 0 then out[#out + 1] = { id = t.id, label = t.label, lead = t.lead, about = t.about, entries = list } end
  end
  local rest = {}
  for _, e in ipairs(entries) do if not placed[e.key] then rest[#rest + 1] = e end end
  if #rest > 0 and #out > 0 then
    for _, e in ipairs(rest) do table.insert(out[#out].entries, e) end
  end
  return out
end

-- STYLE: one row that sets the main looks together. Each style lists
-- the values it wants, best first: the first one this game offers is
-- used -Elvie
cmenu.STYLES = {
  { "GAME", "original", {
    classicNpcs = { OFF }, classicTrainers = { OFF }, classicMons = { OFF }, classicBattleBg = { "game" },
    classicBattleUi = { "game" }, classicWindows = { "game" }, classicTextBox = { "match" } } },
  { "FIRERED", "firered", {
    classicNpcs = { "gba_firered" }, classicTrainers = { "gba_firered" }, classicMons = { "gba_firered" },
    classicBattleBg = { "gba_frlg" }, classicBattleUi = { "game" }, classicWindows = { "fr:1" },
    classicTextBox = { "match" } } },
  { "EMERALD", "emerald", {
    classicNpcs = { "gba_emerald" }, classicTrainers = { "gba_emerald" }, classicMons = { "gba_emerald" },
    classicBattleBg = { "gba_emerald" }, classicBattleUi = { "game" }, classicWindows = { "em:1" },
    classicTextBox = { "match" } } },
  { "DS", "ds", {
    classicNpcs = { "diego" }, classicTrainers = { "ds" }, classicMons = { "ds_hgss", "ds_dppt", "ds_bw2", "ds" },
    classicBattleBg = { "scenery" }, classicBattleUi = { "hgss" }, classicWindows = { "game" },
    classicTextBox = { "match" } } },
}
cmenu.CUSTOM = "custom"

-- What a style sets, as key = value, for the settings this game has -Elvie
function cmenu.styleValues(style, entries, styles)
  local want
  for _, s in ipairs(styles or cmenu.STYLES) do if s[2] == style then want = s[3] end end
  if not want then return nil end
  local offered = {}
  for _, e in ipairs(entries) do
    offered[e.key] = {}
    for _, c in ipairs(e.choices) do offered[e.key][c[2]] = true end
  end
  local out = {}
  for key, list in pairs(want) do
    if offered[key] then
      for _, v in ipairs(list) do
        if offered[key][v] then out[key] = v break end
      end
    end
  end
  return out
end

-- The style the settings are in now, or CUSTOM -Elvie
function cmenu.styleOf(get, entries, styles)
  for _, s in ipairs(styles or cmenu.STYLES) do
    local values, same = cmenu.styleValues(s[2], entries, styles), true
    if not next(values) then same = false end
    for key, v in pairs(values) do
      if get(key) ~= v then same = false break end
    end
    if same then return s[2] end
  end
  return cmenu.CUSTOM
end

function cmenu.start(mod, rows)
  if not (mod.hooks and type(mod.hooks.wrap) == "function") then return end
  local gen1 = require("mods.facets.classic").generation() == 1
  local okO, OptionsMenu = pcall(require, gen1 and "src.ui.OptionsMenu" or "src.ui.gen2.OptionsMenu")
  if not (okO and type(OptionsMenu) == "table") then return end
  local entries = cmenu.entries(rows)
  if #entries == 0 then return end

  -- set the way the Mods manager sets it (see menu.lua) -Elvie
  local function set(game, key, value)
    local Runtime = package.loaded["src.mods.Runtime"]
    if Runtime and Runtime.safeMode then return end
    -- The settings that get saved: game.options in Gold/Silver/Crystal and
    -- the Gen 3 games, game.save.options in Red/Blue/Yellow (the same table
    -- in Gold/Silver/Crystal), as the Mods manager writes them -Elvie
    local saved = {}
    if type(game.options) == "table" then saved[#saved + 1] = game.options end
    local fromSave = type(game.save) == "table" and game.save.options
    if type(fromSave) == "table" and fromSave ~= game.options then saved[#saved + 1] = fromSave end
    for _, t in ipairs(saved) do
      t.modOptions = t.modOptions or {}
      t.modOptions[mod.id] = t.modOptions[mod.id] or {}
      t.modOptions[mod.id][key] = value
    end
    local loader = game.mods
    if type(loader) == "table" then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id][key] = value
    end
    if type(game.writeOptions) == "function" then pcall(game.writeOptions, game) end
    if type(loader) == "table" and loader.events then
      loader.events:emit("mod.options_changed", { mod = mod.id, key = key, value = value })
    end
  end

  local topics = cmenu.topics(entries)
  local function get(key) return mod.options:get(key) end
  local function labelFor(e)
    local v = get(e.key)
    for _, c in ipairs(e.choices) do if c[2] == v then return c[1] end end
    return e.choices[1][1]
  end

  -- SELECT opens a row's ABOUT page (classic_about.lua) -Elvie
  local function about(g, info, row)
    if not info then return end
    local ok, page = pcall(function() return require("mods.facets.classic_about").screen(mod, g, info, set, row) end)
    if ok and page then g.stack:push(page)
    else mod.log:warn("ABOUT couldn't open: %s", tostring(page)) end
  end

  -- A page's rows: its settings, as the Mods manager has them. On its
  -- topic's page a SIZE needs no POKEMON or TRAINER before it, and Gen 2's
  -- page has room for nine letters before the values -Elvie
  -- (on PEOPLE, TRAINERS' size says whose; on POKEMON, the map's
  -- partners say they're the map's) -Elvie
  local SHORT = { classicSize = "SIZE", classicTrainerSize = "TRAINER SIZE",
    classicPikachu = "MAP PIKACHU", classicClefairy = "MAP CLEFAIRY" }
  local function settingRows(list)
    local out = {}
    for _, e in ipairs(list) do
      out[#out + 1] = { id = "facets." .. e.key, label = SHORT[e.key] or e.label, port = true, facetsKey = e.key,
        -- a long one scrolls under the cursor, as the screen's own do -Elvie
        value = function() return labelFor(e) end,
        step = function(game, dir)
          set(game, e.key, cmenu.step(e.choices, get(e.key), dir, e.key))
          return true
        end,
        about = function()
          return { key = e.key, label = e.label, choices = e.choices, value = get(e.key) }
        end }
    end
    return out
  end

  local openPage -- below, once the page builders are -Elvie

  -- STYLE's choices: the styles, and CUSTOM while it's a mix -Elvie
  local function styleChoices()
    local out = {}
    if cmenu.styleOf(get, entries) == cmenu.CUSTOM then out[1] = { "CUSTOM", cmenu.CUSTOM } end
    for _, s in ipairs(cmenu.STYLES) do out[#out + 1] = { s[1], s[2] } end
    return out
  end
  local function setStyle(game, style)
    for key, v in pairs(cmenu.styleValues(style, entries) or {}) do
      if get(key) ~= v then set(game, key, v) end
    end
  end

  -- The first page: STYLE, the topics, then CREDITS -Elvie
  local function topRows()
    local out = {}
    out[#out + 1] = { id = "facets.style", label = "PRESETS", port = true,
      value = function()
        local now = cmenu.styleOf(get, entries)
        for _, c in ipairs(styleChoices()) do if c[2] == now then return c[1] end end
        return "CUSTOM"
      end,
      step = function(game, dir)
        local list = {}
        for _, s in ipairs(cmenu.STYLES) do list[#list + 1] = { s[1], s[2] } end
        local now = cmenu.styleOf(get, entries)
        local nextOne
        if now == cmenu.CUSTOM then nextOne = (dir or 1) > 0 and list[1][2] or list[#list][2]
        else nextOne = cmenu.step(list, now, dir) end
        setStyle(game, nextOne)
        return true
      end,
      about = function()
        return { key = "style", label = "PRESETS", choices = styleChoices(), value = cmenu.styleOf(get, entries) }
      end }
    for _, t in ipairs(topics) do
      local lead
      for _, e in ipairs(t.entries) do if e.key == t.lead then lead = e end end
      out[#out + 1] = { id = "facets.topic." .. t.id, label = t.label, port = true,
        value = lead and function() return labelFor(lead) end or nil,
        activate = function(g) openPage(g, settingRows(t.entries)) end,
        step = function() return false end,
        about = function() return { key = "topic", label = t.label, about = t.about, choices = {} } end }
    end
    -- CREDITS last: A opens who made it all -Elvie
    out[#out + 1] = { id = "facets.credits", label = "CREDITS", port = true,
      activate = function(g)
        local ok, page = pcall(function() return require("mods.facets.classic_credits").screen(mod, g, rows) end)
        if ok and page then g.stack:push(page)
        else mod.log:warn("CREDITS couldn't open: %s", tostring(page)) end
      end,
      step = function() return false end,
      about = function() return { key = "credits", label = "CREDITS", about = "Everyone whose art Facets shows on these games.", choices = {} } end }
    return out
  end
  cmenu.topRows = topRows

  -- The TEXT BOX row shows the text box it gives: Gen 1 draws that row's
  -- own box as the text box; Gen 2's page gives it a box of its own, the
  -- rest as the game lays them out. WINDOWS shows on the page's own
  -- frame -Elvie
  local TEXTBOX = "facets.classicTextBox"
  local function wins()
    local w = package.loaded["mods.facets.classic_windows"]
    return type(w) == "table" and w or nil
  end
  local function boxed(row)
    local w = wins()
    return row and row.id == TEXTBOX and w and w.textStyled() or false
  end

  -- SELECT on a row opens its ABOUT page; the page's own update gets
  -- everything else -Elvie
  local function withAbout(page, current)
    local ownUpdate = page.update
    page.update = function(p, ...)
      local input = p.game and p.game.input
      if input and input:wasPressed("select") then
        local row = current(p)
        if row and type(row.about) == "function" then
          local ok, info = pcall(row.about)
          if ok and info then return about(p.game, info, row) end
        end
      end
      return ownUpdate(p, ...)
    end
    return page
  end

  local function gen1Page(g, list)
    local page = OptionsMenu.new(g, { rows = list })
    withAbout(page, function(p) return (p.view or p.rows or {})[p.index] end)
    local ownDraw = page.draw
    page.draw = function(p, ...)
      local w, rows = wins(), p.view or p.rows
      for slot = 1, 4 do
        if boxed(rows[(p.scroll or 0) + slot]) then w.textBoxAt = (slot - 1) * 4 end
      end
      -- (the screen under it, PRISM's list, owned the whole screen as a
      -- dark window: let it go, so the white round this page's boxes, its
      -- foot, is paper again and not kept white) -Elvie
      local okF, filter = pcall(require, "mods.facets.filter")
      if okF and type(filter.disown) == "function" then filter.disown(0, 0, 160, 144) end
      if okF and type(filter.markPaper) == "function" then filter.markPaper(0, 0, 160, 144) end
      local ok, err = pcall(ownDraw, p, ...)
      if w then w.textBoxAt = nil end
      if not ok then error(err, 0) end
      -- the way to ABOUT, beside BACK -Elvie
      local Font = require("src.render.Font")
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw("SELECT:ABOUT", 7 * 8, 17 * 8)
      love.graphics.setColor(1, 1, 1, 1)
    end
    return page
  end

  -- Gen 2's OPTION page lays rows out two lines apart; the TEXT BOX row
  -- here takes four, for its box, and the bottom line is SELECT:ABOUT's -Elvie
  local FIRST, LAST, ARROW = 2, 14, 16
  local function height(row)
    if boxed(row) then return 4 end
    return type(row.value) == "function" and 2 or 1
  end
  local function lastShown(rows, scroll)
    local y, last = FIRST, scroll
    for i = scroll + 1, #rows do
      if y + height(rows[i]) - 1 > LAST then break end
      last = i
      y = y + math.max(2, height(rows[i]))
    end
    return last
  end

  local function gen2Page(g, list)
    local Chrome = require("src.ui.gen2.Chrome")
    local Marquee = require("src.ui.Marquee")
    local Font = require("src.render.Font")
    local okS, Strings = pcall(require, "src.core.Strings")
    local function str(t) return okS and Strings(t) or t end
    local page = setmetatable({}, OptionsMenu)
    local view = list
    page.game, page.rows = g, view
    page.options = g.options
    page.index, page.scroll, page.sub = 1, 0, true
    page.view = {}
    for i, r in ipairs(view) do page.view[i] = r end
    page.view[#page.view + 1] = { label = "BACK", cancel = true, id = "cancel" }

    function page:ensureVisible()
      local rows = self:visible()
      local floor = #rows > 0 and #rows - 1 or 0
      while floor > 0 and lastShown(rows, floor - 1) >= #rows do floor = floor - 1 end
      if self.index <= self.scroll then self.scroll = self.index - 1 end
      while self.scroll < self.index - 1 and lastShown(rows, self.scroll) < self.index do
        self.scroll = self.scroll + 1
      end
      self.scroll = math.max(0, math.min(self.scroll, floor))
    end

    function page:layout(scroll)
      local rows = self:visible()
      scroll = scroll or self.scroll
      local last = lastShown(rows, scroll)
      local out, y = {}, FIRST
      for i = scroll + 1, last do
        local row = rows[i]
        local top = boxed(row) and 1 or 0
        out[#out + 1] = { index = i, row = row, labelY = y + top,
          valueY = type(row.value) == "function" and y + top + 1 or nil }
        y = y + math.max(2, height(row))
      end
      return out, last < #rows
    end

    function page:drawPanel()
      Chrome.clear()
      Chrome.textbox(0, 0, Chrome.SCREEN_W - 2, Chrome.SCREEN_H - 2)
      self:ensureVisible()
      local spots, more = self:layout()
      local cursorY
      for _, at in ipairs(spots) do
        local row, hot = at.row, at.index == self.index
        local key = tostring(row.id or row.label)
        local room = 19
        if hot then cursorY = at.labelY end
        if boxed(row) then
          local w = wins()
          w.textBoxAt = at.labelY - 1
          local ok, err = pcall(Font.drawBox, 0, at.labelY - 1, 20, 4)
          w.textBoxAt = nil
          if not ok then error(err, 0) end
          room = 18
        end
        local function put(text, tx, ty)
          text = hot and Marquee.scroll(text, room - tx, key) or Marquee.clip(text, room - tx)
          if room == 18 then
            love.graphics.setColor(0, 0, 0, 1)
            Font.draw(text, tx * 8, ty * 8)
          else
            Chrome.print(text, tx, ty)
          end
        end
        put(str(row.label), 2, at.labelY)
        if at.valueY then
          local ok, text = pcall(row.value, self.game)
          put(":", 10, at.valueY)
          put(ok and tostring(text) or "?", 11, at.valueY)
        end
      end
      if cursorY then Chrome.cursor(1, cursorY) end
      if more then
        love.graphics.setColor(0, 0, 0, 1)
        Font.drawCode(Chrome.DOWN_ARROW, 8, ARROW * 8)
      end
      -- the way to ABOUT, along the bottom -Elvie
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(str("SELECT:ABOUT"), 7 * 8, ARROW * 8)
    end
    withAbout(page, function(p) return p:visible()[p.index] end)
    return page
  end

  openPage = function(g, list, key)
    local page = gen1 and gen1Page(g, list) or gen2Page(g, list)
    local shown = page.view or page.rows or {}
    for i, row in ipairs(shown) do
      if key and row.id == "facets." .. key then
        page.index = i
        if gen1 then page.scroll = math.max(0, i - 4) end
      end
    end
    g.stack:push(page)
    return page
  end

  -- key: a setting to start on (the game's COLORS row opens it at
  -- COLORS): its topic's page opens over the first one -Elvie
  local function open(g, key)
    local top = openPage(g, topRows())
    if not key then return end
    for _, t in ipairs(topics) do
      for _, e in ipairs(t.entries) do
        if e.key == key then
          local shown = top.view or top.rows or {}
          for j, row in ipairs(shown) do
            if row.id == "facets.topic." .. t.id then top.index = j end
          end
          openPage(g, settingRows(t.entries), key)
          return
        end
      end
    end
  end
  cmenu.open = open

  -- START and OPTION menus through prism.lua, as in the Gen 3 games: on
  -- its own it's FACETS on both; with Emerald Lens (or another visuals
  -- mod) they share one PRISM item. The OPTION row shows the first
  -- setting, the NPC set. -Elvie
  local prism = require("mods.facets.prism")
  local prismScreen = prism.registerGb(mod)
  local entry = { id = "facets", label = "FACETS", short = "FACETS",
    about = "The look of everything else.",
    colour = { 130, 60, 170 }, -- amethyst -Elvie
    order = 20, -- under the lens mods in PRISM -Elvie
    value = function()
      local first = entries[1]
      return first and labelFor(first) or "OFF"
    end,
    open = function(g) open(g) end,
  }
  local function liveGame(game)
    if type(game) == "table" then return game end
    local ok, g = pcall(function() return mod.game end)
    return ok and type(g) == "table" and g or nil
  end
  mod.hooks:wrap("ui.start_menu.items", function(nextFn, game, items)
    local got = nextFn(game, items)
    if type(got) ~= "table" then return got end
    return prism.addStartGb(mod, got, entry, liveGame(game), prismScreen)
  end)
  mod.hooks:wrap("ui.options.rows", function(nextFn, game, list)
    local got = nextFn(game, list)
    if type(got) ~= "table" then return got end
    return prism.addOptionGb(mod, got, entry, liveGame(game), prismScreen)
  end)
end

return cmenu
