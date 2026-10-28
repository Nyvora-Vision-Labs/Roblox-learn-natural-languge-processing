--!strict
-- Small icons drawn from Frames, so they stay crisp at any size until real icons are uploaded.
-- Each returns a transparent square Frame of `size` px.

local Create = require(script.Parent.Parent:WaitForChild("Create"))

local Glyph = {}

local function box(size: number, name: string): Frame
	return Create("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
end

-- Padlock: a stroked, rounded shackle behind a solid body with a keyhole.
-- `hole` is the keyhole color (usually the background behind the icon).
function Glyph.lock(size: number, color: Color3, hole: Color3): Frame
	local root = box(size, "Lock")
	local stroke = math.max(2, math.floor(size * 0.11 + 0.5))

	Create("Frame", {
		Name = "Shackle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.54, 0.62),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Create("UIStroke", { Color = color, Thickness = stroke }),
	})

	local body = Create("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.8, 0.56),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.18, 0) }),
	})

	Create("Frame", {
		Name = "Keyhole",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.2, 0.32),
		BackgroundColor3 = hole,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = body,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})

	return root
end

-- A text glyph (✓ ✕ ← →) centered in a square.
function Glyph.text(size: number, char: string, color: Color3, font: Font): Frame
	local root = box(size, "Glyph")
	-- BuilderSans doesn't contain all of these symbols on every device. Draw the
	-- essential status/navigation marks so they never become missing-glyph boxes.
	local function line(a: Vector2, b: Vector2)
		local delta = (b - a) * size
		Create("Frame", {
			Name = "Stroke",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((a.X + b.X) / 2, (a.Y + b.Y) / 2),
			Size = UDim2.fromOffset(delta.Magnitude, math.max(2, size * 0.1)),
			Rotation = math.deg(math.atan2(delta.Y, delta.X)),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = root,
		}, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	if char == "✓" then
		line(Vector2.new(0.16, 0.52), Vector2.new(0.4, 0.76))
		line(Vector2.new(0.4, 0.76), Vector2.new(0.86, 0.24))
		return root
	elseif char == "✕" then
		line(Vector2.new(0.25, 0.25), Vector2.new(0.75, 0.75))
		line(Vector2.new(0.25, 0.75), Vector2.new(0.75, 0.25))
		return root
	elseif char == "▸" or char == "▾" then
		if char == "▸" then
			line(Vector2.new(0.35, 0.2), Vector2.new(0.65, 0.5))
			line(Vector2.new(0.65, 0.5), Vector2.new(0.35, 0.8))
		else
			line(Vector2.new(0.2, 0.35), Vector2.new(0.5, 0.65))
			line(Vector2.new(0.5, 0.65), Vector2.new(0.8, 0.35))
		end
		return root
	end
	Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = char,
		TextColor3 = color,
		FontFace = font,
		TextSize = size,
		Parent = root,
	})
	return root
end

return Glyph
