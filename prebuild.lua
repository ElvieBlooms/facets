-- PREBUILD
-- Facets makes most pictures the first time they're needed: a GB EMERALD
-- Pokémon is built from Emerald's pictures, a GBC NPC from a Gen 1/2
-- sprite. On a fast machine that's a few milliseconds; on a small board
-- or handheld it's a hitch when a battle starts or a new NPC walks on.
-- With PREBUILD on, everything the chosen sets need is built while you
-- play, a few milliseconds a frame starting at the title screen, so it's
-- all ready before it's needed. Anything needed sooner is built then, as
-- usual. -Elvie
--
-- What's built is also kept on the install (diskcache.lua), so the next
-- start reads it back instead of building it again. -Elvie
--
-- Parts hand in their work with prebuild.provide(name, fn, when): fn
-- returns a list of functions, each building one picture, and when is
-- "start" (the title screen) or "map" (once the overworld is loaded,
-- for NPCs). -Elvie
-- --------------------------------------------------
local prebuild = {}

local OFF = "__off"
prebuild.CHOICES = { { "OFF", OFF }, { "ON", "on" } }
-- How long each frame may spend building. One picture is always built,
-- even if it takes longer. -Elvie
prebuild.BUDGET = 0.003
-- BUILD NOW: as much a frame as still lets the progress bar move -Elvie
prebuild.FORCE_BUDGET = 0.03

