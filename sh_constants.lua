assert(darkrp, "darkrp module not found; update StarfallEx")
assert(next(darkrp), "darkrp module empty; you are not on a DarkRP server")
if not darkrp.formatMoney then
	function darkrp.formatMoney(n)
		return "$"..string.comma(n)
	end
end

local function make_enums(prefix, array)
	for k, v in pairs(array) do
		_G[prefix..'_'..v] = k-1
	end
end
local function make_net_enums(prefix, array)
	local bits = 1
	while #array >= 2^bits do
		bits = bits+1
		assert(bits <= 32, "number of net enums may not exceed 2^32")
	end
	_G[prefix..'_BITS'] = bits
	_G[prefix..'_BYTES'] = math.ceil(bits/8)
	for k, v in pairs(array) do
		_G[prefix..'_'..v] = k
	end
end

HOOK_NAME = ''
TIMER_NAME = HOOK_NAME
NET_NAME = HOOK_NAME
make_net_enums('NET', {
	'START', -- serverbound: Request to start a new game; clientbound: Information about the game in progress
	'DOUBLE', -- serverbound: Double the amount
	'CASHOUT', -- serverbound: Cash out
	'READY', -- serverbound: Request for machine configuration; clientbound: Machine configuration info
	'WAITING', -- clientbound: Informs that machine is waiting for a money request to complete
	'ENTROPY', -- serverbound: Provides data to add to RNG entropy pool
	'BLACKLIST_ADD', -- serverbound: Add player to blacklist
	'BLACKLIST_REMOVE', -- serverbound: Remove player from blacklist
	'KILL', -- serverbound: Permanently halt execution
	'JACKPOT_UPDATE', -- serverbound: Update jackpot amount, clientbound: Update jackpot amount
})

-- Script stealer? There's nothing interesting in here. Stuff like payout rates is in the main file, which is serverside only.
