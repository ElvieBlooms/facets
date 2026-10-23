-- Sprite sets and options
-- A set is a folder under assets/npcs/ with gen3/frlg/ and/or gen3/rse/
-- inside, and a meta.json with "label" (the option text) and "credit".
-- Same meta.json keys as Emerald Lens, so its tools carry over. -Elvie
local npcs = {}

local NPCS_DIR = "assets/npcs"
local OFF = "__off"

-- A small JSON reader for meta.json. The engine's own lives under
-- src.link, which would make this mod ask for the network permission just
-- to read a file. Errors on anything malformed; callers pcall it. -Elvie
-- --------------------------------------------------
local function decodeJson(text)
  local pos = 1
  local function fail(what) error(("meta.json: %s at character %d"):format(what, pos), 0) end
  local function skip() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
  local value
  local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
  local function str()
    pos = pos + 1
    local out = {}
    while true do
      local c = text:sub(pos, pos)
      if c == "" then fail("unterminated string") end
      if c == '"' then pos = pos + 1; return table.concat(out) end
      if c == "\\" then
        local e = text:sub(pos + 1, pos + 1)
        if e == "u" then
          local code = tonumber(text:sub(pos + 2, pos + 5), 16) or fail("bad \\u escape")
          out[#out + 1] = code < 128 and string.char(code) or "?"
          pos = pos + 6
        else
          out[#out + 1] = ESCAPES[e] or fail("bad escape")
          pos = pos + 2
        end
      else
        out[#out + 1] = c
        pos = pos + 1
      end
    end
  end
  function value()
    skip()
    local c = text:sub(pos, pos)
    if c == "{" then
      local t = {}
      pos = pos + 1; skip()
      if text:sub(pos, pos) == "}" then pos = pos + 1; return t end
      while true do
        skip()
        if text:sub(pos, pos) ~= '"' then fail("expected a key") end
        local k = str(); skip()
        if text:sub(pos, pos) ~= ":" then fail("expected ':'") end
        pos = pos + 1
        t[k] = value(); skip()
        local d = text:sub(pos, pos); pos = pos + 1
        if d == "}" then return t end
        if d ~= "," then fail("expected ',' or '}'") end
      end
    elseif c == "[" then
      local t = {}
      pos = pos + 1; skip()
      if text:sub(pos, pos) == "]" then pos = pos + 1; return t end
      while true do
        t[#t + 1] = value(); skip()
        local d = text:sub(pos, pos); pos = pos + 1
        if d == "]" then return t end
        if d ~= "," then fail("expected ',' or ']'") end
      end
    elseif c == '"' then
      return str()
    end
    for word, v in pairs({ ["true"] = true, ["false"] = false, ["null"] = false }) do
      if text:sub(pos, pos + #word - 1) == word then pos = pos + #word; return v end
    end
    local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
    if num and num ~= "" and tonumber(num) then pos = pos + #num; return tonumber(num) end
    fail("unexpected input")
  end
  local result = value(); skip()
  if pos <= #text then fail("trailing input") end
  return result
end

npcs.decodeJson = decodeJson

-- Adds the NPC option rows to `rows` and returns a function to call once
-- the options are defined, or nil if there's nothing to replace. Called
-- without rows, it defines its own options and starts. -Elvie
function npcs.init(mod, rows)
  if rows == nil then
    local own = {}
    local start = npcs.init(mod, own)
    if #own > 0 then mod.options:define(own) end
    if start then start() end
    return
  end
  local function isDirectory(rel)
    local info = mod.assets:info(rel)
    return info and info.type == "directory"
  end

  local function readMeta(key)
    local metaPath = NPCS_DIR .. "/" .. key .. "/meta.json"
    if mod.assets:info(metaPath) then
      local ok, decoded = pcall(decodeJson, mod:read(metaPath))
      if ok and type(decoded) == "table" then return decoded end
      mod.log:warn("%s/meta.json couldn't be read, using defaults: %s", key, tostring(decoded))
    end
    return {}
  end

  -- Sets per family, in label order. A set shows up for a family when it
  -- has that family's folder. A set with "test": true in its meta.json
  -- (TEST FRAMES) goes last, is never the default, and is only used when
  -- picked: it never fills gaps in another set. -Elvie
  -- --------------------------------------------------
  local FAMILIES = {
    { id = "frlg", suffix = "Frlg", label = "FR/LG" },
    { id = "rse",  suffix = "Rse",  label = "R/S/E" },
  }
  -- A Game Boy set (meta.json "source": "gb") has no art, only gb.json:
  -- which Gen 1/2 sprite stands in for each Gen 3 NPC, read from the
  -- player's own install (gb.lua). "scale": 2 draws them at double size,
  -- and "map": "<set>" borrows another set's gb.json instead of its own,
-- along with its strips/ folder. -Elvie
  local gbMaps, gbScale, gbStrips = {}, {}, {}
  local function readGbMap(key)
    local rel = NPCS_DIR .. "/" .. key .. "/gb.json"
    if not mod.assets:info(rel) then return nil end
    local ok, decoded = pcall(decodeJson, mod:read(rel))
    if ok and type(decoded) == "table" then return decoded end
    mod.log:warn("%s/gb.json couldn't be read: %s", key, tostring(decoded))
    return nil
  end
  local setsFor, any = { frlg = {}, rse = {} }, false
  for _, key in ipairs(mod.assets:list(NPCS_DIR)) do
    if isDirectory(NPCS_DIR .. "/" .. key) then
      local meta = readMeta(key)
      if meta.source == "gb" then
        local from = type(meta.map) == "string" and meta.map:match("^[%w_%-]+$") and meta.map or key
        gbMaps[key] = readGbMap(from)
        gbScale[key] = tonumber(meta.scale) == 2 and 2 or 1
        gbStrips[key] = NPCS_DIR .. "/" .. from .. "/strips"
      end
      local label = type(meta.label) == "string" and meta.label ~= "" and meta.label or key:upper()
      for _, family in ipairs(FAMILIES) do
        local map = gbMaps[key]
        if isDirectory(NPCS_DIR .. "/" .. key .. "/gen3/" .. family.id)
            or (map and type(map[family.id]) == "table" and next(map[family.id]) ~= nil) then
          table.insert(setsFor[family.id], { label = label, key = key, test = meta.test == true })
          any = true
        end
      end
    end
  end
  for _, sets in pairs(setsFor) do
    table.sort(sets, function(a, b)
      if a.test ~= b.test then return b.test end
      return a.label < b.label
    end)
  end
  if not any then
    mod.log:info("no sprite sets with gen3 art in %s; nothing to replace", NPCS_DIR)
    return
  end

  -- Options
  -- A heading per family, then SET: each set, plus OFF to keep the game's
  -- own NPCs. Headings are choice rows with one choice, since mod options
  -- only have rows the cursor can land on. -Elvie
  -- --------------------------------------------------
  local INERT = "_"
  for _, family in ipairs(FAMILIES) do
    local sets = setsFor[family.id]
    if #sets > 0 then
      table.insert(rows, { key = "section" .. family.suffix, type = "choice", label = family.label,
        choices = { { "", INERT } }, default = INERT })
      local choices = {}
      for _, set in ipairs(sets) do table.insert(choices, { set.label, set.key }) end
      table.insert(choices, { "OFF", OFF })
      table.insert(rows, { key = "set" .. family.suffix, type = "choice", label = "  SET",
        choices = choices, default = sets[1].key })
    end
  end
  return function()
  -- Only the running game's family is set up. -Elvie
  local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
  local layout = okVersion and GameVersion.layout(GameVersion.get())
  local running
  for _, f in ipairs(FAMILIES) do
    if f.id == layout then running = f end
  end
  if not running or #setsFor[running.id] == 0 then return end

  -- Fallback: the selected set, then the family's other sets in menu
  -- order (test sets left out), then the game's own. nil means OFF. -Elvie
  local function resolve()
    local sets = setsFor[running.id]
    local selected = mod.options:get("set" .. running.suffix)
    if selected == OFF then return nil end
    local known = false
    for _, set in ipairs(sets) do known = known or set.key == selected end
    if not known then selected = sets[1].key end
    local setKeys = { selected }
    for _, set in ipairs(sets) do
      if set.key ~= selected and not set.test then table.insert(setKeys, set.key) end
    end
    return { setKeys = setKeys, npcsDir = NPCS_DIR, gbMaps = gbMaps, gbScale = gbScale, gbStrips = gbStrips }
  end

  local handle = require("mods.facets.gen3").init(mod, resolve())
  if not handle then return end

  -- Changing SET applies straight away, no restart. -Elvie
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("mod.options_changed", function(change)
      if type(change) ~= "table" or change.mod ~= mod.id then return end
      if change.key == "set" .. running.suffix then handle.configure(resolve()) end
    end)
  end
  end
end

return npcs
