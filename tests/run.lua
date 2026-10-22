-- Facets headless tests
-- Runs the mod against the engine's real ow_sprites.lua and graphics id
-- tables, with love, the mod API and the sprite cache stubbed. -Elvie
--
--   GEN1RECOMP_SRC=<unzipped .love> GEN1RECOMP_DATA=<game data folder> lua tests/run.lua
--
-- GEN1RECOMP_DATA is the folder holding firered/, ruby/, emerald/ (the
-- install folder); it's read for sprite sizes only. Needs lfs
-- (texlua has it built in, or luarocks install luafilesystem).

local lfs = require("lfs")
local ROOT = (arg[0]:match("^(.*)/tests/[^/]*$") or ".")
local SRC = assert(os.getenv("GEN1RECOMP_SRC"), "set GEN1RECOMP_SRC to an unzipped gen1recomp .love")
local DATA = assert(os.getenv("GEN1RECOMP_DATA"), "set GEN1RECOMP_DATA to the install folder")
local OUT = ROOT .. "/tests/out"

-- Module loading: mods.facets.* from this folder, src.* from the engine.
-- The engine modules ow_sprites needs to stream from the cache are stubbed. -Elvie
-- --------------------------------------------------
package.path = SRC .. "/?.lua;" .. package.path
local searchers = package.searchers or package.loaders
table.insert(searchers, 2, function(name)
  local rest = name:match("^mods%.facets%.(.+)$")
  if not rest then return nil end
  local path = ROOT .. "/" .. rest:gsub("%.", "/") .. ".lua"
  local f = io.open(path)
  if not f then return "\n\tno file " .. path end
  f:close()
  return assert(loadfile(path))
end)

local currentVersion = "firered"
local LAYOUT = { firered = "frlg", leafgreen = "frlg", ruby = "rse", sapphire = "rse", emerald = "rse" }
package.preload["src.core.GameVersion"] = function()
  return {
    get = function() return currentVersion end,
    layout = function(v) return LAYOUT[v] end,
  }
end
package.preload["src.import.gba.extract_island1"] = function() return { CACHE_ROOT = "x" } end
package.preload["src.import.gba.ow_extract"] = function() return { ready = function() return true end } end
package.preload["src.import.gba.versions"] = function() return { OW_RENDER = true } end
package.preload["src.core.game3.asset_stream"] = function()
  return { new = function() return { get = function() return nil end, prefetch = function() end, cancel = function() end } end }
end

-- love stubs: PNG sizes are read from the file header. -Elvie
-- --------------------------------------------------
local function pngSize(path)
  local f = assert(io.open(path, "rb"))
  local head = f:read(24)
  f:close()
  assert(head and head:sub(2, 4) == "PNG", path .. " isn't a PNG")
  local function u32(i)
    local a, b, c, d = head:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end
love = {
  image = {
    newImageData = function(path)
      local w, h = pngSize(path)
      return { path = path, getDimensions = function() return w, h end }
    end,
  },
  graphics = {
    newImage = function(data) return { data = data, setFilter = function() end } end,
    newQuad = function(x, y, w, h, sw, sh) return { x = x, y = y, w = w, h = h, sw = sw, sh = sh } end,
    setColor = function() end,
    draw = function(...) love.graphics.lastDraw = { ... } end,
  },
}

-- The game's own sprite records, sized from the cache manifest. -Elvie
local manifests = {}
local function vanillaRecords(version)
  local key = ({ leafgreen = "firered", sapphire = "ruby" })[version] or version
  if not manifests[key] then
    local f = assert(io.open(DATA .. "/" .. key .. "/data/generated/gba/ow/manifest.lua"))
    local m = load(f:read("a"), "manifest", "t", {})()
    f:close()
    manifests[key] = m.sprites
  end
  local out = {}
  for id, s in pairs(manifests[key]) do
    out[id] = { width = s.width, height = s.height, frameCount = s.frameCount,
      inanimate = s.inanimate, paletteSlot = 3, drawOffX = 0, drawOffY = 0, image = "vanilla" .. id }
  end
  return out
