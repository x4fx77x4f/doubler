local adminpanel = {}

adminpanel.open = false
adminpanel.menus = {
	main = {
		{label="exit", href=function()
			adminpanel.open = false
		end)},
		{label="EMERGENCY STOP", href=function()
			net.start(NET_NAME)
				net.writeUInt(NET_KILL, NET_BITS)
			net.send()
		end)},
		{label="net debug", href='net'},
	},
	net = {
		{label="back", href='main'},
	},
}
adminpanel.menu = adminpanel.menus.main
adminpanel.selected = 1
local t = {}
local blacklist = {NET_BITS=true, NET_BYTES=true}
for k, v in pairs(_G) do
	if k:sub(1, 4) == 'NET_' and not blacklist[k] then
		table.insert(t, k)
	end
end
table.insert(t, '$$$nonexistent$$$')
table.sort(t)
for k=1, #t do
	local v = t[k]
	adminpanel.menus.net[k+1] = {label=v, href=function()
		net.start(NET_NAME)
			net.writeUInt(_G[v], NET_BITS)
		net.send()
	end}
end

local me = player()
function adminpanel.update()
	if not input.isControlLocked() then
		return
	end
	if me:keyDown(IN_KEY.FORWARD) then -- up
		
	elseif me:keyDown(IN_KEY.BACK) then -- down
		
	elseif me:keyDown(IN_KEY.MOVELEFT) then -- back
		
	elseif me:keyDown(IN_KEY.MOVERIGHT) then -- forward
		
	end
end

function adminpanel.draw(sw, sh)
	render.setFont('DebugFixed')
	
end

return adminpanel
