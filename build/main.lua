local lg = love.graphics
math.clamp = function(n, low, high)
	return math.min(math.max(n, low), high)
end
math.sign = function(n)
	return n < 0 and -1 or n > 0 and 1 or n
end
lg.setLineStyle('smooth')
local filepath = nil
local image = nil
local width = 0
local height = 0
local whiteboard = nil
local left = 0
local right = 0
local top = 0
local bottom = 0
local crop = {
	min = {
		x = 0,
		y = 0
	},
	max = {
		x = 1920,
		y = 1080
	}
}
local x, y, w, h = 0, 0, 1920, 1080
local omx, omy = 0, 0
local brushSize = 8
local brushAlpha = 0
local brushTarget = 0
local hsvImage = nil
local hsvData = nil
local hsvPadding = 16
local hsvSize = {
	w = 128,
	h = 128
}
local hsvPos = {
	x = hsvPadding,
	y = hsvPadding
}
local IsInColorPicker
IsInColorPicker = function(x, y)
	return x > hsvPos.x and x < hsvPos.x + hsvSize.w and y > hsvPos.y and y < hsvPos.y + hsvSize.h
end
local shader = nil
local r, g, b = 1, 1, 1
local t = 0
local wheelWidth = 0.2
local isColored = 1
local pickingColor = false
love.load = function(args)
	filepath = args[1]
	local file = io.open(filepath, 'rb')
	local data = file:read('*a')
	file:close()
	image = lg.newImage(love.image.newImageData(love.filesystem.newFileData(data, 'image.png')))
	width = image:getWidth()
	height = image:getHeight()
	left = 1920 / 2 - width / 2
	right = 1920 / 2 + width / 2
	top = 1080 / 2 - height / 2
	bottom = 1080 / 2 + height / 2
	whiteboard = lg.newCanvas(1920, 1080, {
		msaa = 16
	})
	shader = lg.newShader([[		uniform float tween;
		uniform float width;
		uniform float isColored;
		#define PI 3.14159265358979323844
		vec3 hsv(float h,float s,float v) { return mix(vec3(1.),clamp((abs(fract(h+vec3(3.,2.,1.)/3.)*6.-3.)-1.),0.,1.),s)*v; }
		vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
		{
			vec2 p = texture_coords - vec2(0.5);
			float radius = length(p);
			float angle = atan(p.y, p.x);
			float h = angle * 0.5 / PI + 0.5;
			float step = 0.000001;
			float start = 0.5 - width;
			float end = start + width * tween;
			float alpha =  smoothstep(start - step, start, radius) * smoothstep(end + step, end, radius);
			vec4 a = vec4(vec3(h), alpha);
			vec4 c = vec4(hsv(h, 1., 1.), alpha);
		    return mix(a, c, isColored);
		}
	]])
	hsvImage = lg.newCanvas(hsvSize.w, hsvSize.h)
	hsvImage:renderTo(function()
		shader:send('tween', 1)
		shader:send('width', wheelWidth)
		shader:send('isColored', 1)
		lg.setShader(shader)
		lg.draw(image, 0, 0, 0, hsvSize.w / width, hsvSize.h / height)
		return lg.setShader()
	end)
	hsvData = hsvImage:newImageData()
end
love.update = function(dt)
	brushAlpha = math.clamp(brushAlpha + math.sign(brushTarget - brushAlpha) * dt / 2, 0, 1)
	if brushAlpha == 1 then
		brushTarget = 0
	end
	local mx, my = love.mouse.getPosition()
	if not pickingColor then
		if love.mouse.isDown(1) then
			lg.setLineWidth(brushSize)
			lg.setColor(r, g, b)
			whiteboard:renderTo(function()
				return lg.line(mx, my, omx, omy)
			end)
			whiteboard:renderTo(function()
				return lg.circle('fill', mx, my, brushSize / 2)
			end)
			lg.setColor(1, 1, 1)
		end
		if love.mouse.isDown(2) then
			do
				crop.max.x, crop.max.y = mx, my
				crop.max.x, crop.max.y = math.clamp(crop.max.x, left, right), math.clamp(crop.max.y, top, bottom)
				x = math.min(crop.min.x, crop.max.x)
				y = math.min(crop.min.y, crop.max.y)
				w = math.abs(crop.max.x - crop.min.x)
				h = math.abs(crop.max.y - crop.min.y)
			end
		end
		t = math.max(0, t - dt * 10)
	else
		t = math.min(1, t + dt * 10)
		local px, py = mx - hsvPos.x - hsvSize.w / 2, my - hsvPos.y - hsvSize.h / 2
		local angle = math.atan2(py, px)
		local ix = hsvSize.w / 2 + math.cos(angle) * hsvSize.w / 2 * 0.9
		local iy = hsvSize.h / 2 + math.sin(angle) * hsvSize.h / 2 * 0.9
		if isColored == 1 then
			r, g, b = hsvData:getPixel(ix, iy)
		else
			local c = angle * 0.5 / math.pi + 0.5
			r, g, b = c, c, c
		end
	end
	omx, omy = mx, my
