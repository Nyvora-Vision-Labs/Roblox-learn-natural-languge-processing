--!strict
-- Instance factory: Create(className, props, children).
-- Parent is applied last so the instance is fully configured before it enters the tree.
-- A function value under a key that names an event connects to it:
--   Create("TextButton", { Text = "Go", Activated = function() ... end })

type Props = { [string]: any }

local function Create(className: string, props: Props?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil

	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif type(value) == "function" then
				(instance :: any)[key]:Connect(value)
			else
				(instance :: any)[key] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if parent then
		instance.Parent = parent
	end
	return instance
end

return Create
