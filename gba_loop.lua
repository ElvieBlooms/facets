-- ANIMATION: LOOP for the GBA games' own animations
-- FireRed to Emerald play a Pokémon's animation (Emerald's hops and
-- shakes, and the GBC looks' Crystal frames, which ride on it) once, as it
-- comes out. With LOOP, while the battle waits for your command, each
-- Pokémon on the field plays it again after a rest, with no cry, as the
-- DS and BW looks already loop theirs. INTRO and OFF leave the game's
-- single play -Elvie
-- --------------------------------------------------

local loop = {}

loop.REST = 3 -- seconds between plays -Elvie

-- Whether this POKéMON set loops on its own already (DS and BW pictures
-- step through their frames by the clock, in mons.lua) -Elvie
function loop.ownLoop(set)
  set = tostring(set or "")
  return set == "ds" or set == "bw_anim" or set:sub(1, 3) == "ds_"
end

-- Whether a Pokémon that's been still for `still` seconds should play
-- again -Elvie
function loop.due(mode, phase, still, rest)
  return mode == "loop" and phase == "command" and (still or 0) >= (rest or loop.REST)
end

function loop.init(mod)
  return function()
    local okB, MAB = pcall(require, "src.core.game3.battle.mon_anim_battle")
    if not (okB and type(MAB) == "table" and type(MAB.start) == "function") then return end
    local bw = require("mods.facets.bw")
    -- the last animation started for each battler: key and kind, and how
    -- long it's been still -Elvie
    local shown = {}
    local own = MAB.start
    MAB.start = function(key, kind, opts, ...)
      local sprite = own(key, kind, opts, ...)
      if sprite and key ~= nil then shown[key] = { kind = kind, still = 0 } end
      return sprite
    end
    local function battle()
      local B = package.loaded["src.core.game3.battle"]
      return type(B) == "table" and B or nil
    end
    -- once a frame, after the game's own update (Game3:update, which runs
    -- however the game is driven) -Elvie
    local function tick(dt)
      local B = battle()
      local active = B and type(B.isActive) == "function" and B.isActive()
      if not active then
        if next(shown) then shown = {} end
        return
      end
      local mode = bw.mode(mod)
      if mode ~= "loop" or loop.ownLoop(mod.options:get("setMons")) then return end
      local phase = B._phase
      -- only a Pokémon that's out and standing: a fainted one, or one gone
      -- from the field, is never brought back to play -Elvie
      local okS, State = pcall(require, "src.core.game3.battle.state")
      local okA, Anim = pcall(require, "src.core.game3.battle.anim")
      local function standing(key)
        local st = B._st
        local b
        if type(key) == "number" then b = okS and st and State.battler(st, key)
        else b = type(st) == "table" and st[key] or nil end
        if not b or b.fainted or (tonumber(b.mon and b.mon.hp) or 0) <= 0 then return false end
        local p = okA and type(Anim.present) == "function" and Anim.present(key)
        return not (p and p.visible == false)
      end
      for key, s in pairs(shown) do
        if not standing(key) then
          s.still = 0
        elseif MAB.busy({ key }) then
          s.still = 0
        else
          s.still = s.still + (tonumber(dt) or 0)
          if loop.due(mode, phase, s.still, loop.REST) then
            s.still = 0
            own(key, s.kind, { noCry = true })
          end
        end
      end
    end
    local okG, Game3 = pcall(require, "src.core.Game3")
    if okG and type(Game3) == "table" and type(Game3.update) == "function" and not Game3.facetsLoop then
      Game3.facetsLoop = true
      local update = Game3.update
      Game3.update = function(self, dt, ...)
        local results = { update(self, dt, ...) }
        local ok, err = pcall(tick, dt)
        if not ok then mod.log:warn("ANIMATION: LOOP: %s", tostring(err)) end
        return unpack(results)
      end
    end
  end
end

return loop
