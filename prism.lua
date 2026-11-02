-- PRISM: one menu item for every visuals mod
-- Facets and Emerald Lens each carry a copy of this file (the same code),
-- so neither needs the other. Each adds its screen to the START menu and
-- the OPTION menu through it: the first one there makes the item, the
-- next adds itself to that item's list. With one mod it's that mod's own
-- item (LENS, FACETS) and opens its screen; with more it's PRISM and
-- opens a list of them. It works on the Game Boy games too, drawn their
-- way, so Crystal Lens carries a copy as well. Another mod can join by doing the same: an item
-- or row with id "prism" and an `entries` list. -Elvie
-- --------------------------------------------------

local prism = {}

local ID = "prism"
local LAYER = "prism"
local BLUE = { 0, 123, 197 } -- the OPTION menu's, for an entry with no colour -Elvie
local HELP = "{A_BUTTON}OPEN {B_BUTTON}EXIT"
local LABEL_X, VALUE_X, ROW_Y0, ROW_STEP = 32, 112, 26, 13
local VALUE_W = 104
-- the game's cursor arrow, then each entry's gem, then its name -Elvie
local ARROW_X, GEM_X = 10, 19
-- The preview corner: inside the window (8..232 x 24..152), bottom right,
-- its top-left corner cut on a slant. -Elvie
local PANEL_X0, PANEL_X1, PANEL_Y1, PANEL_CUT = 112, 230, 150, 26

-- A gem, 7x7: K outline, L light, H highlight, M body, D dark. -Elvie
local GEM = { "  KKK  ", " KLHLK ", "KLLLLLK", "KMMMMMK", " KMDMK ", "  KDK  ", "   K   " }

local function engine(name)
  local ok, m = pcall(require, name)
  return ok and m or nil
end

