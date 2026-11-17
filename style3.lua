-- STYLE on the GBA games: the FACETS screen's first row sets the main
-- looks together, as on Red to Crystal (classic_menu.lua), across both
-- of Facets' screens (FACETS and SCREEN). CUSTOM while they're a mix -Elvie
-- --------------------------------------------------

local style3 = {}

local OFF = "__off"

-- each style's values, best first: the first one this game offers is
-- used. NPCS is setFrlg or setRse, by the game's family -Elvie
style3.STYLES = {
  { "GAME", "original", {
    setFrlg = { OFF }, setRse = { OFF }, setTrainers = { OFF }, setMons = { OFF },
    gbcBattleBg = { "game" }, gbcFrame = { "game" }, gbcTextBox = { "match" }, gbcHud = { "game" } } },
  { "GBC", "gbc", {
    setFrlg = { "gbc" }, setRse = { "gbc" }, setTrainers = { "gbcish", "gameboy" }, setMons = { "gbc_anim", "gbcish" },
    gbcBattleBg = { "white" }, gbcFrame = { "1" }, gbcTextBox = { "match" }, gbcHud = { "gbc" } } },
  { "DS", "ds", {
    setFrlg = { "diego" }, setRse = { "diego" }, setTrainers = { "ds" },
    setMons = { "ds_hgss", "ds_dppt", "ds_bw2", "bw_anim", "ds" },
    gbcBattleBg = { "scenery" }, gbcFrame = { "game" }, gbcTextBox = { "match" }, gbcHud = { "hgss", "game" } } },
}

-- menus: the FACETS screen's and the other pages', whose rows STYLE reads -Elvie
function style3.init(mod, menu)
  local cmenu = require("mods.facets.classic_menu")
  local busy = false
  local function entries()
    local out = {}
    local lists = { menu }
    for _, page in ipairs(menu.pages or {}) do lists[#lists + 1] = page end
    for _, m in ipairs(lists) do
      local ok, rows = pcall(m.allRows or m.rows)
      for _, row in ipairs(ok and rows or {}) do
        if row.key and row.key ~= "style" and type(row.choices) == "table" then
          out[#out + 1] = { key = row.key, choices = row.choices, value = row.value }
        end
      end
    end
    return out
  end
  local function now(list)
    local byKey = {}
    for _, e in ipairs(list) do byKey[e.key] = e.value end
    return cmenu.styleOf(function(k) return byKey[k] end, list, style3.STYLES)
  end
  local part = {
    rows = function()
      if busy then return {} end
      busy = true
      local list = entries()
      busy = false
      local current = now(list)
      local choices = {}
      if current == cmenu.CUSTOM then choices[1] = { "CUSTOM", cmenu.CUSTOM } end
      for _, st in ipairs(style3.STYLES) do choices[#choices + 1] = { st[1], st[2] } end
      return { { key = "style", label = "PRESETS", who = "style", choices = choices, value = current } }
    end,
    preview = function(who)
      if who ~= "style" then return nil end
      return { lines = { { text = "Sets the looks together." }, { text = "SELECT tells you more." } } }
    end,
  }
  -- first on the FACETS screen -Elvie
  table.insert(menu.parts, 1, part)

  -- the screen sets "style" like any row; this sets the style's looks -Elvie
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("mod.options_changed", function(change)
      if not (type(change) == "table" and change.mod == mod.id and change.key == "style") then return end
      local style = change.value
      if style == cmenu.CUSTOM then return end
      busy = true
      local list = entries()
      busy = false
      local values = cmenu.styleValues(style, list, style3.STYLES) or {}
      local current = {}
      for _, e in ipairs(list) do current[e.key] = e.value end
      for key, v in pairs(values) do
        if current[key] ~= v then menu.set(nil, key, v) end
      end
    end)
  end
end

return style3
