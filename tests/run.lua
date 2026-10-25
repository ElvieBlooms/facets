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
-- Pixel ImageData for Game Boy sheets (no PNG decoding headless: the
-- cached Game Boy sprites are fixtures below, handed out by a CacheFs stub). -Elvie
local function pixelData(w, h)
  local px = {}
  return {
    getDimensions = function() return w, h end,
    getPixel = function(_, x, y) local p = px[y * w + x] or { 0, 0, 0, 0 }; return p[1], p[2], p[3], p[4] end,
    setPixel = function(_, x, y, r, g, b, a)
      assert(x >= 0 and x < w and y >= 0 and y < h, ("setPixel %d,%d outside %dx%d"):format(x, y, w, h))
      px[y * w + x] = { r, g, b, a }
    end,
  }
end
-- A 16x96 strip of 6 frames: frame f (0-5) has a black pixel at (f, 15)
-- and a skin pixel (grey 170) at (15, f); the rest is white (see-through). -Elvie
local function gbStrip(frames, drawn)
  local d = pixelData(16, 16 * frames)
  for y = 0, 16 * frames - 1 do for x = 0, 15 do d:setPixel(x, y, 1, 1, 1, 1) end end
  for f = 0, (drawn or frames) - 1 do
    d:setPixel(f, f * 16 + 15, 0, 0, 0, 1)
    d:setPixel(15, f * 16 + f, 170 / 255, 170 / 255, 170 / 255, 1)
  end
  return d
end
local GB_FILES = {
  ["crystal/assets/generated/sprites/gbnurse.png"] = function() return gbStrip(3) end,
  ["red/assets/generated/sprites/gbkid.png"] = function() return gbStrip(6) end,
  ["crystal/assets/generated/sprites/gbbiker.png"] = function() return gbStrip(6) end,
  ["crystal/assets/generated/sprites/gbcaptain.png"] = function() return gbStrip(6, 3) end,
  ["red/assets/generated/sprites/gbyoung.png"] = function() return gbStrip(6) end,
  ["crystal/assets/generated/sprites/gbyoung.png"] = function() return gbStrip(6) end,
  ["crystal/assets/generated/icons/gen2/pikachu.png"] = function() return gbStrip(2) end,
  ["crystal/assets/generated/sprites/big_snorlax.png"] = function() return gbStrip(3) end,
}
-- Strips shipped in a set: the same layout in their own colours, with
-- alpha for see-through. Frame f has a red pixel at (f, 15). -Elvie
local function colourStrip(frames)
  local d = pixelData(16, 16 * frames)
  for f = 0, frames - 1 do d:setPixel(f, f * 16 + 15, 200 / 255, 10 / 255, 10 / 255, 1) end
  return d
