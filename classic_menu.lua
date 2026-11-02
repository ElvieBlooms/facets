-- FACETS on the OPTION menu of the Game Boy games
-- One FACETS row on the OPTION screen (the ui.options.rows hook) opens a
-- page of the same settings as the Mods manager, set the same way, so
-- everything listening reacts as it would there. -Elvie
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
      out[#out + 1] = { key = row.key, label = (label == "SET" and section) or label, choices = row.choices }
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
    if type(game.options) == "table" then
      game.options.modOptions = game.options.modOptions or {}
      game.options.modOptions[mod.id] = game.options.modOptions[mod.id] or {}
      game.options.modOptions[mod.id][key] = value
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
    return out
  end

  mod.hooks:wrap("ui.options.rows", function(nextFn, game, list)
    local got = nextFn(game, list)
    if type(got) ~= "table" then return got end
    local row = { id = "facets", label = "FACETS", port = true,
      activate = gen1 and function(g)
        -- Gen 1's own page for a list of rows -Elvie
        g.stack:push(OptionsMenu.new(g, { rows = members() }))
      end or function(g)
        local page = setmetatable({}, OptionsMenu)
        local view = members()
        page.game, page.rows = g, view
        page.options = g.options
        page.index, page.scroll, page.sub = 1, 0, true
        page.view = {}
        for i, r in ipairs(view) do page.view[i] = r end
        page.view[#page.view + 1] = { label = "BACK", cancel = true, id = "cancel" }
        g.stack:push(page)
      end }
    -- just before BACK, where a mod's rows go -Elvie
    local at = #got + 1
    for i, r in ipairs(got) do if r.cancel then at = i break end end
    table.insert(got, at, row)
    return got
  end)
end

return cmenu
