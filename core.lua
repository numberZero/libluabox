-- The maximum event count setting value.
local event_limit = minetest.settings.get("libluabox_events_max")

-- Handles a debug event indicating too much time was taken.
local function handle_timeout()
	-- Clear the hook to prevent coming back here again, and raise an error.
	debug.sethook()
	error("Code timed out!", 2)
end

-- Runs the user script inside pcall protection.
local function program_run_protected(program)
	-- Set a timeout to limit CPU time.
	debug.sethook(handle_timeout, "", event_limit)

	-- If a timeout event happens before calling the user code, handle_timeout
	-- will clear the hook and the error will propagate to the pcall in
	-- program_run. It will not propagate further out, nor will further timeout
	-- events happen, so cleanup in program_run is not at risk of being
	-- skipped.

	-- Run the user code. If a timeout event happens while the user code is
	-- running, handle_timeout will clear the hook and the error will propagate
	-- to here and stop. If any other error occurs, the error will propagate to
	-- here and stop, and the event limit will still apply; see below for what
	-- happens then.
	local ok, error_message = pcall(program.func)

	-- If a timeout event happens here, after the user code returns,
	-- handle_timeout will clear the hook and the error will propagate to the
	-- pcall in program_run. This will replace any error which we might
	-- previously have been trying to report, but that's not a big deal. It
	-- will not propagate further out, nor will further timeout events happen,
	-- so cleanup in program_run is not at risk of being skipped.

	-- Clear the CPU time limit.
	debug.sethook()

	-- Report the error, if there was one.
	if not ok then
		error(error_message, 0)
	end
end

-- Public API program:run.
local function program_run(program)
	-- Build the environment.
	local env = {}
	for _, builder in ipairs(program.env_builders) do
		builder(program, env)
	end

	-- If s is a string and f is a function in the string library, then
	-- s:f(args) is equivalent to string.f(s, args). However, the string used
	-- for lookup is the original string library, not whatever happens to be
	-- called "string" in the global environment at the moment the code is
	-- executed. This is implemented by strings sharing a metatable, and that
	-- metatable's __index pointing at the "string" table. We want to prevent
	-- user scripts from accessing unsafe functions in the string library; to
	-- do this, get the metatable for all strings and change its __index to
	-- point at our sandboxed "string" table while running the script, then
	-- change it back after.
	local string_metatable = getmetatable("")
	local original_string_index = string_metatable.__index
	string_metatable.__index = env.string

	-- Set the script's environment.
	setfenv(program.func, env)

	-- Run the script. Use pcall to ensure that no error can possibly escape.
	-- See program_run_protected for a bit more on why this level of pcall is
	-- necessary.
	local ok, error_message = pcall(program_run_protected, program)

	-- Change the string metatable's __index back to its proper value.
	string_metatable.__index = original_string_index

	-- Rip the environment out, to prevent denial of service by having many
	-- user scripts all construct big objects and just leave them lying around
	-- their environments taking up memory.
	setfenv(program.func, {})

	-- Report the environment or error message to the caller.
	if ok then
		return env
	else
		error(error_message, 0)
	end
end

-- The member functions on a program object.
local program_class = {
	run = program_run,
}

-- The metatable for all program objects.
local program_metatable = {
	__index = program_class,
}

-- Public API.
function libluabox.create_program(src, env_builders, name)
	-- Compile the source code, checking that it's really source and not
	-- bytecode.
	assert type(src) == "string", "libluabox.create_program first parameter must be string."
	assert src:byte(1) ~= 27, "libluabox.create_program first parameter must not be bytecode."
	local func, error_message = loadstring(src, name)
	if func == nil then
		error(error_message, 0)
	end

	-- Disable JIT so that the event counter debug hook works, if we are
	-- running Luajit.
	if minetest.global_exists("jit") then
		jit.off(func, true)
	end

	-- Return a program object.
	local program = {
		func = func,
		env_builders = env_builders,
	}
	setmetatable(program, program_metatable)
	return program
end
