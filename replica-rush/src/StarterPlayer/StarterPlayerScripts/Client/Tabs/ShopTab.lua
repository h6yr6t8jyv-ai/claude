--!strict
-- "DupeDeal" catalog — browse and buy counterfeit items with Cash.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)
local ItemData = require(Shared.ItemData)
local Remotes = require(Shared.Remotes)

local remotes = Remotes.Get()

local ShopTab = {}

function ShopTab.Build(parent: Instance, state, notify)
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "ShopScroller"
	scroller.BackgroundTransparency = 1
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Color.Border
	scroller.Parent = parent

	Components.padding(scroller, 4)
	local grid = Components.gridLayout(scroller, UDim2.fromOffset(148, 168), 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder

	for i, item in ItemData.Items do
		local card = Components.frame({
			Name = item.id,
			BackgroundColor3 = Theme.Color.Surface,
			CornerRadius = Theme.Corner.Medium,
			LayoutOrder = i,
			Parent = scroller,
		})
		Components.stroke(card, Theme.Color.Border, 1)
		Components.padding(card, 8)

		local swatch = Components.frame({
			Name = "Swatch",
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundColor3 = item.accentColor,
			CornerRadius = Theme.Corner.Small,
			Parent = card,
		})
		Components.label({
			Text = item.brand,
			Font = Theme.Font.Heading,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromScale(1, 1),
			Parent = swatch,
		})

		Components.label({
			Text = item.name,
			Font = Theme.Font.Bold,
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.new(0, 0, 0, 76),
			Parent = card,
		})
		Components.label({
			Text = item.category,
			Font = Theme.Font.Body,
			TextSize = 11,
			TextColor3 = Theme.Color.TextMuted,
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.new(0, 0, 0, 94),
			Parent = card,
		})

		local buyButton = Components.button({
			Text = ("Buy $%d"):format(item.basePrice),
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 1, -30),
			BackgroundColor3 = Theme.Color.Accent,
			Parent = card,
			OnClick = function()
				local ok, message = remotes.BuyItem:InvokeServer(item.id)
				if not ok then
					notify({ title = "Can't buy that", message = message, kind = "warning" })
				end
			end,
		})
		buyButton.ZIndex = 2
	end
end

return ShopTab
