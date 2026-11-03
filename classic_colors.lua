-- COLORS on the Game Boy games
-- Facets' people, pictures and windows are drawn for the games' full-colour
-- mode (ADVANCED on Red, Blue and Yellow; GEN 2 on Gold, Silver and
-- Crystal). In the others the game shades them down, and the DMG greys
-- look half done next to Facets' own FILTER. So while any Facets look is
-- on, COLORS here keeps the game in full colour, whatever its own COLORS
-- says. The player's own choice stays saved, and comes back as soon as
-- nothing in Facets is on, or with COLORS on GAME. -Elvie
-- --------------------------------------------------

local colors = {}

local GAME, FULL = "game", "full"

-- The settings that change how the game looks. the SIZE rows on their own
-- change nothing -Elvie
colors.LOOKS = { "classicNpcs", "classicPikachu", "classicTrainers", "classicMons", "classicSide",
  "classicIcons", "classicBattleBg", "classicBattleUi", "classicWindows", "filter" }

-- Whether the game's colours are Facets' to hold: COLORS on and any look
-- away from its default -Elvie
function colors.holds(value, looks, defaults)
  if value == GAME then return false end
  for _, key in ipairs(colors.LOOKS) do
    local v = looks[key]
    if v ~= nil and v ~= defaults[key] then return true end
  end
  return false
end

function colors.init(mod, rows)
  local gen1 = require("mods.facets.classic").generation() == 1
  colors.FULL_LABEL = gen1 and "ADVANCED" or "GEN 2"
  rows[#rows + 1] = { key = "classicColors", type = "choice", label = "COLORS",
    choices = { { colors.FULL_LABEL, FULL }, { "GAME", GAME } }, default = FULL }

  return function()
    local defaults = {}
    for _, row in ipairs(rows) do
      if type(row.key) == "string" then defaults[row.key] = row.default end
    end
    local function holding()
      local looks = {}
      for _, key in ipairs(colors.LOOKS) do
        if defaults[key] ~= nil then looks[key] = mod.options:get(key) end
      end
      return colors.holds(mod.options:get("classicColors"), looks, defaults)
    end
    colors.holding = holding

    -- Gen 1's PaletteFX, Gen 2's GbcPalette: the same three calls. What
    -- the game asks for is kept, and given back when Facets lets go -Elvie
    local ok, Pal = pcall(require, gen1 and "src.render.PaletteFX" or "src.render.GbcPalette")
    if not (ok and type(Pal) == "table" and type(Pal.setMode) == "function"
        and type(Pal.setCustomRamp) == "function") then
      mod.log:warn("the game's colour modes weren't found; COLORS is off")
      return
    end
    local full = gen1 and "redpp" or "gbc"
    local ownMode, ownRamp, ownCycle = Pal.setMode, Pal.setCustomRamp, gen1 and Pal.cycleMode or Pal.cycle
    local wanted, wantedRamp = Pal.mode, Pal.customRamp
    local held = false

    local function apply()
      held = holding()
      if held then
        ownMode(full)
        ownRamp(nil)
      else
        ownMode(wanted)
        ownRamp(wantedRamp)
      end
    end

    Pal.setMode = function(mode, ...)
      wanted = mode
      if held then return ownMode(full) end
      return ownMode(mode, ...)
    end
    Pal.setCustomRamp = function(ramp, ...)
      wantedRamp = ramp
      if held then return ownRamp(nil) end
      return ownRamp(ramp, ...)
    end
    -- the colour hotkey steps the player's choice, not the held one -Elvie
    if type(ownCycle) == "function" then
      local cycleName = gen1 and "cycleMode" or "cycle"
      Pal[cycleName] = function(delta, ...)
        if not held then
          local got = ownCycle(delta, ...)
          wanted = Pal.mode
          if not gen1 then wantedRamp = nil end
          return got
        end
        local modes = Pal.MODES or {}
        local at = 1
        for i, m in ipairs(modes) do if m == wanted then at = i end end
        if #modes > 0 then wanted = modes[(at - 1 + (delta or 1)) % #modes + 1] end
        if not gen1 then wantedRamp = nil end
        return wanted
      end
    end
    apply()

    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id then apply() end
      end)
    end

    -- The game's own COLORS row says FACETS while Facets holds it, and
    -- opens the FACETS page there -Elvie
    if mod.hooks and type(mod.hooks.wrap) == "function" then
      mod.hooks:wrap("ui.options.rows", function(nextFn, game, list)
        local got = nextFn(game, list)
        if type(got) ~= "table" then return got end
        for i, row in ipairs(got) do
          local mine = type(row) == "table" and (row.id == "colors" or (not gen1 and row.key == "color"))
          if mine then
            local copy = {}
            for k, v in pairs(row) do copy[k] = v end
            local ownValue, ownText, ownActivate = row.value, row.text, row.activate
            if gen1 then
              copy.value = function(g, ...)
                if held then return "FACETS" end
                return ownValue(g, ...)
              end
            elseif type(ownText) == "function" then
              copy.text = function(options, ...)
                if held then return "FACETS" end
                return ownText(options, ...)
              end
            end
            copy.activate = function(g, ...)
              if held then
                local okM, menu = pcall(require, "mods.facets.classic_menu")
                if okM and type(menu.open) == "function" then return menu.open(g, "classicColors") end
              end
              if ownActivate then return ownActivate(g, ...) end
            end
            got[i] = copy
          end
        end
        return got
      end)
    end
  end
end

return colors
