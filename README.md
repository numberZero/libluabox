# LuaBox library
This is a helper library providing simple general-purpose sandboxing system.

License: MIT (see `LICENSE.txt` for details).

# API
All functions are contained in the `libluabox` namespace.

## Using LuaBox
Example:

```lua
local a, b = 12, 5
local sb = libluabox.create_sandbox("Example1")
libluabox.load_code(sb, "c = a + b")
sb.env.a = a
sb.env.b = b
if libluabox.run(sb) then
	print(("Success! %d + %d is %d"):format(a, b, sb.env.c))
else
	print("Fail")
end
-- drop reference to `sb`
```

### Sandbox
Main object managed by the library.

Public properties:
* `name` (string, read only) Sandbox name.
* `env` (table) The environment for the code being sandboxed. May be altered
but should not be replaced unless absolutely necessary.

Mods may add properties of form `modname:property`, if necessary.

### `create_sandbox(name, options)`
Creates and returns a sandbox with label `name`. `options` should be a table,
if supplied.

Supported options are:

* `instruction_limit` (integer) Maximum amount of instruction that may be
performed in a single run without timing out.
* `no_extras` (boolean) Blocks loading of non-core libraries.
* `no_stdlib` (boolean) Blocks loading of *all* libraries (including explicitly
specified).
* `use_*` (boolean) Whether supply the named library (may be set to `false` to
prevent inclusion of a standard library) to the sandboxed code.

### `load_code(sandbox, code)`
Loads code from string `code` into the sandbox, making it ready to run.

Returns `true` on success, `false` and error message on failure.

### `run(sandbox)`
Runs the code loaded in the sandbox.

Returns `true` on successful run, `false` and message in case of error
(including
code timing out).

### Core libraries
* `_G`: some commonly used globals like `pairs`
* `string`, `table`, `math`: safe parts of Lua standard libraries, plus
libluabox-supplied `string.strstr`
* `rawaccess`: `raw*` functions
* `random`: PRNG access

### Extra libraries
* `rstring`: restricted versions of `string.find` and `string.rep`: `find`
supports plaintext search only, `rep` has limit on result length.
* `rtime`: `os.clock`, `os.difftime`, `os.time` and `os.date`, restricted to
formats `%c`, `*t` and `!*t`.

## Extending libluabox
### Library format
The library structure is simple:

	{
		package1 = { <functions> },
		package2 = { <functions> },
		...
	}

A shallow copy of each table from the library is added to the sandbox
environment with the key as the name, merging with existing table with the same
name, if any.

### `register_library(name, library, auto_include)`
Adds `library` with name `name` to the list of extra libraries available.

If `auto_include` is `true`, the library will be added to all new sandboxes
by default.

### `add_library(sandbox, library)`
Add (unregistered) `library` to `sandbox` environment.
