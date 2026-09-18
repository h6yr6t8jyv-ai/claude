--!strict
-- "ThriftLyst" — the player's active resale listings, with a cancel option.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)
local ItemData = require(Shared.ItemData)
local Remotes = require(Shared.Remotes)

local remotes = Remotes.Get()

local MarketTab = {}

function MarketTab.Build(parent: Instance, state, notify)
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "MarketScroller"
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
		Components.listLayout(scroller, Enum.FillDirection.Vertical, 8)

		local listings = state.Data.Listings or {}
		local ids = {}
		for listingId in listings do
			table.insert(ids, listingId)
		end

		if #ids == 0 then
			Components.label({
				Text = "You have no active ThriftLyst listings. List an item from your Closet to start earning while you're away.",
				Font = Theme.Font.Body,
				TextSize = 13,
				TextColor3 = Theme.Color.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 60),
				Parent = scroller,
			})
			return
		end

		table.sort(ids, function(a, b)
			return (listings[a].listedAt or 0) > (listings[b].listedAt or 0)
		end)

		for i, listingId in ids do
			local listing = listings[listingId]
			local item = ItemData.ById[listing.itemId]
			if not item then
				continue
			end
			local grade = ItemData.GetGrade(listing.qcGrade)

			local card = Components.frame({
				Size = UDim2.new(1, 0, 0, 64),
				BackgroundColor3 = Theme.Color.Surface,
				CornerRadius = Theme.Corner.Medium,
				LayoutOrder = i,
				Parent = scroller,
			})
			Components.stroke(card, Theme.Color.Border, 1)
			Components.padding(card, 10)

			Components.label({
				Text = ("%s %s"):format(item.brand, item.name),
				Font = Theme.Font.Bold,
				TextSize = 14,
				Size = UDim2.new(1, -90, 0, 18),
				Parent = card,
			})
			Components.label({
				Text = ("%s · Listed $%d"):format(grade.name, listing.price),
				Font = Theme.Font.Body,
				TextSize = 12,
				TextColor3 = grade.color,
				Size = UDim2.new(1, -90, 0, 16),
				Position = UDim2.new(0, 0, 0, 20),
				Parent = card,
			})

			Components.button({
				Text = "Cancel",
				Size = UDim2.new(0, 80, 0, 28),
				Position = UDim2.new(1, -80, 0, 6),
				BackgroundColor3 = Theme.Color.Danger,
				TextSize = 12,
				Parent = card,
				OnClick = function()
					remotes.CancelListing:FireServer(listingId)
				end,
			})
		end
	end

	refresh()
	return refresh
end

return MarketTab
