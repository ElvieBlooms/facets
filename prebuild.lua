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
    if mod.hooks and type(mod.hooks.wrap) == "function" then
      mod.hooks:wrap("input.step", function(nextFn, ...)
        if on() then
          -- after any setting changed: the parts have reset their
          -- pictures by now, so the list is made again -Elvie
          if dirty then dirty = false; runner.fill() end
          -- all built: written to the install in one go -Elvie
          if runner.step(clock) and runner.finished() then flush() end
        end
        return nextFn(...)
      end)
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

return prebuild