end
local DrawColorWheel
DrawColorWheel = function()
	lg.setShader(shader)
	shader:send('tween', t)
	lg.draw(image, hsvPos.x, hsvPos.y, 0, hsvSize.w / width, hsvSize.h / height)
	return lg.setShader()
end
love.draw = function()
	lg.setColor(0.5, 0.5, 0.5)
	lg.draw(image, left, top)
	lg.draw(whiteboard)
	lg.setScissor(x, y, w, h)
	lg.setColor(1, 1, 1)
	lg.draw(image, left, top)
	lg.draw(whiteboard)
	lg.setScissor()
	lg.setLineWidth(1)
	lg.rectangle('line', x - 1, y - 1, w + 2, h + 2)
	lg.setColor(r, g, b)
	lg.circle('fill', hsvPos.x + hsvSize.w / 2, hsvPos.y + hsvSize.h / 2, hsvSize.w / 2 - hsvSize.w * wheelWidth)
	lg.setColor(1, 1, 1)
	DrawColorWheel()
	lg.setColor(0, 0, 0)
	lg.setLineWidth(3)
	lg.circle('line', hsvPos.x + hsvSize.w / 2, hsvPos.y + hsvSize.h / 2, hsvSize.w / 2 - hsvSize.w * wheelWidth * (1 - t))
	lg.setLineWidth(2)
	local col = (r < 0.5 and 1 or 0) * (1 - isColored)
	lg.setColor(col, col, col, 1 - math.pow(brushAlpha - 1, 4))
	lg.circle('line', hsvPos.x + hsvSize.w / 2, hsvPos.y + hsvSize.h / 2, brushSize / 2)
	return lg.setColor(1, 1, 1)
end
local SaveImage
SaveImage = function()
	local canvas = lg.newCanvas(w, h)
	canvas:renderTo(function()
		lg.draw(image, 1920 / 2 - width / 2 - x, 1080 / 2 - height / 2 - y)
		return lg.draw(whiteboard, -x, -y)
	end)
	local imagedata = canvas:newImageData()
	local filedata = imagedata:encode('png', 'image.png')
	filepath = filepath:sub(1, #filepath - 4) .. love.math.random(374829) .. filepath:sub(#filepath - 3)
	local file = io.open(filepath, 'wb')
	file:write(filedata:getString())
	return file:close()
end
love.mousepressed = function(x, y, button)
	pickingColor = IsInColorPicker(x, y)
	if pickingColor then
		isColored = 1 - (button - 1)
		shader:send('isColored', isColored)
		return
	end
	if button == 2 then
		crop.min = {
			x = math.clamp(x, left, right),
			y = math.clamp(y, top, bottom)
		}
	end
	if button == 1 then
		omx, omy = x, y
		return whiteboard:renderTo(function()
			lg.setColor(r, g, b)
			return lg.circle('fill', x, y, brushSize / 2)
		end)
	end
end
love.mousereleased = function(x, y, button)
	if button == 2 and not pickingColor then
		if crop.min.x > crop.max.x then
			crop.min.x, crop.max.x = crop.max.x, crop.min.x
		end
		if crop.min.y > crop.max.y then
			crop.min.y, crop.max.y = crop.max.y, crop.min.y
		end
	end
	pickingColor = false
end
love.wheelmoved = function(dx, dy)
	if IsInColorPicker(love.mouse.getPosition()) then
		brushSize = math.clamp(brushSize + dy, 4, (hsvSize.w / 2 - hsvSize.w * wheelWidth) * 2)
		brushTarget = 1
	end
end
local keyEvents = {
	escape = love.event.quit,
	["return"] = SaveImage,
	c = function()
		return whiteboard:renderTo(function()
			return lg.clear(0, 0, 0, 0)
		end)
	end
}
love.keypressed = function(key)
	local _obj_0 = keyEvents[key]
	if _obj_0 ~= nil then
		return _obj_0()
	end
	return nil
end
