--!strict
-- Central tuning values. Change numbers here to rebalance the whole game.

local Config = {}

Config.STARTING_CASH = 100
Config.STARTING_COINS = 0

-- Shipping & customs
Config.CUSTOMS_SEIZURE_CHANCE = 0.15 -- 15% of every order gets seized
Config.SHIPPING_TIME_MIN = 75 -- seconds
Config.SHIPPING_TIME_MAX = 210 -- seconds
Config.SEIZURE_CONSOLATION_COINS = 5 -- soft cushion so a seizure never feels like a total dead end

-- ThriftLyst resale market
Config.RESELL_FEE_PERCENT = 0.10 -- platform cut on a successful resale
Config.QUICK_SELL_PERCENT = 0.55 -- instant guaranteed sale to an NPC buyer
Config.MIN_LISTING_PERCENT = 0.4 -- can't list below 40% of market value (anti-exploit)
Config.MAX_LISTING_PERCENT = 2.5 -- can't list above 250% of market value
Config.LISTING_CHECK_INTERVAL = 20 -- seconds between "does a buyer bite" rolls per listing

-- XP / progression
Config.XP_PER_SALE = 8
Config.XP_PER_WEAR = 4
Config.XP_PER_OPEN = 3

-- Battlepass ("Heat Pass")
Config.BATTLEPASS_XP_PER_LEVEL = 120
Config.BATTLEPASS_MAX_LEVEL = 40
Config.BATTLEPASS_PREMIUM_GAMEPASS_NAME = "HeatPass_Premium" -- create this Game Pass in Studio and paste its id in ProductIds.lua
Config.BATTLEPASS_PREMIUM_COST_COINS = 1800 -- coin alternative to spending Robux

-- Daily reward streak (7 day cycle, escalating, then loops back with a bump)
Config.DAILY_REWARD_CASH = { 25, 25, 50, 50, 75, 75, 150 }
Config.DAILY_REWARD_COINS = { 10, 15, 20, 25, 35, 45, 100 }
Config.DAILY_STREAK_RESET_HOURS = 48 -- miss more than this and the streak resets

Config.DATASTORE_NAME = "ReplicaRush_PlayerData_v1"
Config.AUTOSAVE_INTERVAL = 120 -- seconds

return Config
