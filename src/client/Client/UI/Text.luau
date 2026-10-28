--!strict
-- Text labels built from the type scale, and the formula markup used by math cards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Create = require(script.Parent:WaitForChild("Create"))
local Context = require(script.Parent:WaitForChild("Context"))

local Text = {}

-- A wrapping, auto-height rich-text label in one of the Theme.text styles.
function Text.new(ctx: Context.Ctx, style: string, text: string, props: { [string]: any }?): TextLabel
	local styleDef = Theme.text[style]
	assert(styleDef, `unknown text style "{style}"`)
	local label = Create("TextLabel", {
		Name = style,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		RichText = true,
		TextWrapped = true,
		Text = text,
		FontFace = styleDef.font,
		TextSize = ctx.metrics.text[style],
		LineHeight = styleDef.lineHeight,
		TextColor3 = Theme.color.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

-- "{role|text}" → that text in the role's diagram color, bold. Unknown roles render plain.
function Text.formula(source: string): string
	return (string.gsub(source, "{(%a+)|([^}]*)}", function(role: string, inner: string)
		local color = Theme.role[role]
		if not color then
			return inner
		end
		return `<font color="{hex(color)}"><b>{inner}</b></font>`
	end))
end

function Text.roleColor(role: string?): Color3
	return if role and Theme.role[role] then Theme.role[role] else Theme.color.text
end

return Text
