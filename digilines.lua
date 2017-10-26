-- Given a message object passed to digiline_send, clean it up into a form
-- which is safe to transmit over the network and compute its "cost" (a very
-- rough estimate of its memory usage).
--
-- The cleaning comprises the following:
-- 1. Functions (and userdata, though user scripts ought not to get hold of
--    those in the first place) are removed, because they break the model of
--    Digilines as a network that carries basic data, and they could exfiltrate
--    references to mutable objects from one Luacontroller to another, allowing
--    inappropriate high-bandwidth, no-wires communication.
-- 2. Tables are duplicated because, being mutable, they could otherwise be
--    modified after the send is complete in order to change what data arrives
--    at the recipient, perhaps in violation of the previous cleaning rule or
--    in violation of the message size limit.
--
-- The cost indication is only approximate; it's not a perfect measurement of
-- the number of bytes of memory used by the message object.
--
-- Parameters:
-- msg -- the message to clean
-- back_references -- for internal use only; do not provide
--
-- Returns:
-- 1. The cleaned object.
-- 2. The approximate cost of the object.
local function clean_and_weigh_message(msg, back_references)
	local t = type(msg)
	if t == "string" then
		-- Strings are immutable so can be passed by reference, and cost their
		-- length plus the size of the Lua object header (24 bytes on a 64-bit
		-- platform) plus one byte for the NUL terminator.
		return msg, #msg + 25
	elseif t == "number" then
		-- Numbers are passed by value so need not be touched, and cost 8 bytes
		-- as all numbers in Lua are doubles.
		return msg, 8
	elseif t == "boolean" then
		-- Booleans are passed by value so need not be touched, and cost 1
		-- byte.
		return msg, 1
	elseif t == "table" then
		-- Tables are duplicated. Check if this table has been seen before
		-- (self-referential or shared table); if so, reuse the cleaned value
		-- of the previous occurrence, maintaining table topology and avoiding
		-- infinite recursion, and charge zero bytes for this as the object has
		-- already been counted.
		back_references = back_references or {}
		local bref = back_references[msg]
		if bref then
			return bref, 0
		end
		-- Construct a new table by cleaning all the keys and values and adding
		-- up their costs, plus 8 bytes as a rough estimate of table overhead.
		local cost = 8
		local ret = {}
		back_references[msg] = ret
		for k, v in pairs(msg) do
			local k_cost, v_cost
			k, k_cost = clean_and_weigh_message(k, back_references)
			v, v_cost = clean_and_weigh_message(v, back_references)
			if k ~= nil and v ~= nil then
				-- Only include an element if its key and value are of legal
				-- types.
				ret[k] = v
			end
			-- If we only counted the cost of a table element when we actually
			-- used it, we would be vulnerable to the following attack:
			-- 1. Construct a huge table (too large to pass the cost limit).
			-- 2. Insert it somewhere in a table, with a function as a key.
			-- 3. Insert it somewhere in another table, with a number as a key.
			-- 4. The first occurrence doesn't pay the cost because functions
			--    are stripped and therefore the element is dropped.
			-- 5. The second occurrence doesn't pay the cost because it's in
			--    back_references.
			-- By counting the costs regardless of whether the objects will be
			-- included, we avoid this attack; it may overestimate the cost of
			-- some messages, but only those that won't be delivered intact
			-- anyway because they contain illegal object types.
			cost = cost + k_cost + v_cost
		end
		return ret, cost
	else
		return nil, 0
	end
end

-- The maximum message cost limit setting value.
local message_cost_limit = minetest.settings.get("libluabox_digiline_max")

-- The public API.
function libluabox.make_digilines_env_builder(pos, rules)
	if minetest.global_exists("digilines") then
		rules = rules or digilines.rules.default
		-- This function takes pos and rules from its closure.
		local function digiline_send(channel, msg)
			-- Legal channels are strings, numbers, and booleans.
			local channel_type = type(channel)
			if channel_type ~= "string" and channel_type ~= "number" and channel_type ~= "boolean" then
				return false
			end

			-- Clean and weigh the message and check the cost limit.
			local msg_cost
			msg, msg_cost = clean_and_weigh_message(msg)
			if msg == nil or msg_cost > message_cost_limit then
				return false
			end

			-- Queue the message for transmission after script execution.
			minetest.after(0, digilines.receptor_send, pos, rules, channel, msg)
			return true
		end
		-- This function takes digiline_send from its closure.
		return function(_, env)
			env.digiline_send = digiline_send
		end
	else
		return function(env) end
	end
end
