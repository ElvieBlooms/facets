-- The FACETS screen's model
-- Each part (npcs.lua, mons.lua) registers its rows, preview lines,
-- preview drawing and credits here; this puts them on one screen, opened
-- from the START menu (FACETS) and the OPTION menu (FACETS), the way
-- Emerald Lens has its LENS screen. Only the running game's rows are
-- shown. The mod options keep every row for both families. -Elvie
-- --------------------------------------------------

local menu = {}

local FAMILIES = {
  frlg = { id = "frlg", suffix = "Frlg" },
  rse = { id = "rse", suffix = "Rse" },
}

-- The running family (frlg or rse), or nil outside the Gen 3 games. -Elvie
function menu.family()
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if not ok or type(GameVersion) ~= "table" then return nil end
  local okL, layout = pcall(GameVersion.layout, GameVersion.get())
  return okL and FAMILIES[layout] or nil
end

function menu.labelOf(list, value)
  for _, choice in ipairs(list or {}) do
    if choice[2] == value then return choice[1] end
  end
  return ""
end

-- A meta.json credit (a string or a list) as { text } lines. -Elvie
function menu.creditLines(credit, lines)
  lines = lines or {}
  if type(credit) == "string" then credit = { credit } end
  if type(credit) ~= "table" then return lines end
  for _, line in ipairs(credit) do
    if type(line) == "string" and line ~= "" then lines[#lines + 1] = { text = line } end
  end
  return lines
end

-- part = {
--   rows(family) -> { { key, label, who, choices, value }, ... },
--   preview(who, family) -> { lines = { { text, red } } },
--   draw(clock, family) draws its side of the preview,
--   credits(family) -> { { text, heading } },
-- } -Elvie
-- opts (for another page, like SCREEN): title, layer (its screen's), and
-- credits = false to leave out the CREDITS row. -Elvie
function menu.new(mod, opts)
  local M = { parts = {}, pages = {} }
  opts = opts or {}
  if not opts.title then menu.current = M end -- for the tests -Elvie
  M.layer = opts.layer

  function M.register(part)
    if type(part) == "table" then M.parts[#M.parts + 1] = part end
  end

  local function liveGame(game)
    if type(game) == "table" then return game end
    local ok, g = pcall(function() return mod.game end)
    return ok and type(g) == "table" and g or nil
  end
  M.liveGame = liveGame

  -- Set the way the mod settings screen sets them (ManagerState:setOption),
  -- so everything listening reacts the same. -Elvie
  function M.set(game, key, value)
    local Runtime = package.loaded["src.mods.Runtime"]
    if Runtime and Runtime.safeMode then return end
    game = liveGame(game)
    if not game then return end
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

  function M.rows()
    local family, out = menu.family(), {}
    if not family then return out end
    for _, part in ipairs(M.parts) do
      local ok, rows = pcall(part.rows, family)
      if ok and type(rows) == "table" then
        for _, row in ipairs(rows) do
          row.valueLabel = row.valueLabel or menu.labelOf(row.choices, row.value)
          out[#out + 1] = row
        end
      elseif not ok then
        mod.log:warn("FACETS screen rows: %s", tostring(rows))
      end
    end
    -- A opens the full credits page. -Elvie
    if opts.credits ~= false then
      out[#out + 1] = { key = "credits", label = "CREDITS", who = "credits", page = true, valueLabel = "SEE ALL" }
    end
    return out
  end

  function M.preview(who)
    local family, lines = menu.family(), {}
    if family then
      for _, part in ipairs(M.parts) do
        if type(part.preview) == "function" then
          local ok, got = pcall(part.preview, who, family)
          if ok and type(got) == "table" then
            for _, line in ipairs(got.lines or {}) do lines[#lines + 1] = line end
          end
        end
      end
    end
    if who == "credits" then lines[#lines + 1] = { text = "Everyone whose art Facets uses." } end
    return { lines = lines }
  end

  -- who: the row the cursor is on, for a part that previews it -Elvie
  function M.draw(clock, who)
    local family = menu.family()
    if not family then return end
    for _, part in ipairs(M.parts) do
      if type(part.draw) == "function" then pcall(part.draw, clock, family, nil, who) end
    end
  end

  -- The same preview in PRISM's corner: the NPC large on the left, the
  -- focus, and the Pokémon at its own size on the right, behind it (so
  -- the parts draw in reverse: Pokémon first). Both stand on the
  -- corner's bottom edge. -Elvie
  function M.drawPreview(area, clock)
    local family = menu.family()
    if not (family and type(area) == "table") then return end
    local spots = {
      npc = { x = area.x0 + 50, bottom = area.y1, height = 64 },
      mon = { x = area.x1 - 60, y = area.y1 - 64 },
    }
    for i = #M.parts, 1, -1 do
      local part = M.parts[i]
      if type(part.draw) == "function" then pcall(part.draw, clock, family, spots) end
    end
  end

  function M.credits()
    local family, out = menu.family(), {}
    for _, part in ipairs(M.parts) do
      if family and type(part.credits) == "function" then
        local ok, list = pcall(part.credits, family)
        if ok and type(list) == "table" then
          for _, entry in ipairs(list) do out[#out + 1] = entry end
        end
      end
    end
    out[#out + 1] = { text = "FACETS", heading = true }
    out[#out + 1] = { text = "A time machine for Gen 3's people and Pokémon, by Elvie." }
    out[#out + 1] = { text = "Companion to Emerald Lens, which keeps the player and the rival." }
    return out
  end

  function M.title() return opts.title or "FACETS" end

  -- The screen and its two doors. -Elvie
  function M.start()
    if #M.parts == 0 or not menu.family() then return nil end
    local screen = require("mods.facets.screen").new(mod, M)
    M.screen = screen
    if not (mod.hooks and type(mod.hooks.wrap) == "function") then return screen end
    -- START and OPTION menus: through prism.lua, so with Emerald Lens
    -- (or another visuals mod) installed both share one PRISM item.
    -- On its own it's FACETS, as before; the OPTION row shows the NPC
    -- set. -Elvie
    local prism = require("mods.facets.prism")
    local picker = prism.picker()
    M.picker = picker
    local entry = { id = "facets", label = "FACETS", short = "FACETS",
      about = "The look of everything else.",
      colour = { 130, 60, 170 }, -- amethyst -Elvie
      draw = function(area, clock) M.drawPreview(area, clock) end,
      value = function()
        local first = M.rows()[1]
        return first and first.valueLabel or "OFF"
      end,
      open = function(g) screen.open(liveGame(g)) end,
    }
    -- PERFORMANCE: PREBUILD's own screen and PRISM entry -Elvie
    local entries = { entry }
    -- other pages (SCREEN): a screen and a PRISM entry each -Elvie
    for _, page in ipairs(M.pages) do
      if #page.parts > 0 and type(page.entry) == "table" then
        local pageScreen = require("mods.facets.screen").new(mod, page)
        page.screen = pageScreen
        local e = {}
        for k, v in pairs(page.entry) do e[k] = v end
        e.open = function(g) pageScreen.open(liveGame(g)) end
        e.value = e.value or function()
          local first = page.rows()[1]
          return first and first.valueLabel or ""
        end
        entries[#entries + 1] = e
      end
    end
    local okB, prebuild = pcall(require, "mods.facets.prebuild")
    if okB and type(prebuild) == "table" and type(prebuild.model) == "function" then
      local perf = prebuild.model(mod, M.set)
      local perfScreen = require("mods.facets.screen").new(mod, perf)
      M.performance = perfScreen
      entries[#entries + 1] = { id = "facets_performance", label = "PERFORMANCE", short = "PERFORMANCE",
        about = "Facets, built ahead of time.",
        colour = prebuild.COLOUR,
        draw = function(area) perf.drawPreview(area) end,
        value = function() return perf.value() end,
        open = function(g) perfScreen.open(liveGame(g)) end,
      }
    end
    mod.hooks:wrap("ui.start_menu.items", function(nextFn, game, items)
      local out = nextFn()
      if type(out) ~= "table" then return out end
      -- Not in the scripted tutorial menu, which waits on a pick. -Elvie
      local StartMenu = package.loaded["src.ui.game3.start_menu"]
      if StartMenu and StartMenu._tutorial then return out end
      for _, e in ipairs(entries) do out = prism.addStart(out, e, picker, game) end
      return out
    end)
    mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
      local out = nextFn()
      if type(out) ~= "table" then return out end
      for _, e in ipairs(entries) do out = prism.addOption(out, e, picker, game) end
      return out
    end)
    return screen
  end

  return M
end

return menu