end
STRIP_FILES = {
  SWIMMER = function() return colourStrip(6) end,
  SITTER = function() return colourStrip(3) end,
}
-- Text files from the install (Crystal's palettes.lua), as-is. -Elvie
local GB_TEXT = {}
package.preload["src.import.CacheFs"] = function()
  return { readAt = function(rel)
    if GB_TEXT[rel] then return GB_TEXT[rel] end
    return GB_FILES[rel] and ("bytes:" .. rel) or nil
  end }
end
love = {
  data = { newByteData = function(str) return { bytes = str } end },
  image = {
    newImageData = function(a, b, fmt, bytes)
      if type(a) == "number" then
        local d = pixelData(a, b)
        -- raw RGBA bytes (Gen 3 .rgba pictures) -Elvie
        if type(bytes) == "string" then
          for i = 0, a * b - 1 do
            local r, g, bl, al = bytes:byte(i * 4 + 1, i * 4 + 4)
            if al and al > 0 then d:setPixel(i % a, math.floor(i / a), r / 255, g / 255, bl / 255, al == 255 and 1 or al / 255) end
          end
        end
        return d
      end
      if type(a) == "table" and a.bytes then
        local make = GB_FILES[a.bytes:sub(7)]
        assert(make, "no fixture for " .. a.bytes)
        return make()
      end
      local path = a
      if path:find("/assets/mons/", 1, true) then
        -- a Pokémon picture: its size from the header, one red pixel at (10, 40) -Elvie
        local w, h = pngSize(path)
        local d = pixelData(w, h)
        d:setPixel(10, 40, 1, 0, 0, 1)
        return d
      end
      local strip = path:match("/strips/([%w_]+)%.png$")
      if strip and STRIP_FILES[strip] then return STRIP_FILES[strip]() end
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
  mod.on = {}
  mod.events = { on = function(_, name, fn)
    if name == "mod.options_changed" then table.insert(mod.handlers, fn) end
    mod.on[name] = mod.on[name] or {}
    table.insert(mod.on[name], fn)
  end }
  function mod.fire(name, ...) for _, fn in ipairs(mod.on[name] or {}) do fn(...) end end
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
copy(TF .. "rse/YOUNGSTER.png", MOD_B .. "/assets/npcs/aaa/gen3/rse/LINK_RS_MAY.png")
copy(TF .. "rse/YOUNGSTER.png", MOD_B .. "/assets/npcs/aaa/gen3/rse/LINK_RECEPTIONIST.png")
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
  eq(Ow.get(236), vanilla[236], "emerald skip: LINK_RS_MAY")
  check(Ow.get(28) ~= vanilla[28], "emerald: LINK_RECEPTIONIST is an ordinary NPC")
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

-- A test set (TEST FRAMES) goes last, is never the default, and never
-- fills gaps in another set. -Elvie
do
  local Ow = fresh("firered")
  local vanilla = {}
  for id, r in pairs(Ow._loaded) do vanilla[id] = r end
  local MOD_D = OUT .. "/modD"
  copy(TF .. "frlg/NURSE.png", MOD_D .. "/assets/npcs/aaa_test/gen3/frlg/NURSE.png")
  copy(TF .. "frlg/YOUNGSTER.png", MOD_D .. "/assets/npcs/real/gen3/frlg/YOUNGSTER.png")
  local f = io.open(MOD_D .. "/assets/npcs/aaa_test/meta.json", "w"); f:write('{"label":"AAA TEST","test":true}'); f:close()
  f = io.open(MOD_D .. "/assets/npcs/real/meta.json", "w"); f:write('{"label":"REAL"}'); f:close()
  local mod = newMod(MOD_D)
  require("mods.facets.npcs").init(mod)
  local row = mod.rows[2]
  eq(row.default, "real", "test set: not the default, though its label sorts first")
  eq(row.choices[1][2], "real", "test set: real sets listed first")
  eq(row.choices[2][2], "aaa_test", "test set: listed after them")
  check(Ow.get(18) ~= vanilla[18], "test set: REAL's YOUNGSTER used")
  eq(Ow.get(64), vanilla[64], "test set: doesn't fill REAL's gaps")
  mod.options:set("setFrlg", "aaa_test")
  check(Ow.get(64) ~= vanilla[64], "test set: used when picked")
  check(Ow.get(18) ~= vanilla[18], "test set: real sets still fill its gaps")
end

-- Game Boy sets: sprites read from the player's install (gb.lua)
-- --------------------------------------------------
do
  local Ow = fresh("firered")
  local vanilla = {}
  for id, r in pairs(Ow._loaded) do vanilla[id] = r end
  local MOD_G = OUT .. "/modG"
  copy(TF .. "frlg/BROCK.png", MOD_G .. "/assets/npcs/real/gen3/frlg/LASS.png")
  sh(("mkdir -p '%s'"):format(MOD_G .. "/assets/npcs/gb"))
  local f = io.open(MOD_G .. "/assets/npcs/gb/meta.json", "w"); f:write('{"label":"AAA GB","source":"gb"}'); f:close()
  f = io.open(MOD_G .. "/assets/npcs/gb/gb.json", "w")
  f:write([[{"frlg": {"NURSE": {"sprite": "gbnurse", "palette": "PAL_OW_RED"},
    "YOUNGSTER": {"sprite": "gbyoung", "palette": "PAL_OW_BLUE"},
    "LITTLE_BOY": {"sprite": "gbkid", "palette": "PAL_OW_GREEN"},
    "BIKER": {"sprite": "gbbiker", "palette": "PAL_OW_BROWN"},
    "LASS": {"sprite": "nobody_has_this", "palette": "PAL_OW_RED"},
    "CAPTAIN": {"sprite": "gbcaptain", "palette": "PAL_OW_BROWN"},
    "SWIMMER_M_LAND": {"strip": "SWIMMER"},
    "SITTING_BOY": {"strip": "SITTER"},
    "WORKER_M": {"strip": "NOT_SHIPPED"},
    "PIKACHU": {"icon": "pikachu", "palette": "PAL_OW_RED"},
    "SNORLAX": {"sprite": "big_snorlax", "palette": "PAL_OW_BLUE", "big": true},
    "RED_NORMAL": {"sprite": "gbyoung", "palette": "PAL_OW_RED"}}}]]); f:close()
  sh(("mkdir -p '%s'"):format(MOD_G .. "/assets/npcs/gb/strips"))
  copy(TF .. "frlg/NURSE.png", MOD_G .. "/assets/npcs/gb/strips/SWIMMER.png")
  copy(TF .. "frlg/NURSE.png", MOD_G .. "/assets/npcs/gb/strips/SITTER.png")
  f = io.open(MOD_G .. "/assets/npcs/real/meta.json", "w"); f:write('{"label":"REAL"}'); f:close()
  sh(("mkdir -p '%s'"):format(MOD_G .. "/assets/npcs/gb2"))
  f = io.open(MOD_G .. "/assets/npcs/gb2/meta.json", "w"); f:write('{"label":"AAA GB 2X","source":"gb","scale":2,"map":"gb"}'); f:close()
  local mod = newMod(MOD_G)
  require("mods.facets.npcs").init(mod)
  eq(mod.rows[2].default, "gb", "gb: a Game Boy set is offered for FR/LG")
  local function px(spr, frame, x, y)
    local r, g, b, a = spr.imageData:getPixel(x, frame * spr.height + y)
    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), a
  end

  local nurse = Ow.get(64)
  check(nurse ~= vanilla[64], "gb: NURSE built from Crystal's sprite")
  eq(nurse.width, 16, "gb: NURSE 16 wide (the game's size)"); eq(nurse.height, 32, "gb: NURSE 32 tall")
  eq(nurse.frameCount, 9, "gb: 9 frames")
  local r, g, b = px(nurse, 0, 0, 30)
  eq(r + g + b, 0, "gb: black marker on the feet row (row 30)")
  r, g, b = px(nurse, 0, 15, 15)
  eq(("%d,%d,%d"):format(r, g, b), "255,156,82", "gb: grey 170 becomes Crystal's skin colour")
  local _, _, _, a0 = px(nurse, 0, 5, 20)
  eq(a0, 0, "gb: white is see-through")
  local r3, g3, b3, a3 = px(nurse, 3, 0, 29)
  local _, _, _, feet3 = px(nurse, 3, 0, 30)
  check(a3 == 1 and r3 + g3 + b3 == 0 and feet3 == 0, "gb: standing-only sprite: walk frames are the stand frames, a pixel up (a hop)")
  local _, _, _, still0 = px(nurse, 0, 0, 30)
  eq(still0, 1, "gb: ...and its standing frames stay on the feet row")

  local young = Ow.get(18)
  eq(young.imageData:getDimensions(), 16, "gb: YOUNGSTER built")
  r = px(young, 3, 3, 30); eq(r, 0, "gb: frame 3 is the walk-down frame")
  r = px(young, 4, 12, 30); eq(r, 0, "gb: frame 4 is the walk-down frame mirrored")
  -- both left steps are the walk-left frame (marker at x 5), not the stand
  -- frame (x 2), or every other step stands still -Elvie
  local _, _, _, a7 = px(young, 7, 5, 30)
  local _, _, _, a8 = px(young, 8, 5, 30)
  local _, _, _, s8 = px(young, 8, 2, 30)
  check(a7 == 1 and a8 == 1 and s8 == 0, "gb: frames 7 and 8 (walk left, both steps) are the walk-left frame")
  r, g, b = px(young, 0, 15, 15)
  eq(("%d,%d,%d"):format(r, g, b), "255,156,82", "gb: Crystal's copy used before Red's")

  local kid = Ow.get(16)
  eq(kid.height, 16, "gb: LITTLE_BOY stays 16x16"); r = px(kid, 0, 0, 15); eq(r, 0, "gb: 16x16 feet on row 15")
  local biker = Ow.get(53)
  eq(biker.width, 32, "gb: BIKER 32 wide"); r = px(biker, 0, 8, 30); eq(r, 0, "gb: centred in a 32-wide frame")

  local cap = Ow.get(63)
  local _, _, _, ca = px(cap, 3, 0, 29); eq(ca, 1, "gb: 6-frame strip with blank walk frames hops on its stand frames")

  check(Ow.get(22) ~= vanilla[22], "gb: LASS (not in any install) falls through to the next set")
  eq(Ow.get(22).image.data.path:match("/(real)/"), "real", "gb: ...REAL's sheet")
  eq(Ow.get(0), vanilla[0], "gb: the player is never replaced, even when mapped")
  eq(Ow.get(80), vanilla[80], "gb: unmapped BROCK is the game's own")
  -- Overworld Pokémon: a party icon, and a big doll -Elvie
  local pika = Ow.get(120)
  check(pika ~= vanilla[120], "gb: PIKACHU from Crystal's party icon")
  r = px(pika, 0, 0, 15); eq(r, 0, "icon: facing frames show the icon's first frame")
  r = px(pika, 3, 1, 15); eq(r, 0, "icon: walk steps show its second")
  local stepsOk = true
  for f = 3, 8 do if px(pika, f, 1, 15) ~= 0 then stepsOk = false end end
  check(stepsOk, "icon: every walk step (frames 3-8) shows its second frame, so each step bobs")
  r = px(pika, 1, 0, 15); eq(r, 0, "icon: no mirrored or turned frames")
  local lax = Ow.get(109)
  eq(lax.width .. "x" .. lax.height, "32x32", "big: SNORLAX 32x32")
  r = px(lax, 0, 0, 15); eq(r, 0, "big: left half as drawn")
  r = px(lax, 0, 31, 15); eq(r, 0, "big: right half mirrored")
  r = px(lax, 0, 30, 31); eq(r, 0, "big: both of its 16-row frames used")
  r = px(lax, 5, 31, 15); eq(r, 0, "big: the same picture in every frame")

  -- Strips: the set's own art, in its own colours -Elvie
  local idOf = {}
  for id, full in pairs(require("src.core.game3.constants").of("firered"):raw("event_objects").byId.OBJ_EVENT_GFX_) do
    idOf[full:sub(15)] = tonumber(id)
  end
  local swim = Ow.get(idOf.SWIMMER_M_LAND)
  check(swim ~= vanilla[idOf.SWIMMER_M_LAND], "strip: SWIMMER_M_LAND built from the set's strip")
  eq(swim.frameCount, 9, "strip: 9 frames")
  r, g, b = px(swim, 0, 0, 30)
  eq(("%d,%d,%d"):format(r, g, b), "200,10,10", "strip: own colour kept, feet on row 30")
  r = px(swim, 4, 12, 30); eq(r, 200, "strip: walk frames mirrored like Game Boy sprites")
  local _, _, _, sa = px(swim, 0, 5, 20); eq(sa, 0, "strip: alpha 0 is see-through")
  r = px(Ow.get(idOf.SITTING_BOY), 3, 0, 29); eq(r, 200, "strip: a 3-frame strip hops on its stand frames")
  eq(Ow.get(idOf.WORKER_M), vanilla[idOf.WORKER_M], "strip: a missing strip leaves the game's own")
  local warns = 0
  for _, l in ipairs(mod.logs) do
    if l:match("^warn") and not l:match("NOT_SHIPPED") then warns = warns + 1 end
  end
  eq(warns, 0, "gb: nothing else logged")

  -- 2x: the same map (borrowed), every pixel a 2x2 block, 32x32 frames -Elvie
  local labels = {}
  for _, c in ipairs(mod.rows[2].choices) do labels[#labels + 1] = c[2] end
  eq(table.concat(labels, ","), "gb,gb2,real,__off", "gb2: a 2x set with a borrowed map is offered")
  mod.options:set("setFrlg", "gb2")
  local n2 = Ow.get(64)
  eq(n2.width, 32, "gb2: NURSE 32 wide"); eq(n2.height, 32, "gb2: NURSE 32 tall"); eq(n2.frameCount, 9, "gb2: 9 frames")
  local ok2 = true
  for _, p in ipairs({ { 0, 30 }, { 1, 30 }, { 0, 31 }, { 1, 31 } }) do
    local rr, gg, bb, aa = px(n2, 0, p[1], p[2]); ok2 = ok2 and aa == 1 and rr + gg + bb == 0
  end
  check(ok2, "gb2: the black marker is a 2x2 block on the bottom rows")
  r, g, b = px(n2, 0, 30, 0)
  eq(("%d,%d,%d"):format(r, g, b), "255,156,82", "gb2: skin pixel scaled to the top-right corner")
  local k2 = Ow.get(16)
  eq(k2.width .. "x" .. k2.height, "32x32", "gb2: LITTLE_BOY 32x32 over the game's 16x16")
  local lax2 = Ow.get(109)
  eq(lax2.width .. "x" .. lax2.height, "32x32", "gb2: a big doll stays 1x (2x wouldn't fit)")
  r = px(lax2, 0, 31, 15); eq(r, 0, "gb2: ...drawn as at 1x")
  local b2 = Ow.get(53)
  eq(b2.width .. "x" .. b2.height, "32x32", "gb2: BIKER 32x32")
  r = px(Ow.get(18), 4, 24, 31); eq(r, 0, "gb2: mirrored walk frame scaled too")
  check(Ow.get(22) ~= vanilla[22], "gb2: LASS still falls through to the next set")
  mod.options:set("setFrlg", "real")
  eq(Ow.get(16), vanilla[16], "gb: a Game Boy set doesn't fill gaps when another set is picked")
  check(Ow.get(22) ~= vanilla[22], "gb: ...the picked set still works")
  mod.options:set("setFrlg", "gb2")
  local s2 = Ow.get(idOf.SWIMMER_M_LAND)
  eq(s2.width .. "x" .. s2.height, "32x32", "gb2: strips borrowed from the map's set, at 2x")
  r = px(s2, 0, 1, 31); eq(r, 200, "gb2: strip pixel a 2x2 block")
end

-- The repo's own sets: labels in the options, GBC 2X borrowing GBC's map -Elvie
do
  fresh("firered")
  local mod = newMod(ROOT)
  require("mods.facets.npcs").init(mod)
  local labels = {}
  for _, c in ipairs(mod.rows[2].choices) do labels[c[2]] = c[1] end
  if labels.gbc then
    eq(labels.gbc, "GBC", "shipped: GBC is offered")
    eq(labels.gbc_2x, "GBC 2X", "shipped: GBC 2X is offered (borrowing GBC's map)")
  end
  eq(mod.rows[2].choices[#mod.rows[2].choices - 1][1], "TEST FRAMES", "shipped: TEST FRAMES listed last")
end

-- Pokémon pictures (mons.lua)
-- --------------------------------------------------
do
  fresh("firered")
  -- Crystal-style battle sprite: w x w, see-through outside, a black pixel
  -- at the bottom-left, grey 170 at the top-right, inner white at (5,5). -Elvie
  local function battleSprite(w)
    local d = pixelData(w, w)
    d:setPixel(0, w - 1, 0, 0, 0, 1)
    d:setPixel(w - 1, 0, 170 / 255, 170 / 255, 170 / 255, 1)
    d:setPixel(5, 5, 1, 1, 1, 1)
    return d
  end
  local B = "assets/generated/battle/"
  GB_FILES["crystal/" .. B .. "front/charizard.png"] = function() return battleSprite(56) end
  GB_FILES["crystal/" .. B .. "back/charizard_back.png"] = function() return battleSprite(48) end
  -- Unown comes with no see-through pixels: a white square with a black dot -Elvie
  GB_FILES["crystal/" .. B .. "front/unown_c.png"] = function()
    local d = pixelData(40, 40)
    for y = 0, 39 do for x = 0, 39 do d:setPixel(x, y, 1, 1, 1, 1) end end
    d:setPixel(20, 39, 0, 0, 0, 1)
    return d
  end
  GB_FILES["gold/" .. B .. "front/pikachu.png"] = function() return battleSprite(40) end
  GB_FILES["crystal/" .. B .. "front/egg.png"] = function() return battleSprite(40) end
  GB_TEXT["crystal/data/generated/palettes.lua"] = table.concat({
    "return {", "  objects = {", "  },", "  pokemon = {",
    "    CHARIZARD = {", "      normal = {", "        {", "          200,", "          100,", "          50,", "        },",
    "        {", "          20,", "          40,", "          60,", "        },", "      },",
    "      shiny = {", "        {", "          1,", "          2,", "          3,", "        },",
    "        {", "          4,", "          5,", "          6,", "        },", "      },", "    },",
    "    PIKACHU = {", "      normal = {", "        {", "          255,", "          255,", "          0,", "        },",
    "        {", "          9,", "          9,", "          9,", "        },", "      },",
    "      shiny = {", "        {", "          7,", "          7,", "          7,", "        },",
    "        {", "          8,", "          8,", "          8,", "        },", "      },", "    },",
    "    UNOWN = {", "      normal = { { 10, 10, 10 }, { 11, 11, 11 } },", "      shiny = { { 12, 12, 12 }, { 13, 13, 13 } },", "    },",
    "    EGG = {", "      normal = { { 30, 30, 30 }, { 31, 31, 31 } },", "      shiny = { { 32, 32, 32 }, { 33, 33, 33 } },", "    },",
    "  },", "  roofs = {", "  },", "}" }, "\n")

  -- Engine stubs: the Pokemon module's two pic functions, Unown and the
  -- egg, pic offsets and Emerald's frame pics. -Elvie
  local calls = {}
  local Pokemon = {
    SPECIES_EGG = 412,
    frontPic = function(sp) calls[#calls + 1] = "front" .. tostring(sp); return { vanilla = "front" .. tostring(sp) } end,
    icon = function(sp) return { vanilla = "icon" .. tostring(sp) } end,
    backPic = function(sp) calls[#calls + 1] = "back" .. tostring(sp); return { vanilla = "back" .. tostring(sp) } end,
    picBaseSpecies = function(sp)
      if sp == 201 then return 201, 0 end
      if sp >= 413 and sp < 440 then return 201, sp - 412 end
      return sp, nil
    end,
    national = function(sp) if sp == 277 then return 252 end; return sp end,
    deoxysFormSuffix = function(sp) if sp == 386 and Pokemon_handled then return "_handled" end; return "" end,
  }
  package.loaded["src.core.game3.pokemon"] = Pokemon
  package.loaded["src.core.game3.battle.pic_coords"] = { front = { [6] = 1, [25] = 9 }, back = { [6] = 4 } }
  local MonAnim = { framePic = function(sp, frame) return { vanilla = "frame" .. frame } end }
  package.loaded["src.core.game3.mon_anim"] = MonAnim
  -- Gen 3 animation data: the game's own cache, Emerald's two-frame lists -Elvie
  local resets = 0
  -- its folder paths are the real module's: Facets reads them from it -Elvie
  package.loaded["src.core.game3.mon_anim_data"] = nil
  local realAnim = require("src.core.game3.mon_anim_data")
  local AnimData = {
    FRONT = realAnim.FRONT, SHEET = realAnim.SHEET, SHEET_SHINY = realAnim.SHEET_SHINY,
    cache = function() return "own" end,
    anims = function(sp) return { [0] = { "still" }, [1] = { "emerald" .. tostring(sp) } } end,
    reset = function() resets = resets + 1 end,
  }
  package.loaded["src.core.game3.mon_anim_data"] = AnimData
  -- Crystal's Charizard anim: frame 1 for 3 ticks, on a 2-picture sheet whose
  -- second picture is one black pixel at (30, 10). -Elvie
  GB_TEXT["crystal/data/generated/pokemon.lua"] = table.concat({
    "return {", "  CHARIZARD = {", "    anim = {", "      count = 1,", "      frames = {},",
    "      play = {", "        { 0, 2, },", "        { 1, 3, },", "        { 255, 0, },", "      },",
    '      sheet = "assets/generated/battle/anim/charizard.png",', "      tiles = 7,", "    },",
    '    name = "CHARIZARD",', "  },", "}" }, "\n")
  GB_FILES["crystal/" .. B .. "anim/charizard.png"] = function()
    local d = battleSprite(56)
    local sheet = pixelData(56, 112)
    for y = 0, 55 do for x = 0, 55 do local r, g, b2, a = d:getPixel(x, y); if a and a > 0 then sheet:setPixel(x, y, r, g, b2, a) end end end
    sheet:setPixel(30, 66, 0, 0, 0, 1)
    return sheet
  end
  -- FR/LG's own fronts and Emerald's: Bulbasaur the same, Ivysaur redrawn -Elvie
  local G = "data/generated/gba/pokemon/"
  GB_TEXT["firered/" .. G .. "front/1.rgba"] = "AAAA"
  GB_TEXT["emerald/" .. G .. "front_anim/1.rgba"] = "AAAABBBB"
  GB_TEXT["firered/" .. G .. "front/2.rgba"] = "CCCC"
  -- Emerald's two 64x64 frames: frame 1 red at (10, 40), frame 2 red at (20, 40) -Elvie
  local function rgbaFrames(points)
    local out = {}
    for f, p in ipairs(points) do
      local frame = {}
      for i = 0, 64 * 64 - 1 do frame[#frame + 1] = "\0\0\0\0" end
      frame[p[2] * 64 + p[1] + 1] = "\255\0\0\255"
      out[f] = table.concat(frame)
    end
    return table.concat(out)
  end
  GB_TEXT["emerald/" .. G .. "front_anim/2.rgba"] = rgbaFrames({ { 10, 40 }, { 20, 40 } })
  GB_TEXT["emerald/" .. G .. "front_anims.lua"] = "EMERALD"

  -- Crystal's party icons: 16x32 greyscale, white all round (no
  -- see-through), a black dot at (8, 15) and grey 170 at (15, 0). -Elvie
  local function iconSprite()
    local d = pixelData(16, 32)
    for y = 0, 31 do for x = 0, 15 do d:setPixel(x, y, 1, 1, 1, 1) end end
    d:setPixel(8, 15, 0, 0, 0, 1)
    d:setPixel(15, 0, 170 / 255, 170 / 255, 170 / 255, 1)
    d:setPixel(7, 4, 85 / 255, 85 / 255, 85 / 255, 1)
    return d
  end
  local I = "assets/generated/icons/gen2/"
  GB_FILES["crystal/" .. I .. "bigmon.png"] = iconSprite
  GB_FILES["crystal/" .. I .. "egg.png"] = iconSprite
  GB_FILES["crystal/" .. I .. "unown.png"] = iconSprite
  GB_TEXT["crystal/data/generated/icons.lua"] = table.concat({
    "return {", "  icons = {",
    "    ICON_BIGMON = {", '      image = "' .. I .. 'bigmon.png",', "    },",
    "    ICON_EGG = {", '      image = "' .. I .. 'egg.png",', "    },",
    "    ICON_UNOWN = {", '      image = "' .. I .. 'unown.png",', "    },",
    "  },", "  species = {", '    BULBASAUR = "ICON_BIGMON",', '    CHARIZARD = "ICON_BIGMON",', '    UNOWN = "ICON_UNOWN",', "  },", "}" }, "\n")

  local MOD_M = OUT .. "/modM"
  sh(("mkdir -p '%s/assets/mons/gbc' '%s/assets/mons/zzz/front'"):format(MOD_M, MOD_M))
  local f = io.open(MOD_M .. "/assets/mons/gbc/meta.json", "w"); f:write('{"label":"GBC","source":"gb"}'); f:close()
  f = io.open(MOD_M .. "/assets/mons/zzz/meta.json", "w"); f:write('{"label":"ZZZ"}'); f:close()
  -- PNG headers only: the love stub reads sizes from them. -Elvie
  local function fakePng(path, w, h)
    local function u32(n) return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256) end
    local out = io.open(path, "wb"); out:write("\137PNG\r\n\26\n\0\0\0\13IHDR" .. u32(w) .. u32(h) .. "\8\6\0\0\0"); out:close()
  end
  sh(("mkdir -p '%s/assets/mons/gbc/icons'"):format(MOD_M))
  fakePng(MOD_M .. "/assets/mons/gbc/icons/252.png", 32, 64)
  fakePng(MOD_M .. "/assets/mons/gbc/icons/001.png", 32, 64)
  -- GBC ANIM-style set: its own Hoenn front and animation, the rest from
  -- gbc (its fallback) -Elvie
  sh(("mkdir -p '%s/assets/mons/gbca/front' '%s/assets/mons/gbca/anim'"):format(MOD_M, MOD_M))
  f = io.open(MOD_M .. "/assets/mons/gbca/meta.json", "w"); f:write('{"label":"GBCA","source":"gb","fallback":"gbc"}'); f:close()
  fakePng(MOD_M .. "/assets/mons/gbca/front/252.png", 64, 64)
  fakePng(MOD_M .. "/assets/mons/gbca/anim/252.png", 40, 80)
  f = io.open(MOD_M .. "/assets/mons/gbca/anim/252.json", "w"); f:write('{"tiles":5,"play":[[1,3],[255,0]]}'); f:close()
  fakePng(MOD_M .. "/assets/mons/zzz/front/001.png", 64, 64)
  fakePng(MOD_M .. "/assets/mons/zzz/front/002.png", 80, 80)
  fakePng(MOD_M .. "/assets/mons/zzz/front/327.png", 64, 64)
  fakePng(MOD_M .. "/assets/mons/zzz/front/351.png", 64, 64)
  fakePng(MOD_M .. "/assets/mons/zzz/front/351_sunny.png", 64, 64)
  fakePng(MOD_M .. "/assets/mons/zzz/front/386.png", 64, 64)
  fakePng(MOD_M .. "/assets/mons/zzz/front/386_attack.png", 64, 64)

  local mod = newMod(MOD_M)
  local rows = {}
  -- the battle's animation starter, as the engine has it -Elvie
  local battleCalls = {}
  local BattleAnim = { _active = {} }
  function BattleAnim.start(key, kind, opts)
    battleCalls[#battleCalls + 1] = { key = key, kind = kind, noCry = opts and opts.noCry }
    return { species = 6 }
  end
  function BattleAnim.apply(p, sprite) p.ox, p.rotation = 3, 0.5 end
  package.loaded["src.core.game3.battle.mon_anim_battle"] = BattleAnim
  local start = require("mods.facets.mons").init(mod, rows)
  check(start ~= nil, "mons: init returns a start function")
  mod.options:define(rows)
  eq(rows[1].label, "POKEMON", "mons: POKEMON heading")
  eq(rows[2].key, "setMons", "mons: SET row")
  eq(rows[2].default, "__off", "mons: OFF by default")
  local labels = {}
  for _, c in ipairs(rows[2].choices) do labels[#labels + 1] = c[2] end
  eq(table.concat(labels, ","), "gbc,gbca,zzz,__off", "mons: sets in label order, then OFF")
  eq(rows[3].key, "animMons", "mons: FR/LG ANIMS row")
  eq(rows[3].default, "__off", "mons: FR/LG ANIMS off by default")
  start()
  eq(Pokemon.frontPic(6).vanilla, "front6", "mons: OFF leaves the game's own")

  mod.options:set("setMons", "gbc")
  local function px(e, x, y)
    local r, g, b, a = e.imageData:getPixel(x, y)
    return ("%d,%d,%d,%s"):format(math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5), tostring(a))
  end
  local zard = Pokemon.frontPic(6, nil, false, 0, "dex")
  check(zard and zard.image and not zard.vanilla, "gbc: Charizard front from Crystal")
  eq(zard.w .. "x" .. zard.h, "64x64", "gbc: 64x64")
  -- 56 wide: x 4..59; lowest row on 64 - 1 - 1 = row 62 (y offset 1) -Elvie
  eq(px(zard, 4, 62), "0,0,0,1", "gbc: black, bottom-left, on the game's own bottom row")
  eq(px(zard, 59, 7), "200,100,50,1", "gbc: grey 170 is the palette's first colour")
  eq(px(zard, 9, 12), "255,255,255,1", "gbc: inner white stays white")
  local _, _, _, a = zard.imageData:getPixel(20, 30)
  eq(a, 0, "gbc: outside is see-through")
  eq(Pokemon.frontPic(6), zard, "gbc: cached")
  local shiny = Pokemon.frontPic(6, nil, true)
  eq(px(shiny, 59, 7), "1,2,3,1", "gbc: shiny uses Crystal's shiny palette")
  local back = Pokemon.backPic(6, nil, false)
  check(back and not back.vanilla, "gbc: back from <name>_back.png")
  eq(px(back, 8, 59), "0,0,0,1", "gbc: back bottom on 64 - 4 - 1 (y offset 4)")
  local pika = Pokemon.frontPic(25)
  check(pika and not pika.vanilla, "gbc: Gold's copy used when Crystal's is missing")
  eq(px(pika, 12, 54), "0,0,0,1", "gbc: Pikachu's bottom on row 54 (y offset 9)")
  local unown = Pokemon.frontPic(414)
  check(unown and not unown.vanilla, "gbc: Unown C from unown_c.png")
  local _, _, _, ua = unown.imageData:getPixel(12, 10)
  eq(ua, 0, "gbc: a sprite with no see-through: the white round the edge is cleared")
  eq(px(unown, 32, 63), "0,0,0,1", "gbc: ...and the rest is drawn (bottom on row 63, no offset)")
  eq(Pokemon.frontPic(413).vanilla, "front413", "gbc: Unown B missing from the install: the game's own")
  eq(Pokemon.frontPic(439).vanilla, "front439", "gbc: Unown ? (no Game Boy letter): the game's own")
  check(not Pokemon.frontPic(412).vanilla, "gbc: the egg")
  eq(Pokemon.backPic(412).vanilla, "back412", "gbc: no egg back")
  eq(Pokemon.frontPic(277).vanilla, "front277", "gbc: Hoenn Pokémon stay the game's own")
  eq(Pokemon.frontPic(6, 1).vanilla, "front6", "gbc: forms stay the game's own")
  eq(MonAnim.framePic(25, 1, false), pika, "gbc: with no Crystal anim, the second frame is the same picture")
  eq(MonAnim.framePic(277, 1).vanilla, "frame1", "gbc: unreplaced frames are the game's own")

  -- Party icons -Elvie
  local icon = Pokemon.icon(6)
  check(icon and icon.image and not icon.vanilla, "gbc icons: Charizard's icon from Crystal's BIGMON")
  eq(icon.w .. "x" .. icon.h .. ":" .. icon.frames, "32x32:2", "gbc icons: two 32x32 frames, like Gen 3's")
  check(icon.quads[0] and icon.quads[1], "gbc icons: a quad per frame")
  -- 16x16 at (8, 16) in each 32x32 frame: grey 170 at (15, 0) -> (23, 16) -Elvie
  eq(px(icon, 23, 16), "255,156,82,1", "gbc icons: grey 170 is the party menu's orange, at the bottom-centre")
  eq(px(icon, 15, 20), "255,58,33,1", "gbc icons: grey 85 is the party menu's red")
  eq(px(icon, 16, 31), "0,0,0,1", "gbc icons: black stays black, on the frame's bottom row")
  local _, _, _, da = icon.imageData:getPixel(31, 1)
  eq(da, 0, "gbc icons: Game Boy size, nothing doubled")
  local _, _, _, ia = icon.imageData:getPixel(0, 0)
  eq(ia, 0, "gbc icons: the white round the icon is see-through")
  eq(Pokemon.icon(6), icon, "gbc icons: cached")
  local own = Pokemon.icon(277)
  check(own and not own.vanilla and own ~= icon, "gbc icons: Hoenn from the set's icons/252.png")
  eq(px(own, 10, 40), "255,0,0,1", "gbc icons: a 32x64 file is used as it is")
  check(not Pokemon.icon(412).vanilla, "gbc icons: the egg from Crystal's")
  check(not Pokemon.icon(414).vanilla, "gbc icons: Unown letters from Crystal's Unown")
  eq(Pokemon.icon(25).vanilla, "icon25", "gbc icons: not in Crystal's table: the game's own")
  eq(px(Pokemon.icon(1), 10, 40), "255,0,0,1", "gbc icons: the set's own Kanto icon beats Crystal's")
  eq(#rows, 5, "mons: no icon size row (POKEMON, SET, ANIMS, YOUR SIDE, MIRROR)")

  -- Crystal's animations on Game Boy fronts -Elvie
  local zanims = AnimData.anims(6)
  eq(zanims[0][1], "still", "crystal anim: anim 0 is left alone")
  local hasF1 = false
  for _, c in ipairs(zanims[1]) do if c.frame == 1 and c.duration == 3 then hasF1 = true end end
  check(hasF1, "crystal anim: anim 1 plays Crystal's frame 1 for 3 ticks")
  eq(zanims[1][#zanims[1]].op, "end", "crystal anim: ...and ends")
  eq(AnimData.anims(277)[1][1], "emerald277", "crystal anim: Hoenn keeps Emerald's list")
  local f1 = MonAnim.framePic(6, 1, false)
  check(f1 and f1 ~= zard and f1.gb, "crystal anim: frame 1 is Crystal's second picture")
  -- placed like the front (x + 4, y + 7), not stood on the ground line -Elvie
  eq(px(f1, 34, 17), "0,0,0,1", "crystal anim: the frame sits where the front does")
  eq(MonAnim.framePic(6, 2, false), Pokemon.frontPic(6, nil, false), "crystal anim: a frame past the sheet is the front")
  check(MonAnim.framePic(6, 1, true) ~= f1, "crystal anim: shiny frames are their own")

  -- A set's own animation, and its fallback -Elvie
  mod.options:set("setMons", "gbca")
  local hf = Pokemon.frontPic(277)
  check(hf and hf.set and hf.set.key == "gbca", "anim set: Hoenn front from the set's own file")
  local hc = AnimData.anims(277)[1]
  check(hc and hc[1] and hc[1].frame ~= nil, "anim set: anim 1 is the set's own script")
  local has1 = false
  for _, c in ipairs(hc or {}) do if c.frame == 1 and c.duration == 3 then has1 = true end end
  check(has1, "anim set: ...frame 1 for 3 ticks, from anim/252.json")
  local hf1 = MonAnim.framePic(277, 1, false)
  check(hf1 and hf1 ~= hf, "anim set: frame 1 is the sheet's second picture")
  -- the sheet's red pixel (10, 40) is frame 1's (10, 0): at (22, 24) in the
  -- 64x64 frame, moved by the front's spot (0, 23) to (22, 47) -Elvie
  eq(px(hf1, 22, 47), "255,0,0,1", "anim set: the frame sits where its front does")
  check(not Pokemon.frontPic(6).vanilla, "anim set: Kanto from Crystal (source gb), like GBC")
  local hi = Pokemon.icon(277)
  check(hi and not hi.vanilla, "anim set: an icon it doesn't have comes from its fallback (gbc)")

  mod.options:set("setMons", "zzz")
  local own = Pokemon.frontPic(1)
  check(own and not own.vanilla and own.w == 64, "folder set: front/001.png used")
  eq(px(own, 10, 63), "255,0,0,1", "folder set: stood on the game's ground line (row 63 with no offset)")
  local _, _, _, oa = own.imageData:getPixel(10, 40)
  eq(oa, 0, "folder set: ...moved down from where it was drawn")
  eq(Pokemon.frontPic(327).vanilla, "front327", "folder set: Spinda's front stays the game's own (spots)")
  local cast = Pokemon.frontPic(351)
  check(cast and not cast.vanilla, "folder set: Castform")
  local sunny = Pokemon.frontPic(351, 1)
  check(sunny and not sunny.vanilla and sunny ~= cast, "folder set: Castform's sunny form from 351_sunny")
  eq(Pokemon.frontPic(351, 2).vanilla, "front351", "folder set: a form without a file is the game's own")
  local deo = Pokemon.frontPic(386)
  check(deo and not deo.vanilla, "folder set: Deoxys")
  Pokemon_handled = true
  local atk = Pokemon.frontPic(386)
  check(atk and not atk.vanilla and atk ~= deo, "folder set: FireRed's Deoxys is 386_attack when the game asks for its own form")
  Pokemon_handled = nil
  eq(Pokemon.frontPic(2).vanilla, "front2", "folder set: an 80x80 file is skipped")
  eq(Pokemon.frontPic(6).vanilla, "front6", "folder set: no file, no Game Boy source: the game's own")
  eq(Pokemon.frontPic(1, nil, true).vanilla, "front1", "folder set: no shiny file: the game's own")
  mod.options:set("setMons", "__off")
  eq(Pokemon.frontPic(1).vanilla, "front1", "mons: back to OFF")
  eq(Pokemon.icon(6).vanilla, "icon6", "mons: OFF leaves icons alone")
  eq(AnimData.anims(6)[1][1], "emerald6", "crystal anim: OFF keeps Emerald's list")

  -- Emerald's animations in FR/LG -Elvie
  eq(AnimData.cache(), "own", "fr/lg anims: off reads the game's own data")
  local before = resets
  mod.options:set("animMons", "emerald")
  check(resets > before, "fr/lg anims: the engine's animation data is reloaded")
  eq(AnimData.cache():read(G .. "front_anims.lua"), "EMERALD", "fr/lg anims: on reads Emerald's")
  eq(MonAnim.framePic(1, 1).vanilla, "frame1", "fr/lg anims: same picture as Emerald's, Emerald's frame")
  local emFront = Pokemon.frontPic(2)
  check(emFront and emFront.emerald, "fr/lg anims: redrawn in FR/LG, the front is Emerald's art")
  eq(px(emFront, 10, 63), "255,0,0,1", "fr/lg anims: ...stood on FR/LG's ground line")
  local emF2 = MonAnim.framePic(2, 1)
  check(emF2 and emF2.emerald and emF2 ~= emFront, "fr/lg anims: ...and its second frame is Emerald's")
  eq(px(emF2, 20, 63), "255,0,0,1", "fr/lg anims: ...in the same spot")
  eq(Pokemon.frontPic(1).vanilla, "front1", "fr/lg anims: same art in both games: FR/LG's own")
  currentVersion = "emerald"
  eq(AnimData.cache(), "own", "fr/lg anims: Emerald reads its own")
  currentVersion = "firered"
  mod.options:set("animMons", "__off")
  eq(AnimData.cache(), "own", "fr/lg anims: off again")
  eq(Pokemon.frontPic(2).vanilla, "front2", "fr/lg anims: off, FR/LG's own art again")
  eq(MonAnim.framePic(2, 1).vanilla, "frame1", "fr/lg anims: off leaves frames alone")

  -- Game Boy pictures made from the game's own, for what a Game Boy set
  -- has no art for -Elvie
  local monsG = require("mods.facets.mons")
  local px = {}
  for i = 1, 100 do
    -- 12 darkest, then dark to the middle, light, and the 7 brightest -Elvie
    local v = i <= 12 and 10 or i <= 55 and 100 or i <= 93 and 180 or 250
    -- the middle shades: mostly one colour each, a few strays -Elvie
    local c = { v, v, v, 255 }
    if v == 100 then c = (i % 10 == 0) and { 90, 40, 40, 255 } or { 40, 60, 120, 255 } end
    if v == 180 then c = (i % 10 == 0) and { 200, 160, 160, 255 } or { 120, 200, 90, 255 } end
    px[i] = c
  end
  px[101] = { 0, 0, 0, 0 }
  local out = monsG.toGbc(px)
  eq(table.concat(out[1], ","), "0,0,0,255", "to gbc: the darkest pixels go black")
  eq(table.concat(out[99], ","), "248,248,248,255", "to gbc: the brightest go white")
  eq(table.concat(out[20], ","), "40,56,120,255", "to gbc: dark: its most-used colour, in 5 bits")
  eq(table.concat(out[61], ","), "120,200,88,255", "to gbc: light: its most-used colour, in 5 bits")
  eq(table.concat(out[70], ","), "120,200,88,255", "to gbc: a light stray too")
  eq(table.concat(out[30], ","), "40,56,120,255", "to gbc: a stray takes its shade's colour")
  eq(out[101][4], 0, "to gbc: see-through stays see-through")
  local shinyPx = {}
  for i, c in ipairs(px) do shinyPx[i] = (c[1] == 40) and { 200, 40, 200, 255 } or c end
  local sOut = monsG.toGbc(px, shinyPx)
  eq(table.concat(sOut[20], ","), "200,40,200,255", "to gbc: a shiny takes the shiny's colours...")
  eq(table.concat(sOut[1], ",") .. "|" .. table.concat(sOut[99], ","), "0,0,0,255|248,248,248,255",
    "to gbc: ...on the normal picture's shading")
  -- 8 and 16 shades: more middles, still black and white at the ends -Elvie
  local ramp = {}
  for i = 1, 200 do local v = math.floor(i * 255 / 200); ramp[i] = { v, math.floor(v / 2), 255 - v, 255 } end
  for _, n in ipairs({ 4, 8, 16 }) do
    local got, distinct = monsG.toGbc(ramp, ramp, n), {}
    for _, c in ipairs(got) do distinct[table.concat(c, ",")] = true end
    local count = 0
    for _ in pairs(distinct) do count = count + 1 end
    eq(count, n, ("to gbc: %d shades on a smooth ramp"):format(n))
    eq(table.concat(got[1], ",") .. "|" .. table.concat(got[200], ","), "0,0,0,255|248,248,248,255", ("to gbc: %d shades: black to white"):format(n))
  end
  eq(#monsG.toGbc(ramp, ramp, 5), 200, "to gbc: another count falls back to 4")
  -- an animation's other frames reuse the first frame's plan -Elvie
  local f0, plan0 = monsG.toGbc(px, px, 4)
  check(plan0 and #plan0.cuts == 3 and plan0.pal[2], "to gbc: returns its plan (cut points, colours)")
  local moved = {}
  for i, c in ipairs(px) do moved[i] = px[((i + 4) % #px) + 1] end
  local f1 = monsG.toGbc(moved, nil, 8, plan0)
  local same = true
  for i = 1, #moved do
    local want = f0[((i + 4) % #px) + 1]
    if table.concat(f1[i], ",") ~= table.concat(want, ",") then same = false end
  end
  check(same, "to gbc: a frame with the same pixels moved gets the same shades and colours (the plan wins over shades)")

  -- Unown ! (no art in GBC, none in Crystal): made from the game's own -Elvie
  local gbM = require("mods.facets.gb")
  local function rgbaOf(pixels)
    local t = {}
    for i = 1, 64 * 64 do
      local c = pixels[i] or { 0, 0, 0, 0 }
      t[i] = string.char(c[1], c[2], c[3], c[4])
    end
    return table.concat(t)
  end
  GB_TEXT["firered/" .. gbM.path("monData", "back/438.rgba")] = rgbaOf(px)
  mod.options:set("setMons", "gbc")
  local excl = Pokemon.backPic(438, nil, false)
  check(excl and not excl.vanilla and excl.imageData, "gbc: Unown ! back made from the game's own picture")
  local r1, g1, b1 = excl.imageData:getPixel(19, 0)
  eq(("%d,%d,%d"):format(math.floor(r1 * 255 + 0.5), math.floor(g1 * 255 + 0.5), math.floor(b1 * 255 + 0.5)), "40,56,120",
    "gbc: ...in Game Boy shades, where the game's stands")
  eq(Pokemon.backPic(439).vanilla, "back439", "gbc: no picture in the install: the game's own")
  mod.options:set("setMons", "__off")
  GB_TEXT["firered/" .. gbM.path("monData", "back/438.rgba")] = nil

  -- YOUR SIDE: FRONT, and MIRROR FRONTS -Elvie
  local monsM = require("mods.facets.mons")
  eq(monsM.frontAsBackShift({ front = { [6] = 10 }, back = { [6] = 4 }, elev = { [6] = 3 } }, 6), 3,
    "your side: front offset, less its float, less the back offset")
  eq(monsM.frontAsBackShift(nil, 6), 0, "your side: no offsets, no move")
  eq(rows[4].key .. "," .. rows[4].default, "backMons,back", "your side: row, BACK by default")
  eq(rows[5].key .. "," .. rows[5].default, "mirrorMons,on", "mirror fronts: row, ON by default")
  mod.options:set("setMons", "gbc")
  mod.options:set("backMons", "front")
  check(not Pokemon.backPic(6).vanilla and Pokemon.backPic(6).imageData, "your side: no canvas (headless): the set's back, as before")
  local G = love.graphics
  local saved = { newCanvas = G.newCanvas, push = G.push, pop = G.pop, setCanvas = G.setCanvas, clear = G.clear,
    origin = G.origin, setShader = G.setShader, draw = G.draw }
  local drawn, made = nil, 0
  G.newCanvas = function(w, h)
    made = made + 1
    return { newImageData = function() return { w = w, h = h } end, release = function() end }
  end
  for _, k in ipairs({ "push", "pop", "setCanvas", "clear", "origin", "setShader" }) do G[k] = function() end end
  G.draw = function(img, x, y, r, sx, sy) drawn = { img = img, x = x, y = y, sx = sx } end
  local zardFront = Pokemon.frontPic(6)
  local asBack = Pokemon.backPic(6, nil, false)
  check(asBack and asBack.imageData and asBack.imageData.w == 64, "your side: FRONT draws a 64x64 picture")
  eq(drawn and drawn.img, zardFront.image, "your side: ...from the front picture (the set's)")
  eq(drawn and (drawn.x .. "," .. drawn.y .. "," .. drawn.sx), "64,-3,-1", "your side: moved to the back's ground line (1 - 4), mirrored by default")
  eq(Pokemon.backPic(6, nil, false), asBack, "your side: kept")
  eq(made, 1, "your side: drawn once")
  mod.options:set("mirrorMons", "__off")
  Pokemon.backPic(6, nil, false)
  eq(drawn and (drawn.x .. "," .. drawn.sx), "0,1", "mirror fronts off: as drawn")
  eq(made, 2, "mirror fronts: drawn again when changed")
  -- front animations on your side -Elvie
  local sprite = BattleAnim.start("player", "back", { st = 1 })
  eq(battleCalls[#battleCalls].kind .. "," .. tostring(battleCalls[#battleCalls].noCry), "front,true",
    "your side: FRONT starts the front animation, without a second cry")
  check(sprite.facetsSide, "your side: ...marked as yours")
  BattleAnim.start(1, "front", {})
  eq(battleCalls[#battleCalls].kind .. "," .. tostring(battleCalls[#battleCalls].noCry), "front,nil", "your side: the foe's untouched")
  local pres = {}
  BattleAnim.apply(pres, sprite)
  eq(pres.ox .. "," .. pres.rotation, "3,0.5", "your side: not mirrored, moves as they are")
  mod.options:set("mirrorMons", "on")
  BattleAnim.apply(pres, sprite)
  eq(pres.ox .. "," .. pres.rotation, "-3,-0.5", "your side: mirrored, its moves mirrored too")
  local foePres = {}
  BattleAnim.apply(foePres, { species = 6 })
  eq(foePres.ox, 3, "your side: the foe's moves untouched")
  local savedFrame = MonAnim.framePic
  MonAnim.framePic = function(sp, frame) return { image = "frame" .. frame } end
  pres.monFrame = 1
  BattleAnim._active[pres] = sprite
  eq(require("mods.facets.mons").sideFrame(6), 1, "your side: the animation's frame is found")
  Pokemon.backPic(6, nil, false)
  eq(drawn and drawn.img, "frame1", "your side: its picture follows the frame")
  BattleAnim._active[pres] = nil
  Pokemon.backPic(6, nil, false)
  eq(drawn and drawn.img, zardFront.image, "your side: back to the still picture when it's done")
  MonAnim.framePic = savedFrame
  mod.options:set("backMons", "back")
  BattleAnim.start("player", "back", {})
  eq(battleCalls[#battleCalls].kind, "back", "your side: BACK keeps the back animation")
  local plainBack = Pokemon.backPic(6, nil, false)
  check(plainBack and plainBack ~= asBack and not plainBack.vanilla, "your side: BACK again: the set's back")
  mod.options:set("mirrorMons", "__off")
  mod.options:set("setMons", "__off")
  for k, fn in pairs(saved) do G[k] = fn end
  package.loaded["src.core.game3.pokemon"] = nil
  package.loaded["src.core.game3.battle.pic_coords"] = nil
  package.loaded["src.core.game3.mon_anim"] = nil
  package.loaded["src.core.game3.battle.mon_anim_battle"] = nil
  package.loaded["src.core.game3.mon_anim_data"] = nil
end

-- main.lua: NPC rows, then the POKEMON rows -Elvie
do
  fresh("firered")
  local Pokemon = { frontPic = function() return nil end, backPic = function() return nil end }
  package.loaded["src.core.game3.pokemon"] = Pokemon
  local mod = newMod(ROOT)
  local f = assert(loadfile(ROOT .. "/main.lua"))
  f()(mod)
  local keys = {}
  for _, r in ipairs(mod.rows) do keys[#keys + 1] = r.key end
  eq(table.concat(keys, ","), "sectionFrlg,setFrlg,sectionRse,setRse,sectionMons,setMons,animMons,backMons,mirrorMons", "main: NPC rows then POKEMON rows")
  local monSets = {}
  for _, c in ipairs(mod.rows[6].choices) do monSets[#monSets + 1] = c[1] end
  eq(table.concat(monSets, ","), "DS,GB EMERALD,GBC ANIM,GBC-ISH,OFF", "shipped: Pokémon sets DS, GB EMERALD, GBC ANIM and GBC-ISH, then OFF")
  package.loaded["src.core.game3.pokemon"] = nil
end


-- The FACETS screen (menu.lua, screen.lua) -Elvie
-- --------------------------------------------------
for _, version in ipairs({ "firered", "emerald" }) do
  fresh(version)
  local frlg = version == "firered"
  local Pokemon = { frontPic = function(sp) return { image = "pic" .. tostring(sp) } end, backPic = function() return nil end }
  package.loaded["src.core.game3.pokemon"] = Pokemon
  local layers = {}
  package.loaded["src.ui.game3.stack"] = {
    has = function(name) return layers[name] ~= nil end,
    push = function(name, s) layers[name] = s end,
    pop = function(name) layers[name] = nil end,
  }
  local mod = newMod(ROOT)
  local wraps = {}
  mod.hooks = { wrap = function(_, name, fn) wraps[name] = fn end }
  local f = assert(loadfile(ROOT .. "/main.lua"))
  f()(mod)
  local M = require("mods.facets.menu").current
  local tag = "screen (" .. version .. "): "
  local keys = {}
  for _, r in ipairs(M.rows()) do keys[#keys + 1] = r.label end
  eq(table.concat(keys, ","), frlg and "NPCS,POKéMON,ANIMS,YOUR SIDE,CREDITS" or "NPCS,POKéMON,YOUR SIDE,CREDITS",
    tag .. "the running game's rows only")
  -- YOUR SIDE: one row here for both options -Elvie
  local side
  local function sideRow()
    for _, r in ipairs(M.rows()) do if r.key == "backMons" then return r end end
  end
  side = sideRow()
  eq(side and side.valueLabel, "BACK", tag .. "YOUR SIDE starts BACK")
  local sets = {}
  local sideGame = { options = {}, mods = { events = { emit = function(_, _, c) sets[#sets + 1] = c.key .. "=" .. tostring(c.value) end } } }
  side.set(sideGame, "mirrored")
  eq(table.concat(sets, ","), "backMons=front,mirrorMons=on", tag .. "YOUR SIDE MIRRORED sets both options")
  sets = {}
  side.set(sideGame, "front")
  eq(table.concat(sets, ","), "backMons=front,mirrorMons=__off", tag .. "YOUR SIDE FRONT: front, not mirrored")
  sets = {}
  side.set(sideGame, "back")
  eq(table.concat(sets, ","), "backMons=back", tag .. "YOUR SIDE BACK: MIRROR FRONTS left as it was")
  mod.options:set("backMons", "front"); mod.options:set("mirrorMons", "on")
  eq(sideRow().valueLabel, "MIRRORED", tag .. "both options on show as MIRRORED")
  mod.options:set("mirrorMons", "__off")
  eq(sideRow().valueLabel, "FRONT", tag .. "...front alone as FRONT")
  mod.options:set("backMons", "back")
  local rows = M.rows()
  eq(rows[1].key, frlg and "setFrlg" or "setRse", tag .. "NPCS is this family's SET")
  eq(rows[1].valueLabel, "COMMUNITY", tag .. "NPCS shows the set's label")
  eq(rows[2].valueLabel, "OFF", tag .. "POKEMON starts OFF")

  -- START menu: FACETS above MODS; OPTION menu: FACETS last -Elvie
  local items = wraps["ui.start_menu.items"](function()
    return { { id = "pokedex" }, { id = "mods" }, { id = "exit" } }
  end, {}, nil)
  eq(items[2].label .. "," .. items[3].id, "FACETS,mods", tag .. "FACETS goes above MODS")
  eq(items[2].id, "prism", tag .. "...as the shared PRISM item, with one entry")
  local orows = wraps["ui.options.rows"](function() return { { id = "text_speed" } } end, {}, nil)
  eq(orows[2].label, "FACETS", tag .. "FACETS on the OPTION menu")
  eq(orows[2].value(), "COMMUNITY", tag .. "...showing the NPC set")

  -- Opening it and changing a row the way the mod settings screen does -Elvie
  local emitted = {}
  local game = { options = {}, mods = { events = { emit = function(_, name, change) emitted[#emitted + 1] = change end } } }
  items[2].onSelect(game)

  -- Sharing PRISM with another visuals mod (Emerald Lens), whichever
  -- hooks first -Elvie
  local lensOpened = 0
  local V = require("mods.facets.prism")
  local lensEntry = { id = "emerald_lens", label = "EMERALD LENS", short = "LENS",
    value = function() return "KRIS" end, open = function() lensOpened = lensOpened + 1 end }
  local lensPicker = V.picker()
  local base = function() return { { id = "pokedex" }, { id = "mods" }, { id = "exit" } } end
  -- Lens hooked first (inner), Facets outer -Elvie
  local both = wraps["ui.start_menu.items"](function() return V.addStart(base(), lensEntry, lensPicker, {}) end, {}, nil)
  eq(#both, 4, tag .. "with Lens: still one item added")
  eq(both[2].label, "PRISM", tag .. "with Lens: the item is PRISM")
  eq(both[2].entries[1].label .. "," .. both[2].entries[2].label, "EMERALD LENS,FACETS", tag .. "with Lens: both listed, by label")
  local fe = both[2].entries[2]
  eq(table.concat(fe.colour, ","), "130,60,170", tag .. "FACETS brings its gem colour (amethyst)")
  check(type(fe.draw) == "function", tag .. "...and its live preview for PRISM's corner")
  -- Facets inner, Lens outer -Elvie
  local other = V.addStart(wraps["ui.start_menu.items"](base, {}, nil), lensEntry, lensPicker, {})
  eq(#other .. ":" .. other[2].label .. ":" .. #other[2].entries, "4:PRISM:2", tag .. "with Lens the other way round: the same")
  local orBoth = wraps["ui.options.rows"](function() return V.addOption({ { id = "text_speed" } }, lensEntry, lensPicker, {}) end, {}, nil)
  eq(#orBoth .. ":" .. orBoth[2].label, "2:PRISM", tag .. "with Lens: one PRISM row on the OPTION menu")
  -- PRISM opens the list; A opens the picked mod's screen on top -Elvie
  both[2].onSelect(game)
  check(layers.prism ~= nil, tag .. "PRISM opens the list")
  local function pressV(key) layers.prism.handleInput({ wasPressed = function(_, k) return k == key end }) end
  pressV("a")
  eq(lensOpened, 1, tag .. "A on EMERALD LENS opens Lens's screen")
  pressV("down"); pressV("a")
  check(layers.facets ~= nil, tag .. "A on FACETS opens the FACETS screen")
  layers.facets.close()
  check(layers.prism ~= nil, tag .. "closing it comes back to the list")
  pressV("b")
  check(layers.prism == nil, tag .. "B closes the list")
  items[2].onSelect(game)
  check(layers.facets ~= nil and layers.facets.isOpen(), tag .. "START > FACETS opens the screen")
  local function press(key) layers.facets.handleInput({ wasPressed = function(_, k) return k == key end }) end
  press("down")
  eq(layers.facets.state().index, 2, tag .. "down picks the next row")
  press("right")
  eq(emitted[1] and emitted[1].key, "setMons", tag .. "right changes POKEMON")
  eq(emitted[1].value, "ds", tag .. "...to the next set")
  eq(game.options.modOptions.facets.setMons, "ds", tag .. "...saved with the options")
  press("up"); press("up")
  eq(layers.facets.state().index, #rows, tag .. "up from the top wraps to CREDITS")
  press("a")
  check(layers.facets.state().credits ~= nil, tag .. "A on CREDITS opens the credits page")
  press("b")
  check(layers.facets.state().credits == nil, tag .. "B leaves the credits page")
  press("b")
  check(layers.facets == nil, tag .. "B closes the screen")

  -- Preview lines and credits -Elvie
  eq(M.preview("npcs").lines[1].text:sub(1, 17), "Overworld sprites", tag .. "NPCS shows the set's credit")
  eq(M.preview("mons").lines[1].text, "The game's own POKéMON.", tag .. "POKEMON OFF")
  if frlg then eq(M.preview("anims").lines[1].text, "FR/LG's still pictures.", tag .. "ANIMS OFF") end
  local heads = {}
  for _, e in ipairs(M.credits()) do if e.heading then heads[#heads + 1] = e.text end end
  local all = table.concat(heads, "|")
  check(all:find("NPCS: COMMUNITY", 1, true) and all:find("POKEMON: GBC", 1, true) and all:find("FACETS", 1, true),
    tag .. "credits: NPC sets, Pokémon sets, then Facets")
  check(not all:find("TEST FRAMES", 1, true), tag .. "credits: no test set")

  -- The preview draws an NPC through OwSprites and a Pokémon picture -Elvie
  local drawn = {}
  local saved = love.graphics.draw
  love.graphics.draw = function(img, ...) drawn[#drawn + 1] = img end
  M.draw(0)
  love.graphics.draw = saved
  local seen = table.concat((function() local t = {} for _, d in ipairs(drawn) do t[#t + 1] = tostring(type(d) == "table" and (d.path or d.data or "tbl") or d) end return t end)(), " ")
  check(seen:find("pic1", 1, true), tag .. "preview draws Bulbasaur's front first")
  check(#drawn == 2, tag .. "...and one NPC")
  package.loaded["src.core.game3.pokemon"] = nil
  package.loaded["src.ui.game3.stack"] = nil
end

-- Preview timing -Elvie
do
  local npcs = require("mods.facets.npcs")
  local who, frame, flip = npcs.walkAt(0, 3)
  eq(who .. ":" .. frame .. ":" .. tostring(flip), "1:0:false", "walk preview: the first NPC standing, facing down")
  who, frame, flip = npcs.walkAt(npcs.TURN_TIME * 3 + 0.01, 3)
  eq(tostring(flip), "true", "walk preview: the fourth facing is right (left, flipped)")
  who = npcs.walkAt(npcs.TURN_TIME * 4 + 0.01, 3)
  eq(who, 2, "walk preview: the next NPC after all four facings")
  local mons = require("mods.facets.mons")
  local cmds = { { frame = 0, duration = 2 }, { frame = 1, duration = 3 }, { op = "end" } }
  eq(mons.frameAt(cmds, 1) .. mons.frameAt(cmds, 2) .. mons.frameAt(cmds, 4) .. mons.frameAt(cmds, 5), "0110",
    "mon preview: frames by tick, then the base picture")
  local sp, fr = mons.showcaseAt(mons.SLOT_TIME + 0.5 + 3 / 60, function() return { [1] = cmds } end)
  eq(sp .. ":" .. fr, "4:1", "mon preview: Charmander second, playing its anim")
  sp, fr = mons.showcaseAt(0.1, nil)
  eq(sp .. ":" .. fr, "1:0", "mon preview: no animation data, the still picture")
end


-- The engine's folders, read from its own modules (MK301) -Elvie
do
  fresh("firered")
  package.loaded["src.core.game3.mon_anim_data"] = nil
  local gb = require("mods.facets.gb")
  gb.resetRoots()
  local roots = gb.roots()
  eq(roots.assets, "assets/generated/", "roots: the art folder, from AssetTransform")
  eq(roots.data, "data/generated/", "roots: the data folder, from MonAnimData")
  eq(roots.monData, "data/generated/gba/pokemon/", "roots: Gen 3's Pokémon data folder, from MonAnimData")
  eq(gb.path("assets", "sprites/x.png"), "assets/generated/sprites/x.png", "roots: a path under a folder")
  -- an engine that doesn't say: nothing is read -Elvie
  package.loaded["src.core.game3.mon_anim_data"] = {}
  gb.resetRoots()
  eq(gb.path("data", "palettes.lua"), nil, "roots: no data folder from the engine, no path")
  eq(gb.readAt(gb.path("data", "palettes.lua")), nil, "roots: ...and nothing read")
  package.loaded["src.core.game3.mon_anim_data"] = nil
  gb.resetRoots()
end


-- The GB filter (filter.lua) -Elvie
do
  fresh("firered")
  local Pipelines = require("src.render.Pipelines")
  local registered, wraps = {}, {}
  local mod = newMod(ROOT)
  mod.content = { render_pipelines = { register = function(_, id, def) registered[id] = def end } }
  mod.hooks = { wrap = function(_, name, fn) wraps[name] = fn end }
  local rows = {}
  local filter = require("mods.facets.filter")
  local start = filter.init(mod, rows)
  check(start ~= nil, "filter: init returns a start function")
  local def = registered[filter.ID]
  check(def and type(def.present) == "function", "filter: registered as a render pipeline with a present pass")
  check(type(wraps["render.compose"]) == "function", "filter: wraps render.compose for MAP")
  local keys = {}
  for _, r in ipairs(rows) do keys[#keys + 1] = r.key .. "=" .. tostring(r.default) end
  eq(table.concat(keys, ","), "sectionScreen=_,filter=off,filterOn=screen,dots=off,shades=4", "filter: SCREEN rows and defaults")
  local looks = {}
  for _, c in ipairs(rows[2].choices) do looks[#looks + 1] = c[1] end
  eq(table.concat(looks, ","), "OFF,GRAY,GREEN,RUBY,SAPPHIRE,EMERALD,GBC", "filter: the looks")
  for _, k in ipairs({ "gray", "green", "ruby", "sapphire", "emerald" }) do
    check(filter.SHADES[k] and #filter.SHADES[k] == 4, "filter: " .. k .. " has four shades, lightest first")
  end
  mod.options:define(rows)
  Pipelines.install({ render_pipelines = { [filter.ID] = def } })
  start()
  eq(Pipelines.level(filter.ID), 0, "filter: all off, the pipeline is off")
  local game = { options = {} }
  mod.game = game
  mod.options:set("filter", "green")
  eq(Pipelines.level(filter.ID), 1, "filter: GREEN on the screen turns the pipeline on")
  eq(game.options.pipelines and game.options.pipelines[filter.ID], 1, "filter: ...kept with the game's options")
  mod.options:set("filterOn", "map")
  eq(Pipelines.level(filter.ID), 0, "filter: MAP only, no whole-screen pass")
  mod.options:set("dots", "on")
  eq(Pipelines.level(filter.ID), 1, "filter: DOTS needs the whole-screen pass")
  -- a load restores levels from the options; game.ready sets it again -Elvie
  Pipelines.applyOptions({})
  mod.fire("game.ready")
  eq(Pipelines.level(filter.ID), 1, "filter: game.ready sets the level again")
  -- no shader support (headless): the frame goes through untouched -Elvie
  local frame = { getDimensions = function() return 240, 160 end }
  eq(def.present(frame, {}), frame, "filter: no shader, the frame itself")
  -- render.compose always carries on to the engine's own composite -Elvie
  local carried = wraps["render.compose"](function() return "next" end, {}, { worldActive = true, scale = 3, ox = 10, oy = 4 })
  eq(carried, "next", "filter: render.compose hands on to the composite")
  check(filter.screenOn("off", "screen", "off") == false and filter.screenOn("gbc", "screen", "off") == true
    and filter.screenOn("gbc", "map", "off") == false, "filter: whole-screen pass only when it has work")
  local look, where, dots = filter.settings(function(k) return ({ filter = "bogus", filterOn = "map", dots = "on" })[k] end)
  eq(look .. where .. dots, "offmapon", "filter: an unknown value is OFF")
  local _, _, _, steps = filter.settings(function(k) return ({ shades = "16" })[k] end)
  eq(steps, "16", "filter: 16 shades")
  _, _, _, steps = filter.settings(function(k) return ({ shades = "12" })[k] end)
  eq(steps, "4", "filter: an unknown shade count is 4")
  -- no render pipelines in the engine: nothing added -Elvie
  local bare = newMod(ROOT)
  local none = {}
  check(filter.init(bare, none) == nil and #none == 0, "filter: no pipelines, no rows")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
