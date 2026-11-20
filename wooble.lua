-- WoobleView (gen3-hd-sprites, by poooooby), when it's installed and on.
--
-- Its Battle Fit draws a battle's Pokémon to one scale by their real
-- heights, the camera pulling back for a tall one, for a sprite mod that
-- tags its pictures (WoobleSpritePack). Facets tags the battle pictures it
-- makes the same way: its SET's, Emerald's for FR/LG ANIMS, and YOUR SIDE:
-- FRONT's, each with its side, the Pokémon's height from the player's own
-- game (the Pokédex's), and where in the picture its art is. A sprite
-- pack's own pictures, or any picture another mod has tagged, are left to
-- it. And where the two would both draw the same thing, Facets steps
-- aside: a battle background set (SCENERY and the rest) gives way to
-- WoobleView's zoomed background, or its 3D Battle Scene. -Elvie

local wooble = {}

wooble.ID = "gen3-hd-sprites"

-- WoobleView's exports, or nil -Elvie
function wooble.exports(mod)
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return nil end
  local ok, h = pcall(mod.find, wooble.ID)
  local ex = ok and type(h) == "table" and h.exports or nil
  if type(ex) ~= "table" then return nil end
  if type(ex.isActive) == "function" then
    local okA, on = pcall(ex.isActive)
    if not (okA and on) then return nil end
  end
  return ex
end

-- Battle Fit on (it draws the battle, its background and its Pokémon,
-- zoomed to the screen) -Elvie
function wooble.fitting(mod)
  local ex = wooble.exports(mod)
  if not ex or type(ex.fitEnabled) ~= "function" then return false end
  local ok, on = pcall(ex.fitEnabled)
  return ok and on == true
end

-- A Pokémon's height in metres, from the player's own game's Pokédex,
-- or nil -Elvie
local heights = {}
function wooble.height(species)
  local sp = tonumber(species)
  if not sp then return nil end
  if heights[sp] ~= nil then return heights[sp] or nil end
  local h = false
  pcall(function()
    local Data = require("src.core.game3.pokedex_data")
    -- (its entry's raw height, by the game's own species number: getEntry
    -- would write out the weight too, in the game's text, which isn't
    -- loaded in a battle) -Elvie
    Data.init()
    local raw = type(Data._entries) == "table" and Data._entries[sp]
    local dm = type(raw) == "table" and tonumber(raw.height) or nil
    if dm and dm > 0 then h = dm / 10 end
  end)
  heights[sp] = h
  return h or nil
end

-- Where a picture's art is, { x0, y0, x1, y1 } in its pixels (past the
-- last), from its pixels, or nil -Elvie
function wooble.artBox(data)
  if not (data and data.getDimensions and data.getPixel) then return nil end
  local w, h = data:getDimensions()
  local x0, y0, x1, y1 = w, h, -1, -1
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local _, _, _, a = data:getPixel(x, y)
      if a > 0 then
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        y1 = y
      end
    end
  end
  if x1 < 0 then return nil end
  return { x0, y0, x1 + 1, y1 + 1 }
end

-- Tag a battle picture Facets made (an entry, { image, imageData }) for
-- Battle Fit: side "enemy" or "player", its species for the height. Once
-- for each picture; never one another mod tagged. Nothing without Battle
-- Fit, or a height -Elvie
local done = setmetatable({}, { __mode = "k" })
function wooble.tag(mod, entry, side, species)
  if type(entry) ~= "table" then return end
  local image = entry.image
  if not (image and image.getDimensions) or done[image] then return end
  local ex = wooble.exports(mod)
  if not ex or type(ex.tag) ~= "function" then return end
  local okF, fit = pcall(ex.fitEnabled)
  if not (okF and fit) then return end
  done[image] = true
  if type(ex.tagOf) == "function" then
    local okT, already = pcall(ex.tagOf, image)
    if okT and already ~= nil then return end
  end
  local h = wooble.height(species)
  if not h then return end
  local spec = { side = side == "player" and "player" or "enemy", height = h, texture = image, filter = "nearest" }
  local art = wooble.artBox(entry.imageData)
  if art then spec.art, spec.top = art, art[2] end
  pcall(ex.tag, image, spec)
end

