# Concept
libluabox is a secure sandbox for running untrusted Lua code. For example, it can be used to allow players to write their own Lua code which can run on some sort of item or node in-game, which is (hopefully) safe to deploy even in a multiplayer environment. libluabox sandboxes its code in three ways: it uses a custom whitelist-based global environment to prevent access to dangerous APIs such as the `io` standard library and the `minetest` core library, it replaces certain dangerous but useful APIs with wrappers that restrict them to a safe subset of their functionality, and it limits the amount of processor time that an untrusted script can consume by setting an event count debug hook.

libluabox doesn’t add any items, nodes, or other player-interactable objects. It’s a library providing sandboxing services to other mods, which add their own items and nodes.

libluabox is built around the concept of a *program object*. A program object represents a particular piece of code and the associated metadata needed to run it in whatever form is most optimal for the environment. A program object is a table. Some fields in the table (documented in this README) are public and are meant to be read or consumed by the mod that is using libluabox. libluabox also adds other fields to the table which are private and subject to change and should not be relied upon by consuming mods. Mods should also not add their own fields to the table except as documented here, lest they collide with future enhancements of libluabox. Although it is possible to construct a fresh program object every time code is to be run, the intent is that mods which run the same code frequently will construct a single program object, cache it (perhaps in a weak table), and reuse it for multiple invocations. Each invocation will run in a fresh environment, but reusing the program object will save time on re-parsing the source code. Mods that cache program objects must handle cache invalidation appropriately to ensure that the program object is discarded when the source code is changed or no longer applicable (e.g. due to a node being dug).

Like any software, libluabox is a best effort attempt and may contain bugs. Trusting the security of critical data to libluabox alone is probably a poor decision. Responsible server operators should follow the principle of defense in depth by using appropriate OS-level isolation (dedicated user IDs, `chroot`s, containers, etc.) to prevent their Minetest server process from affecting non-Minetest-related files and processes, and should take regular backups of their Minetest worlds to mitigate the potential damage caused by an exploit.

# API
## `function libluabox.create_program(src, env_builders, name)`
Constructs and returns a new program object.

* `src` is a string containing the program’s source code.
* `env_builders` is a numerically indexed table containing the environment builders to apply when running the program. Each environment builder must be a function taking two parameters, the program object and the environment table under construction, and modifying the environment table as desired. The event builders are invoked in the order they appear in the table, which allows later builders to override earlier ones. Most mods will want to use some of the standard environment builders provided by libluabox and also add their own custom environment builders depending on how they want the scripts to interact with the world.
* `name` is the name of the program, which is reported in certain error messages.

In the event that the source code doesn’t compile, an error is raised; calling mods probably want to use `pcall` or `xpcall` in order to report this error to the player usefully and avoid crashing the world.

## `function libluabox.standard_env_builder(program, env)`
The standard environment builder which adds the safe subset of the Lua standard library to the environment. Most consumers will want to place this function first in the `env_builders` list passed to `libluabox.create_program`.

## `function libluabox.make_digilines_env_builder(pos, rules)`
Constructs and returns an environment builder that provides a Digilines API.

* `pos` is the node position from which the Digilines messages should be emitted.
* `rules` is the connectivity rules for connecting to Digilines conductors, which can be omitted to use the default rules.

The Digilines API exposed to the script is `function digiline_send(channel, msg)`. `channel` must be a string which is the channel name to send on. `msg` is the message to send; anything that’s not a boolean, number, string, or table is filtered out (including keys and values of tables, recursively). `true` is returned if a message is sent (including if some but not all of the message was filtered); `false` is returned if the message exceeded the cost limit or was completely filtered out due to being e.g. a function.

It is acceptable to call this function and use the resulting environment builder without first checking whether Digilines is present. If Digilines is absent, the environment builder will successfully do nothing, and the `digiline_send` function will not be present in the script’s global environment.

## `function program:run()`
Runs the target script. If the script successfully runs to completion, the return value is the global environment that the script used, including any modifications the script made. Otherwise, an appropriate error is raised; calling mods probably want to use `pcall` or `xpcall` in order to report this error to the player usefully and avoid crashing the world.

## Field `program.mod_data`
This field is not, and will never be, touched in any way by libluabox. Mods consuming libluabox can therefore rely on it being set to `nil` on a freshly created program object, and can store any value of any type in it for later access. Mods needing to attach more than one value to a program object should do so by setting `mod_data` to a table and storing the values in that table. Mods that share program objects between them must come up with their own conventions for what will be stored in `mod_data`; that is outside the scope of libluabox itself to decide.

# Guidelines for environment builders
When writing environment builders, consider the following guidelines:

* Never expose a table that you don’t want modified. You might intend for the script to *read* the entire contents of a table, but remember that the script could also *modify* the table. If you’re going to add a table to the environment, you probably want to create a fresh one on every invocation, perhaps copying an existing one, rather than just adding a reference to an existing table. You might also be able to protect a table from modification using a metatable (remember that scripts don’t, by default, get access to `rawget` and `rawset` functions).
* When adding an exposed function, always consider every possible type of value the script might pass as a parameter. What happens if this string is actually a function? If this number is actually `nil`? When in doubt, check every parameter with an `assert(type(param) == "whatever")` at the top of the function, before doing any work.
* If an exposed function accepts a mutable type (e.g. a table) as a parameter, remember that the script could keep a reference to it and modify it after your function finishes running. If you sanity-check the contents of the table and then store it somewhere for later reference, the script can just put the illegal stuff in after the check. When in doubt, either duplicate the table (be sure to deep copy) or move the sanity check to after the script finishes running.
* Never call a function that the script handed you. There is probably no reason why you should ever accept a function, either directly as a parameter or in a table.
* Your exposed function’s code counts against the script’s CPU time quota. If this is what you want, great. If not, consider doing minimal work in your function and then deferring the rest of the work to after the script finishes.
* Remember that your exposed function might be randomly interrupted at any moment should the CPU time quota expire. Don’t do anything that requires that two operations both complete in order to avoid violating invariants. Building a big table and then assigning it to a variable is fine, as the assignment will either happen or not; assigning it first and then populating it is bad as you might not get a chance to populate it.
* Never, ever swallow errors. Try to avoid using `pcall` or `xpcall` in your exposed functions. If you must do so, then be sure to re-raise the error rather than returning normally to the script. Violating this can grant a script infinite CPU time.
* Due to technical requirements, code of the form `s:f(args)` in an exposed function or function it calls (where `s` is a string and `f` is some function in the `string` standard library) will use the restricted `string` API provided to the script, not the unrestricted `string` API normally provided to mods. Since your exposed function is running in an unrestricted global environment, just replace this code with `string.f(s, args)` instead to get the normal version.
