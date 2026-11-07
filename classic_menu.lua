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

-- The next choice along, wrapping -Elvie
function cmenu.step(choices, value, dir)
  local at = 1
  for i, c in ipairs(choices) do if c[2] == value then at = i end end
  return choices[(at - 1 + (dir or 1)) % #choices + 1][2]
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

  local function members()
    local out = {}
    for _, e in ipairs(entries) do
      out[#out + 1] = { id = "facets." .. e.key, label = e.label, port = true,
        value = function()
          local v = mod.options:get(e.key)
          -- a long one scrolls under the cursor, as the screen's own do -Elvie
          for _, c in ipairs(e.choices) do if c[2] == v then return c[1] end end
          return e.choices[1][1]
        end,
        step = function(game, dir)
          set(game, e.key, cmenu.step(e.choices, mod.options:get(e.key), dir))
          return true
        end }
    end
    -- CREDITS last: A opens who made it all -Elvie
    out[#out + 1] = { id = "facets.credits", label = "CREDITS", port = true,
      activate = function(g)
        local ok, page = pcall(function() return require("mods.facets.classic_credits").screen(mod, g, rows) end)
        if ok and page then g.stack:push(page)
        else mod.log:warn("CREDITS couldn't open: %s", tostring(page)) end
      end,
      step = function() return false end }
    return out
  end

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

  local function gen1Page(g)
    local page = OptionsMenu.new(g, { rows = members() })
    local ownDraw = page.draw
    page.draw = function(p, ...)
      local w, rows = wins(), p.view or p.rows
      for slot = 1, 4 do
        if boxed(rows[(p.scroll or 0) + slot]) then w.textBoxAt = (slot - 1) * 4 end
      end
      local ok, err = pcall(ownDraw, p, ...)
      if w then w.textBoxAt = nil end
      if not ok then error(err, 0) end
    end
    return page
  end

  -- Gen 2's OPTION page lays rows out two lines apart; the TEXT BOX row
  -- here takes four, for its box -Elvie
  local FIRST, LAST, ARROW = 2, 15, 16
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

  local function gen2Page(g)
    local Chrome = require("src.ui.gen2.Chrome")
    local Marquee = require("src.ui.Marquee")
    local Font = require("src.render.Font")
    local okS, Strings = pcall(require, "src.core.Strings")
    local function str(t) return okS and Strings(t) or t end
    local page = setmetatable({}, OptionsMenu)
    local view = members()
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
    end
    return page
  end

  -- key: a setting to start on (the game's COLORS row opens it at
  -- COLORS) -Elvie
  local function open(g, key)
    local page = gen1 and gen1Page(g) or gen2Page(g)
    local rows = page.view or page.rows or {}
    for i, row in ipairs(rows) do
      if key and row.id == "facets." .. key then
        page.index = i
        if gen1 then page.scroll = math.max(0, i - 4) end
      end
    end
    g.stack:push(page)
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
      local first = members()[1]
      return first and tostring(first.value()) or "OFF"
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
