--!strict
-- "ThriftLyst" — the Depop/Vinted-style resale marketplace. Players list a
-- piece from their closet at a price they choose; simulated buyers roll a
-- chance to bite every few seconds based on how good the price is versus
-- market value. There's also an instant guaranteed Quick Sell.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemData = require(Shared.ItemData)
local Remotes = require(Shared.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local Notify = require(script.Parent.Notify)
local BattlepassService = require(script.Parent.BattlepassService)

local remotes = Remotes.Get()

local ResellMarketService = {}

local function watchListing(player: Player, listingId: string)
	while true do
		task.wait(Config.LISTING_CHECK_INTERVAL)

		local data = PlayerDataService.Get(player)
		if not data then
			return
		end
		local listing = data.Listings[listingId]
		if not listing then
			return -- cancelled or already sold
		end

		local marketValue = ItemData.GetMarketValue(listing.itemId, listing.qcGrade)
		if marketValue <= 0 then
			return
		end

		-- Priced at or under market value sells fast; overpriced listings sell slowly.
		local priceRatio = listing.price / marketValue
		local sellChance = math.clamp(1.15 - priceRatio, 0.05, 0.9)

		if math.random() < sellChance then
			data.Listings[listingId] = nil
			data.Inventory[listing.invId] = nil

			local fee = math.floor(listing.price * Config.RESELL_FEE_PERCENT + 0.5)
			local payout = listing.price - fee
			data.Cash += payout

			local item = ItemData.ById[listing.itemId]
			BattlepassService.AddXP(player, Config.XP_PER_SALE)
			PlayerDataService.Push(player)
			Notify.Send(
				player,
				"Sold on ThriftLyst!",
				("Your %s %s sold for $%d (after %d%% fee)."):format(item.brand, item.name, payout, math.floor(Config.RESELL_FEE_PERCENT * 100)),
				"success"
			)
			return
		end
	end
end

function ResellMarketService.Init()
	remotes.ListForSale.OnServerInvoke = function(player: Player, invId: string, price: number)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, "Data not loaded."
		end
		local invItem = data.Inventory[invId]
		if not invItem then
			return false, "You don't own that item."
		end
		if invItem.equipped then
			return false, "Unequip it before listing."
		end
		if type(price) ~= "number" or price ~= price or price <= 0 then
			return false, "Invalid price."
		end

		local marketValue = ItemData.GetMarketValue(invItem.itemId, invItem.qcGrade)
		local minPrice = math.floor(marketValue * Config.MIN_LISTING_PERCENT)
		local maxPrice = math.ceil(marketValue * Config.MAX_LISTING_PERCENT)
		price = math.clamp(math.floor(price), minPrice, maxPrice)

		local listingId = "listing_" .. data.NextListingId
		data.NextListingId += 1

		data.Listings[listingId] = {
			invId = invId,
			itemId = invItem.itemId,
			qcGrade = invItem.qcGrade,
			price = price,
			listedAt = os.time(),
		}

		PlayerDataService.Push(player)
		task.spawn(watchListing, player, listingId)

		return true, ("Listed for $%d."):format(price)
	end

	remotes.CancelListing.OnServerEvent:Connect(function(player: Player, listingId: string)
		local data = PlayerDataService.Get(player)
		if not data then
			return
		end
		if data.Listings[listingId] then
			data.Listings[listingId] = nil
			PlayerDataService.Push(player)
		end
	end)

	remotes.QuickSell.OnServerInvoke = function(player: Player, invId: string)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, 0, "Data not loaded."
		end
		local invItem = data.Inventory[invId]
		if not invItem then
			return false, 0, "You don't own that item."
		end
		if invItem.equipped then
			return false, 0, "Unequip it before selling."
		end

		local marketValue = ItemData.GetMarketValue(invItem.itemId, invItem.qcGrade)
		local payout = math.floor(marketValue * Config.QUICK_SELL_PERCENT)

		data.Inventory[invId] = nil
		data.Cash += payout
		BattlepassService.AddXP(player, Config.XP_PER_SALE)
		PlayerDataService.Push(player)

		return true, payout, ("Quick sold for $%d."):format(payout)
	end

	-- Resume watching any listings that were still active from a previous session.
	game:GetService("Players").PlayerAdded:Connect(function(player)
		task.spawn(function()
			local data
			for _ = 1, 100 do
				data = PlayerDataService.Get(player)
				if data then
					break
				end
				task.wait(0.1)
			end
			if not data then
				return
			end
			for listingId in data.Listings do
				task.spawn(watchListing, player, listingId)
			end
		end)
	end)
end

return ResellMarketService
