libluabox = {}

local jit_found = rawget(_G,"jit") ~= nil

local standard_library = {
	_G = { "assert", "error", "ipairs", "next", "pairs", "select", "type", "unpack" },
	string = { "byte", "char", "format", "len", "lower", "reverse", "sub", "upper" },
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
	for name, list in standard_library do
		if options["use_" .. name] ~= false then
			add_system_lib(env, name, list)
		end
	end
	for group, contents in optional_library do
		if options["use_" .. group] then
			for name, list in contents do
				add_system_lib(env, name, list)
			end
		end
	end
	if options.no_extra then
		return env
	end
	for group, library in extra_library do
		if options["use_" .. group] then
			for name, contents in library do
				add_extra_lib(env, name, contents)
			end
		end
	end
	return env
end

function libluabox.create_sandbox(name, options)
	options = options or {}
	assert(type(name) == "string")
	assert(type(options) == "table")
	local sandbox = {}
	sandbox.name = name
	sandbox.instruction_limit = tonumber(options.instruction_limit or 8192)
	sandbox.env = build_environment(options)
	return sandbox
end

function libluabox.add_library(sandbox, library)
	for name, contents in library do
		add_extra_lib(sandbox.env, name, contents)
	end
end

function libluabox.load_code(sandbox, code)
	local f, err = loadstring(code, "Code for " .. sandbox.name)
	if err then
		return false, err
	end
	setfenv(f, sandbox.env)
	if jit_found then
		jit.off(f, true)
	end
	sandbox.program = f
end

function Sandbox:_enter()
	-- warning: we are messing with superglobals here!
	-- be *extremely* sure to revert *all* changes!
	self._string_meta = getmetatable("")
	self._string_index = self._string_meta.__index
	self._string_meta.__index = self.env.string
end

function Sandbox:_leave()
	self._string_meta.__index = self._string_index
end

function Sandbox:_work()
	local hook = function() self._error ="Timeout"; error() end
	debug.sethook(hook,"", self.instruction_limit)
	pcall(self.program)
	debug.sethook()
end

function Sandbox:run()
	self._error = nil
	self:_enter()
	local done, msg = pcall(self._work, self)
	self:_leave()
	if done then
		if not self._done then
			self._error = "Error in sandboxed code:" .. tostring(self._error)
		end
	else
		selt._done = false
		self._error = "Code timed out."
	end
end
