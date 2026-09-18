--!strict
-- Popup used from the Closet: choose to List on ThriftLyst at a chosen price,
-- or Quick Sell instantly for a guaranteed (lower) payout.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local remotes = Remotes.Get()

local SellModal = {}

function SellModal.Mount(screenGui: ScreenGui, notify, onChanged: () -> ())
	local overlay = Components.frame({
		Name = "SellModalOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Corner = false,
		Visible = false,
		ZIndex = 45,
		Parent = screenGui,
	})

	local card = Components.frame({
		Size = UDim2.fromOffset(320, 300),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.Surface,
		CornerRadius = Theme.Corner.Large,
		ZIndex = 46,
		Parent = overlay,
	})
	Components.stroke(card, Theme.Color.Border, 1)
	Components.padding(card, 16)

	local title = Components.label({ Font = Theme.Font.Heading, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), ZIndex = 46, Parent = card })
	local subtitle = Components.label({ Font = Theme.Font.Body, TextSize = 12, TextColor3 = Theme.Color.TextSecondary, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, 24), ZIndex = 46, Parent = card })

	local priceBox = Instance.new("TextBox")
	priceBox.Size = UDim2.new(1, 0, 0, 40)
	priceBox.Position = UDim2.new(0, 0, 0, 64)
	priceBox.BackgroundColor3 = Theme.Color.SurfaceRaised
	priceBox.Font = Theme.Font.Bold
	priceBox.TextSize = 18
	priceBox.TextColor3 = Theme.Color.TextPrimary
	priceBox.PlaceholderText = "Listing price"
	priceBox.ClearTextOnFocus = false
	priceBox.ZIndex = 46
	priceBox.Parent = card
	Components.corner(priceBox, Theme.Corner.Small)

	local listButton = Components.button({
		Text = "List on ThriftLyst",
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, 116),
		BackgroundColor3 = Theme.Color.AccentAlt,
		ZIndex = 46,
		Parent = card,
	})

	local quickSellButton = Components.button({
		Text = "Quick Sell",
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, 166),
		BackgroundColor3 = Theme.Color.Gold,
		TextColor3 = Color3.new(0, 0, 0),
		ZIndex = 46,
		Parent = card,
	})

	local cancelButton = Components.button({
		Text = "Cancel",
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.new(0, 0, 1, -36),
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		ZIndex = 46,
		Parent = card,
	})

	local currentInvId: string? = nil
	local currentMarketValue = 0

	local function close()
		overlay.Visible = false
	end
	cancelButton.MouseButton1Click:Connect(close)

	listButton.MouseButton1Click:Connect(function()
		local price = tonumber(priceBox.Text)
		if not currentInvId or not price then
			notify({ title = "Enter a price", message = "Type a number first.", kind = "warning" })
			return
		end
		local ok, message = remotes.ListForSale:InvokeServer(currentInvId, price)
		notify({ title = ok and "Listed!" or "Couldn't list", message = message, kind = ok and "success" or "warning" })
		if ok then
			close()
			onChanged()
		end
	end)

	quickSellButton.MouseButton1Click:Connect(function()
		if not currentInvId then
			return
		end
		local ok, amount, message = remotes.QuickSell:InvokeServer(currentInvId)
		notify({ title = ok and "Sold!" or "Couldn't sell", message = message, kind = ok and "success" or "warning" })
		if ok then
			close()
			onChanged()
		end
	end)

	local function open(invId: string, item, grade, marketValue: number)
		currentInvId = invId
		currentMarketValue = marketValue
		title.Text = ("Sell %s %s"):format(item.brand, item.name)
		subtitle.Text = ("%s · Market value ~$%d"):format(grade.name, marketValue)
		priceBox.Text = tostring(marketValue)
		quickSellButton.Text = ("Quick Sell — $%d instantly"):format(math.floor(marketValue * Config.QUICK_SELL_PERCENT))
		overlay.Visible = true
	end

	return { Open = open }
end

return SellModal
