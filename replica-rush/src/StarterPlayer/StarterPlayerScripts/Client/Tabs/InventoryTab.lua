--!strict
-- "Closet" — everything the player owns. Wear/unwear, or send to ThriftLyst
-- (list for sale) / Quick Sell for instant guaranteed cash.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)
local ItemData = require(Shared.ItemData)
local Remotes = require(Shared.Remotes)

local remotes = Remotes.Get()

local InventoryTab = {}

function InventoryTab.Build(parent: Instance, state, notify, openSellModal)
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "ClosetScroller"
	scroller.BackgroundTransparency = 1
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Color.Border
	scroller.Parent = parent
	Components.padding(scroller, 4)

	local function refresh()
		Components.clearChildren(scroller, { "UIPadding" })
		local grid = Components.gridLayout(scroller, UDim2.fromOffset(148, 190), 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder

		local inv = state.Data.Inventory or {}
		local ids = {}
		for invId in inv do
			table.insert(ids, invId)
		end
		table.sort(ids, function(a, b)
			return (inv[a].obtainedAt or 0) > (inv[b].obtainedAt or 0)
		end)

		if #ids == 0 then
			grid:Destroy()
			Components.label({
				Text = "Your closet is empty. Open a haul from the Orders tab to get your first piece.",
				Font = Theme.Font.Body,
				TextSize = 13,
				TextColor3 = Theme.Color.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 60),
				Parent = scroller,
			})
			return
		end

		for i, invId in ids do
			local invItem = inv[invId]
			local item = ItemData.ById[invItem.itemId]
			if not item then
				continue
			end
			local grade = ItemData.GetGrade(invItem.qcGrade)
			local marketValue = ItemData.GetMarketValue(invItem.itemId, invItem.qcGrade)

			local card = Components.frame({
				Name = invId,
				BackgroundColor3 = Theme.Color.Surface,
				CornerRadius = Theme.Corner.Medium,
				LayoutOrder = i,
				Parent = scroller,
			})
			Components.stroke(card, invItem.equipped and Theme.Color.Accent or Theme.Color.Border, invItem.equipped and 2 or 1)
			Components.padding(card, 8)

			local swatch = Components.frame({ Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = item.accentColor, CornerRadius = Theme.Corner.Small, Parent = card })
			Components.label({ Text = item.brand, Font = Theme.Font.Heading, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = swatch })

			Components.label({ Text = item.name, Font = Theme.Font.Bold, TextSize = 12, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 62), Parent = card })
			Components.label({ Text = grade.name .. (" · $%d"):format(marketValue), Font = Theme.Font.Body, TextSize = 11, TextColor3 = grade.color, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 78), Parent = card })

			Components.button({
				Text = invItem.equipped and "Unwear" or "Wear",
				Size = UDim2.new(1, 0, 0, 26),
				Position = UDim2.new(0, 0, 0, 98),
				BackgroundColor3 = invItem.equipped and Theme.Color.SurfaceRaised or Theme.Color.Accent,
				TextSize = 13,
				Parent = card,
				OnClick = function()
					remotes.WearItem:FireServer(invId)
				end,
			})

			Components.button({
				Text = "Sell",
				Size = UDim2.new(1, 0, 0, 26),
				Position = UDim2.new(0, 0, 0, 128),
				BackgroundColor3 = Theme.Color.Gold,
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 13,
				Parent = card,
				OnClick = function()
					if invItem.equipped then
						notify({ title = "Unwear first", message = "Take it off before selling.", kind = "warning" })
						return
					end
					openSellModal(invId, item, grade, marketValue)
				end,
			})
		end
	end

	refresh()
	return refresh
end

return InventoryTab
