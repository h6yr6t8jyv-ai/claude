--!strict
-- Classic day-streak login reward. This is the single biggest lever for
-- "people come back every day" — 7-day escalating track that loops with a
-- bump, and resets if they miss more than DAILY_STREAK_RESET_HOURS.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local Notify = require(script.Parent.Notify)

local remotes = Remotes.Get()

local DailyRewardService = {}

local function isAvailable(daily)
	local secondsSince = os.time() - daily.LastClaimUnix
	return daily.LastClaimUnix == 0 or secondsSince >= 20 * 3600 -- new "day" after 20h, matches typical mobile-sim cadence
end

function DailyRewardService.Init()
	remotes.ClaimDailyReward.OnServerInvoke = function(player: Player)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, "Data not loaded."
		end
		local daily = data.DailyReward

		if not isAvailable(daily) then
			return false, "Come back later for your next reward."
		end

		local hoursSince = (os.time() - daily.LastClaimUnix) / 3600
		if daily.LastClaimUnix ~= 0 and hoursSince > Config.DAILY_STREAK_RESET_HOURS then
			daily.Streak = 0
		end

		daily.Streak = (daily.Streak % 7) + 1
		daily.LastClaimUnix = os.time()

		local cash = Config.DAILY_REWARD_CASH[daily.Streak]
		local coins = Config.DAILY_REWARD_COINS[daily.Streak]
		data.Cash += cash
		data.Coins += coins

		PlayerDataService.Push(player)
		Notify.Send(player, ("Day %d Reward!"):format(daily.Streak), ("+$%d Cash, +%d Coins."):format(cash, coins), "success")

		return true, daily.Streak
	end
end

return DailyRewardService
