libluabox = {}

local core_whitelist = { "assert", "error", "ipairs", "next", "pairs", "select", "type", "unpack" }

local Sandbox = {}

function libluabox.create_sandbox(name)
	local sandbox = setmetatable({}, {__index = Sandbox}) -- instantiate Sandbox
	assert(type(name) == "string")
	sandbox.name = name
	sandbox.env = {}
	sandbox.env._G = sandbox.env
	sandbox.env._VERSION = _VERSION
	return sandbox
end

function Sandbox:include_core(whitelist = core_whitelist)
	for _, k in ipairs(whitelist) do
		self.env[k] = _G[k]
	end
end

function Sandbox:include_package(name, package, whitelist)
	local target = self.env[name] or {}
	if whiltelist == true then
		for k, v in pairs(package) do
			target[k] = package[k]
		end
	else
		for _, k in ipairs(whitelist) do
			target[k] = package[k]
		end
	end
	self.env[name] = {}
end

function Sandbox:load_code(code)
	local f, err = loadstring(code, "Code for " .. name)
	if err then
		return false, err
	end
	setfenv(f, self.env)
	self.program = f
end

function Sandbox:run()
	-- warning: we are messing with superglobals here!
	-- be *extremely* sure to revert *all* changes!
	local string_meta = getmetatable("")
	local string_index = string_meta.__index
	string_meta.__index = self.env.string
-- self.program()
	string_meta.__index = string_index
end
