libluabox = {}
local modpath = minetest.get_current_modpath()
local jit_found = rawget(_G,"jit") ~= nil

local build_environment = dofile(modpath .. "/environment.lua")

local str_meta = getmetatable("")

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

function libluabox.load_code(sandbox, code)
	assert(type(code) == "string")
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

local function timeout_hook()
	debug.sethook()
	error("Timeout", 2)
end

local function wrapper(sandbox)
	debug.sethook(timeout_hook, "", sandbox.instruction_limit)
	local ok, err = pcall(sandbox.program)
	debug.sethook()
	if not ok then
		error(err, 0) -- propagate error
	end
end

function libluabox.run(sandbox)
	str_meta.__index = sandbox.env.string
	local ok, err = pcall(wrapper, sandbox)
	str_meta.__index = string -- this *must* be executed or weird things will happen
	return ok, err
end
