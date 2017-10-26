-- Create the public libluabox API table.
libluabox = {}

-- Import subsidiary files.
dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/core.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/stdenv.lua")
dofile(minetest.get_modpath(mientest.get_current_modname()) .. "/digilines.lua")