end

-- A mod object over a real folder, with options and events. -Elvie
-- --------------------------------------------------
local function newMod(root)
  local mod = { id = "facets", logs = {}, handlers = {} }
  mod.log = {
    warn = function(_, fmt, ...) table.insert(mod.logs, "warn: " .. fmt:format(...)) end,
    info = function(_, fmt, ...) table.insert(mod.logs, "info: " .. fmt:format(...)) end,
  }
  mod.assets = {
    info = function(_, rel)
      local a = lfs.attributes(root .. "/" .. rel)
      return a and { type = a.mode == "directory" and "directory" or "file" } or nil
    end,
    list = function(_, rel)
      local out = {}
      if lfs.attributes(root .. "/" .. rel, "mode") ~= "directory" then return out end
      for name in lfs.dir(root .. "/" .. rel) do
        if name ~= "." and name ~= ".." then out[#out + 1] = name end
      end
      table.sort(out)
      return out
    end,
    path = function(_, rel) return root .. "/" .. rel end,
  }
  function mod.read(_, rel)
    local f = assert(io.open(root .. "/" .. rel))
    local s = f:read("a")
    f:close()
    return s
  end
  local values, rowsByKey = {}, {}
  mod.options = {
    define = function(_, rows)
      mod.rows = rows
      for _, row in ipairs(rows) do rowsByKey[row.key] = row end
    end,
    get = function(_, key)
      if values[key] ~= nil then return values[key] end
      return rowsByKey[key] and rowsByKey[key].default
    end,
    set = function(_, key, v)
      values[key] = v
      for _, h in ipairs(mod.handlers) do h({ mod = "facets", key = key, value = v }) end
    end,
  }
  mod.events = { on = function(_, name, fn) if name == "mod.options_changed" then table.insert(mod.handlers, fn) end end }
  return mod
end

-- Fresh engine and mod modules for each scenario. -Elvie
local function fresh(version)
  currentVersion = version
  for name in pairs(package.loaded) do
    if name:match("^mods%.facets") or name:match("^src%.core%.game3%.ow_sprites")
        or name == "src.core.game3.constants" then
      package.loaded[name] = nil
    end
  end
  local Ow = require("src.core.game3.ow_sprites")
  Ow._loaded = vanillaRecords(version)
  Ow._manifestAttempted = true
  return Ow
end

-- Test folders
-- --------------------------------------------------
local function sh(cmd) assert(os.execute(cmd)) end
local function copy(from, to)
  sh(("mkdir -p '%s' && cp '%s' '%s'"):format(to:match("^(.*)/"), from, to))
end
local TF = ROOT .. "/assets/npcs/test_frames/gen3/"
sh("rm -rf '" .. OUT .. "' && mkdir -p '" .. OUT .. "'")

-- A: the mod as shipped (test_frames only)
local MOD_A = ROOT
-- B: two sets: "aaa" (selected, label AAA) has a badly sized LASS and
-- the player and rival's files; "zzz" has NURSE for the fallback. -Elvie
local MOD_B = OUT .. "/modB"
copy(TF .. "frlg/YOUNGSTER.png", MOD_B .. "/assets/npcs/aaa/gen3/frlg/RED_NORMAL.png")
copy(TF .. "frlg/YOUNGSTER.png", MOD_B .. "/assets/npcs/aaa/gen3/frlg/BLUE.png")
copy(TF .. "frlg/YOUNGSTER.png", MOD_B .. "/assets/npcs/aaa/gen3/frlg/rs_brendan.png")
copy(TF .. "frlg/BROCK.png", MOD_B .. "/assets/npcs/aaa/gen3/frlg/Lass.png")
copy(TF .. "frlg/NURSE.png", MOD_B .. "/assets/npcs/aaa/gen3/frlg/ITEM_BALL.png")
copy(TF .. "frlg/NURSE.png", MOD_B .. "/assets/npcs/zzz/gen3/frlg/NURSE.png")
copy(TF .. "rse/YOUNGSTER.png", MOD_B .. "/assets/npcs/aaa/gen3/rse/BRENDAN_NORMAL.png")
copy(TF .. "rse/YOUNGSTER.png", MOD_B .. "/assets/npcs/aaa/gen3/rse/RIVAL_MAY_NORMAL.png")
copy(TF .. "rse/YOUNGSTER.png", MOD_B .. "/assets/npcs/aaa/gen3/rse/LINK_BRENDAN.png")
do
  local f = io.open(MOD_B .. "/assets/npcs/aaa/meta.json", "w"); f:write('{"label":"AAA"}'); f:close()
  f = io.open(MOD_B .. "/assets/npcs/zzz/meta.json", "w"); f:write('{"label":"ZZZ"}'); f:close()
end

-- Assertions
-- --------------------------------------------------
local passed, failed = 0, 0
local function check(cond, what)
  if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. what) end
