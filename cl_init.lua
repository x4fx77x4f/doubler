--@name Double or nothing
--@client

--@include ./sh_constants.lua
dofile('./sh_constants.lua')

-- @ include ./cl_adminpanel.lua
--dofile('./cl_adminpanel.lua')

local debug_mode = false
local initialized = false
local DON_BET
local DON_MAXIMUM
local DON_DEMO
local jackpot
local multiplier
local potential_winnings
local current_player
local me = player()
local using = false
local GAMEOVERANIM_DURATION = 2.5
local gameover = -GAMEOVERANIM_DURATION
local timeout
local is_admin = me == owner()
local admin_panel = false

local mm = Matrix()
local mmt = Vector()
mm:setTranslation(mmt)
local mmsm = 6
local mms = Vector(mmsm, mmsm)
mm:setScale(mms)

local mtx = Matrix()
mtx:setTranslation(Vector(0, 512))
mtx:setAngles(Angle(0, -90, 0))
local mult = 1.5
mtx:setScale(Vector(mult, mult))

local bg = Color(15, 15, 15)
hook.add('render', HOOK_NAME, function()
	render.setBackgroundColor(bg)
	render.pushMatrix(mtx)
		local sw, sh = render.getResolution()
		sw, sh = sh/mult, sw/mult
		local cx, cy = render.cursorPos()
		if cx then
			cx, cy = sw-(cy/mult), cx/mult
		end
		local bx, by, bw, bh
		if current_player then
			local won = multiplier == DON_MAXIMUM
			local x = sw/2
			local y = sh/6
			local l1t = darkrp.formatMoney(potential_winnings)
			render.setFont('DermaLarge')
			local l1w, l1h = render.getTextSize(l1t)
			local l2t = won and (jackpot > 0 and "You just won the jackpot!" or "You just fucking won!") or "Use here to cash out."
			render.setFont('DermaDefault')
			local l2w, l2h = render.getTextSize(l2t)
			local p = 8
			by, bw, bh = y-p, math.max(l1w, l2w)+p*2, p+l1h+l2h+p
			bx = (sw-bw)/2
			if not won then
				render.setRGBA(63, 63, 63, 255)
				render.drawRoundedBox(p, bx, by, bw, bh)
			end
			render.setRGBA(255, 255, 255, 255)
			render.setFont('DermaLarge')
			render.drawSimpleText(x, y, l1t, TEXT_ALIGN.CENTER)
			render.setFont('DermaDefault')
			render.drawSimpleText(x, y+l1h, l2t, TEXT_ALIGN.CENTER)
			mmt[1] = x
			y = sh/2.35
			mmt[2] = y
			mm:setTranslation(mmt)
			mm:setScale(mms)
			render.pushMatrix(mm)
				render.setFont('DermaLarge')
				local str = string.format("x%d", multiplier)
				local tw, th = render.getTextSize(str)
				render.drawSimpleText(0, 0, str, TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)
			render.popMatrix()
			render.setFont('DermaDefault')
			y = y+th*mmsm/2
			render.drawSimpleText(x, y, won and "Use here to redeem your winnings!" or "Use here to potentially double your money!", TEXT_ALIGN.CENTER, TEXT_ALIGN.TOP)
			local time_until_timeout = math.max(timeout-timer.curtime(), 0)
			if time_until_timeout <= 10 then
				render.drawSimpleText(x, y+48, string.format("Timing out in %s", string.niceTime(time_until_timeout)), TEXT_ALIGN.CENTER)
			end
		else
			local l1t = timer.systime() >= gameover and "DOUBLE OR NOTHING" or "GAME OVER"
			local l2t = string.format("Bet is %s.\nPress your use key here to play!", darkrp.formatMoney(DON_BET or -1))
			render.setFont('DermaLarge')
			local y = sh/3
			local l1w, l1h = render.getTextSize(l1t)
			render.drawText(sw/2, y, l1t, TEXT_ALIGN.CENTER)
			render.setFont('DermaDefault')
			y = y+l1h
			render.drawText(sw/2, y, l2t, TEXT_ALIGN.CENTER)
		end
		if jackpot and (not current_player or not multiplier or multiplier < DON_MAXIMUM) then
			local l1t = string.format("Reach x%d to additionally win the jackpot of", DON_MAXIMUM or -1)
			local l2t = string.format("%s!", darkrp.formatMoney(jackpot or -1))
			render.setFont('DermaDefault')
			local y = sh-sh/4
			local l1w, l1h = render.getTextSize(l1t)
			render.drawText(sw/2, y, l1t, TEXT_ALIGN.CENTER)
			render.setFont('DermaLarge')
			y = y+l1h
			render.drawText(sw/2, y, l2t, TEXT_ALIGN.CENTER)
		end
		if cx then
			render.drawRect(cx-1, cy-1, 2, 2)
		end
		if initialized then
			if me:keyDown(IN_KEY.USE) then
				if not using then
					using = true
					-- Doesn't work properly if there's more than one screen
					if cx and render.getScreenEntity():obbCenterW():getDistanceSqr(me:getEyePos()) <= 8000 then
						if current_player then
							if me == current_player then
								net.start(NET_NAME)
									net.writeUInt(((cx >= bx and cy >= by and cx < bx+bw and cy < by+bh) or multiplier == DON_MAXIMUM) and NET_CASHOUT or NET_DOUBLE, NET_BITS)
								net.send()
							end
						else
							net.start(NET_NAME)
								net.writeUInt(NET_START, NET_BITS)
							net.send()
						end
					--else print("Failed...", cx)
					end
				end
			elseif using then
				using = false
			end
			if DON_DEMO then
				local str = "MACHINE IS IN DEMO MODE\nWINNINGS WILL NOT BE DISPENSED"
				render.setFont('DermaDefault')
				local tw, th = render.getTextSize(str)
				render.setRGBA(31, 31, 15, 255)
				render.drawRect(0, 0, sw, 48)
				render.setRGBA(255, 255, 0, 255)
				render.drawRect(0, 48-2, sw, 1)
				render.drawText(sw/2, 24-th/2, str, TEXT_ALIGN.CENTER)
			end
			if debug_mode then
				render.setFont('DebugFixed')
				render.setRGBA(255, 255, 255, 255)
				render.drawSimpleText(sw/2, 0, "sw: "..sw, TEXT_ALIGN.CENTER, TEXT_ALIGN.TOP)
				render.drawSimpleText(0, sh/2, "sh: "..sh, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)
				if cx then
					render.drawText(0, 0, string.format("cx: %7.2f\ncy: %7.2f", cx, cy))
				end
				local str = string.format(
					"DON_BET: %d\n"..
					"DON_MAXIMUM: %d\n"..
					"jackpot: %d\n"..
					"multiplier: %d\n"..
					"potential_winnings: %d\n"..
					"current_player: %s\n"..
					"using: %s\n"..
					"gameover: %f\n"..
					"timeout: %f",
					DON_BET or -1,
					DON_MAXIMUM or -1,
					jackpot or -1,
					multiplier or -1,
					potential_winnings or -1,
					tostring(current_player),
					tostring(using),
					gameover or -1,
					timeout or -1
				)
				local tw, th = render.getTextSize(str)
				render.setRGBA(0, 0, 0, 191)
				render.drawRect(0, sh-th, tw, th)
				render.setRGBA(255, 255, 255, 255)
				render.drawText(0, sh-th, str)
			end
			--[[
			if is_admin or debug_mode then
				render.setFont('DebugFixed')
				local str = "OPERATOR\nPANEL"
				local tw, th = render.getTextSize(str)
				local x, y = sw-tw, sh-th
				render.setRGBA(0, 0, 0, 191)
				render.drawRect(x, y, tw, th)
				render.setRGBA(255, 255, 255, 255)
				render.drawText(x, y, str)
				if cx and cx >= x and cy >= y and cx < x+tw and cy < y+th then
					admin_panel = not admin_panel
				end
			end
			--]]
		else
			render.setRGBA(0, 0, 0, 239)
			render.drawRect(0, 0, sw, sh)
			render.setRGBA(255, 255, 0, 255)
			render.setFont('DermaLarge')
			render.drawSimpleText(sw/2, sh/2, "Please wait", TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)
		end
	render.popMatrix()
end)

net.receive(NET_NAME, function(length)
	local action = net.readUInt(NET_BITS)
	if action == NET_READY then
		DON_BET = net.readDouble()
		DON_MAXIMUM = net.readUInt(8)
		DON_DEMO = net.readBool()
		jackpot = net.readDouble()
		initialized = true
	elseif action == NET_START then
		current_player = net.readEntity()
		if not isValid(current_player) or current_player:entIndex() <= 0 then
			current_player = nil
		end
		multiplier = net.readUInt(8)
		if multiplier == 0 then
			multiplier = nil
		end
		potential_winnings = net.readDouble()
		gameover = net.readBool() and timer.systime()+GAMEOVERANIM_DURATION or -GAMEOVERANIM_DURATION
		timeout = net.readFloat()
	elseif action == NET_JACKPOT_UPDATE then
		jackpot = net.readDouble()
	end
end)
net.start(NET_NAME)
	net.writeUInt(NET_READY, NET_BITS)
net.send()
