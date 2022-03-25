--@name Double or nothing
--@server
--@include ./cl_init.lua
--@clientmain ./cl_init.lua

--@include ./sh_constants.lua
dofile('./sh_constants.lua')

local DON_BET = 500 -- Amount of money required to play.
local DON_MAXIMUM = 10 -- Highest multiplier allowed. If nil, no limit (NOT RECOMMENDED).
local DON_CHANCE = 0.5 -- Chance that playing will result in one's bet being multiplied. This should really never be anything but 50%.
local DON_MULTIPLIER = 2 -- Amount bet will be multiplied on win. This should really never be anything but 2.
local DON_JACKPOT = true -- Whether or not a jackpot will exist and be able to be won by reaching the maximum multiplier.
local DON_JACKPOT_MULTIPLIER = 0.5 -- How much of each loss will enter the jackpot (if it's enabled).
local DON_JACKPOT_STARTING = 100000 -- How much the money jackpot will start at (if it's enabled).
local DON_DEMO = false -- If true, machine will neither accept bets nor dispense winnings, and players will be able to play for free.
local DON_TIMEOUT = 15 -- Amount of time in seconds until player is timed out.

assert(DON_BET < 2^32, "bet amount exceeds maximum width")
assert(DON_MAXIMUM < 2^8, "maximum multiplier exceeds maximum width")
assert(DON_CHANCE >= 0 and DON_CHANCE <= 1, "chance out of range")
assert(DON_MULTIPLIER > 1, "multiplier out of range")
assert(DON_MAXIMUM or not DON_JACKPOT, "maximum bet must be defined if jackpot is enabled")
assert(DON_JACKPOT_MULTIPLIER > 0 and DON_JACKPOT_MULTIPLIER <= 1, "jackpot multiplier out of range")
assert(DON_JACKPOT_STARTING > 0, "starting jackpot out of range")

local jackpot = DON_JACKPOT_STARTING
local multiplier
local potential_winnings
local current_player
local current_player_steamid
local gameover
local pending_payment_from
local timeout

local function don_update(target, gameover)
	net.start(NET_NAME)
		net.writeUInt(NET_START, NET_BITS)
		net.writeEntity(current_player or entity(0))
		net.writeUInt(multiplier or 0, 8)
		net.writeDouble(potential_winnings or -2)
		net.writeBool(not not gameover)
		net.writeFloat(timeout or -2)
	net.send(target)
end
local function don_update_jackpot()
	net.start(NET_NAME)
		net.writeUInt(NET_JACKPOT_UPDATE, NET_BITS)
		net.writeDouble(jackpot)
	net.send()
end
local function don_set_multiplier(new_multiplier)
	new_multiplier = new_multiplier or multiplier+1
	assert(new_multiplier <= DON_MAXIMUM, "new multiplier exceeds maximum")
	if multiplier and new_multiplier == multiplier+1 then
		potential_winnings = math.floor(potential_winnings*DON_MULTIPLIER)
	else
		potential_winnings = DON_BET
		for i=1, new_multiplier-1 do
			potential_winnings = math.floor(potential_winnings*DON_MULTIPLIER)
		end
	end
	if DON_JACKPOT and new_multiplier == DON_MAXIMUM then
		potential_winnings = potential_winnings+jackpot
	end
	multiplier = new_multiplier
	timeout = timer.curtime()+DON_TIMEOUT
	don_update()
end
local function don_start(ply)
	current_player = ply
	current_player_steamid = ply:getSteamID()
	don_set_multiplier(1)
end
local function don_chance()
	local n = (math.random()+0.87602689051036)%1
	--printConsole(string.format("DON: Our random number is %f", n))
	return n < DON_CHANCE -- TODO: Make it harder to defeat
end
local function don_end(win)
	if DON_JACKPOT and not win then
		jackpot = jackpot+DON_BET*DON_JACKPOT_MULTIPLIER
		don_update_jackpot()
	end
	current_player = nil
	don_update(nil, true)
end

local blacklist = {}
local admin = owner()
net.receive(NET_NAME, function(length, sender)
	if blacklist[sender:getSteamID()] then
		return
	end
	local action = net.readUInt(NET_BITS)
	if action == NET_READY then
		net.start(NET_NAME)
			net.writeUInt(NET_READY, NET_BITS)
			net.writeDouble(DON_BET)
			net.writeUInt(DON_MAXIMUM, 8)
			net.writeBool(DON_DEMO)
			net.writeDouble(DON_JACKPOT and jackpot or -2)
		net.send(sender)
		don_update(sender)
	elseif action == NET_START then
		if not current_player then
			if DON_DEMO then
				don_start(sender)
			elseif darkrp.canMakeMoneyRequest(sender) then
				printConsole(string.format("DON: %s requesting to play for %s", sender:getSteamID(), darkrp.formatMoney(DON_BET)))
				pending_payment_from = sender
				darkrp.requestMoney(sender, DON_BET, "Double or nothing", function()
					printConsole(string.format("DON: %s request succeeded", sender:getSteamID()))
					if pending_payment_from == sender then
						pending_payment_from = nil
					end
					don_start(sender)
				end, function(err)
					printConsole(string.format("DON: %s request failed with %q", sender:getSteamID(), err))
					if pending_payment_from == sender then
						pending_payment_from = nil
					end
				end)
			end
		end
	elseif action == NET_DOUBLE then
		if sender ~= current_player then
			return
		end
		if multiplier < DON_MAXIMUM then
			if don_chance() then
				don_set_multiplier()
			else
				don_end()
			end
		end
	elseif action == NET_CASHOUT then
		if sender ~= current_player then
			return
		end
		if not DON_DEMO then
			printConsole(string.format("DON: %s cashed out %s", current_player:getSteamID(), darkrp.formatMoney(potential_winnings)))
			darkrp.payPlayer(admin, current_player, potential_winnings)
			if DON_JACKPOT and multiplier == DON_MAXIMUM then
				jackpot = DON_JACKPOT_STARTING
				don_update_jackpot()
			end
		end
		don_end(true)
	elseif action == NET_ENTROPY then
		if sender ~= admin then
			return
		end
		-- TODO
	elseif action == NET_BLACKLIST_ADD then
		if sender ~= admin then
			return
		end
		blacklist[net.readString()] = true
	elseif action == NET_BLACKLIST_REMOVE then
		if sender ~= admin then
			return
		end
		blacklist[net.readString()] = nil
	elseif action == NET_KILL then
		if sender ~= admin then
			return
		end
		error("NET_KILL")
	end
end)
timer.create(TIMER_NAME, 1, 0, function()
	if current_player == nil then
		return
	end
	if not isValid(current_player) then
		printConsole(string.format("DON: %s no longer valid; was at x%d (%s)", current_player_steamid, multiplier or -2, darkrp.formatMoney(potential_winnings or -2)))
		current_player = nil
		don_update()
	elseif timer.curtime() > timeout then
		printConsole(string.format("DON: %s timed out; auto cashing out %s (x%d)", current_player:getSteamID(), darkrp.formatMoney(potential_winnings or -2), multiplier or -2))
		if not DON_DEMO then
			darkrp.payPlayer(admin, current_player, potential_winnings)
			if DON_JACKPOT and multiplier == DON_MAXIMUM then
				jackpot = DON_JACKPOT_STARTING
				don_update_jackpot()
			end
		end
		current_player = nil
		don_update()
	end
end)
hook.add('Removed', HOOK_NAME, function()
	printConsole(string.format("DON: %s was at x%d (%s)", current_player_steamid or "nil", multiplier or -2, darkrp.formatMoney(potential_winnings or -2)))
end)
local prefix = '$'..chip():entIndex()..' '
hook.add('PlayerSay', HOOK_NAME, function(sender, text, in_team_chat)
	if string.sub(text, 1, #prefix) ~= prefix then
		return
	end
	if sender ~= admin then
		return
	end
	text = string.sub(text, #prefix+1)
	local command, parameter = string.match(text, '^(%w+) ?(.*)$')
	if command == 'setjackpot' then
		jackpot = tonumber(parameter)
		don_update_jackpot()
	elseif command == 'die' then
		error("die")
	else
		printConsole("DON: command not found")
	end
end)