-- NPC overworld sprites (gen3.lua)
-- A set's people are drawn in Gen 4 style, in 32x32 frames, a head or so
-- taller than the game's own. With WoobleView's Field HD on, the overworld
-- draws a tagged sheet at the screen's own resolution, so each NPC sheet
-- Facets builds is tagged to stand as tall as the game's own sprite there:
-- the game's sizes, with every pixel of the set's art kept. With Field HD
-- off, or without WoobleView, they're drawn as before.
--
-- The engine also makes copies of a sheet in other colours (a palette
-- swap, the water's reflection colours); those are tagged the same way, so
-- a reflection is as small as the person it reflects. `frame` has
-- WoobleView grow a piece of a frame (a reflection is drawn in slices)
-- with its whole frame, so this needs a WoobleView with `features.frame`.
-- --------------------------------------------------
wooble.NPC_FRAMES = 9   -- the walking frames: standing, stepping, each way
wooble.NPC_MIN = 0.5    -- never smaller than half
wooble.NPC_KEEP = 0.97  -- this close to the game's size, left as it is

-- The tallest art in a sheet's first n frames (fw x fh each, stacked in a
-- column), in pixels, or nil for none
function wooble.artHeight(data, fw, fh, n)
  if not (data and data.getDimensions and data.getPixel and fw and fh) then return nil end
  local w, h = data:getDimensions()
  fw = math.min(fw, w)
  local best
  for f = 0, math.min(n or 1, math.floor(h / fh)) - 1 do
    local top, bottom
    for y = 0, fh - 1 do
      for x = 0, fw - 1 do
        local _, _, _, a = data:getPixel(x, f * fh + y)
        if a > 0 then top = top or y; bottom = y; break end
      end
    end
    if top and (not best or bottom - top + 1 > best) then best = bottom - top + 1 end
  end
  return best
end

-- The size a set's sheet (record) is drawn at to stand as tall as the
-- game's own (vanilla): below 1, or nil to leave it as it is
function wooble.npcScale(vanilla, record)
  if type(vanilla) ~= "table" or type(record) ~= "table" then return nil end
  local n = wooble.NPC_FRAMES
  local own = wooble.artHeight(vanilla.imageData, vanilla.width, vanilla.height, math.min(n, vanilla.frameCount or n))
  local ours = wooble.artHeight(record.imageData, record.width, record.height, math.min(n, record.frameCount or n))
  if not (own and ours) then return nil end
  local s = own / ours
  if s >= wooble.NPC_KEEP then return nil end
  return math.max(wooble.NPC_MIN, s)
end

local npcs = { byId = {}, byQuads = setmetatable({}, { __mode = "k" }), done = setmetatable({}, { __mode = "k" }) }
local copySpec = setmetatable({}, { __mode = "k" }) -- [a sheet's reflection copies] = { mod, spec }

local function tagImage(mod, image, spec)
  if not image or npcs.done[image] then return end
  local ex = wooble.exports(mod)
  if not ex or type(ex.tag) ~= "function" then return end
  npcs.done[image] = true
  pcall(ex.tag, image, spec)
end

-- Tag an NPC sheet Facets built (gen3.lua's record) for graphics id `id`,
-- sized by the game's own sheet (vanilla)
function wooble.tagNpc(mod, record, vanilla, id)
  if type(record) ~= "table" or not record.image or not record.quads then return end
  local ex = wooble.exports(mod)
  if not ex or type(ex.tag) ~= "function" then return end
  if not (type(ex.features) == "table" and ex.features.frame) then return end
  local s = wooble.npcScale(vanilla, record)
  if not s then return end
  local spec = { scale = s, anchor = "feet", frame = { record.width, record.height }, filter = "nearest" }
  npcs.byQuads[record.quads] = spec
  if tonumber(id) then npcs.byId[tonumber(id)] = spec end
  tagImage(mod, record.image, spec)
end

-- A record the engine hands out for a sheet (OwSprites.getDraw,
-- getReflectionDraw): a copy of a tagged sheet in other colours shares its
-- quads, and is tagged the same way
function wooble.followCopy(mod, spr)
  if type(spr) ~= "table" or not spr.image or not spr.quads then return end
  local spec = npcs.byQuads[spr.quads]
  if spec then tagImage(mod, spr.image, spec) end
end

-- Ruby, Sapphire and Emerald draw reflections from copies in the water's
-- colours, kept by graphics id and colours in the engine's field effects;
-- each one made for a tagged sheet is tagged as it's kept
local WATCH = {
  __newindex = function(t, k, v)
    rawset(t, k, v)
    local c = copySpec[t]
    if c and type(v) == "table" and v.image then tagImage(c.mod, v.image, c.spec) end
  end,
}
function wooble.watchReflections(mod, id)
  id = tonumber(id)
  local spec = id and npcs.byId[id]
  if not spec then return end
  local fx = package.loaded["src.core.game3.field_effects_rse"]
  local kept = type(fx) == "table" and type(fx._images) == "table" and fx._images or nil
  if not kept then return end
  local copies = rawget(kept, id)
  if copies == nil then
    copies = {}
    kept[id] = copies
  end
  if type(copies) ~= "table" or getmetatable(copies) == WATCH then return end
  copySpec[copies] = { mod = mod, spec = spec }
  for _, v in pairs(copies) do
    if type(v) == "table" and v.image then tagImage(mod, v.image, spec) end
  end
  setmetatable(copies, WATCH)
end

-- A change of SET: its sheets are built and tagged again
function wooble.forgetNpcs()
  npcs.byId = {}
end

return wooble
