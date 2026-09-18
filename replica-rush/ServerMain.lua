-- ============================================================================
-- REPLICA RUSH — SERVER
-- Paste this ENTIRE file into a single Script inside ServerScriptService.
-- (Everything the server needs — config, item data, data persistence, the
-- buy/ship/customs loop, the resale market, wearing, the battlepass, daily
-- rewards, and the map builder — lives in this one script.)
-- ============================================================================

--== Roblox services (fetched once) ==--
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

--== Forward-declared shared tables, filled in by the sections below ==--
local Config
local ItemData
local ProductIds
local BattlepassData
local remotes
local Notify
local PlayerDataService
local BattlepassService

-- ============================================================================
-- SECTION: Config — central tuning values. Change numbers here to rebalance
-- the whole game.
-- ============================================================================
do
	Config = {}

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
	Config.BATTLEPASS_PREMIUM_GAMEPASS_NAME = "HeatPass_Premium" -- create this Game Pass in Studio and paste its id below in ProductIds
	Config.BATTLEPASS_PREMIUM_COST_COINS = 1800 -- coin alternative to spending Robux

	-- Daily reward streak (7 day cycle, escalating, then loops back with a bump)
	Config.DAILY_REWARD_CASH = { 25, 25, 50, 50, 75, 75, 150 }
	Config.DAILY_REWARD_COINS = { 10, 15, 20, 25, 35, 45, 100 }
	Config.DAILY_STREAK_RESET_HOURS = 48 -- miss more than this and the streak resets

	Config.DATASTORE_NAME = "ReplicaRush_PlayerData_v1"
	Config.AUTOSAVE_INTERVAL = 120 -- seconds
end

