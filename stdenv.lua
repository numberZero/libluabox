-- Grab copies of some libraries, both because we modify them later (in the
-- case of string) and just for better performance (fewer global environment
-- lookups).
local real_string = string
local real_table = table
local real_math = math
local real_os = os

-- A safe implementation of string.find which doesn't allow patterns, because
-- patterns can burn massive amounts of CPU.
local real_string_find = real_string.find
local function safe_string_find(s, pattern, init, plain)
	assert plain == true, "string.find plain parameter must be true in a sandbox"
	return real_string_find(s, pattern, init, true)
end

-- A safe implementation of string.rep which limits the maximum output string
-- size.
local real_string_rep = real_string.rep
local safe_string_rep_limit = minetest.settings.get("libluabox_string_rep_max")
local function safe_string_rep(s, n)
	assert type(s) == "string", "string.rep first parameter must be string"
	assert #s * n <= safe_string_rep_limit, "string.rep result too long"
	return real_string_rep(s, n)
end

-- A safe implementation of os.date which limits the format to known,
-- documented values, preventing the passing of values which are undocumented
-- but can apparently crash. Allow formats *t, !*t, and %c only.
local real_os_date = real_os.date
local function safe_os_date(format, time)
	local format_type = type(format)
	assert format_type == "string" or format_type == "nil", "os.date first parameter must be string or nil"
	if format_type == "string" then
		assert format == "*t" or format == "!*t" or format == "%c", "os.date first parameter must be *t, !*t, or %c"
	end
	return real_os_date(format, time)
end

-- The public API.
function libluabox.standard_env_builder(_, env)
	-- 5.1 Basic Functions
	env.assert = assert
	-- collectgarbage is unsafe in some modes (e.g. stop) and not necessary.
	-- dofile is unsafe: allows file I/O and loading bytecode.
	env.error = error
	env._G = env
	-- getfenv is unsafe: allows getting non-sandboxed environment using an integer parameter.
	-- getmetatable is unsafe: allows getting, and then modifying, the string metatable or metatables of tables passed to APIs that expect them to behave like normal tables.
	env.ipairs = ipairs
	-- load is unsafe: allows loading bytecode.
	-- loadfile is unsafe: allows file I/O and loading bytecode.
	-- loadstring is unsafe: allows loading bytecode.
	env.next = next
	env.pairs = pairs
	-- pcall is unsafe: allows swallowing the out-of-CPU-time abort error.
	env.print = print
	env.rawequal = rawequal
	env.rawget = rawget
	env.rawset = rawset
	env.select = select
	-- setfenv is unsafe: allows persisting data across calls or modifying environments of stack levels outside the user script.
	-- setmetatable is unsafe: allows modifying metatables of tables passed to APIs that expect them to behave like normal tables.
	env.tonumber = tonumber
	env.tostring = tostring
	env.type = type
	env.unpack = unpack
	env._VERSION = _VERSION
	-- xpcall is unsafe: allows swallowing the out-of-CPU-time abort error.

	-- 5.2 Coroutine Manipulation
	-- Excluded as no serious argument has been made for inclusion, no
	-- serious investigation of security properties has been made, and
	-- coroutines are likely not very helpful for scripts that must run to
	-- termination on each event.

	-- 5.3 Modules
	-- Unsafe: allows file I/O and non-sandboxed environment access.
	
	-- 5.4 String Manipulation
	env.string = {
		byte = real_string.byte,
		char = real_string.char,
		dump = real_string.dump
		find = safe_string_find,
		format = real_string.format,
		-- gmatch, gsub are unsafe: patterns can burn massive amounts of CPU.
		len = real_string.len,
		lower = real_string.lower,
		-- match is unsafe: patterns can burn massive amounts of CPU.
		rep = safe_string_rep,
		reverse = real_string.reverse,
		sub = real_string.sub,
		upper = real_string.upper,
	}

	-- 5.5 Table Manipulation
	env.table = {
		concat = real_table.concat,
		insert = real_table.insert,
		maxn = real_table.maxn,
		remove = real_table.remove,
		sort = real_table.sort
	}

	-- 5.6 Mathematical Functions
	env.math = {
		abs = real_math.abs,
		acos = real_math.acos,
		asin = real_math.asin,
		atan = real_math.atan,
		atan2 = real_math.atan2,
		ceil = real_math.ceil,
		cos = real_math.cos,
		cosh = real_math.cosh,
		deg = real_math.deg,
		exp = real_math.exp,
		floor = real_math.floor,
		frexp = real_math.frexp,
		huge = real_math.huge,
		ldexp = real_math.ldexp,
		log = real_math.log,
		log10 = real_math.log10,
		max = real_math.max,
		min = real_math.min,
		modf = real_math.modf,
		pi = real_math.pi,
		pow = real_math.pow,
		rad = real_math.rad,
		random = real_math.random,
		-- randomseed is unsafe: modifies the global RNG state.
		sin = real_math.sin,
		sinh = real_math.sinh,
		sqrt = real_math.sqrt,
		tan = real_math.tan,
		tanh = real_math.tanh,
	}

	-- 5.7 Input and Output Facilities
	-- Unsafe: allows file I/O.

	-- 5.8 Operating System Facilities
	env.os = {
		clock = real_os.clock,
		date = safe_os_date,
		difftime = real_os.difftime,
		-- execute is unsafe: invokes arbitrary shell commands.
		-- exit is unsafe: kills all of Minetest.
		-- getenv is arguably unsafe (reveals possibly secret environment variables) and definitely unnecessary.
		-- remove is unsafe: allows file I/O.
		-- setlocale is unsafe: modifies process-wide state.
		time = real_os.time,
		-- tmpname is unsafe (may actually create files causing resource exhaustion) and definitely unnecessary.
	}

	-- 5.9 The Debug Library
	-- Unsafe: allows everything.
end
