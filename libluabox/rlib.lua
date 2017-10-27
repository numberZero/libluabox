local strrep_limit = tonumber(minetest.settings:get("libluabox.string_rep_limit")) or 65536

function string.strstr(haystack, needle, base)
	return string.find(haystack, needle, base or 1, true)
end

local rstring = {}

function rstring.find(s, pattern, init, plain)
	assert(plain == true, "Only plain find is allowed")
	return string.find(s, pattern, init, true)
end

function rstring.rep(s, n)
	assert(type(s) == "string")
	if n * #s > strrep_limit then
		error("String repeat limit exceeded")
	end
	return string.rep(s, n)
end


local rtime = {}
rtime.clock = os.clock
rtime.difftime = os.difftime
rtime.time = os.time

function rtime.date(format, time)
	assert(format == nil or format == "%c" or format == "*t" or format == "!*t",
		"Date formats are restricted")
	return os.date(format, time)
end

libluabox.register_library("rstring", {string = rstring}, true)
libluabox.register_library("rtime", {os = rtime})