-- ============================================================================
-- SECTION: ItemData — the counterfeit catalog. All brand names are original
-- wordplay/parody names (no real trademarks).
--
-- icon = decal/asset id string. Placeholder "rbxassetid://0" — swap in real
-- uploaded images from Studio > Asset Manager once you have art.
-- ============================================================================
do
	ItemData = {}

	-- Quality Control grades rolled when a package is delivered. Higher grades
	-- are rarer and multiply both the "flex value" and the resale market value.
	ItemData.QCGrades = {
		{ id = "bootleg", name = "Bootleg", weight = 32, valueMult = 0.4, color = Color3.fromRGB(150, 150, 150) },
		{ id = "gradeA", name = "Grade A", weight = 40, valueMult = 0.85, color = Color3.fromRGB(120, 200, 255) },
		{ id = "aaa", name = "AAA Replica", weight = 21, valueMult = 1.35, color = Color3.fromRGB(180, 120, 255) },
		{ id = "museum", name = "Museum 1:1", weight = 7, valueMult = 2.25, color = Color3.fromRGB(255, 200, 60) },
	}

	function ItemData.RollQCGrade(): string
		local totalWeight = 0
		for _, grade in ItemData.QCGrades do
			totalWeight += grade.weight
		end
		local roll = math.random() * totalWeight
		local cursor = 0
		for _, grade in ItemData.QCGrades do
			cursor += grade.weight
			if roll <= cursor then
				return grade.id
			end
		end
		return ItemData.QCGrades[1].id
	end

	function ItemData.GetGrade(gradeId: string)
		for _, grade in ItemData.QCGrades do
			if grade.id == gradeId then
				return grade
			end
		end
		return ItemData.QCGrades[1]
	end

	ItemData.Categories = { "Hoodies", "Tees", "Sneakers", "Bags", "Accessories", "Denim" }

	ItemData.Items = {
		{ id = "gucki_wave_hoodie", name = "Wave Hoodie", brand = "Gucki", category = "Hoodies", basePrice = 60, icon = "rbxassetid://0", accentColor = Color3.fromRGB(70, 130, 60) },
		{ id = "supremo_box_tee", name = "Box Logo Tee", brand = "Supremo", category = "Tees", basePrice = 35, icon = "rbxassetid://0", accentColor = Color3.fromRGB(200, 40, 40) },
		{ id = "nyke_air_flex_270", name = "Air Flex 270", brand = "Nyke", category = "Sneakers", basePrice = 80, icon = "rbxassetid://0", accentColor = Color3.fromRGB(40, 40, 40) },
		{ id = "adidos_trackstar_pants", name = "Trackstar Pants", brand = "Adidos", category = "Denim", basePrice = 45, icon = "rbxassetid://0", accentColor = Color3.fromRGB(30, 30, 30) },
		{ id = "vittone_monogram_duffel", name = "Monogram Duffel", brand = "Vittone", category = "Bags", basePrice = 150, icon = "rbxassetid://0", accentColor = Color3.fromRGB(120, 80, 40) },
		{ id = "prada_nylon_crossbody", name = "Nylon Crossbody", brand = "Prad'a", category = "Bags", basePrice = 110, icon = "rbxassetid://0", accentColor = Color3.fromRGB(20, 20, 20) },
		{ id = "balenciyaga_triple_s", name = "Triple S Clones", brand = "Balenciyaga", category = "Sneakers", basePrice = 130, icon = "rbxassetid://0", accentColor = Color3.fromRGB(230, 230, 230) },
		{ id = "offwyte_diagonal_belt", name = "Diagonal Belt", brand = "Off-Wyte", category = "Accessories", basePrice = 40, icon = "rbxassetid://0", accentColor = Color3.fromRGB(240, 240, 240) },
		{ id = "versachi_silk_shirt", name = "Silk Print Shirt", brand = "Versachi", category = "Tees", basePrice = 70, icon = "rbxassetid://0", accentColor = Color3.fromRGB(220, 190, 40) },
		{ id = "chanoel_quilted_bag", name = "Quilted Flap Bag", brand = "Chanoel", category = "Bags", basePrice = 160, icon = "rbxassetid://0", accentColor = Color3.fromRGB(10, 10, 10) },
		{ id = "jordann_retro_1", name = "Retro 1 Highs", brand = "Jordann", category = "Sneakers", basePrice = 95, icon = "rbxassetid://0", accentColor = Color3.fromRGB(180, 30, 30) },
		{ id = "rolexx_oyster", name = "Oyster Replica Watch", brand = "Rolexx", category = "Accessories", basePrice = 200, icon = "rbxassetid://0", accentColor = Color3.fromRGB(255, 210, 90) },
		{ id = "gucki_belt_classic", name = "Classic Buckle Belt", brand = "Gucki", category = "Accessories", basePrice = 50, icon = "rbxassetid://0", accentColor = Color3.fromRGB(150, 30, 30) },
		{ id = "supremo_hood_boxlogo", name = "Hooded Box Logo", brand = "Supremo", category = "Hoodies", basePrice = 90, icon = "rbxassetid://0", accentColor = Color3.fromRGB(210, 20, 20) },
		{ id = "balenciyaga_oversized_tee", name = "Oversized Tee", brand = "Balenciyaga", category = "Tees", basePrice = 55, icon = "rbxassetid://0", accentColor = Color3.fromRGB(240, 240, 240) },
		{ id = "adidos_track_jacket", name = "Track Jacket", brand = "Adidos", category = "Hoodies", basePrice = 65, icon = "rbxassetid://0", accentColor = Color3.fromRGB(30, 60, 150) },
		{ id = "offwyte_arrow_denim", name = "Arrow Denim Jeans", brand = "Off-Wyte", category = "Denim", basePrice = 85, icon = "rbxassetid://0", accentColor = Color3.fromRGB(70, 90, 140) },
		{ id = "nyke_dunk_lows", name = "Dunk Lows", brand = "Nyke", category = "Sneakers", basePrice = 75, icon = "rbxassetid://0", accentColor = Color3.fromRGB(50, 130, 90) },
	}

	ItemData.ById = {}
	for _, item in ItemData.Items do
		ItemData.ById[item.id] = item
	end

	function ItemData.GetMarketValue(itemId: string, qcGradeId: string): number
		local item = ItemData.ById[itemId]
		if not item then
			return 0
		end
		local grade = ItemData.GetGrade(qcGradeId)
		return math.floor(item.basePrice * grade.valueMult + 0.5)
	end
end

