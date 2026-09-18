--!strict
-- Server bootstrap: creates remotes, leaderstats, then starts every service.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

Remotes.Init()

-- Classic Roblox leaderboard display (separate from the full data snapshot
-- pushed over DataUpdated, which the phone UI actually reads from).
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = leaderstats

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats
end)

local PlayerDataService = require(script.Parent.PlayerDataService)
local OrderService = require(script.Parent.OrderService)
local ResellMarketService = require(script.Parent.ResellMarketService)
local InventoryService = require(script.Parent.InventoryService)
local BattlepassService = require(script.Parent.BattlepassService)
local DailyRewardService = require(script.Parent.DailyRewardService)

BattlepassService.Init()
OrderService.Init()
ResellMarketService.Init()
InventoryService.Init()
DailyRewardService.Init()

-- Keep the classic leaderboard numbers in sync with the real data table.
local function syncLeaderstats(player: Player)
	local data = PlayerDataService.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if data and leaderstats then
		leaderstats.Cash.Value = data.Cash
		leaderstats.Coins.Value = data.Coins
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			syncLeaderstats(player)
		end
	end
end)

print("[ReplicaRush] Server systems online.")
