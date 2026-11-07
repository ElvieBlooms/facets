-- The DS games, through Prism Importer
-- Prism Importer (a separate mod) pulls sprites out of the player's own
-- Diamond/Pearl/Platinum, HeartGold/SoulSilver and Black 2/White 2 dumps
-- and hands them out through its exports. This file reads them for
-- Facets: which dumps are there, and each picture fitted to what Gen 3
-- draws. Nothing from the games ships with Facets; without Prism Importer
-- (or before a dump is imported) every DS choice falls back to the sets
-- Facets ships. -Elvie
-- --------------------------------------------------

local ds = {}

local SIZE = 64

-- The dumps, in menu order: Prism Importer's id and the label -Elvie
ds.GAMES = {
  { id = "dppt", label = "DPPT", name = "Diamond, Pearl or Platinum" },
  { id = "hgss", label = "HGSS", name = "HeartGold or SoulSilver" },
  { id = "bw2", label = "B2W2", name = "Black 2 or White 2" },
}
ds.NAMES = {}
for _, g in ipairs(ds.GAMES) do ds.NAMES[g.id] = g end

-- Prism Importer's exports, or nil -Elvie
function ds.api(mod)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, other = pcall(mod.find, "prism_importer")
  local api = ok and type(other) == "table" and other.exports
  if type(api) ~= "table" or api.apiVersion ~= 1 then return nil end
  return api
end

-- A dump's state: "ready", "needed", "queued", "running", "failed", or
-- "absent" (not picked, or no Prism Importer) -Elvie
function ds.state(api, game)
  if not api or type(api.status) ~= "function" then return "absent" end
  local ok, all = pcall(api.status)
  local st = ok and type(all) == "table" and all[game]
  return type(st) == "table" and tostring(st.state or "absent") or "absent"
end

-- The dumps the player has picked in Prism Importer, imported or not:
-- the DS choices Facets offers -Elvie
function ds.picked(api)
  local out = {}
  for _, g in ipairs(ds.GAMES) do
    if ds.state(api, g.id) ~= "absent" then out[#out + 1] = g end
  end
  return out
end

-- Gen 3's Castform and Deoxys variants by Prism Importer's form names:
-- Gen 4 by name, Black 2/White 2 by number (the games' own order) -Elvie
local FORMS4 = { _sunny = "sun", _rainy = "rain", _snowy = "ice",
  _attack = "attack", _defense = "defense", _speed = "speed" }
local FORMS5 = { _sunny = "1", _rainy = "2", _snowy = "3",
  _attack = "1", _defense = "2", _speed = "3" }
local UNOWN4 = {}
for i = 1, 26 do UNOWN4[i - 1] = string.char(96 + i) end
UNOWN4[26], UNOWN4[27] = "exclamation_mark", "question_mark"

-- Prism Importer's battle sprite id for a Gen 3 picture, or nil. kind is
-- "front" or "back"; nat a national number or "egg"; letter Unown's
-- (0 = A, 26 = !, 27 = ?); variant "" or a Castform / Deoxys suffix -Elvie
function ds.monId(game, kind, shiny, nat, letter, variant)
  local gen5 = game == "bw2"
  if nat == "egg" then
    if gen5 or kind ~= "front" then return nil end
    return "normal/egg/normal"
  end
  if type(nat) ~= "number" or nat < 1 then return nil end
  local id = ("%s/%03d/%s"):format(shiny and "shiny" or "normal", nat, kind)
  if nat == 201 and (letter or 0) > 0 then
    if gen5 then return id .. "/form/" .. letter end
    local name = UNOWN4[letter]
    return name and (id .. "/form/" .. name) or nil
  end
  if variant and variant ~= "" then
    local form = (gen5 and FORMS5 or FORMS4)[variant]
    if not form then return nil end
    return id .. "/form/" .. form
  end
  return id
end

-- How a picture of w x h (its drawn part) fits Gen 3's 64x64: fronts
-- shrink to fit whole; backs keep their top 64 rows (the DS hides a back's
-- lower part behind the text box), then shrink if still too wide. Returns
-- the rows to keep and the scale -Elvie
function ds.fitPlan(w, h, back)
  local keepH = h
  if back and h > SIZE then keepH = SIZE end
  local scale = math.min(1, SIZE / w, SIZE / keepH)
  return keepH, scale
end

-- Which frames of a sheet to use: the still picture, and for a front the
-- one Gen 3's two-frame animation shows second (a Gen 4 front's second
-- frame; for Black 2/White 2's idle, the middle of it) -Elvie
function ds.altFrame(game, frames)
  frames = tonumber(frames) or 1
  if frames < 2 then return nil end
  if game == "bw2" then return math.max(1, math.floor(frames / 2)) end
  return 1
end

-- The drawn rectangle of frames (each { x, y } in the sheet), all
-- together, so every frame is cut the same way and stays in place -Elvie
local function drawnBox(sheet, fw, fh, frames)
  local x0, y0, x1, y1
  for _, f in ipairs(frames) do
    for y = 0, fh - 1 do
      for x = 0, fw - 1 do
        local _, _, _, a = sheet:getPixel(f[1] + x, f[2] + y)
        if a > 0 then
          x0 = (not x0 or x < x0) and x or x0
          x1 = (not x1 or x > x1) and x or x1
          y0 = (not y0 or y < y0) and y or y0
          y1 = (not y1 or y > y1) and y or y1
        end
      end
    end
  end
  if not x0 then return nil end
  return x0, y0, x1 - x0 + 1, y1 - y0 + 1
end

-- A battle sprite's picture for Gen 3: frame 0 (or, with alt, the
-- animation's second frame), fitted to 64x64 or less, as ImageData; nil
-- when the dump or the picture isn't there. Both frames are cut from the
-- same rectangle, so they line up -Elvie
function ds.monPicture(api, game, id, back, alt)
  if not (api and type(api.imageData) == "function" and id) then return nil end
  local ok, sheet, entry = pcall(api.imageData, game, "battle_sprites", id)
  if not (ok and sheet and type(entry) == "table") then return nil end
  local sp = type(entry.sprite) == "table" and entry.sprite or {}
  local sw, sh = sheet:getDimensions()
  local fw, fh = tonumber(sp.width) or sh, tonumber(sp.height) or sh
  local cols = math.max(1, tonumber(sp.columns) or math.floor(sw / fw))
  local count = tonumber(sp.frames) or tonumber(entry.frames) or math.floor(sw / fw)
  local function at(n) return { (n % cols) * fw, math.floor(n / cols) * fh } end
  local frames = { at(0) }
  local second = not back and ds.altFrame(game, count) or nil
  if second then frames[2] = at(second) end
  if alt and not second then return nil end
  local bx, by, bw, bh = drawnBox(sheet, fw, fh, frames)
  if not bx then return nil end
  local keepH, scale = ds.fitPlan(bw, bh, back)
  local from = alt and frames[2] or frames[1]
  local ow, oh = math.max(1, math.floor(bw * scale + 0.5)), math.max(1, math.floor(keepH * scale + 0.5))
  local out = love.image.newImageData(ow, oh)
  for y = 0, oh - 1 do
    local sy = from[2] + by + math.min(keepH - 1, math.floor(y / scale))
    for x = 0, ow - 1 do
      local sx = from[1] + bx + math.min(bw - 1, math.floor(x / scale))
      out:setPixel(x, y, sheet:getPixel(sx, sy))
    end
  end
  return out
end

return ds
