if minetest.settings.get_bool("libluabox.enable_cache") == false then
	return loadstring
end

local cache = {}

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
	return program
end

return get_or_load_string
