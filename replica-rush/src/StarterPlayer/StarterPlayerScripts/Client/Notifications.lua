--!strict
-- Toast notifications stacked top-center. Used for shipping updates, customs
-- seizures, sales, level ups, daily rewards, etc.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)

local KIND_COLOR = {
	info = Theme.Color.AccentAlt,
	success = Theme.Color.Success,
	warning = Theme.Color.Warning,
	danger = Theme.Color.Danger,
}

local KIND_ICON = {
	info = "i",
	success = "✓",
	warning = "!",
	danger = "✕",
}

local Notifications = {}

function Notifications.Mount(screenGui: ScreenGui)
	local container = Components.frame({
		Name = "ToastContainer",
		Size = UDim2.new(0, 340, 1, -20),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Corner = false,
		Parent = screenGui,
	})
	Components.listLayout(container, Enum.FillDirection.Vertical, 8, Enum.SortOrder.LayoutOrder)

	local order = 0

	local function show(data)
		order += 1
		local kind = data.kind or "info"
		local color = KIND_COLOR[kind] or Theme.Color.AccentAlt

		local toast = Components.frame({
			Name = "Toast",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Color.SurfaceRaised,
			CornerRadius = Theme.Corner.Medium,
			LayoutOrder = order,
			Parent = container,
		}) :: any
		toast.AutomaticSize = Enum.AutomaticSize.Y
		Components.stroke(toast, color, 1.5)
		Components.padding(toast, 12)

		local row = Components.frame({ Name = "Row", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Corner = false, Parent = toast }) :: any
		row.AutomaticSize = Enum.AutomaticSize.Y
		Components.listLayout(row, Enum.FillDirection.Horizontal, 10)

		local badge = Components.frame({ Name = "Badge", Size = UDim2.fromOffset(28, 28), BackgroundColor3 = color, CornerRadius = Theme.Corner.Pill, Parent = row })
		Components.label({ Text = KIND_ICON[kind] or "i", Font = Theme.Font.Heading, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = badge })

		local textCol = Components.frame({ Name = "Text", Size = UDim2.new(1, -38, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Corner = false, Parent = row }) :: any
		textCol.AutomaticSize = Enum.AutomaticSize.Y
		Components.listLayout(textCol, Enum.FillDirection.Vertical, 2)

		Components.label({ Text = data.title or "", Font = Theme.Font.Bold, TextSize = 15, Size = UDim2.new(1, 0, 0, 18), Parent = textCol })
		Components.label({
			Text = data.message or "",
			Font = Theme.Font.Body,
			TextSize = 13,
			TextColor3 = Theme.Color.TextSecondary,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = textCol,
		})

		toast.Position = UDim2.new(1.4, 0, 0, 0)
		toast.Parent = container
		TweenService:Create(toast, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()

		task.delay(4.2, function()
			if toast.Parent then
				local tw = TweenService:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1.4, 0, 0, 0) })
				tw:Play()
				tw.Completed:Connect(function()
					toast:Destroy()
				end)
			end
		end)
	end

	return show
end

return Notifications
