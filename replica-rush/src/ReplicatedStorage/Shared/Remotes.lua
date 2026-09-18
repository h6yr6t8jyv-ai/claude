--!strict
-- Single place that defines every client<->server call in the game.
-- Server calls Remotes.Init() once on startup to create the instances.
-- Both sides call Remotes.Get() to fetch a table of ready-to-use remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local EVENT_NAMES = {
	"WearItem", -- client -> server: fire(invId)
	"CancelListing", -- client -> server: fire(listingId)
	"BuyBattlepassPremiumWithRobux", -- client -> server: fire()
	"ClaimDailyReward", -- client -> server: fire()
	"Notify", -- server -> client: fire(player, {title, message, kind})
	"DataUpdated", -- server -> client: fire(player, snapshot)
	"OrderDelivered", -- server -> client: fire(player, orderId) -- triggers haul popup
}

local FUNCTION_NAMES = {
	"BuyItem", -- (itemId) -> ok: boolean, message: string
	"OpenPackage", -- (orderId) -> ok, itemId, qcGrade, message
	"ListForSale", -- (invId, price) -> ok, message
	"QuickSell", -- (invId) -> ok, amount, message
	"ClaimBattlepassReward", -- (level, track) -> ok, message
	"BuyBattlepassPremiumWithCoins", -- () -> ok, message
}

function Remotes.Init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local re = Instance.new("RemoteEvent")
			re.Name = name
			re.Parent = folder
		end
	end

	for _, name in FUNCTION_NAMES do
		if not folder:FindFirstChild(name) then
			local rf = Instance.new("RemoteFunction")
			rf.Name = name
			rf.Parent = folder
		end
	end

	return folder
end

function Remotes.Get()
	local folder = ReplicatedStorage:WaitForChild("Remotes", 30)
	assert(folder, "Remotes folder never appeared — did the server call Remotes.Init()?")

	local remotes: { [string]: any } = {}
	for _, name in EVENT_NAMES do
		remotes[name] = folder:WaitForChild(name)
	end
	for _, name in FUNCTION_NAMES do
		remotes[name] = folder:WaitForChild(name)
	end
	return remotes
end

return Remotes