local providers = {} -- { name, fn, when }, in the order handed in
function prebuild.provide(name, fn, when)
  for _, p in ipairs(providers) do
    if p.name == name then p.fn, p.when = fn, when or "start"; return end
  end
  providers[#providers + 1] = { name = name, fn = fn, when = when or "start" }
end

-- For the tests: forget every provider. -Elvie
function prebuild.reset()
  providers = {}
end

-- A runner: queue(stages) fills the work list from the providers whose
-- stage has come, step(clock) does a frame's share. -Elvie
function prebuild.runner(log)
  local R = { queue = {}, done = 0, total = 0, stages = {} }
  function R.fill()
    R.queue, R.done, R.total = {}, 0, 0
    for _, p in ipairs(providers) do
      if R.stages[p.when] then
        local ok, units = pcall(p.fn)
        if ok and type(units) == "table" then
          for _, u in ipairs(units) do R.queue[#R.queue + 1] = u end
        elseif not ok and log then
          log:warn("PREBUILD %s: %s", p.name, tostring(units))
        end
      end
    end
    R.total = #R.queue
  end
  function R.reach(stage)
    if R.stages[stage] then return end
    R.stages[stage] = true
    R.fill()
  end
  function R.step(clock, budget)
    if R.done >= R.total then return false end
    local start = clock()
    repeat
      R.done = R.done + 1
      local unit = R.queue[R.done]
      R.queue[R.done] = nil
      local ok, err = pcall(unit)
      if not ok and log then log:warn("PREBUILD: %s", tostring(err)) end
    until R.done >= R.total or clock() - start >= (budget or prebuild.BUDGET)
    return true
  end
  function R.finished() return R.done >= R.total end
  return R
end

function prebuild.init(mod, rows)
  rows[#rows + 1] = { key = "sectionSpeed", type = "choice", label = "SPEED",
    choices = { { "", "_" } }, default = "_" }
  rows[#rows + 1] = { key = "prebuild", type = "choice", label = "  PREBUILD",
    choices = prebuild.CHOICES, default = OFF }

  return function()
    local runner = prebuild.runner(mod.log)
    prebuild.current = runner
    local dirty = false
    local function on() return mod.options:get("prebuild") == "on" end

    -- The install cache: what was built is kept, under a stamp of
    -- Facets', the engine's and each imported game's versions. -Elvie
    local disk = require("mods.facets.diskcache")
    local function markers()
      local out = {}
      local okC, Contract = pcall(require, "src.import.CacheContract")
      -- every game Facets reads, whichever is running, so switching
      -- games keeps each one's pictures -Elvie
      local games = { "firered", "leafgreen", "ruby", "sapphire", "emerald" }
      for _, g in ipairs(require("mods.facets.gb").GAMES) do games[#games + 1] = g end
      for _, g in ipairs(games) do
        local marker = okC and type(Contract) == "table" and type(Contract.readMarker) == "function"
          and select(2, pcall(Contract.readMarker, g)) or nil
        out[g] = type(marker) == "string" and marker or "none"
      end
      return out
    end
    local okV, Version = pcall(require, "src.core.Version")
    local engine = okV and type(Version) == "table" and (tostring(Version.engine) .. " " .. tostring(Version.cache)) or "?"
    local ready = false
    local function setUp()
      if ready then return end
      ready = true
      disk.setup(mod.cache, disk.stampText(mod.version, engine, markers()), mod.log)
    end
    local function applyDisk()
      if on() then setUp() end
      disk.enable(on())
    end
    applyDisk()
    local function flush()
      if disk.enabled() and disk.dirty() then disk.flush() end
    end
    local function clock()
      return love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
    end
    local forcing = false
    if mod.hooks and type(mod.hooks.wrap) == "function" then
      mod.hooks:wrap("input.step", function(nextFn, ...)
        if on() then
          -- after any setting changed: the parts have reset their
          -- pictures by now, so the list is made again -Elvie
          if dirty then dirty = false; runner.fill() end
          -- all built: written to the install in one go -Elvie
          if runner.step(clock, forcing and prebuild.FORCE_BUDGET or prebuild.BUDGET) and runner.finished() then
            forcing = false
            flush()
          end
        end
        return nextFn(...)
      end)
    end

    -- For the PERFORMANCE screen -Elvie
    -- where it's got to: on, building (BUILD NOW running), done, total,
    -- kept (written to the install) -Elvie
    function prebuild.status()
      return { on = on(), forcing = forcing, done = runner.done, total = runner.total,
        finished = runner.finished(), kept = disk.enabled() and not disk.dirty() }
    end
    -- BUILD NOW: everything at once, a big share every frame. set turns
    -- PREBUILD on the way the screen sets options. -Elvie
    function prebuild.force(set)
      if not on() and type(set) == "function" then set("prebuild", "on") end
      applyDisk()
      runner.reach("start")
      runner.reach("map")
      if dirty then dirty = false end
      runner.fill()
      forcing = true
    end
    -- CLEAR: the kept pictures deleted, to be built and kept again next
    -- start (the ones loaded now stay) -Elvie
    function prebuild.clearKept()
      setUp()
      return disk.clear()
    end
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("game.ready", function() runner.reach("start") end)
      mod.events:on("map.entered", function() runner.reach("map"); flush() end)
      -- pictures built as they were needed get kept too -Elvie
      mod.events:on("battle.ended", flush)
      mod.events:on("save.writing", flush)
      mod.events:on("mod.options_changed", function(change)
        if type(change) == "table" and change.mod == mod.id then
          dirty = true
          if change.key == "prebuild" then applyDisk() end
        end
      end)
    end
  end
end

-- The PERFORMANCE screen
-- Its own screen (screen.lua, built like FACETS) and its own PRISM entry,
-- since the FACETS screen has no room for more rows: PREBUILD, BUILD NOW
-- (everything at once, with a progress bar) and CLEAR (delete what's
-- kept). menu.lua opens it. -Elvie
-- --------------------------------------------------
prebuild.COLOUR = { 196, 132, 30 } -- topaz -Elvie
local BAR_X0, BAR_X1, BAR_Y, BAR_H = 16, 224, 128, 8

local function status()
  if type(prebuild.status) == "function" then
    local ok, st = pcall(prebuild.status)
    if ok and type(st) == "table" then return st end
  end
  return { on = false, forcing = false, done = 0, total = 0, finished = true, kept = false }
end
prebuild.safeStatus = status

-- How far along, 0-100 -Elvie
function prebuild.percent(st)
  st = st or status()
  if (st.total or 0) <= 0 then return st.on and 100 or 0 end
  return math.floor(math.min(st.done, st.total) * 100 / st.total)
end

-- The line over the bar -Elvie
function prebuild.progressText(st)
  st = st or status()
  if st.forcing then return ("BUILDING  %d / %d"):format(math.min(st.done, st.total), st.total) end
  if not st.on then return "PREBUILD is OFF." end
  if not st.finished then return ("BUILDING  %d / %d"):format(math.min(st.done, st.total), st.total) end
  return st.kept and "ALL READY, KEPT." or "ALL READY."
end

-- A progress bar in area { x0, y0, x1 } (y0 its top), drawn with plain
-- rectangles in the screen's colours. -Elvie
function prebuild.drawBar(x0, y, x1, h, pct, colour)
  if not (love and love.graphics) then return end
  local c = colour or prebuild.COLOUR
  love.graphics.setColor(0.25, 0.25, 0.3, 1)
  love.graphics.rectangle("fill", x0, y, x1 - x0, h)
  love.graphics.setColor(0.93, 0.93, 0.9, 1)
  love.graphics.rectangle("fill", x0 + 1, y + 1, x1 - x0 - 2, h - 2)
  local w = math.floor((x1 - x0 - 2) * math.max(0, math.min(100, pct)) / 100)
  if w > 0 then
    love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
    love.graphics.rectangle("fill", x0 + 1, y + 1, w, h - 2)
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.rectangle("fill", x0 + 1, y + 1, w, 1)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- set(game, key, value): menu.lua's, so changes save like the mod
-- options do. -Elvie
function prebuild.model(mod, set)
  local M = { layer = "facets_performance" }
  local cleared = false
  function M.title() return "PERFORMANCE" end
  function M.set(game, key, value) return set(game, key, value) end
  function M.rows()
    local st = status()
    local build = st.forcing and "BUILDING" or (st.on and st.finished and st.total > 0) and "DONE" or "START"
    return {
      { key = "prebuild", label = "PREBUILD", who = "prebuild", choices = prebuild.CHOICES,
        value = st.on and "on" or OFF, valueLabel = st.on and "ON" or "OFF" },
      { key = "buildNow", label = "BUILD NOW", who = "build", valueLabel = build,
        action = function(game)
          cleared = false
          prebuild.force(function(k, v) set(game, k, v) end)
        end },
      { key = "clearKept", label = "KEPT", who = "kept", valueLabel = cleared and "CLEARED" or "CLEAR",
        action = function()
          if type(prebuild.clearKept) == "function" then cleared = prebuild.clearKept() and true or false end
        end },
    }
  end
  function M.preview(who)
    local st = status()
    if who == "prebuild" then
      if st.on then return { lines = { { text = "Built ahead in the background," }, { text = "and kept on your install." } } } end
      return { lines = { { text = "Built the first time they're" }, { text = "needed, every start." } } }
    elseif who == "build" then
      local lines = { { text = "Builds everything now." } }
      if not st.on then lines[2] = { text = "Turns PREBUILD on." } end
      return { lines = lines }
    elseif who == "kept" then
      if cleared then return { lines = { { text = "Deleted. Built and kept" }, { text = "again next start." } } } end
      return { lines = { { text = "Deletes the kept pictures," }, { text = "to build them fresh." } } }
    end
    return { lines = {} }
  end
  function M.draw()
    local st = status()
    local okW, Window = pcall(require, "src.ui.game3.window")
    local okF, FrlgFont = pcall(require, "src.ui.game3.frlg_font")
    if okW and okF and type(Window) == "table" and type(FrlgFont) == "table" then
      pcall(Window.printPx, prebuild.progressText(st), BAR_X0, BAR_Y - 14, { colors = FrlgFont.COLOR.NORMAL })
    end
    prebuild.drawBar(BAR_X0, BAR_Y, BAR_X1, BAR_H, prebuild.percent(st))
  end
  function M.credits() return {} end
  -- PRISM's corner: the bar, big, on the faceted panel -Elvie
  function M.drawPreview(area)
    if type(area) ~= "table" then return end
    local st = status()
    local y = math.floor((area.y0 + area.y1) / 2) - 4
    prebuild.drawBar(area.x0 + 30, y, area.x1 - 10, 9, prebuild.percent(st))
  end
  function M.value()
    local st = status()
    if st.forcing or (st.on and not st.finished) then return prebuild.percent(st) .. "%" end
    return st.on and "ON" or "OFF"
  end
  return M
end

return prebuild
