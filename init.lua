libluabox = {}

local jit_found = rawget(_G, "jit") ~= nil

local core_whitelist = { "assert", "error", "ipairs", "next", "pairs", "select", "type", "unpack" }

local Sandbox = {}

function libluabox.create_sandbox(name)
	local self = setmetatable({}, {__index = Sandbox}) -- instantiate Sandbox
	assert(type(name) == "string")
	self.name = name
	self.env = {}
	self.env._G = self.env
	self.env._VERSION = _VERSION
	self.instruction_limit = 10000
	return self
end

function Sandbox:include_core(whitelist)
	for _, k in ipairs(whitelist or core_whitelist) do
		self.env[k] = _G[k]
	end
end

function Sandbox:include_library(name, whitelist)
	local library = _G[name]
	local target = {}
	assert(type(library) == "table")
	if whitelist == true then
		for k, v in pairs(library) do
			target[k] = library[k]
		end
	else
		assert(type(whitelist) == "table")
		for _, k in ipairs(whitelist) do
			target[k] = library[k]
		end
	end
	self.env[name] = target
end

function Sandbox:load_code(code)
	local f, err = loadstring(code, "Code for " .. self.name)
	if err then
		return false, err
	end
	setfenv(f, self.env)
	if jit_found then
		jit.off(f, true)
	end
	self.program = f
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
	debug.sethook(error, "", self.instruction_limit)
	print(pcall(self.program))
	debug.sethook()
end

function Sandbox:run()
	self:_enter()
	print(pcall(self._work, self))
-- 	local result = pcall(self._work, self)
	self:_leave()
	return result
end
