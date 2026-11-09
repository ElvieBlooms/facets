-- Kanto Reforged's animations on YOUR SIDE
-- Kanto Reforged (1jamie) gives its Pokémon idle strips and plays them on
-- the foe's side only, twice through when it comes out, then holds the
-- first frame. With YOUR SIDE on FRONT or MIRRORED your Pokémon is its
-- front picture, so it plays the same strip the same way when it's sent
-- out, mirrored for MIRRORED. Everything is read from Kanto Reforged's own
-- front_anim module while it's loaded, so its art and timings stay its
-- own; without it, none of this does anything -Elvie
-- --------------------------------------------------

local kr = {}

kr.MODULE = "mods.Kanto-Reforged.battle.front_anim"

-- Kanto Reforged's front_anim, if it's loaded -Elvie
function kr.api()
  local FA = package.loaded[kr.MODULE]
  if type(FA) ~= "table" or type(FA.prefersKrAnim) ~= "function" or type(FA.meta) ~= "function"
      or type(FA.stripPath) ~= "function" or type(FA.stepState) ~= "function" then return nil end
  return FA
end

-- Whether Kanto Reforged animates this Pokémon itself -Elvie
function kr.owns(battle, mon)
  local FA = kr.api()
  if not (FA and type(mon) == "table" and mon.species) then return false end
  local ok, yes = pcall(FA.prefersKrAnim, mon.species, battle, mon, FA._mod)
  return ok and yes and true or false
end

kr.RESOLVE = "mods.Kanto-Reforged.core.sprite_resolve"

-- Whether it draws this picture itself (its own art for the species and
-- side), answering before Facets is asked -Elvie
function kr.answers(species, side, path)
  local SR, FA = package.loaded[kr.RESOLVE], kr.api()
  if not (type(SR) == "table" and type(SR.resolvePath) == "function" and FA and FA._mod and species) then return false end
  local ok, alt = pcall(SR.resolvePath, FA._mod, species, side, path)
  return ok and type(alt) == "string" and alt ~= ""
end

-- What it plays for a Pokémon, or nil: { meta, animId, path } -Elvie
function kr.strip(battle, mon)
  if not kr.owns(battle, mon) then return nil end
  local FA = kr.api()
  local animId = mon.species
  if type(FA.animSpeciesId) == "function" then
    local ok, id = pcall(FA.animSpeciesId, mon.species, battle, mon)
    if ok and id then animId = id end
  end
  local okM, meta = pcall(FA.meta, animId)
  if not (okM and type(meta) == "table" and meta.frontW and meta.frontH) then return nil end
  local okP, path = pcall(FA.stripPath, FA._mod, mon.species, battle, mon)
  if not (okP and type(path) == "string") then return nil end
  return { meta = meta, animId = animId, path = path }
end

-- A player of a strip, ticked once a frame: step() gives its frame
-- (1 = the still pose) or nil once it's done, the way Kanto Reforged plays
-- the foe's -Elvie
function kr.player(meta)
  local FA = kr.api()
  if not FA then return nil end
  local st = { frame = 1, timer = 0, cycles = 0, done = false }
  local self = {}
  function self.step()
    if st.done then return nil end
    local ok = pcall(FA.stepState, st, meta)
    if not ok or st.done then return nil end
    return st.frame
  end
  function self.frame() return (not st.done) and st.frame or nil end
  return self
end

-- Where frame n (1-based) sits in the strip, as x, y, w, h -Elvie
function kr.rect(meta, n, stripW, stripH)
  local fw, fh = meta.frontW, meta.frontH
  local x, y = (n - 1) * fw, 0
  local FA = kr.api()
  if FA and type(FA.frameOffset) == "function" then
    local ok, ox, oy = pcall(FA.frameOffset, meta, n, stripW, stripH)
    if ok and ox then x, y = ox, oy end
  end
  if x + fw > stripW or y + fh > stripH then return nil end
  return x, y, fw, fh
end

-- Frame n of a strip as ImageData, mirrored if asked -Elvie
function kr.cut(data, meta, n, mirror)
  local w, h = data:getDimensions()
  local x, y, fw, fh = kr.rect(meta, n, w, h)
  if not x then return nil end
  local out = love.image.newImageData(fw, fh)
  out:paste(data, 0, 0, x, y, fw, fh)
  if mirror then
    local flipped = love.image.newImageData(fw, fh)
    for py = 0, fh - 1 do
      for px = 0, fw - 1 do flipped:setPixel(px, py, out:getPixel(fw - 1 - px, py)) end
    end
    out = flipped
  end
  return out
end

return kr
