-- Built pictures, kept on the player's own install
-- With PREBUILD on, every picture Facets makes from the player's games
-- (GB EMERALD and GBC-ISH Pokémon, Crystal's sprites, Emerald's art for
-- FR/LG ANIMS, YOUR SIDE's pictures, GBC NPCs) is also written to the
-- engine's per-install mod cache (mod.cache, the place the engine keeps
-- for data made from the player's ROMs), so the next start reads them
-- back instead of building them again. -Elvie
--
-- Everything sits under a stamp made from Facets' version, the engine's
-- version and ROM cache generation, and each imported game's import
-- marker. A new Facets, a new gen1recomp or a re-imported game gives a
-- new stamp, and the old files are deleted. -Elvie
--
-- Files are groups ("mons-emerald-gb_emerald", ...), each a list of
-- entries: key, a few meta fields, size and the picture's pixels,
-- compressed. A group is read whole the first time it's asked for and
-- written whole when it has changed. -Elvie
-- --------------------------------------------------
local diskcache = {}

local MAGIC = "FACETS-PICS 1\n"
local INDEX = "index.txt"

local store       -- mod.cache, or nil when the engine has none
local stamp       -- this run's folder name
local enabled = false
local groups = {} -- [group] = { entries = { [key] = { meta, w, h, blob } }, dirty }
local listed = {} -- files named in the index
local log

-- A short, stable name for any text (djb2, 32-bit; plain arithmetic, so
-- it's the same in every Lua). -Elvie
function diskcache.hash(text)
  local h = 5381
  for i = 1, #text do
    h = (h * 33 + text:byte(i)) % 4294967296
  end
  return ("%08x"):format(h)
end

-- What the stamp is made from: one line each. -Elvie
function diskcache.stampText(facetsVersion, engine, markers)
  local lines = { "facets " .. tostring(facetsVersion), "engine " .. tostring(engine) }
  local names = {}
  for name in pairs(markers or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do lines[#lines + 1] = name .. " " .. tostring(markers[name]) end
  return table.concat(lines, "\n")
end

-- meta: a flat table of short strings and numbers -Elvie
local function encodeMeta(meta)
  local parts = {}
  for k, v in pairs(meta or {}) do parts[#parts + 1] = k .. "=" .. tostring(v) end
  table.sort(parts)
  return table.concat(parts, ";")
end
local function decodeMeta(text)
  local meta = {}
  for k, v in (text or ""):gmatch("([%w_]+)=([^;]*)") do meta[k] = tonumber(v) or v end
  return meta
end

function diskcache.encode(entries)
  local out = { MAGIC }
  local keys = {}
  for key in pairs(entries) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local e = entries[key]
    out[#out + 1] = ("%s\n%s\n%d %d %d\n"):format(key, encodeMeta(e.meta), e.w, e.h, #e.blob)
    out[#out + 1] = e.blob
  end
  return table.concat(out)
end

function diskcache.decode(bytes)
  if type(bytes) ~= "string" or bytes:sub(1, #MAGIC) ~= MAGIC then return nil end
  local entries, pos = {}, #MAGIC + 1
  while pos <= #bytes do
    local key, meta, w, h, n, after = bytes:match("^([^\n]*)\n([^\n]*)\n(%d+) (%d+) (%d+)\n()", pos)
    if not key then return nil end
    n = tonumber(n)
    if after + n - 1 > #bytes then return nil end
    entries[key] = { meta = decodeMeta(meta), w = tonumber(w), h = tonumber(h),
      blob = bytes:sub(after, after + n - 1) }
    pos = after + n
  end
  return entries
end

local function compress(raw)
  if love and love.data and love.data.compress then
    local ok, out = pcall(love.data.compress, "string", "zlib", raw)
    if ok and type(out) == "string" then return "z" .. out end
  end
  return "r" .. raw
end
local function decompress(blob)
  local kind, body = blob:sub(1, 1), blob:sub(2)
  if kind == "r" then return body end
  if kind == "z" and love and love.data and love.data.decompress then
    local ok, out = pcall(love.data.decompress, "string", "zlib", body)
    if ok and type(out) == "string" then return out end
  end
  return nil
end

local function fileOf(group) return stamp .. "/" .. group .. ".bin" end

-- Sets up the store for this run. cache is mod.cache. Old stamps'
-- files are deleted, using the index of what was written. -Elvie
function diskcache.setup(cache, stampText, logger)
  log = logger
  groups, listed = {}, {}
  if type(cache) ~= "table" or type(cache.read) ~= "function" or type(cache.write) ~= "function" then
    store = nil
    return false
  end
  store = cache
  stamp = "pics-" .. diskcache.hash(stampText)
  local ok, index = pcall(cache.read, cache, INDEX)
  index = ok and type(index) == "string" and index or ""
  local oldStamp = index:match("^stamp ([^\n]+)")
  if oldStamp == stamp then
    for file in index:gmatch("\nfile ([^\n]+)") do listed[file] = true end
  else
    if type(cache.delete) == "function" then
      for file in index:gmatch("\nfile ([^\n]+)") do pcall(cache.delete, cache, file) end
    end
    pcall(cache.write, cache, INDEX, "stamp " .. stamp .. "\n")
  end
  return true
end

local function writeIndex()
  local lines = { "stamp " .. stamp }
  local files = {}
  for file in pairs(listed) do files[#files + 1] = file end
  table.sort(files)
  for _, file in ipairs(files) do lines[#lines + 1] = "file " .. file end
  pcall(store.write, store, INDEX, table.concat(lines, "\n") .. "\n")
end

function diskcache.enable(on) enabled = on and store ~= nil or false end
function diskcache.enabled() return enabled end

local function groupOf(name)
  local g = groups[name]
  if g then return g end
  g = { entries = {}, dirty = false }
  groups[name] = g
  local ok, bytes = pcall(store.read, store, fileOf(name))
  local entries = ok and diskcache.decode(bytes) or nil
  if entries then g.entries = entries end
  return g
end

-- The picture kept for key, as ImageData, and its meta; nil when there
-- isn't one (or the cache is off). -Elvie
function diskcache.get(group, key)
  if not enabled then return nil end
  local e = groupOf(group).entries[key]
  if not e then return nil end
  local raw = decompress(e.blob)
  if not raw or #raw ~= e.w * e.h * 4 or not (love and love.image) then return nil end
  local ok, data = pcall(love.image.newImageData, e.w, e.h, "rgba8", raw)
  if not ok or not data then return nil end
  return data, e.meta
end

-- Keeps data (ImageData) under key, written at the next flush. -Elvie
function diskcache.put(group, key, data, meta)
  if not enabled or not data or type(data.getString) ~= "function" then return end
  local ok, raw = pcall(data.getString, data)
  if not ok or type(raw) ~= "string" then return end
  local w, h = data:getDimensions()
  local g = groupOf(group)
  g.entries[key] = { meta = meta or {}, w = w, h = h, blob = compress(raw) }
  g.dirty = true
end

-- Writes every changed group, and lists the files in the index. -Elvie
function diskcache.flush()
  if not store then return 0 end
  local written, newFile = 0, false
  for name, g in pairs(groups) do
    if g.dirty then
      local ok, res, err = pcall(store.write, store, fileOf(name), diskcache.encode(g.entries))
      if ok and res ~= nil and res ~= false then
        g.dirty = false
        written = written + 1
        if not listed[fileOf(name)] then listed[fileOf(name)], newFile = true, true end
      elseif log then
        log:warn("couldn't keep built pictures (%s): %s", name, tostring(ok and err or res))
      end
    end
  end
  if newFile then writeIndex() end
  return written
end

-- Whether anything waits to be written -Elvie
function diskcache.dirty()
  for _, g in pairs(groups) do if g.dirty then return true end end
  return false
end

-- Deletes everything kept, so it's built (and kept) again. -Elvie
function diskcache.clear()
  if not store then return false end
  if type(store.delete) == "function" then
    for file in pairs(listed) do pcall(store.delete, store, file) end
  end
  listed, groups = {}, {}
  writeIndex()
  return true
end

-- For the tests -Elvie
function diskcache.reset()
  store, stamp, enabled, groups, listed = nil, nil, false, {}, {}
end

return diskcache
