-- The FACETS screen
-- The running game's rows on a screen of their own, with the selected
-- sets drawn beside them: a Pokémon from the POKEMON set and an NPC from
-- the NPC set, walking. Built like Emerald Lens's LENS screen, so the two
-- look and work alike. menu.lua hands over the model. -Elvie
-- --------------------------------------------------

local screen = {}

local LAYER = "facets"
local HELP_BG = { 0 / 255, 123 / 255, 197 / 255, 1 } -- same blue as the OPTION menu -Elvie
local HELP = "{DPAD_LEFTRIGHT}CHANGE {B_BUTTON}EXIT"
local CREDITS_HELP = "{DPAD_UPDOWN}SCROLL {B_BUTTON}BACK"

-- Window(1, 3, 28, 16): 8..232 x 24..152 inside the frame. -Elvie
local LABEL_X, VALUE_X, ROW_Y0, ROW_STEP = 16, 80, 26, 13
local VALUE_W = 76
local INFO_W, WIN_BOTTOM = 152, 152
local CREDITS_W, CREDITS_ROWS = 208, 9
screen.ROW_Y0, screen.ROW_STEP = ROW_Y0, ROW_STEP

local function engine(name)
  local ok, m = pcall(require, name)
  return ok and m or nil
end

-- model.layer names its layer (the FACETS screen's by default), so
-- PERFORMANCE can be a second screen built the same way. -Elvie
function screen.new(mod, model)
  local S = { isMenu = true }
  local state -- nil while closed -Elvie
  local LAYER = model.layer or LAYER

  local function rows()
    local list = model.rows()
    if state.index > #list then state.index = #list end
    return list
  end

  local function step(row, dir)
    local n = row.choices and #row.choices or 0
    if n < 2 then return end
    local at = 1
    for i, choice in ipairs(row.choices) do
      if choice[2] == row.value then at = i end
    end
    local value = row.choices[(at - 1 + dir) % n + 1][2]
    -- a row standing for more than one option sets them itself -Elvie
    if type(row.set) == "function" then return row.set(state.game, value) end
    model.set(state.game, row.key, value)
  end

  -- The engine can clear the whole stack (a warp, the title screen), so
  -- open goes by the layer, not by state. -Elvie
  local hooked = false
  function S.open(game)
    local Stack = engine("src.ui.game3.stack")
    if not Stack or Stack.has(LAYER) then return end
    if not hooked and Stack.onClear then
      hooked = true
      Stack.onClear(function() state = nil end)
    end
    state = { game = game, index = 1, clock = 0 }
    Stack.push(LAYER, S, { hideBelow = true, fullscreen = true })
  end

  function S.close()
    if not state then return end
    state = nil
    local Stack = engine("src.ui.game3.stack")
    if Stack then Stack.pop(LAYER) end
  end

  function S.isOpen() return state ~= nil end
  function S.state() return state end

  -- Word wrap for the credits page; a word too long for a line is cut. -Elvie
  local function wrap(FrlgFont, text, width)
    local out, line = {}, ""
    for word in tostring(text):gmatch("%S+") do
      local try = line == "" and word or (line .. " " .. word)
      if FrlgFont.measure(try) <= width then
        line = try
      else
        if line ~= "" then out[#out + 1] = line end
        line = word
      end
    end
    if line ~= "" or #out == 0 then out[#out + 1] = line end
    return out
  end

  local function openCredits()
    local FrlgFont = engine("src.ui.game3.frlg_font")
    local lines = {}
    for _, entry in ipairs(model.credits()) do
      if entry.heading and #lines > 0 then lines[#lines + 1] = { text = "" } end
      local ok, parts = false, nil
      if FrlgFont then ok, parts = pcall(wrap, FrlgFont, entry.text, entry.heading and CREDITS_W or CREDITS_W - 8) end
      if not ok then parts = { entry.text } end
      for _, part in ipairs(parts) do
        lines[#lines + 1] = { text = part, heading = entry.heading }
      end
    end
    state.credits = { lines = lines, scroll = 0 }
  end

  local function creditsInput(input)
    local page = state.credits
    local last = math.max(0, #page.lines - CREDITS_ROWS)
    if input:wasPressed("up") then page.scroll = math.max(0, page.scroll - 1)
    elseif input:wasPressed("down") then page.scroll = math.min(last, page.scroll + 1)
    elseif input:wasPressed("left") then page.scroll = math.max(0, page.scroll - CREDITS_ROWS)
    elseif input:wasPressed("right") then page.scroll = math.min(last, page.scroll + CREDITS_ROWS)
    elseif input:wasPressed("b") or input:wasPressed("a") then state.credits = nil
    elseif input:wasPressed("start") then S.close()
    end
  end

  function S.handleInput(input)
    if not (state and input) then return end
    if state.credits then return creditsInput(input) end
    local list = rows()
    local row = list[state.index]
    if input:wasPressed("up") then state.index = (state.index - 2) % #list + 1
    elseif input:wasPressed("down") then state.index = state.index % #list + 1
    elseif row and row.page and input:wasPressed("a") then openCredits()
    -- a row that does something (BUILD NOW) instead of changing -Elvie
    elseif row and row.action and (input:wasPressed("a") or input:wasPressed("right")) then
      row.action(state.game)
    elseif input:wasPressed("left") then if row then step(row, -1) end
    elseif input:wasPressed("right") or input:wasPressed("a") then if row then step(row, 1) end
    elseif input:wasPressed("b") or input:wasPressed("start") then S.close()
    end
  end

  function S.update(dt)
    if state then state.clock = state.clock + (tonumber(dt) or 1 / 60) end
  end

  -- One line, cut with "…" to fit. -Elvie
  local function fit(FrlgFont, text, width, opts)
    if FrlgFont.measure(text, opts) <= width then return text end
    local chars = {}
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    while #chars > 0 do
      chars[#chars] = nil
      local cut = table.concat(chars):gsub("%s+$", "") .. "…"
      if FrlgFont.measure(cut, opts) <= width then return cut end
    end
    return ""
  end

  local function drawChrome(Window, FrlgFont, title, help)
    local PokedexChrome = engine("src.ui.game3.pokedex_chrome")
    local Options = engine("src.core.game3.options")
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, 240, 160)
    love.graphics.setColor(HELP_BG)
    love.graphics.rectangle("fill", 0, 0, 240, 16)
    love.graphics.setColor(1, 1, 1, 1)
    FrlgFont.draw(title, 4, 0, { colors = FrlgFont.COLOR.WHITE })
    if PokedexChrome then PokedexChrome.drawControlInfo(help, 0xE4, 0) end
    local game = state.game
    local frameType = 0
    if Options and type(game) == "table" and type(game.options) == "table" then
      local ok, block = pcall(Options.block, game.options)
      frameType = ok and type(block) == "table" and tonumber(block.frameType) or 0
    end
    if not pcall(Window.userFrame, Window.template(1, 3, 28, 16), frameType) then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 8, 24, 224, 128)
    end
  end

  local function drawCredits(Window, FrlgFont)
    drawChrome(Window, FrlgFont, "CREDITS", CREDITS_HELP)
    local page = state.credits
    for slot = 1, CREDITS_ROWS do
      local line = page.lines[page.scroll + slot]
      if line then
        Window.printPx(line.text, line.heading and LABEL_X - 4 or LABEL_X + 4, ROW_Y0 + (slot - 1) * ROW_STEP,
          { colors = line.heading and FrlgFont.COLOR.BLUE or FrlgFont.COLOR.NORMAL })
      end
    end
    local red = { colors = FrlgFont.COLOR.RED }
    if page.scroll > 0 then FrlgFont.drawGlyph(FrlgFont.CHAR_UP_ARROW, 220, 24, red) end
    if page.scroll + CREDITS_ROWS < #page.lines then
      FrlgFont.drawGlyph(FrlgFont.CHAR_DOWN_ARROW, 220, WIN_BOTTOM - 14, red)
    end
  end

  function S.draw()
    if not state then return end
    local Window = engine("src.ui.game3.window")
    local FrlgFont = engine("src.ui.game3.frlg_font")
    if not (Window and FrlgFont) then return end
    if state.credits then return drawCredits(Window, FrlgFont) end
    drawChrome(Window, FrlgFont, model.title(), HELP)

    local list = rows()
    for i, row in ipairs(list) do
      local y = ROW_Y0 + (i - 1) * ROW_STEP
      Window.printPx(row.label, LABEL_X, y, { colors = FrlgFont.COLOR.NORMAL })
      local value = fit(FrlgFont, row.valueLabel or "", VALUE_W)
      local changes = row.choices and #row.choices > 1 or row.page or row.action
      Window.printPx(value, VALUE_X, y,
        { colors = changes and FrlgFont.COLOR.OPTION_VALUE or FrlgFont.COLOR.NORMAL })
    end
    Window.cursorPx(LABEL_X - 8, ROW_Y0 + (state.index - 1) * ROW_STEP)

    local selected = list[state.index]
    love.graphics.setColor(1, 1, 1, 1)
    model.draw(state.clock, selected and selected.who or nil)
    love.graphics.setColor(1, 1, 1, 1)

    local preview = model.preview(selected and selected.who or "npcs")
    local y = ROW_Y0 + #list * ROW_STEP + 2
    for _, line in ipairs(preview.lines or {}) do
      if y + ROW_STEP > WIN_BOTTOM then break end
      local colors = line.red and FrlgFont.COLOR.RED or FrlgFont.COLOR.NORMAL
      Window.printPx(fit(FrlgFont, line.text, preview.width or INFO_W), LABEL_X, y, { colors = colors })
      y = y + ROW_STEP
    end
  end

  return S
end

return screen