end
local function eq(a, b, what) check(a == b, ("%s (got %s, want %s)"):format(what, tostring(a), tostring(b))) end

local function initGen3(mod, setKeys)
  return require("mods.facets.gen3").init(mod, setKeys and { setKeys = setKeys, npcsDir = "assets/npcs" } or nil)
end

-- FireRed
-- --------------------------------------------------
do
  local Ow = fresh("firered")
  local vanilla = {}
  for id, r in pairs(Ow._loaded) do vanilla[id] = r end
  local mod = newMod(MOD_A)
  local h = initGen3(mod, { "test_frames" })
  check(h ~= nil, "frlg: init returns a handle")
  eq(h.family, "frlg", "frlg: family")

  local nurse = Ow.get(64)
  check(nurse ~= vanilla[64], "frlg: NURSE (64) replaced")
  eq(nurse.width, 32, "frlg: NURSE width"); eq(nurse.height, 32, "frlg: NURSE height")
  eq(nurse.frameCount, 10, "frlg: NURSE keeps 10 frames")
  eq(nurse.paletteSlot, 3, "frlg: NURSE keeps paletteSlot")
  eq(#nurse.quads, 9, "frlg: NURSE quads 0..9"); eq(nurse.quads[9].y, 9 * 32, "frlg: NURSE quad 9 offset")
  eq(Ow.get(64), nurse, "frlg: NURSE built once")
  eq((Ow.pose(nurse, "down", 0, false, { bow = true })), 9, "frlg: NURSE bows on frame 9")

  local young = Ow.get(18)
  eq(young.frameCount, 9, "frlg: YOUNGSTER 9 frames")
  eq((Ow.pose(young, "down", 0, false, { bow = true })), 0, "frlg: YOUNGSTER hand raise falls back to standing")
  eq((Ow.pose(vanilla[18], "down", 0, false, { bow = true })), 9, "frlg: game's YOUNGSTER raises on frame 9")
  local f, flip = Ow.pose(young, "right", 1, true, {})
  eq(f, 7, "frlg: YOUNGSTER walking right uses the left frames"); eq(flip, true, "frlg: ...mirrored")

  local kid = Ow.get(16)
  eq(vanilla[16].height, 16, "frlg: game's LITTLE_BOY is 16 tall")
  eq(kid.width, 32, "frlg: LITTLE_BOY 32 wide"); eq(kid.height, 32, "frlg: LITTLE_BOY 32 tall")

  local brock = Ow.get(80)
  check(brock ~= vanilla[80], "frlg: BROCK replaced")
  eq(brock.width, 16, "frlg: BROCK same size"); eq(brock.frameCount, 9, "frlg: BROCK 9 frames")
  local bug = Ow.get(20)
  eq(bug.width, 16, "frlg: BUG_CATCHER same size"); eq(bug.frameCount, 10, "frlg: BUG_CATCHER keeps the hand raise")
  eq((Ow.pose(bug, "down", 0, false, { bow = true })), 9, "frlg: BUG_CATCHER raises on frame 9")

  eq(Ow.get(22), vanilla[22], "frlg: LASS untouched (no file)")
  eq(Ow.get(0), vanilla[0], "frlg: player untouched")
  eq(Ow.get(9999), nil, "frlg: unknown id still nil")
  eq(Ow.getDraw(64), nurse, "frlg: getDraw goes through the wrap")
  eq(Ow.draw(64, 48, 32, 0, 0, "down", 0, false, {}), true, "frlg: draw runs")
  local d = love.graphics.lastDraw
  eq(d[1], nurse.image, "frlg: draw uses our image")
  eq(d[3], 48 + (16 - 32) / 2, "frlg: 32-wide frame centred on the tile")
  eq(d[4], 32 + 16 - 32, "frlg: feet on the tile's bottom edge")

  -- turning it off
  Ow._reflectionLoaded[64] = "stale"
  Ow._reflectionLoaded[22] = "keep"
  h.configure(nil)
  eq(Ow.get(64), vanilla[64], "frlg: OFF gives the game's NURSE")
  eq(Ow._reflectionLoaded[64], nil, "frlg: OFF drops NURSE's reflection cache")
  eq(Ow._reflectionLoaded[22], "keep", "frlg: OFF leaves other reflection caches")
  h.configure({ setKeys = { "test_frames" }, npcsDir = "assets/npcs" })
  check(Ow.get(64) ~= vanilla[64], "frlg: back ON replaces NURSE again")
  eq(#mod.logs, 0, "frlg: nothing logged for good files")
end

-- Skip list, wrong sizes, fallback chain
-- --------------------------------------------------
do
  local Ow = fresh("firered")
  local vanilla = {}
  for id, r in pairs(Ow._loaded) do vanilla[id] = r end
  local mod = newMod(MOD_B)
  initGen3(mod, { "aaa", "zzz" })
  eq(Ow.get(0), vanilla[0], "skip: RED_NORMAL never replaced")
  eq(Ow.get(72), vanilla[72], "skip: BLUE never replaced")
  eq(Ow.get(14), vanilla[14], "skip: RS_BRENDAN never replaced (any case)")
  check(Ow.get(64) ~= vanilla[64], "chain: NURSE comes from the second set")
  eq(Ow.get(64).image.data.path:match("/(zzz)/"), "zzz", "chain: ...from zzz")
  eq(Ow.get(92), vanilla[92], "size: ITEM_BALL (inanimate) not replaced")
  Ow.get(92); Ow.get(92)
  local warns = 0
  for _, l in ipairs(mod.logs) do if l:match("ITEM_BALL") then warns = warns + 1 end end
  eq(warns, 1, "size: refusal logged once")
  check(Ow.get(22) ~= vanilla[22], "case: Lass.png matches LASS")
end

-- A wrong-size file
do
  local Ow = fresh("firered")
  local vanilla = Ow._loaded[18]
  local MOD_C = OUT .. "/modC"
  copy(TF .. "frlg/NURSE.png", MOD_C .. "/assets/npcs/c/gen3/frlg/LITTLE_BOY.png") -- 10 frames over a 9-frame sprite
  copy(ROOT .. "/tests/run.lua", MOD_C .. "/assets/npcs/c/gen3/frlg/notes.txt")
  copy(TF .. "frlg/BUG_CATCHER.png", MOD_C .. "/assets/npcs/c/gen3/frlg/YOUNGSTER.png")
  local mod = newMod(MOD_C)
  initGen3(mod, { "c" })
  eq(Ow.get(16), Ow._loaded[16], "size: 10 frames over a 9-frame sprite refused")
  eq(Ow.get(18).frameCount, 10, "size: 16x32x10 over YOUNGSTER accepted")
  check(vanilla ~= Ow.get(18), "size: YOUNGSTER replaced")
  local found = false
  for _, l in ipairs(mod.logs) do found = found or l:match("LITTLE_BOY%.png is 32x320") ~= nil end
  check(found, "size: the refusal names the file and size")
end

-- Stacking with an Emerald Lens-style wrapper, both orders
-- --------------------------------------------------
for _, order in ipairs({ "lens first", "facets first" }) do
  local Ow = fresh("firered")
  local vanilla = {}
  for id, r in pairs(Ow._loaded) do vanilla[id] = r end
  local mine = { width = 16, height = 32, frameCount = 20, image = "lens" }
  local function lens()
    local orig = Ow.get
    Ow.get = function(id) if tonumber(id) == 0 then return mine end return orig(id) end
  end
  if order == "lens first" then lens() end
  initGen3(newMod(MOD_A), { "test_frames" })
  if order == "facets first" then lens() end
  eq(Ow.get(0), mine, order .. ": player from the lens")
  check(Ow.get(64) ~= vanilla[64] and Ow.get(64).width == 32, order .. ": NURSE from Facets")
  eq(Ow.get(22), vanilla[22], order .. ": LASS from the game")
end

-- Ruby, Sapphire, Emerald
-- --------------------------------------------------
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local Ow = fresh(version)
  local vanilla = {}
  for id, r in pairs(Ow._loaded) do vanilla[id] = r end
  local h = initGen3(newMod(MOD_A), { "test_frames" })
  eq(h.family, "rse", version .. ": family")
  local nurse = Ow.get(58)
  eq(nurse.frameCount, 10, version .. ": NURSE (58) 10 frames")
  -- id 15 is BOY_4 in Ruby/Sapphire and RICH_BOY in Emerald: one file
  check(Ow.get(15) ~= vanilla[15], version .. ": id 15 replaced from RICH_BOY.png")
  eq(Ow.get(15).width, 32, version .. ": id 15 is 32 wide")
  eq(Ow.get(0), vanilla[0], version .. ": Brendan untouched")
end
do
  local Ow = fresh("emerald")
  local vanilla = {}
  for id, r in pairs(Ow._loaded) do vanilla[id] = r end
  initGen3(newMod(MOD_B), { "aaa" })
  eq(Ow.get(0), vanilla[0], "emerald skip: BRENDAN_NORMAL")
  eq(Ow.get(105), vanilla[105], "emerald skip: RIVAL_MAY_NORMAL")
  eq(Ow.get(216), vanilla[216], "emerald skip: LINK_BRENDAN")
end

-- npcs.lua: sets, options rows, live switching
-- --------------------------------------------------
do
  local Ow = fresh("firered")
  local vanilla = {}
  for id, r in pairs(Ow._loaded) do vanilla[id] = r end
  local mod = newMod(MOD_B)
  require("mods.facets.npcs").init(mod)
  local keys = {}
  for _, row in ipairs(mod.rows) do keys[#keys + 1] = row.key end
  eq(table.concat(keys, ","), "sectionFrlg,setFrlg,sectionRse,setRse", "options: rows")
  eq(mod.rows[2].default, "aaa", "options: first set by label is the default")
  eq(mod.rows[2].choices[#mod.rows[2].choices][1], "OFF", "options: OFF is last")
  check(Ow.get(64) ~= vanilla[64], "options: NURSE replaced through the chain")
  mod.options:set("setFrlg", "__off")
  eq(Ow.get(64), vanilla[64], "options: OFF applies live")
  mod.options:set("setFrlg", "zzz")
  check(Ow.get(64) ~= vanilla[64], "options: ZZZ applies live")
  check(Ow.get(22) ~= vanilla[22], "options: ZZZ selected, AAA still fills LASS")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
