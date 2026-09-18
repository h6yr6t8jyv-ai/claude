--!strict
-- The "haul" screen: full-screen modal that shakes a box, then reveals the
-- item + its QC grade, with Wear / Sell / Quick Sell / Keep actions.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)
local ItemData = require(Shared.ItemData)
local Remotes = require(Shared.Remotes)

local remotes = Remotes.Get()

local Unboxing = {}

function Unboxing.Mount(screenGui: ScreenGui, onInventoryChanged: () -> ())
	local overlay = Components.frame({
		Name = "UnboxingOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Corner = false,
		Visible = false,
		ZIndex = 50,
		Parent = screenGui,
	})

	local card = Components.frame({
		Name = "Card",
		Size = UDim2.fromOffset(360, 420),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.Surface,
		CornerRadius = Theme.Corner.Large,
		ZIndex = 51,
		Parent = overlay,
	})
	Components.stroke(card, Theme.Color.Border, 1)
	Components.padding(card, 20)

	local title = Components.label({
		Text = "Opening your haul...",
		Font = Theme.Font.Heading,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = card,
	})

	local box = Components.frame({
		Name = "Box",
		Size = UDim2.fromOffset(160, 160),
		Position = UDim2.new(0.5, 0, 0, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		CornerRadius = Theme.Corner.Medium,
		ZIndex = 52,
		Parent = card,
	})
	Components.label({ Text = "📦", TextSize = 64, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, Parent = box })

	local gradeLabel = Components.label({
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 230),
		Visible = false,
		ZIndex = 52,
		Parent = card,
	})

	local itemLabel = Components.label({
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = 16,
		TextColor3 = Theme.Color.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 258),
		Visible = false,
		ZIndex = 52,
		Parent = card,
	})

	local buttonRow = Components.frame({
		Name = "Buttons",
		Size = UDim2.new(1, 0, 0, 110),
		Position = UDim2.new(0, 0, 1, -110),
		BackgroundTransparency = 1,
		Corner = false,
		Visible = false,
		ZIndex = 52,
		Parent = card,
	})
	Components.listLayout(buttonRow, Enum.FillDirection.Vertical, 8)

	local currentInvId: string? = nil

	local function close()
		overlay.Visible = false
	end

	local function makeActionButton(text, color, order, callback)
		Components.button({
			Text = text,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = color,
			LayoutOrder = order,
			ZIndex = 52,
			Parent = buttonRow,
			OnClick = callback,
		})
	end

	buttonRow:ClearAllChildren()
	Components.listLayout(buttonRow, Enum.FillDirection.Vertical, 8)
	makeActionButton("Wear It", Theme.Color.Accent, 1, function()
		if currentInvId then
			remotes.WearItem:FireServer(currentInvId)
			close()
			onInventoryChanged()
		end
	end)
	makeActionButton("Quick Sell", Theme.Color.Warning, 2, function()
		if currentInvId then
			remotes.QuickSell:InvokeServer(currentInvId)
			close()
			onInventoryChanged()
		end
	end)
	makeActionButton("Keep in Closet", Theme.Color.SurfaceRaised, 3, function()
		close()
		onInventoryChanged()
	end)

	local function open(orderId: string)
		overlay.Visible = true
		title.Text = "Opening your haul..."
		gradeLabel.Visible = false
		itemLabel.Visible = false
		buttonRow.Visible = false
		box.Rotation = 0
		box.Size = UDim2.fromOffset(160, 160)

		-- shake
		for _ = 1, 6 do
			TweenService:Create(box, TweenInfo.new(0.06), { Rotation = math.random(-8, 8) }):Play()
			task.wait(0.07)
		end
		TweenService:Create(box, TweenInfo.new(0.08), { Rotation = 0 }):Play()

		local ok, itemId, qcGrade, invIdOrMessage = remotes.OpenPackage:InvokeServer(orderId)

		if not ok then
			title.Text = tostring(invIdOrMessage or "Couldn't open that package.")
			task.delay(1.6, close)
			return
		end

		currentInvId = invIdOrMessage
		local item = ItemData.ById[itemId]
		local grade = ItemData.GetGrade(qcGrade)

		TweenService:Create(box, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(120, 120) }):Play()
		title.Text = "You got:"
		gradeLabel.Text = grade.name
		gradeLabel.TextColor3 = grade.color
		gradeLabel.Visible = true
		itemLabel.Text = ("%s %s"):format(item.brand, item.name)
		itemLabel.Visible = true
		buttonRow.Visible = true

		onInventoryChanged()
	end

	remotes.OrderDelivered.OnClientEvent:Connect(function(orderId)
		open(orderId)
	end)

	return { Open = open, Close = close }
end

return Unboxing
