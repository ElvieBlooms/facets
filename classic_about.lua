-- ABOUT on Red to Crystal
-- SELECT on a FACETS row opens this page: what the setting changes, each
-- choice with a line on it, and which of your games a choice needs (from
-- help.lua). The current choice has the cursor; left and right change
-- it here too, up and down scroll, and A, B or SELECT go back. Drawn in
-- the game's own font and box, like CREDITS. -Elvie
-- --------------------------------------------------

local about = {}

local W = 16 -- letters a line, after the cursor's column -Elvie
local ROWS = 13 -- rows 2 to 14; 15 for the arrows, 16 for the keys -Elvie

-- The page for a row (row.about() gives key, label, choices, value;
-- row.step changes it), pushed on the game's stack -Elvie
function about.screen(mod, game, info, _, row)
  local Font = mod.ui and mod.ui.Font or require("src.render.Font")
  local Theme = mod.ui and mod.ui.Theme
  local help = require("mods.facets.help")
  local plain = require("mods.facets.classic_credits").plain
  local okD, ds = pcall(require, "mods.facets.ds")
  local api = okD and ds.api(mod) or nil

  local self = { isOpaque = true, scroll = 0 }
  local lines, last = {}, 0

  local function build()
    local page = help.page(info, api)
    if info.about then page.about = info.about end
    lines = help.lines(page, W)
    for _, line in ipairs(lines) do line.text = plain(line.text) end
    last = math.max(0, #lines - ROWS)
  end

  -- Scroll so the current choice and its line show -Elvie
  local function showCurrent()
    for i, line in ipairs(lines) do
      if line.current then
        if i - 1 < self.scroll then self.scroll = math.max(0, i - 2) end
        if i + 1 > self.scroll + ROWS then self.scroll = math.min(last, i + 1 - ROWS) end
        return
      end
    end
  end

  build()
  showCurrent()
  local changes = row and type(row.step) == "function" and #(info.choices or {}) > 1

  function self:update()
    local input = game.input
    if not input then return end
    if input:wasPressed("a") or input:wasPressed("b") or input:wasPressed("select") or input:wasPressed("start") then
      game.stack:pop()
      return
    end
    if input:wasPressed("up") then self.scroll = math.max(0, self.scroll - 1)
    elseif input:wasPressed("down") then self.scroll = math.min(last, self.scroll + 1)
    elseif changes and (input:wasPressed("left") or input:wasPressed("right")) then
      row.step(game, input:wasPressed("left") and -1 or 1)
      if type(row.about) == "function" then
        local ok, again = pcall(row.about)
        if ok and again then info = again end
      end
      build()
      showCurrent()
    end
  end

  function self:draw()
    local G = love.graphics
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, 160, 144)
    Font.drawBox(0, 0, 20, 18)
    G.setColor(0, 0, 0, 1)
    Font.draw(plain(tostring(info.label or "")), 8, 8)
    for i = 1, ROWS do
      local line = lines[self.scroll + i]
      if not line then break end
      local y = (i + 1) * 8
      if line.current and Theme and Theme.cursor then Font.drawCode(Theme.cursor, 8, y) end
      Font.draw(line.text, 16, y)
    end
    if self.scroll < last and Theme and Theme.moreArrow then Font.drawCode(Theme.moreArrow, 144, 15 * 8) end
    Font.draw(changes and "L/R:CHANGE B:BACK" or "B:BACK", 8, 16 * 8)
    G.setColor(1, 1, 1, 1)
  end

  return self
end

return about
