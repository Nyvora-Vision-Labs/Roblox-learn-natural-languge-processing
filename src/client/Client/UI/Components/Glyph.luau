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
