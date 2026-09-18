--!strict
-- Owns the authoritative per-player data table, loads/saves it to DataStore,
-- and pushes snapshots to the client whenever something changes.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local remotes = Remotes.Get()
local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

local PlayerDataService = {}

local profiles: { [Player]: any } = {}

local function defaultData()
	return {
		Cash = Config.STARTING_CASH,
		Coins = Config.STARTING_COINS,
		NextOrderId = 1,
		NextInvId = 1,
		NextListingId = 1,
		Orders = {}, -- [orderId] = {itemId, boughtAt, deliverAt, status, qcGrade}
		Inventory = {}, -- [invId] = {itemId, qcGrade, obtainedAt, equipped}
		Listings = {}, -- [listingId] = {invId, itemId, qcGrade, price, listedAt}
		Battlepass = { XP = 0, Level = 1, PremiumOwned = false, ClaimedFree = {}, ClaimedPremium = {} },
		DailyReward = { LastClaimUnix = 0, Streak = 0 },
	}
end

local function deepCopy(t)
	if typeof(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in t do
		copy[k] = deepCopy(v)
	end
	return copy
end

function PlayerDataService.Get(player: Player)
	return profiles[player]
end

function PlayerDataService.Push(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	remotes.DataUpdated:FireClient(player, deepCopy(data))
end

function PlayerDataService.Load(player: Player)
	local key = "Player_" .. player.UserId
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)

	local data
	if ok and result then
		data = result
		-- Backfill any new fields added after this player's first save.
		local defaults = defaultData()
		for k, v in defaults do
			if data[k] == nil then
				data[k] = v
			end
		end
	else
		data = defaultData()
	end

	profiles[player] = data
	PlayerDataService.Push(player)
end

function PlayerDataService.Save(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local key = "Player_" .. player.UserId
	local ok, err = pcall(function()
		store:SetAsync(key, data)
	end)
	if not ok then
		warn("[PlayerDataService] Save failed for", player.Name, err)
	end
end

function PlayerDataService.Release(player: Player)
	PlayerDataService.Save(player)
	profiles[player] = nil
end

Players.PlayerAdded:Connect(PlayerDataService.Load)
Players.PlayerRemoving:Connect(PlayerDataService.Release)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerDataService.Save(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			PlayerDataService.Save(player)
		end
	end
end)

return PlayerDataService
