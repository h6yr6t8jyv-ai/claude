--!strict
-- Small reusable UI builder functions so tab modules stay short and every
-- button/card/bar looks consistent across the app.

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local Components = {}

function Components.corner(instance: Instance, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or Theme.Corner.Medium
	c.Parent = instance
	return c
end

function Components.stroke(instance: Instance, color: Color3?, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Color.Border
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
	return s
end

function Components.gradient(instance: Instance, colorA: Color3, colorB: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(colorA, colorB)
	g.Rotation = rotation or 90
	g.Parent = instance
	return g
end

function Components.padding(instance: Instance, all: number?)
	local p = Instance.new("UIPadding")
	local n = all or Theme.Padding
	p.PaddingTop = UDim.new(0, n)
	p.PaddingBottom = UDim.new(0, n)
	p.PaddingLeft = UDim.new(0, n)
	p.PaddingRight = UDim.new(0, n)
	p.Parent = instance
	return p
end

function Components.listLayout(instance: Instance, direction: Enum.FillDirection?, gap: number?, sortOrder: Enum.SortOrder?)
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap or 8)
	l.SortOrder = sortOrder or Enum.SortOrder.LayoutOrder
	l.Parent = instance
	return l
end

function Components.gridLayout(instance: Instance, cellSize: UDim2, gap: number?)
	local g = Instance.new("UIGridLayout")
	g.CellSize = cellSize
	g.CellPadding = UDim2.fromOffset(gap or 10, gap or 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = instance
	return g
end

function Components.frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.Surface
	f.BackgroundTransparency = props.BackgroundTransparency or 0
	f.BorderSizePixel = 0
	f.Size = props.Size or UDim2.fromScale(1, 1)
	f.Position = props.Position or UDim2.fromScale(0, 0)
	f.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	f.Visible = props.Visible ~= false
	f.LayoutOrder = props.LayoutOrder or 0
	f.ZIndex = props.ZIndex or 1
	f.ClipsDescendants = props.ClipsDescendants or false
	f.Name = props.Name or "Frame"
	if props.AutomaticSize then
		f.AutomaticSize = props.AutomaticSize
	end
	if props.Corner ~= false then
		Components.corner(f, props.CornerRadius)
	end
	if props.Parent then
		f.Parent = props.Parent
	end
	return f
end

function Components.label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = props.Text or ""
	l.Font = props.Font or Theme.Font.Body
	l.TextSize = props.TextSize or 16
	l.TextColor3 = props.TextColor3 or Theme.Color.TextPrimary
	l.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	l.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	l.TextWrapped = props.TextWrapped ~= false
	l.Size = props.Size or UDim2.new(1, 0, 0, 20)
	l.Position = props.Position or UDim2.fromScale(0, 0)
	l.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	l.LayoutOrder = props.LayoutOrder or 0
	l.ZIndex = props.ZIndex or 1
	l.TextTruncate = props.TextTruncate or Enum.TextTruncate.None
	l.Name = props.Name or "Label"
	if props.AutomaticSize then
		l.AutomaticSize = props.AutomaticSize
	end
	if props.Parent then
		l.Parent = props.Parent
	end
	return l
end

function Components.icon(props: { [string]: any }): ImageLabel
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = props.BackgroundTransparency ~= nil and props.BackgroundTransparency or 1
	i.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.SurfaceRaised
	i.Image = props.Image or "rbxassetid://0"
	i.ImageColor3 = props.ImageColor3 or Color3.new(1, 1, 1)
	i.ScaleType = props.ScaleType or Enum.ScaleType.Fit
	i.Size = props.Size or UDim2.fromOffset(32, 32)
	i.Position = props.Position or UDim2.fromScale(0, 0)
	i.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	i.LayoutOrder = props.LayoutOrder or 0
	i.ZIndex = props.ZIndex or 1
	i.Name = props.Name or "Icon"
	if props.Corner then
		Components.corner(i, props.CornerRadius)
	end
	if props.Parent then
		i.Parent = props.Parent
	end
	return i
end

function Components.button(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.Accent
	b.Text = props.Text or "Button"
	b.Font = props.Font or Theme.Font.Bold
	b.TextSize = props.TextSize or 16
	b.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	b.Size = props.Size or UDim2.new(1, 0, 0, 44)
	b.Position = props.Position or UDim2.fromScale(0, 0)
	b.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	b.LayoutOrder = props.LayoutOrder or 0
	b.ZIndex = props.ZIndex or 1
	b.Name = props.Name or "Button"
	Components.corner(b, props.CornerRadius or Theme.Corner.Medium)

	local baseColor = b.BackgroundColor3
	local hoverColor = props.HoverColor or baseColor:Lerp(Color3.new(1, 1, 1), 0.12)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.06), { Size = (props.Size or UDim2.new(1, 0, 0, 44)) - UDim2.fromOffset(4, 4) }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.08), { Size = props.Size or UDim2.new(1, 0, 0, 44) }):Play()
	end)

	if props.Parent then
		b.Parent = props.Parent
	end
	if props.OnClick then
		b.MouseButton1Click:Connect(props.OnClick)
	end
	return b
end

-- A horizontal fill bar (progress / shipping timer / xp bar).
function Components.progressBar(props: { [string]: any })
	local track = Components.frame({
		Name = props.Name or "ProgressTrack",
		Size = props.Size or UDim2.new(1, 0, 0, 10),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = props.TrackColor or Theme.Color.SurfaceRaised,
		CornerRadius = Theme.Corner.Pill,
		Parent = props.Parent,
	})
	local fill = Components.frame({
		Name = "Fill",
		Size = UDim2.new(math.clamp(props.Progress or 0, 0, 1), 0, 1, 0),
		BackgroundColor3 = props.FillColor or Theme.Color.Accent,
		CornerRadius = Theme.Corner.Pill,
		Parent = track,
	})
	Components.gradient(fill, props.FillColor or Theme.Color.Accent, props.FillColorB or Theme.Color.AccentAlt, 0)
	return track, fill
end

function Components.setProgress(fill: Frame, progress: number, tweenTime: number?)
	local goal = { Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0) }
	if tweenTime and tweenTime > 0 then
		TweenService:Create(fill, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad), goal):Play()
	else
		fill.Size = goal.Size
	end
end

function Components.clearChildren(instance: Instance, keepClassNames: { string }?)
	local keep: { [string]: boolean } = {}
	if keepClassNames then
		for _, n in keepClassNames do
			keep[n] = true
		end
	end
	for _, child in instance:GetChildren() do
		if not keep[child.ClassName] then
			child:Destroy()
		end
	end
end

return Components