-- ============================================================================
-- SECTION: ProductIds — fill these in with real ids from the Creator
-- Dashboard once you've created the Game Passes for this experience.
-- Everything works with the placeholder 0s in Studio for testing (purchase
-- prompts just won't resolve to a real product), but MUST be replaced before
-- publishing.
-- ============================================================================
do
	ProductIds = {
		GamePasses = {
			HeatPass_Premium = 0, -- Battlepass premium track
		},
	}
end

-- ============================================================================
-- SECTION: BattlepassData — "Heat Pass" reward table. Free track gives small
-- cash/coin drips, Premium track gives bigger payouts and exclusive items
-- every 5th and 10th level.
-- ============================================================================
do
	-- Pick a handful of catalog items to act as pass-exclusive drops (still
	-- real items from ItemData, just gated behind the premium track).
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

	BattlepassData = { Rewards = rewards, ExclusiveItemPool = exclusiveItemPool }
end

-- ============================================================================
-- SECTION: Remotes — creates every RemoteEvent/RemoteFunction the client
-- talks to, under ReplicatedStorage.Remotes.
-- ============================================================================
do
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

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

	remotes = {}
	for _, name in EVENT_NAMES do
		local re = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = folder
		remotes[name] = re
	end
	for _, name in FUNCTION_NAMES do
		local rf = folder:FindFirstChild(name) or Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = folder
		remotes[name] = rf
	end
end

-- ============================================================================
-- SECTION: Notify — tiny helper so every service sends notifications the
-- same shape.
-- ============================================================================
do
	Notify = {}

	-- kind: "info" | "success" | "warning" | "danger"
	function Notify.Send(player: Player, title: string, message: string, kind: string?)
		remotes.Notify:FireClient(player, {
			title = title,
			message = message,
			kind = kind or "info",
		})
	end
end

-- ============================================================================
-- SECTION: PlayerDataService — owns the authoritative per-player data table,
-- loads/saves it to DataStore, and pushes snapshots to the client whenever
-- something changes.
-- ============================================================================
do
	local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
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

	PlayerDataService = {}

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
end

-- ============================================================================
-- SECTION: BattlepassService — "Heat Pass" leveling, free/premium reward
-- claiming, and unlocking premium either via a Robux Game Pass or a Coins
-- buy-out.
-- ============================================================================
do
	BattlepassService = {}

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
		Players.PlayerAdded:Connect(function(player)
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

	BattlepassService.Init()
end

-- ============================================================================
-- SECTION: OrderService — buying, shipping timers, the 15% customs seizure
-- roll, and opening the delivered package into a "haul" (the QC grade
-- reveal).
-- ============================================================================
do
	local function startShippingTimer(player: Player, orderId: string)
		local data = PlayerDataService.Get(player)
		if not data then
			return
		end
		local order = data.Orders[orderId]
		if not order then
			return
		end

		local wait = order.deliverAt - os.time()
		if wait > 0 then
			task.wait(wait)
		end

		-- Player could have left; re-fetch fresh state in case data changed.
		data = PlayerDataService.Get(player)
		if not data then
			return
		end
		order = data.Orders[orderId]
		if not order or order.status ~= "Shipping" then
			return -- cancelled/already resolved
		end

		local item = ItemData.ById[order.itemId]
		local seized = math.random() < Config.CUSTOMS_SEIZURE_CHANCE

		if seized then
			order.status = "Seized"
			data.Coins += Config.SEIZURE_CONSOLATION_COINS
			Notify.Send(
				player,
				"Package Seized!",
				("Customs flagged your %s %s. It's gone — here's %d Coins for the trouble."):format(item.brand, item.name, Config.SEIZURE_CONSOLATION_COINS),
				"danger"
			)
		else
			order.status = "Delivered"
			order.qcGrade = ItemData.RollQCGrade()
			Notify.Send(player, "Package Delivered!", ("Your %s %s just landed. Go open your haul!"):format(item.brand, item.name), "success")
			remotes.OrderDelivered:FireClient(player, orderId)
		end

		PlayerDataService.Push(player)
	end

	local OrderService = {}

	function OrderService.Init()
		remotes.BuyItem.OnServerInvoke = function(player: Player, itemId: string)
			local data = PlayerDataService.Get(player)
			if not data then
				return false, "Data not loaded yet, try again."
			end
			local item = ItemData.ById[itemId]
			if not item then
				return false, "That item doesn't exist."
			end
			if data.Cash < item.basePrice then
				return false, "Not enough Cash."
			end

			data.Cash -= item.basePrice

			local orderId = "order_" .. data.NextOrderId
			data.NextOrderId += 1

			local now = os.time()
			local shipTime = math.random(Config.SHIPPING_TIME_MIN, Config.SHIPPING_TIME_MAX)

			data.Orders[orderId] = {
				itemId = itemId,
				boughtAt = now,
				deliverAt = now + shipTime,
				status = "Shipping",
				qcGrade = nil,
			}

			PlayerDataService.Push(player)
			Notify.Send(player, "Order Placed", ("Your %s %s is on the way. ~%ds shipping."):format(item.brand, item.name, shipTime), "info")

			task.spawn(startShippingTimer, player, orderId)

			return true, "Order placed."
		end

		remotes.OpenPackage.OnServerInvoke = function(player: Player, orderId: string)
			local data = PlayerDataService.Get(player)
			if not data then
				return false, nil, nil, "Data not loaded."
			end
			local order = data.Orders[orderId]
			if not order then
				return false, nil, nil, "Order not found."
			end
			if order.status ~= "Delivered" then
				return false, nil, nil, "This order isn't ready to open."
			end

			local invId = "inv_" .. data.NextInvId
			data.NextInvId += 1

			data.Inventory[invId] = {
				itemId = order.itemId,
				qcGrade = order.qcGrade,
				obtainedAt = os.time(),
				equipped = false,
			}

			order.status = "Opened"
			BattlepassService.AddXP(player, Config.XP_PER_OPEN)
			PlayerDataService.Push(player)

			return true, order.itemId, order.qcGrade, invId
		end

		-- Resume any orders that were mid-shipping when the server last saved
		-- (handles the case where a player rejoins while an order is in flight).
		Players.PlayerAdded:Connect(function(player)
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
				for orderId, order in data.Orders do
					if order.status == "Shipping" then
						task.spawn(startShippingTimer, player, orderId)
					end
				end
			end)
		end)
	end

	OrderService.Init()
end

-- ============================================================================
-- SECTION: ResellMarketService — "ThriftLyst", the Depop/Vinted-style resale
-- marketplace. Players list a piece from their closet at a price they
-- choose; simulated buyers roll a chance to bite every few seconds based on
-- how good the price is versus market value. There's also an instant
-- guaranteed Quick Sell.
-- ============================================================================
do
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

	local ResellMarketService = {}

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
		Players.PlayerAdded:Connect(function(player)
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

	ResellMarketService.Init()
end

-- ============================================================================
-- SECTION: InventoryService — wearing/unwearing closet items on the
-- character. Falls back to a colored proxy accessory + nameplate so the
-- feature is fully testable with zero external assets.
-- ============================================================================
do
	local CATEGORY_SLOT = {
		Hoodies = "Top",
		Tees = "Top",
		Denim = "Bottom",
		Sneakers = "Shoes",
		Bags = "Accessory",
		Accessories = "Accessory",
	}

	local function clearSlotVisual(character: Model, slotName: string)
		local holder = character:FindFirstChild("ReplicaRushWorn")
		if not holder then
			return
		end
		local existing = holder:FindFirstChild(slotName)
		if existing then
			existing:Destroy()
		end
	end

	local function applyProxyAccessory(character: Model, invId: string, item, slotName: string)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local holder = character:FindFirstChild("ReplicaRushWorn")
		if not holder then
			holder = Instance.new("Folder")
			holder.Name = "ReplicaRushWorn"
			holder.Parent = character
		end
		clearSlotVisual(character, slotName)

		local acc = Instance.new("Accessory")
		acc.Name = slotName
		acc.AccessoryType = Enum.AccessoryType.Neck

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.6, 0.6, 0.6)
		handle.Color = item.accentColor
		handle.Material = Enum.Material.Neon
		handle.CanCollide = false
		handle.Massless = true

		local attachment = Instance.new("Attachment")
		attachment.Name = "BodyFrontAttachment"
		attachment.Parent = handle

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(140, 34)
		billboard.StudsOffset = Vector3.new(0, 1.1, 0)
		billboard.AlwaysOnTop = false
		billboard.Parent = handle

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = ("%s %s"):format(item.brand, item.name)
		label.Parent = billboard

		handle.Parent = acc
		acc.Parent = holder

		local ok = pcall(function()
			humanoid:AddAccessory(acc)
		end)
		if not ok then
			acc.Parent = holder
		end
	end

	local InventoryService = {}

	function InventoryService.Init()
		remotes.WearItem.OnServerEvent:Connect(function(player: Player, invId: string)
			local data = PlayerDataService.Get(player)
			if not data then
				return
			end
			local invItem = data.Inventory[invId]
			if not invItem then
				return
			end
			local item = ItemData.ById[invItem.itemId]
			if not item then
				return
			end

			local character = player.Character
			local slotName = CATEGORY_SLOT[item.category] or "Accessory"

			if invItem.equipped then
				-- Unequip.
				invItem.equipped = false
				if character then
					clearSlotVisual(character, slotName)
				end
			else
				-- Unequip whatever else is in this slot first.
				for otherInvId, other in data.Inventory do
					if other.equipped and otherInvId ~= invId then
						local otherItem = ItemData.ById[other.itemId]
						if otherItem and (CATEGORY_SLOT[otherItem.category] or "Accessory") == slotName then
							other.equipped = false
						end
					end
				end
				invItem.equipped = true
				if character then
					applyProxyAccessory(character, invId, item, slotName)
				end
				BattlepassService.AddXP(player, Config.XP_PER_WEAR)
			end

			PlayerDataService.Push(player)
		end)

		-- Re-apply worn items whenever the character (re)spawns.
		Players.PlayerAdded:Connect(function(player)
			player.CharacterAdded:Connect(function(character)
				task.wait(0.5)
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
				for invId, invItem in data.Inventory do
					if invItem.equipped then
						local item = ItemData.ById[invItem.itemId]
						if item then
							local slotName = CATEGORY_SLOT[item.category] or "Accessory"
							applyProxyAccessory(character, invId, item, slotName)
						end
					end
				end
			end)
		end)
	end

	InventoryService.Init()
end

-- ============================================================================
-- SECTION: DailyRewardService — classic day-streak login reward. 7-day
-- escalating track that loops with a bump, and resets if the player misses
-- more than Config.DAILY_STREAK_RESET_HOURS.
-- ============================================================================
do
	local function isAvailable(daily)
		local secondsSince = os.time() - daily.LastClaimUnix
		return daily.LastClaimUnix == 0 or secondsSince >= 20 * 3600 -- new "day" after 20h
	end

	local DailyRewardService = {}

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

	DailyRewardService.Init()
end

-- ============================================================================
-- SECTION: Leaderstats — the classic Roblox leaderboard display (separate
-- from the full data snapshot pushed over DataUpdated, which the phone UI
-- actually reads from).
-- ============================================================================
do
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
end

-- ============================================================================
-- SECTION: MapBuilder — procedurally builds a starter map: a central plaza,
-- the DupeDeal warehouse (shop), the ShipFast Customs Dock (shipping/
-- customs), and the ThriftLyst Bazaar (resale market), connected by paths.
-- Runs once per server start and rebuilds deterministically.
-- ============================================================================
do
	local ROOT_NAME = "GeneratedMap"

	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root.Parent = Workspace

	local function part(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = props.Size
		p.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
		p.Color = props.Color or Color3.fromRGB(200, 200, 200)
		p.Material = props.Material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Name = props.Name or "Part"
		p.Parent = props.Parent or root
		return p
	end

	local function sign(props)
		local billboard = Instance.new("Part")
		billboard.Anchored = true
		billboard.Size = props.Size or Vector3.new(0.5, 6, 16)
		billboard.CFrame = props.CFrame
		billboard.Color = Color3.fromRGB(10, 10, 14)
		billboard.Material = Enum.Material.Neon
		billboard.Name = (props.Text or "Sign") .. "_Sign"
		billboard.Parent = props.Parent or root

		local gui = Instance.new("SurfaceGui")
		gui.Face = props.Face or Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.PixelsPerStud = 36
		gui.Parent = billboard

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = props.Text or ""
		label.TextColor3 = props.TextColor or Color3.fromRGB(255, 255, 255)
		label.Parent = gui

		return billboard
	end

	-- Ground
	part({
		Name = "Baseplate",
		Size = Vector3.new(400, 4, 400),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(38, 38, 48),
		Material = Enum.Material.Concrete,
	})

	-- Central plaza
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = root

	part({
		Name = "PlazaFloor",
		Size = Vector3.new(70, 0.4, 70),
		Position = Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(60, 58, 70),
		Material = Enum.Material.SmoothPlastic,
		Parent = plaza,
	})

	-- Spawn ring
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.new(math.cos(angle) * 12, 1, math.sin(angle) * 12)
		spawn.Color = Color3.fromRGB(255, 62, 165)
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.3
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Duration = 0
		spawn.Name = "PlazaSpawn"
		spawn.Parent = plaza
	end

	sign({
		Text = "REPLICA RUSH",
		CFrame = CFrame.new(0, 14, -30) * CFrame.Angles(0, math.pi, 0),
		Size = Vector3.new(0.5, 8, 34),
		TextColor = Color3.fromRGB(255, 62, 165),
		Parent = plaza,
	})

	part({
		Name = "PlazaCenterpiece",
		Size = Vector3.new(4, 10, 4),
		Position = Vector3.new(0, 5, 0),
		Color = Color3.fromRGB(255, 210, 70),
		Material = Enum.Material.Neon,
		Parent = plaza,
	})

	-- Helper: a simple rectangular "building" with an open front doorway
	local function buildBox(name, center, size, wallColor, roofColor, parentFolder)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parentFolder

		local halfX, halfY, halfZ = size.X / 2, size.Y / 2, size.Z / 2

		part({ Name = "Floor", Size = Vector3.new(size.X, 1, size.Z), Position = center + Vector3.new(0, 0.5, 0), Color = wallColor:Lerp(Color3.new(0, 0, 0), 0.3), Parent = folder })
		part({ Name = "Back", Size = Vector3.new(size.X, size.Y, 1), Position = center + Vector3.new(0, halfY, halfZ), Color = wallColor, Parent = folder })
		part({ Name = "Left", Size = Vector3.new(1, size.Y, size.Z), Position = center + Vector3.new(-halfX, halfY, 0), Color = wallColor, Parent = folder })
		part({ Name = "Right", Size = Vector3.new(1, size.Y, size.Z), Position = center + Vector3.new(halfX, halfY, 0), Color = wallColor, Parent = folder })
		part({ Name = "Roof", Size = Vector3.new(size.X, 1, size.Z), Position = center + Vector3.new(0, size.Y + 0.5, 0), Color = roofColor, Parent = folder })
		-- Front wall with a doorway gap (two side strips instead of one full wall)
		local doorWidth = math.min(10, size.X * 0.4)
		local sideWidth = (size.X - doorWidth) / 2
		part({ Name = "FrontLeft", Size = Vector3.new(sideWidth, size.Y, 1), Position = center + Vector3.new(-(doorWidth / 2 + sideWidth / 2), halfY, -halfZ), Color = wallColor, Parent = folder })
		part({ Name = "FrontRight", Size = Vector3.new(sideWidth, size.Y, 1), Position = center + Vector3.new((doorWidth / 2 + sideWidth / 2), halfY, -halfZ), Color = wallColor, Parent = folder })

		return folder
	end

	-- DupeDeal Warehouse (shop) — north of plaza
	local shop = buildBox("DupeDealWarehouse", Vector3.new(0, 0, -70), Vector3.new(46, 16, 34), Color3.fromRGB(40, 40, 56), Color3.fromRGB(255, 62, 165), root)
	sign({ Text = "DUPEDEAL WAREHOUSE", CFrame = CFrame.new(0, 18, -87) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(0.5, 5, 30), TextColor = Color3.fromRGB(255, 62, 165), Parent = shop })

	-- ShipFast Customs Dock — east of plaza
	local dock = buildBox("ShipFastCustomsDock", Vector3.new(75, 0, 0), Vector3.new(40, 14, 40), Color3.fromRGB(50, 46, 40), Color3.fromRGB(255, 210, 70), root)
	sign({ Text = "SHIPFAST CUSTOMS DOCK", CFrame = CFrame.new(75, 16, -21) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(0.5, 5, 30), TextColor = Color3.fromRGB(255, 210, 70), Parent = dock })

	-- Cargo containers for flavor
	for i = 1, 5 do
		part({
			Name = "Container" .. i,
			Size = Vector3.new(8, 8, 20),
			Position = Vector3.new(60 + i * 9, 4, 25),
			Color = Color3.fromHSV((i * 0.15) % 1, 0.55, 0.7),
			Material = Enum.Material.Metal,
			Parent = dock,
		})
	end

	-- Customs checkpoint gate (visual barrier between dock and plaza)
	part({ Name = "GatePostA", Size = Vector3.new(1, 8, 1), Position = Vector3.new(40, 4, 0), Color = Color3.fromRGB(255, 210, 70), Material = Enum.Material.Neon, Parent = dock })
	part({ Name = "GatePostB", Size = Vector3.new(1, 8, 1), Position = Vector3.new(40, 4, 10), Color = Color3.fromRGB(255, 210, 70), Material = Enum.Material.Neon, Parent = dock })
	part({ Name = "GateBar", Size = Vector3.new(1, 1, 12), Position = Vector3.new(40, 7, 5), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon, Parent = dock })

	-- ThriftLyst Bazaar (resale market) — west of plaza
	local bazaar = Instance.new("Folder")
	bazaar.Name = "ThriftLystBazaar"
	bazaar.Parent = root

	part({ Name = "BazaarFloor", Size = Vector3.new(50, 0.4, 50), Position = Vector3.new(-80, 0.2, 0), Color = Color3.fromRGB(46, 40, 56), Parent = bazaar })
	sign({ Text = "THRIFTLYST BAZAAR", CFrame = CFrame.new(-80, 14, 25) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(0.5, 5, 30), TextColor = Color3.fromRGB(62, 193, 255), Parent = bazaar })

	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local stallPos = Vector3.new(-80 + math.cos(angle) * 16, 0, math.sin(angle) * 16)
		part({ Name = "StallPost1_" .. i, Size = Vector3.new(0.6, 8, 0.6), Position = stallPos + Vector3.new(-3, 4, -3), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Wood, Parent = bazaar })
		part({ Name = "StallPost2_" .. i, Size = Vector3.new(0.6, 8, 0.6), Position = stallPos + Vector3.new(3, 4, -3), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Wood, Parent = bazaar })
		part({ Name = "StallCanopy_" .. i, Size = Vector3.new(7, 0.5, 7), Position = stallPos + Vector3.new(0, 8, -3), Color = Color3.fromHSV((i * 0.16) % 1, 0.7, 0.85), Material = Enum.Material.Fabric, Parent = bazaar })
		part({ Name = "StallTable_" .. i, Size = Vector3.new(6, 2, 3), Position = stallPos + Vector3.new(0, 1, 0), Color = Color3.fromRGB(120, 100, 80), Material = Enum.Material.Wood, Parent = bazaar })
	end

	-- Connecting paths
	local function path(from, to, width)
		local diff = to - from
		local length = diff.Magnitude
		local mid = from + diff / 2
		part({
			Name = "Path",
			Size = Vector3.new(width or 12, 0.3, length),
			CFrame = CFrame.new(mid, to) * CFrame.new(0, 0, 0),
			Color = Color3.fromRGB(70, 68, 80),
			Material = Enum.Material.Concrete,
			Parent = root,
		})
	end

	path(Vector3.new(0, 0.3, -35), Vector3.new(0, 0.3, -53))
	path(Vector3.new(35, 0.3, 0), Vector3.new(55, 0.3, 0))
	path(Vector3.new(-35, 0.3, 0), Vector3.new(-55, 0.3, 0))

	-- Lighting mood
	Lighting.Ambient = Color3.fromRGB(40, 40, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(60, 55, 75)
	Lighting.Brightness = 2
	Lighting.ClockTime = 21
	Lighting.FogColor = Color3.fromRGB(30, 20, 45)
	Lighting.FogEnd = 600
	Lighting.Technology = Enum.Technology.Future

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Color = Color3.fromRGB(150, 130, 200)
		atmosphere.Decay = Color3.fromRGB(70, 40, 90)
		atmosphere.Glare = 0.2
		atmosphere.Haze = 1
		atmosphere.Parent = Lighting
	end

	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 24
		bloom.Threshold = 1.4
		bloom.Parent = Lighting
	end

	print("[MapBuilder] Generated starter map (plaza, warehouse, customs dock, bazaar).")
end

print("[ReplicaRush] Server systems online.")
