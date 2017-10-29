libluabox = {}
local modpath = minetest.get_modpath("libluabox")
local jit_found = rawget(_G,"jit") ~= nil

local build_environment = dofile(modpath .. "/environment.lua")
local loadstring = dofile(modpath .. "/cache.lua")
dofile(modpath .. "/rlib.lua")

local str_meta = getmetatable("")

function libluabox.create_sandbox(name, options)
	options = options or {}
	assert(type(name) == "string")
	assert(type(options) == "table")
	local sandbox = {}
	sandbox.name = name
	sandbox.instruction_limit = tonumber(options.instruction_limit) or 8192
	sandbox.env = build_environment(options)
	return sandbox
end

function libluabox.load_code(sandbox, code)
	assert(type(code) == "string")
	local f, err = loadstring(code, "Code for " .. sandbox.name)
	if not f then
		return false, err
	end
	if jit_found then
		jit.off(f, true)
	end
	sandbox.program = f
	return true
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
	if not sandbox.program then
		return false, "Sandbox has no code"
	end
	setfenv(sandbox.program, sandbox.env) -- make sure the environment is correct
	str_meta.__index = sandbox.env.string -- prevent string methods leakage
	local ok, err = pcall(wrapper, sandbox)
	str_meta.__index = string -- this *must* be executed or weird things will happen
	setfenv(sandbox.program, nil) -- drop the reference to `env`
	-- `program` may be shared due to caching, so could hold `env`
	-- in memory after sandbox destruction otherwise
	return ok, err
end
