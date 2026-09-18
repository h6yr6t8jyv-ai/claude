--!strict
-- "Heat Pass" — a seasonal battlepass. Free track gives small cash/coin drips,
-- Premium track (Robux gamepass OR enough Coins) gives bigger payouts and
-- exclusive items every 5th and 10th level.

local Config = require(script.Parent.Config)
local ItemData = require(script.Parent.ItemData)

local BattlepassData = {}

-- Pick a handful of catalog items to act as pass-exclusive drops (still real
-- items from ItemData, just gated behind the premium track instead of the shop).
local exclusiveItemPool = { "rolexx_oyster", "chanoel_quilted_bag", "balenciyaga_triple_s", "vittone_monogram_duffel" }

local rewards = {}
for level = 1, Config.BATTLEPASS_MAX_LEVEL do
	local free, premium

	if level % 5 == 0 then
		free = { kind = "Coins", amount = 20 + level }
	else
		free = { kind = "Cash", amount = 12 }
	end

	if level % 10 == 0 then
		local pick = exclusiveItemPool[(level // 10 - 1) % #exclusiveItemPool + 1]
		premium = { kind = "Item", itemId = pick }
	elseif level % 5 == 0 then
		premium = { kind = "Coins", amount = 50 + level * 2 }
	else
		premium = { kind = "Cash", amount = 35 }
	end

	rewards[level] = { free = free, premium = premium }
end

BattlepassData.Rewards = rewards
BattlepassData.ExclusiveItemPool = exclusiveItemPool

return BattlepassData
