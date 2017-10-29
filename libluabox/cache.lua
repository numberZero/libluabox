-- LuaBox library
-- Copyright (c) 2017 Lobachevskiy Vitaliy

if minetest.settings:get_bool("libluabox.enable_cache") == false then
	return loadstring
end

local cache_entries_threshold = tonumber(minetest.settings:get("libluabox.cache_entries_threshold")) or 65536
local cache_size_threshold = tonumber(minetest.settings:get("libluabox.cache_size_threshold")) or 1024 * 1024
local cache_age_threshold = tonumber(minetest.settings:get("libluabox.cache_age_threshold")) or 60

local cache = {}
local cache_entries = 0
local cache_size = 0

local function cleanup()
	local time_threshold = os.time() - cache_age_threshold
	local e, s = 0, 0 -- debug
	for key, entry in pairs(cache) do
		if entry.atime < time_threshold then
			cache_entries = cache_entries - 1
			cache_size = cache_size - #key
			cache[key] = nil
		else
			e = e + 1
			s = s + #key
		end
	end
	assert(e == cache_entries)
	assert(s == cache_size)
	if cache_size < cache_size_threshold / 2 and cache_entries < cache_entries_threshold / 2 then
		return
	end
-- More aggressive cleanup needed.
-- Purge the cache, in the absence of better ideas.
	cache = {}
	cache_entries = 0
	cache_size = 0
end

local function get_or_load_string(code, label)
	local cache_entry = cache[code]
	local time = os.time()
	if cache_entry then
		cache_entry.atime = time
		if cache_entry.label ~= label then
			-- warning: labels differ
		end
		return cache_entry.program
	end
	local program, err = loadstring(code, label)
	if not program then
		return nil, err
	end
	cache[code] = {
		ctime = time,
		atime = time,
		label = label,
		program = program,
	}
	cache_entries = cache_entries + 1
	cache_size = cache_size + #code
	if cache_size > cache_size_threshold or cache_entries > cache_entries_threshold then
		minetest.after(0, cleanup)
	end
	return program
end

return get_or_load_string
