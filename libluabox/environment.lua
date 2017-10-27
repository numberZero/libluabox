local standard_library = {
	_G = { "assert", "error", "ipairs", "next", "pairs", "select", "type",
		"unpack", "tostring", "tonumber" },
	string = { "byte", "char", "format", "len", "lower", "reverse",
		"strstr", "sub", "upper" },
	table = { "concat", "insert", "maxn", "remove", "sort" },
	math = { "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "cosh",
		"deg", "exp", "floor", "fmod", "frexp", "huge", "ldexp",
		"log", "log10", "max", "min", "modf", "pi", "pow", "rad",
		"sin", "sinh", "sqrt", "tan", "tanh" },
}

local optional_library = {
	rawaccess = { _G = { "rawequal", "rawget", "rawset" }},
	random = { math = { "random", "randomseed" }},
}

local extra_library = {}
local auto_included_libs = {}

local function add_system_lib(env, name, list)
	local source = _G[name]
	local target = env[name]
	if not target then
		target = {}
		env[name] = target
	end
	for _, key in ipairs(list) do
		target[key] = source[key]
	end
end

local function add_extra_lib(env, name, source)
	local target = env[name]
	if not target then
		target = {}
		env[name] = target
	end
	for key, member in pairs(source) do
		target[key] = member
	end
end

local function build_environment(options)
	local env = {}
	env._G = env
	env._VERSION = _VERSION
	if options.no_stdlib then
		return env
	end
	for name, list in pairs(standard_library) do
		if options["use_" .. name] ~= false then
			add_system_lib(env, name, list)
		end
	end
	for group, contents in pairs(optional_library) do
		if options["use_" .. group] then
			for name, list in pairs(contents) do
				add_system_lib(env, name, list)
			end
		end
	end
	if options.no_extra then
		return env
	end
	for group, library in pairs(extra_library) do
		local include = options["use_" .. group]
		if include == nil then
			include = auto_included_libs[group]
		end
		if include then
			for name, contents in pairs(library) do
				add_extra_lib(env, name, contents)
			end
		end
	end
	return env
end

function libluabox.register_library(name, library, auto_include)
	if extra_library[name] then
		error("Library " .. name .. " already registered")
	end
	extra_library[name] = library
	if auto_include then
		auto_included_libs[name] = true
	end
end

function libluabox.add_library(sandbox, library)
	for name, contents in pairs(library) do
		add_extra_lib(sandbox.env, name, contents)
	end
end

return build_environment
