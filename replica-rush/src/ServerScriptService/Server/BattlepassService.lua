--!strict
-- "Heat Pass" leveling, free/premium reward claiming, and unlocking premium
-- either via a Robux Game Pass or a Coins buy-out.

local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local BattlepassData = require(Shared.BattlepassData)
local ProductIds = require(Shared.ProductIds)
local Remotes = require(Shared.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local Notify = require(script.Parent.Notify)

local remotes = Remotes.Get()

local BattlepassService = {}

function BattlepassService.AddXP(player: Player, amount: number)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	local bp = data.Battlepass
	bp.XP += amount
	local newLevel = math.min(Config.BATTLEPASS_MAX_LEVEL, (bp.XP // Config.BATTLEPASS_XP_PER_LEVEL) + 1)
	if newLevel > bp.Level then
		bp.Level = newLevel
		Notify.Send(player, "Heat Pass Level Up!", ("You reached Heat Pass level %d."):format(newLevel), "success")
	end
	PlayerDataService.Push(player)
end

local function grantReward(player: Player, data, reward)
	if reward.kind == "Cash" then
		data.Cash += reward.amount
	elseif reward.kind == "Coins" then
		data.Coins += reward.amount
	elseif reward.kind == "Item" then
		local invId = "inv_" .. data.NextInvId
		data.NextInvId += 1
		data.Inventory[invId] = {
			itemId = reward.itemId,
			qcGrade = "museum", -- pass-exclusive drops are always top grade
			obtainedAt = os.time(),
			equipped = false,
		}
	end
end

function BattlepassService.Init()
	remotes.ClaimBattlepassReward.OnServerInvoke = function(player: Player, level: number, track: string)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, "Data not loaded."
		end
		local bp = data.Battlepass
		if level > bp.Level then
			return false, "You haven't reached that level yet."
		end
		local rewardRow = BattlepassData.Rewards[level]
		if not rewardRow then
			return false, "Invalid level."
		end

		if track == "premium" then
			if not bp.PremiumOwned then
				return false, "Unlock Heat Pass Premium first."
			end
			if bp.ClaimedPremium[tostring(level)] then
				return false, "Already claimed."
			end
			bp.ClaimedPremium[tostring(level)] = true
			grantReward(player, data, rewardRow.premium)
		elseif track == "free" then
			if bp.ClaimedFree[tostring(level)] then
				return false, "Already claimed."
			end
			bp.ClaimedFree[tostring(level)] = true
			grantReward(player, data, rewardRow.free)
		else
			return false, "Invalid track."
		end

		PlayerDataService.Push(player)
		return true, "Reward claimed."
	end

	remotes.BuyBattlepassPremiumWithCoins.OnServerInvoke = function(player: Player)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, "Data not loaded."
		end
		if data.Battlepass.PremiumOwned then
			return false, "You already own Heat Pass Premium."
		end
		if data.Coins < Config.BATTLEPASS_PREMIUM_COST_COINS then
			return false, "Not enough Coins."
		end
		data.Coins -= Config.BATTLEPASS_PREMIUM_COST_COINS
		data.Battlepass.PremiumOwned = true
		PlayerDataService.Push(player)
		Notify.Send(player, "Heat Pass Premium!", "Unlocked with Coins. Go claim your premium rewards.", "success")
		return true, "Unlocked."
	end

	remotes.BuyBattlepassPremiumWithRobux.OnServerEvent:Connect(function(player: Player)
		local gamepassId = ProductIds.GamePasses.HeatPass_Premium
		if gamepassId == 0 then
			Notify.Send(player, "Not Configured", "The developer hasn't set up the Heat Pass Game Pass id yet.", "warning")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
		if wasPurchased and gamepassId == ProductIds.GamePasses.HeatPass_Premium then
			local data = PlayerDataService.Get(player)
			if data and not data.Battlepass.PremiumOwned then
				data.Battlepass.PremiumOwned = true
				PlayerDataService.Push(player)
				Notify.Send(player, "Heat Pass Premium!", "Thanks for the support. Go claim your premium rewards.", "success")
			end
		end
	end)

	-- Re-grant ownership on join in case a player bought the pass outside a session.
	game:GetService("Players").PlayerAdded:Connect(function(player)
		local gamepassId = ProductIds.GamePasses.HeatPass_Premium
		if gamepassId == 0 then
			return
		end
		task.spawn(function()
			local data
			for _ = 1, 100 do
				data = PlayerDataService.Get(player)
				if data then
					break
				end
				task.wait(0.1)
			end
			if not data or data.Battlepass.PremiumOwned then
				return
			end
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
			end)
			if ok and owns then
				data.Battlepass.PremiumOwned = true
				PlayerDataService.Push(player)
			end
		end)
	end)
end

return BattlepassService