-- entry = { id, label (EMERALD LENS), short (LENS), value = fn() -> text,
-- about (a line on what it changes), colour = { r, g, b } (0-255, its
-- gem and the header), draw = fn(area, clock) (its live preview, drawn
-- inside area = { x0, y0, x1, y1 }), open = fn(game) }. Entries sort by
-- label, so the order doesn't depend on which mod loaded first. A mod's
-- entry replaces an older one with its id. -Elvie
local function withEntry(entries, entry)
  local out = {}
  for _, e in ipairs(entries or {}) do
    if e.id ~= entry.id then out[#out + 1] = e end
  end
  out[#out + 1] = entry
  table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
  return out
end
prism.withEntry = withEntry

local function valueOf(entry)
  local ok, v = pcall(entry.value or function() return "" end)
  return ok and type(v) == "string" and v or ""
end

-- The list screen. Picking an entry opens its screen on top, so B there
-- comes back here. -Elvie
-- --------------------------------------------------
local function gen3Picker()
  local P = { isMenu = true }
  local state

  function P.open(game, entries)
    local Stack = engine("src.ui.game3.stack")
    if not Stack or Stack.has(LAYER) then return end
    if Stack.onClear and not P.hooked then
      P.hooked = true
      Stack.onClear(function() state = nil end)
    end
    state = { game = game, entries = entries, index = 1 }
    Stack.push(LAYER, P, { hideBelow = true, fullscreen = true })
  end

  function P.close()
    if not state then return end
    state = nil
    local Stack = engine("src.ui.game3.stack")
    if Stack then Stack.pop(LAYER) end
  end

  function P.isOpen() return state ~= nil end
  function P.state() return state end

  function P.handleInput(input)
    if not (state and input) then return end
    local n = #state.entries
    if input:wasPressed("up") then state.index = (state.index - 2) % n + 1
    elseif input:wasPressed("down") then state.index = state.index % n + 1
    elseif input:wasPressed("a") or input:wasPressed("right") then
      local entry = state.entries[state.index]
      if entry and entry.open then entry.open(state.game) end
    elseif input:wasPressed("b") or input:wasPressed("start") then P.close()
    end
  end

  function P.update(dt)
    if state then state.clock = (state.clock or 0) + (tonumber(dt) or 1 / 60) end
  end

  local function rgb(c, t, toward)
    -- c moved t of the way to toward (white by default), as 0-1 -Elvie
    toward = toward or { 255, 255, 255 }
    return (c[1] + (toward[1] - c[1]) * t) / 255, (c[2] + (toward[2] - c[2]) * t) / 255,
      (c[3] + (toward[3] - c[3]) * t) / 255
  end
  local function colourOf(entry)
    local c = entry and entry.colour
    if type(c) == "table" and tonumber(c[1]) and tonumber(c[2]) and tonumber(c[3]) then return c end
    return BLUE
  end

  local function drawGem(x, y, c)
    local pal = {
      K = { 0, 0, 0 }, H = { 1, 1, 1 },
      L = { rgb(c, 0.45) }, M = { rgb(c, 0.1) }, D = { rgb(c, 0.35, { 0, 0, 0 }) },
    }
    for gy, row in ipairs(GEM) do
      for gx = 1, #row do
        local p = pal[row:sub(gx, gx)]
        if p then
          love.graphics.setColor(p[1], p[2], p[3], 1)
          love.graphics.rectangle("fill", x + gx - 1, y + gy - 1, 1, 1)
        end
      end
    end
  end

  -- A four-point glint, r pixels each way, fading in and out. -Elvie
  local function glint(x, y, r, a)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.rectangle("fill", x - r, y, r * 2 + 1, 1)
    love.graphics.rectangle("fill", x, y - r, 1, r * 2 + 1)
  end

  -- The faceted corner: eight shards round a centre point, each a shade
  -- of the entry's colour, with white cuts between them, like the Facets
  -- banner. Every shard is a slice of the panel, so nothing spills out. -Elvie
  local function drawPanel(c, y0, clock)
    local x0, x1, y1, cut = PANEL_X0, PANEL_X1, PANEL_Y1, PANEL_CUT
    local h = y1 - y0
    local A, B, C, D = { x0 + cut, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 }
    local Q = { x0 + 66, y0 + math.floor(h * 0.48) }
    local P1 = { x0 + cut + 50, y0 }
    local P2 = { x1, y0 + math.floor(h * 0.42) }
    local P3 = { x0 + 70, y1 }
    local t = 0.55
    local P4 = { math.floor(x0 + cut * (1 - t) + 0.5), math.floor(y0 + h * t + 0.5) }
    local ring = { A, P1, B, P2, C, P3, D, P4 }
    local shades = { 0.62, 0.80, 0.70, 0.88, 0.66, 0.84, 0.74, 0.58 }
    for i = 1, #ring do
      local a, b = ring[i], ring[i % #ring + 1]
      love.graphics.setColor(rgb(c, shades[i]))
      love.graphics.polygon("fill", a[1], a[2], b[1], b[2], Q[1], Q[2])
    end
    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 0.9)
    for _, p in ipairs(ring) do love.graphics.line(Q[1] + 0.5, Q[2] + 0.5, p[1] + 0.5, p[2] + 0.5) end
    love.graphics.setColor(rgb(c, 0.15, { 0, 0, 0 }))
    love.graphics.line(A[1] + 0.5, A[2] + 0.5, D[1] + 0.5, D[2] + 0.5)
    love.graphics.line(A[1] + 0.5, A[2] + 0.5, B[1] + 0.5, B[2] + 0.5)
    -- glints at three of the cuts, twinkling out of step -Elvie
    local spots = { { Q, 4, 0 }, { P1, 3, 1.3 }, { P4, 2, 2.6 } }
    for _, s in ipairs(spots) do
      local a = 0.35 + 0.65 * math.abs(math.sin((clock + s[3]) * 1.6))
      glint(s[1][1], s[1][2] + (s[1] == P1 and 1 or 0), s[2], a)
    end
    return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  end

  function P.draw()
    if not state then return end
    local Window = engine("src.ui.game3.window")
    local FrlgFont = engine("src.ui.game3.frlg_font")
    if not (Window and FrlgFont) then return end
    local PokedexChrome = engine("src.ui.game3.pokedex_chrome")
    local Options = engine("src.core.game3.options")
    local clock = state.clock or 0
    local picked = state.entries[state.index]
    local colour = colourOf(picked)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, 240, 160)
    -- the header takes the picked entry's colour -Elvie
    love.graphics.setColor(rgb(colour, 0))
    love.graphics.rectangle("fill", 0, 0, 240, 16)
    love.graphics.setColor(1, 1, 1, 1)
    FrlgFont.draw("PRISM", 4, 0, { colors = FrlgFont.COLOR.WHITE })
    if PokedexChrome then PokedexChrome.drawControlInfo(HELP, 0xE4, 0) end
    local frameType = 0
    local game = state.game
    if Options and type(game) == "table" and type(game.options) == "table" then
      local ok, block = pcall(Options.block, game.options)
      frameType = ok and type(block) == "table" and tonumber(block.frameType) or 0
    end
    if not pcall(Window.userFrame, Window.template(1, 3, 28, 16), frameType) then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 8, 24, 224, 128)
    end
    -- each entry's gem; the game's dark arrow points at the picked one
    -- (the sparkle alone is hard to see through a 4-shade FILTER) -Elvie
    for i, entry in ipairs(state.entries) do
      local y = ROW_Y0 + (i - 1) * ROW_STEP
      drawGem(GEM_X, y + 2, colourOf(entry))
      if i == state.index then
        local a = 0.5 + 0.5 * math.abs(math.sin(clock * 3))
        love.graphics.setColor(1, 214 / 255, 80 / 255, a)
        love.graphics.rectangle("fill", GEM_X + 9, y + 1, 1, 3)
        love.graphics.rectangle("fill", GEM_X + 8, y + 2, 3, 1)
      end
      love.graphics.setColor(1, 1, 1, 1)
      if i == state.index then Window.cursorPx(ARROW_X, y) end
      Window.printPx(entry.label, LABEL_X, y, { colors = FrlgFont.COLOR.NORMAL })
      local value = valueOf(entry)
      if FrlgFont.measure(value) > VALUE_W then value = "" end
      Window.printPx(value, VALUE_X, y, { colors = FrlgFont.COLOR.OPTION_VALUE })
    end
    -- a blank row before the about line, while there's room for the
    -- corner below it too -Elvie
    local gap = #state.entries >= 4 and 0 or 1
    local aboutY = ROW_Y0 + (#state.entries + gap) * ROW_STEP
    if picked and type(picked.about) == "string" then
      love.graphics.setColor(1, 1, 1, 1)
      Window.printPx(picked.about, 16, aboutY, { colors = FrlgFont.COLOR.NORMAL })
    end
    if picked and type(picked.draw) == "function" then
      local y0 = math.max(76, aboutY + ROW_STEP + 1)
      if PANEL_Y1 - y0 >= 48 then
        local area = drawPanel(colour, y0, clock)
        love.graphics.setColor(1, 1, 1, 1)
        pcall(picked.draw, area, clock)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  return P
end

-- 1, 2 or 3 for the running game -Elvie
local function generation()
  local GameVersion = engine("src.core.GameVersion")
  if GameVersion and type(GameVersion.generation) == "function" then
    local ok, gen = pcall(GameVersion.generation)
    if ok and type(gen) == "number" then return gen end
  end
  return 3
end
prism.generation = generation

local function cut(text, n)
  text = tostring(text or "")
  return #text > n and text:sub(1, n) or text
end

-- Words to lines of at most n letters -Elvie
local function wrap(text, n)
  local lines, line = {}, ""
  for word in tostring(text or ""):gmatch("%S+") do
    if line == "" then line = cut(word, n)
    elseif #line + 1 + #word <= n then line = line .. " " .. word
    else lines[#lines + 1] = line line = cut(word, n) end
  end
  if line ~= "" then lines[#lines + 1] = line end
  return lines
end

-- The Game Boy list: the game's own box and font, each entry's name with
-- its value under it, and the picked one's line in a box at the bottom.
-- Up and down pick, A opens, B (or START) closes. -Elvie
local function gbPicker(mod)
  local P = { isMenu = true }
  local Font = (mod and mod.ui and mod.ui.Font) or engine("src.render.Font")
  local Theme = (mod and mod.ui and mod.ui.Theme) or engine("src.ui.Theme")

  function P.open(game, entries)
    if not (Font and game and game.stack) then return end
    local self = { isOpaque = true, index = 1 }
    function self:update()
      local input = game.input
      local n = #entries
      if n == 0 or not input then return end
      if input:wasPressed("b") or input:wasPressed("start") then game.stack:pop() return end
      if input:wasPressed("up") then self.index = (self.index - 2) % n + 1
      elseif input:wasPressed("down") then self.index = self.index % n + 1
      elseif input:wasPressed("a") or input:wasPressed("right") then
        local picked = entries[self.index]
        if picked and type(picked.open) == "function" then picked.open(game) end
      end
    end
    function self:draw()
      Font.drawBox(0, 0, 20, 12)
      Font.draw("PRISM", 8, 8)
      for i, e in ipairs(entries) do
        local y = i * 24
        if i == self.index then
          if Theme and Theme.cursor and Font.drawCode then Font.drawCode(Theme.cursor, 8, y)
          else Font.draw(">", 8, y) end
        end
        Font.draw(cut(e.label, 16), 16, y)
        Font.draw(cut(valueOf(e), 15), 32, y + 8)
      end
      Font.drawBox(0, 12, 20, 6)
      local picked = entries[self.index]
      for i, line in ipairs(wrap(picked and picked.about, 18)) do
        if i <= 4 then Font.draw(line, 8, 104 + (i - 1) * 8) end
      end
    end
    game.stack:push(self)
  end

  return P
end

-- The list screen for the running game. A Game Boy game's needs the
-- mod's own `mod` for the game's font. -Elvie
function prism.picker(mod)
  if generation() ~= 3 then return gbPicker(mod) end
  return gen3Picker()
end

-- START menu: add `entry` to the PRISM item (making it, just above MODS
-- or EXIT/QUIT, if it isn't there). Returns the new list. -Elvie
function prism.addStart(items, entry, picker, game)
  local out, found = {}, nil
  for i, item in ipairs(items) do
    out[i] = item
    if type(item) == "table" and item.id == ID and type(item.entries) == "table" then found = i end
  end
  local entries = withEntry(found and out[found].entries, entry)
  -- Crystal's description box under the START menu -Elvie
  local item = { id = ID, entries = entries, desc = { "Change", "the looks" } }
  if #entries == 1 then
    item.label = entry.short or entry.label
    item.onSelect = function(g) entry.open(g or game) end
  else
    item.label = "PRISM"
    item.onSelect = function(g) picker.open(g or game, entries) end
  end
  if found then
    out[found] = item
    return out
  end
  local at
  -- Gen 1's items have no ids, only labels -Elvie
  local mods, last
  for i, it in ipairs(out) do
    if type(it) == "table" then
      if it.id == "mods" or it.label == "MODS" then mods = mods or i end
      if it.id == "exit" or it.id == "quit" or it.label == "QUIT" then last = last or i end
    end
  end
  at = mods or last
  if not at then return items end
  table.insert(out, at, item)
  return out
end

-- OPTION menu: the same, as a row at the end. One mod: its label and its
-- value (the character, the NPC set); more: PRISM. -Elvie
function prism.addOption(rows, entry, picker, game)
  local out, found = {}, nil
  for i, row in ipairs(rows) do
    out[i] = row
    if type(row) == "table" and row.id == ID and type(row.entries) == "table" then found = i end
  end
  local entries = withEntry(found and out[found].entries, entry)
  local row = { id = ID, entries = entries }
  if #entries == 1 then
    row.label = entry.label
    row.value = function() return valueOf(entry) end
    row.activate = function(g) entry.open(g or game) end
  else
    row.label = "PRISM"
    row.value = function() return "" end
    row.activate = function(g) picker.open(g or game, entries) end
  end
  if found then
    out[found] = row
    return out
  end
  -- just before BACK on the Game Boy games, where a mod's rows go -Elvie
  local at = #out + 1
  for i, r in ipairs(out) do if type(r) == "table" and r.cancel then at = i break end end
  table.insert(out, at, row)
  return out
end

return prism
