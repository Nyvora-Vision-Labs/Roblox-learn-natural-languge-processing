--!strict
-- Toasts: one short message at a time, top-center, then it fades away.
-- A new message replaces the current one; repeating the same message just restarts its timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Scale = require(UI:WaitForChild("Scale"))
local Context = require(UI:WaitForChild("Context"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))

export type Kind = "info" | "warning" | "success" | "locked"

export type Options = {
	kind: Kind?,
	duration: number?,
	reducedMotion: boolean?,
	textScale: number?,
}

local TOP_OFFSET = Theme.toast.topOffset
local SLIDE = Theme.toast.slide
local DEFAULT_DURATION = Theme.toast.duration

type Entry = {
	root: CanvasGroup,
	label: TextLabel,
	icon: Frame?,
	text: string,
	token: number,
	kind: Kind,
	textScale: number,
}

local Toast = {}

local gui: ScreenGui? = nil
local stage: Frame? = nil
local scaleHandle: Scale.ScaleHandle? = nil
local current: Entry? = nil
local token = 0
local layout: (Entry) -> ()

local function ensureGui(): (ScreenGui, Frame)
	if gui and stage and gui.Parent then
		return gui, stage
	end
	local screen = Create("ScreenGui", {
		Name = "Toasts",
		DisplayOrder = 50,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local frame = Create("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		Parent = screen,
	})
	scaleHandle = Scale.attach(screen, frame)
	gui, stage = screen, frame
	scaleHandle:onChanged(function()
		if current then
			layout(current)
		end
	end)
	return screen, frame
end

local function iconFor(kind: Kind, size: number): Frame
	if kind == "locked" then
		return Glyph.lock(size, Theme.color.textMuted, Theme.color.surfaceRaised)
	elseif kind == "warning" then
		return Glyph.text(size, "!", Theme.color.warning, Theme.font.extraBold)
	elseif kind == "success" then
		return Glyph.text(size, "✓", Theme.color.success, Theme.font.bold)
	end
	return Glyph.text(size, "•", Theme.color.textMuted, Theme.font.bold)
end

layout = function(entry: Entry)
	if not entry.root.Parent or not gui or not scaleHandle then
		return
	end
	local state = scaleHandle:get()
	local textSize = Context.metrics(state, entry.textScale).text.body
	local iconSize = math.ceil(textSize * 0.9)
	local maxWidth = math.max(1, math.min(
		Theme.toast.maxScreenWidth / state.scale,
		gui.AbsoluteSize.X / state.scale - 2 * Theme.space.xl
	))
	local chrome = Theme.space.lg + Theme.space.xl + Theme.space.md + iconSize
	local plain = entry.text:gsub("<[^>]+>", "")
	local bounds = TextService:GetTextSize(plain, textSize, Theme.toast.font, Vector2.new(math.huge, math.huge))
	entry.root.Size = UDim2.fromOffset(math.min(maxWidth, math.ceil(bounds.X) + chrome + Theme.space.xs), 0)
	entry.label.TextSize = textSize
	entry.label.Size = UDim2.new(1, -(iconSize + Theme.space.md), 0, 0)
	if entry.icon then
		entry.icon:Destroy()
	end
	local icon = iconFor(entry.kind, iconSize)
	icon.LayoutOrder = 1
	icon.Parent = entry.root
	entry.icon = icon
end

local function hide(entry: Entry, reducedMotion: boolean)
	local info = TweenInfo.new(Theme.duration.state, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local goal: { [string]: any } = { GroupTransparency = 1 }
	if not reducedMotion then
		goal.Position = UDim2.new(0.5, 0, 0, TOP_OFFSET - SLIDE)
	end
	local tween = TweenService:Create(entry.root, info, goal)
	tween.Completed:Connect(function()
		entry.root:Destroy()
	end)
	tween:Play()
end

function Toast.show(text: string, options: Options?)
	local opts: Options = options or {}
	local kind: Kind = opts.kind or "info"
	local reducedMotion = opts.reducedMotion == true
	local duration = opts.duration or DEFAULT_DURATION

	token += 1
	local myToken = token

	-- Same message already showing: keep it, restart its timer.
	if current and current.text == text and current.root.Parent then
		current.token = myToken
		current.kind = kind
		current.textScale = opts.textScale or 1
		layout(current)
	else
		if current and current.root.Parent then
			hide(current, reducedMotion)
		end
		local _, parent = ensureGui()
		local root = Create("CanvasGroup", {
			Name = "Toast",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, TOP_OFFSET - (if reducedMotion then 0 else SLIDE)),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = Theme.color.surfaceRaised,
			GroupTransparency = 1,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.button }),
			Create("UIStroke", {
				Color = Theme.color.border,
				Thickness = Theme.strokeThickness,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Create("UIPadding", {
				PaddingTop = UDim.new(0, Theme.space.md),
				PaddingBottom = UDim.new(0, Theme.space.md),
				PaddingLeft = UDim.new(0, Theme.space.lg),
				PaddingRight = UDim.new(0, Theme.space.xl),
			}),
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, Theme.space.md),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local label = Create("TextLabel", {
			Name = "Text",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			RichText = true,
			Text = text,
			TextWrapped = true,
			LineHeight = Theme.text.body.lineHeight,
			TextColor3 = Theme.color.text,
			FontFace = Font.fromEnum(Theme.toast.font),
			Parent = root,
		})
		root.Parent = parent
		current = {
			root = root,
			label = label,
			icon = nil,
			text = text,
			token = myToken,
			kind = kind,
			textScale = opts.textScale or 1,
		}
		layout(current)

		TweenService:Create(root, Theme.ease.state, {
			GroupTransparency = 0,
			Position = UDim2.new(0.5, 0, 0, TOP_OFFSET),
		}):Play()
	end

	local entry = current :: Entry
	task.delay(duration, function()
		if entry.token == myToken and entry.root.Parent then
			hide(entry, reducedMotion)
			if current == entry then
				current = nil
			end
		end
	end)
end

return Toast
