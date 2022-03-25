-- This is *awful* code. Please don't ever do anything like this.
--@client
--@include ./cl_init.lua
if player() ~= owner() then
	return
end
local receiver
function net.receive(a, b)
	receiver = b
end
function net.start() end
function net.send() end
local _hook_add = hook.add
function hook.add(a, b, c)
	return _hook_add('_'..a, b, c)
end
function render.cursorPos() end
function net.writeUInt() end
DON_NOMTX = true
dofile('./cl_init.lua')
function net.readUInt(bits)
	return bits == NET_BITS and NET_READY or 10
end
function net.readDouble()
	function net.readDouble()
		return 102250
	end
	return 500
end
function net.readBool()
	return false
end
receiver()
if true then
	function net.readEntity()
		return player()
	end
	local m = 4
	function net.readUInt(bits)
		return bits == NET_BITS and NET_START or m
	end
	local pw = 500
	for i=1, m-1 do
		pw = pw*2
	end
	function net.readDouble()
		return pw
	end
	function net.readFloat()
		return timer.curtime()+4
	end
	receiver()
end
render.createRenderTarget('ss')
local bg = Color(255, 0, 255)
function render.setBackgroundColor(c)
	bg = c
end
local sw, sh = 858.34031852473, 512
function render.getResolution()
	return sw, sh
end
local mtx = Matrix()
local mult = 1.5
--mtx:setScale(Vector(1, sw/sh))
_hook_add('renderoffscreen', '', function()
	render.selectRenderTarget('ss')
	hook.run('_render')
	_hook_add('renderoffscreen', '', function()
		render.selectRenderTarget('ss')
		render.clear(Color(255, 0, 255), true)
		render.setColor(bg)
		render.drawRect(0, 0, math.ceil(sh/1.5), math.ceil(sw/1.5))
		render.setRGBA(255, 255, 255, 255)
		render.pushMatrix(mtx)
			hook.run('_render')
		render.popMatrix()
		_hook_add('renderoffscreen', '', function()
			render.selectRenderTarget('ss')
			local data = render.captureImage({
				format = 'png',
				x = 0,
				y = 0,
				w = math.ceil(sh/mult), h = math.ceil(sw/mult),
				--w = 1024, h = 1024,
				quality = 90,
				alpha = false,
			})
			local i, path = 0
			repeat
				i = i+1
				path = 'donss'..i..'.png'
			until not file.exists(path)
			file.write(path, data)
			hook.remove('renderoffscreen', '')
		end)
	end)
end)
_hook_add('render', '', function()
	render.setRenderTargetTexture('ss')
	render.drawTexturedRect(0, 0, render.getResolution())
end)
