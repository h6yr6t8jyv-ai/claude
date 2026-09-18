--!strict
-- Shows every order: shipping progress, delivered (open it), or seized.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)
local ItemData = require(Shared.ItemData)
local Config = require(Shared.Config)

local OrdersTab = {}

local STATUS_COLOR = {
	Shipping = Theme.Color.AccentAlt,
	Delivered = Theme.Color.Success,
	Seized = Theme.Color.Danger,
	Opened = Theme.Color.TextMuted,
}

function OrdersTab.Build(parent: Instance, state, notify, unboxing)
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "OrdersScroller"
	scroller.BackgroundTransparency = 1
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Color.Border
	scroller.Parent = parent
	Components.padding(scroller, 4)
	Components.listLayout(scroller, Enum.FillDirection.Vertical, 8)

	local function refresh()
		Components.clearChildren(scroller, { "UIPadding", "UIListLayout" })

		local orders = state.Data.Orders or {}
		local sorted = {}
		for orderId, order in orders do
			if order.status ~= "Opened" then
				table.insert(sorted, { id = orderId, order = order })
			end
		end
		table.sort(sorted, function(a, b)
			return a.order.boughtAt > b.order.boughtAt
		end)

		if #sorted == 0 then
			Components.label({
				Text = ("No orders yet. Head to the Shop — every order has a %d%% chance of getting seized by customs, so QC hauls are always a gamble!"):format(
					math.floor(Config.CUSTOMS_SEIZURE_CHANCE * 100)
				),
				Font = Theme.Font.Body,
				TextSize = 13,
				TextColor3 = Theme.Color.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 60),
				Parent = scroller,
			})
			return
		end

		for i, entry in sorted do
			local orderId, order = entry.id, entry.order
			local item = ItemData.ById[order.itemId]
			if not item then
				continue
			end

			local card = Components.frame({
				Name = orderId,
				Size = UDim2.new(1, 0, 0, 86),
				BackgroundColor3 = Theme.Color.Surface,
				CornerRadius = Theme.Corner.Medium,
				LayoutOrder = i,
				Parent = scroller,
			})
			Components.stroke(card, STATUS_COLOR[order.status] or Theme.Color.Border, 1)
			Components.padding(card, 10)

			Components.label({
				Text = ("%s %s"):format(item.brand, item.name),
				Font = Theme.Font.Bold,
				TextSize = 14,
				Size = UDim2.new(1, -80, 0, 18),
				Parent = card,
			})
			Components.label({
				Text = order.status,
				Font = Theme.Font.Heading,
				TextSize = 12,
				TextColor3 = STATUS_COLOR[order.status] or Theme.Color.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.new(0, 80, 0, 18),
				Position = UDim2.new(1, -80, 0, 0),
				Parent = card,
			})

			if order.status == "Shipping" then
				local total = order.deliverAt - order.boughtAt
				local progress = math.clamp((os.time() - order.boughtAt) / math.max(total, 1), 0, 1)
				Components.progressBar({
					Size = UDim2.new(1, 0, 0, 8),
					Position = UDim2.new(0, 0, 0, 30),
					Progress = progress,
					FillColor = Theme.Color.AccentAlt,
					FillColorB = Theme.Color.Accent,
					Parent = card,
				})
				local remaining = math.max(0, order.deliverAt - os.time())
				Components.label({
					Text = ("~%ds remaining"):format(remaining),
					Font = Theme.Font.Body,
					TextSize = 12,
					TextColor3 = Theme.Color.TextMuted,
					Size = UDim2.new(1, 0, 0, 16),
					Position = UDim2.new(0, 0, 0, 42),
					Parent = card,
				})
			elseif order.status == "Delivered" then
				Components.button({
					Text = "Open Haul",
					Size = UDim2.new(1, 0, 0, 30),
					Position = UDim2.new(0, 0, 1, -30),
					BackgroundColor3 = Theme.Color.Success,
					Parent = card,
					OnClick = function()
						unboxing.Open(orderId)
					end,
				})
			elseif order.status == "Seized" then
				Components.label({
					Text = ("Seized by customs — you got %d Coins as a consolation."):format(Config.SEIZURE_CONSOLATION_COINS),
					Font = Theme.Font.Body,
					TextSize = 12,
					TextColor3 = Theme.Color.TextMuted,
					Size = UDim2.new(1, 0, 0, 32),
					Position = UDim2.new(0, 0, 0, 32),
					Parent = card,
				})
			end
		end
	end

	refresh()
	return refresh
end

return OrdersTab
