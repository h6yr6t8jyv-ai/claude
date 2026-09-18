-- ============================================================================
-- GLITCH RANCH — SERVER
-- Paste this ENTIRE file into a single Script inside ServerScriptService.
--
-- What it is: an original creature-collecting ranch sim built around the
-- mechanics actually driving Roblox retention right now (researched, not
-- guessed): idle income generators with offline earning (Grow a Garden),
-- weather-triggered mutations worth up to 40x (Grow a Garden), physically
-- stealing from other players' unlocked bases with a chase/tackle mechanic
-- (Steal a Brainrot), tycoon-style automation upgrades + prestige resets
-- (Tycoon genre), a seasonal battlepass, and a daily login streak.
-- All creatures/names are original — nothing here reskins an existing game.
-- ============================================================================

--== Roblox services (fetched once) ==--
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

--== Forward-declared shared tables, filled in by the sections below ==--
local Config
local AnomalyData
local WeatherData
local BattlepassData
local ProductIds
local remotes
local Notify
local PlayerDataService
local RanchService
local MarketService
local WeatherService
local UpgradeService
local BattlepassService

-- ============================================================================
-- SECTION: Config — every tunable number lives here.
-- ============================================================================
do
	Config = {}

	Config.STARTING_GLIMMER = 100
	Config.STARTING_PLOTS = 4
	Config.MAX_PLOTS = 12
	Config.PLOT_COST_BASE = 250
	Config.PLOT_COST_GROWTH = 1.6 -- cost of Nth extra plot = base * growth^(n-1)

	Config.INCOME_TICK_SECONDS = 1
	Config.OFFLINE_EARNINGS_CAP_SECONDS = 2 * 3600 -- 2 hours of offline income max

	Config.MARKET_SLOTS = 4
	Config.MARKET_REFRESH_SECONDS = 90
	Config.MARKET_PRICE_ESCALATION = 1.18 -- price grows 18% per buy of a slot until it refreshes

	Config.LOCK_DURATION = 180 -- seconds a ranch stays locked once you lock it
	Config.NEW_PLAYER_GRACE_SECONDS = 60 -- new joiners start locked for this long

	Config.STEAL_WALK_SPEED_MULT = 0.5 -- thief moves at 50% speed while carrying
	Config.STEAL_TACKLE_RADIUS = 6 -- studs; any player this close to a thief reclaims the anomaly

	Config.INCOME_UPGRADE_BASE_COST = 200
	Config.INCOME_UPGRADE_COST_GROWTH = 1.5
	Config.INCOME_UPGRADE_BONUS_PER_LEVEL = 0.08 -- +8% income per level
	Config.INCOME_UPGRADE_MAX_LEVEL = 15

	Config.PRESTIGE_BASE_THRESHOLD = 5000 -- lifetime Glimmer earned needed for first Reboot
	Config.PRESTIGE_THRESHOLD_GROWTH = 1.7
	Config.PRESTIGE_BONUS_PER_REBOOT = 0.10 -- +10% permanent income multiplier per Reboot

	Config.XP_PER_BUY = 3
	Config.XP_PER_MUTATION = 10
	Config.XP_PER_STEAL_SUCCESS = 15
	Config.XP_PER_REBOOT = 100

	Config.BATTLEPASS_XP_PER_LEVEL = 150
	Config.BATTLEPASS_MAX_LEVEL = 40
	Config.BATTLEPASS_PREMIUM_GAMEPASS_NAME = "SignalPass_Premium"
	Config.BATTLEPASS_PREMIUM_COST_GLIMMER = 4000

	Config.DAILY_REWARD_GLIMMER = { 60, 60, 120, 120, 200, 200, 400 }
	Config.DAILY_STREAK_RESET_HOURS = 48

	Config.RANCH_COUNT = 12 -- number of physical ranch plots generated in the world
	Config.DATASTORE_NAME = "GlitchRanch_PlayerData_v1"
	Config.AUTOSAVE_INTERVAL = 120
end

-- ============================================================================
-- SECTION: AnomalyData — the creature catalog. 16 original "Anomalies"
-- across 4 rarities, plus the mutation grade table (rolled while boosted
-- weather is active on a placed, not-yet-mutated Anomaly).
-- ============================================================================
do
	AnomalyData = {}

	AnomalyData.Rarities = { "Common", "Rare", "Epic", "Legendary" }

	AnomalyData.Items = {
		{ id = "sir_puddlebyte", name = "Sir Puddlebyte", rarity = "Common", income = 1.0, cost = 50, color = Color3.fromRGB(90, 160, 220) },
		{ id = "toastwig", name = "Toastwig", rarity = "Common", income = 1.4, cost = 70, color = Color3.fromRGB(200, 150, 80) },
		{ id = "bloop_bloop_jr", name = "Bloop Bloop Jr.", rarity = "Common", income = 1.2, cost = 60, color = Color3.fromRGB(120, 210, 160) },
		{ id = "lampcat_mochi", name = "Lampcat Mochi", rarity = "Common", income = 1.6, cost = 85, color = Color3.fromRGB(240, 210, 120) },

		{ id = "disco_yeti_jr", name = "Disco Yeti Jr.", rarity = "Rare", income = 3.2, cost = 180, color = Color3.fromRGB(230, 120, 220) },
		{ id = "sock_goblin_supreme", name = "Sock Goblin Supreme", rarity = "Rare", income = 3.8, cost = 220, color = Color3.fromRGB(150, 200, 90) },
		{ id = "vacuum_knight_whiskington", name = "Vacuum Knight Whiskington", rarity = "Rare", income = 4.4, cost = 260, color = Color3.fromRGB(180, 180, 190) },
		{ id = "boombox_cactus", name = "Boombox Cactus", rarity = "Rare", income = 5.0, cost = 320, color = Color3.fromRGB(90, 190, 100) },

		{ id = "glorp_puddle_king", name = "Glorp the Puddle King", rarity = "Epic", income = 8, cost = 600, color = Color3.fromRGB(60, 120, 255) },
		{ id = "neon_wobblesaurus", name = "Neon Wobblesaurus", rarity = "Epic", income = 10, cost = 780, color = Color3.fromRGB(60, 255, 190) },
		{ id = "captain_sparkbeard", name = "Captain Sparkbeard", rarity = "Epic", income = 12, cost = 940, color = Color3.fromRGB(255, 200, 60) },
		{ id = "moth_priestess_lumina", name = "Moth Priestess Lumina", rarity = "Epic", income = 14, cost = 1100, color = Color3.fromRGB(230, 230, 255) },

		{ id = "grand_combobulator", name = "The Grand Combobulator", rarity = "Legendary", income = 25, cost = 2500, color = Color3.fromRGB(255, 90, 90) },
		{ id = "rainbow_void_walrus", name = "Rainbow Void Walrus", rarity = "Legendary", income = 32, cost = 3400, color = Color3.fromRGB(180, 90, 255) },
		{ id = "emperor_glitchazoid", name = "Emperor Glitchazoid", rarity = "Legendary", income = 40, cost = 4600, color = Color3.fromRGB(255, 60, 160) },
		{ id = "static_phoenix_prime", name = "Static Phoenix Prime", rarity = "Legendary", income = 50, cost = 6000, color = Color3.fromRGB(255, 140, 40) },
	}

	AnomalyData.ById = {}
	for _, item in AnomalyData.Items do
		AnomalyData.ById[item.id] = item
	end

	-- Mutation grades: once a placed Anomaly mutates it stays at that grade.
	AnomalyData.Grades = {
		{ id = "normal", name = "Normal", mult = 1, color = Color3.fromRGB(200, 200, 200), weight = 0 }, -- weight 0 = never rolled as a "you got upgraded to this" result
		{ id = "glitched", name = "Glitched", mult = 2, color = Color3.fromRGB(120, 220, 140), weight = 60 },
		{ id = "golden", name = "Golden", mult = 5, color = Color3.fromRGB(255, 210, 70), weight = 30 },
		{ id = "rainbow", name = "Rainbow", mult = 15, color = Color3.fromRGB(220, 100, 255), weight = 8 },
		{ id = "corrupted", name = "Corrupted", mult = 40, color = Color3.fromRGB(255, 60, 60), weight = 2 },
	}

	AnomalyData.GradeById = {}
	for _, g in AnomalyData.Grades do
		AnomalyData.GradeById[g.id] = g
	end

	-- Rolls which grade a mutation event upgrades an Anomaly to.
	function AnomalyData.RollMutationGrade(): string
		local totalWeight = 0
		for _, g in AnomalyData.Grades do
			totalWeight += g.weight
		end
		local roll = math.random() * totalWeight
		local cursor = 0
		for _, g in AnomalyData.Grades do
			if g.weight > 0 then
				cursor += g.weight
				if roll <= cursor then
					return g.id
				end
			end
		end
		return "glitched"
	end

	function AnomalyData.GetEffectiveIncome(defId: string, gradeId: string): number
		local def = AnomalyData.ById[defId]
		if not def then
			return 0
		end
		local grade = AnomalyData.GradeById[gradeId] or AnomalyData.Grades[1]
		return def.income * grade.mult
	end
end

-- ============================================================================
-- SECTION: WeatherData — server-wide weather cycle. Boosted weather raises
-- income and/or the chance a placed Anomaly mutates.
-- ============================================================================
do
	WeatherData = {}

	WeatherData.States = {
		{ id = "normal", name = "Clear Signal", icon = "📡", weight = 45, duration = 120, mutateChance = 0, incomeMult = 1.0, skyColor = Color3.fromRGB(40, 40, 55) },
		{ id = "overclock", name = "Overclock Surge", icon = "⚡", weight = 22, duration = 60, mutateChance = 0.03, incomeMult = 1.25, skyColor = Color3.fromRGB(70, 40, 90) },
		{ id = "aurora", name = "Aurora Static", icon = "🌌", weight = 16, duration = 45, mutateChance = 0.06, incomeMult = 1.1, skyColor = Color3.fromRGB(30, 70, 90) },
		{ id = "blackout", name = "Blackout", icon = "🌑", weight = 12, duration = 40, mutateChance = 0.10, incomeMult = 0.5, skyColor = Color3.fromRGB(10, 10, 14) },
		{ id = "goldenhour", name = "Golden Hour", icon = "✨", weight = 5, duration = 30, mutateChance = 0.20, incomeMult = 1.5, skyColor = Color3.fromRGB(90, 70, 30) },
	}

	WeatherData.ById = {}
	for _, w in WeatherData.States do
		WeatherData.ById[w.id] = w
	end

	function WeatherData.RollNext()
		local totalWeight = 0
		for _, w in WeatherData.States do
			totalWeight += w.weight
		end
		local roll = math.random() * totalWeight
		local cursor = 0
		for _, w in WeatherData.States do
			cursor += w.weight
			if roll <= cursor then
				return w
			end
		end
		return WeatherData.States[1]
	end
end

-- ============================================================================
-- SECTION: ProductIds — fill these in from the Creator Dashboard before
-- publishing. Placeholder 0 works fine for Studio testing.
-- ============================================================================
do
	ProductIds = {
		GamePasses = {
			SignalPass_Premium = 0,
		},
	}
end

-- ============================================================================
-- SECTION: BattlepassData — "Signal Pass" reward table.
-- ============================================================================
do
	local exclusiveItemPool = { "static_phoenix_prime", "emperor_glitchazoid", "rainbow_void_walrus", "grand_combobulator" }

	local rewards = {}
	for level = 1, Config.BATTLEPASS_MAX_LEVEL do
		local free, premium

		if level % 5 == 0 then
			free = { kind = "Glimmer", amount = 150 + level * 5 }
		else
			free = { kind = "Glimmer", amount = 40 }
		end

		if level % 10 == 0 then
			local pick = exclusiveItemPool[(level // 10 - 1) % #exclusiveItemPool + 1]
			premium = { kind = "Anomaly", itemId = pick }
		elseif level % 5 == 0 then
			premium = { kind = "Glimmer", amount = 400 + level * 15 }
		else
			premium = { kind = "Glimmer", amount = 120 }
		end

		rewards[level] = { free = free, premium = premium }
	end

	BattlepassData = { Rewards = rewards, ExclusiveItemPool = exclusiveItemPool }
end

-- ============================================================================
-- SECTION: Remotes
-- ============================================================================
do
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	local EVENT_NAMES = {
		"PlaceAnomaly", -- client -> server: fire(animId)
		"UnplaceAnomaly", -- client -> server: fire(animId)
		"ToggleLock", -- client -> server: fire()
		"BuyBattlepassPremiumWithRobux", -- client -> server: fire()
		"Notify", -- server -> client
		"DataUpdated", -- server -> client
		"WeatherUpdated", -- server -> client: fire(player, {id, name, icon, endsAt, incomeMult})
		"MarketUpdated", -- server -> client: fire(player, {slots = {...}, refreshesAt = unix})
	}
	local FUNCTION_NAMES = {
		"BuyMarketSlot", -- (slotIndex) -> ok, message
		"BuyPlot", -- () -> ok, message
		"BuyUpgrade", -- (upgradeId) -> ok, message
		"DoReboot", -- () -> ok, message
		"ClaimDailyReward", -- () -> ok, streak
		"ClaimBattlepassReward", -- (level, track) -> ok, message
		"BuyBattlepassPremiumWithGlimmer", -- () -> ok, message
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
-- SECTION: Notify
-- ============================================================================
do
	Notify = {}

	function Notify.Send(player: Player, title: string, message: string, kind: string?)
		remotes.Notify:FireClient(player, {
			title = title,
			message = message,
			kind = kind or "info",
		})
	end
end

-- ============================================================================
-- SECTION: PlayerDataService — authoritative per-player data, DataStore
-- persistence, and offline-earnings crediting on load.
-- ============================================================================
do
	local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	local profiles: { [Player]: any } = {}

	local function defaultData()
		return {
			Glimmer = Config.STARTING_GLIMMER,
			LifetimeGlimmer = 0, -- never decreases; gates Reboot thresholds
			RebootCount = 0,
			UnlockedPlots = Config.STARTING_PLOTS,
			IncomeLevel = 0,
			NextAnomalyId = 1,
			Anomalies = {}, -- [animId] = {defId, grade, placedSlot (nil if unplaced)}
			RanchLocked = true,
			LockExpiresAt = os.time() + Config.NEW_PLAYER_GRACE_SECONDS,
			LastSeenUnix = os.time(),
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

	-- Sum of effective income/sec across a data table's currently placed Anomalies.
	local function computeIncomePerSecond(data): number
		local total = 0
		for _, anomaly in data.Anomalies do
			if anomaly.placedSlot then
				total += AnomalyData.GetEffectiveIncome(anomaly.defId, anomaly.grade)
			end
		end
		local incomeMult = 1 + (data.IncomeLevel * Config.INCOME_UPGRADE_BONUS_PER_LEVEL)
		local prestigeMult = 1 + (data.RebootCount * Config.PRESTIGE_BONUS_PER_REBOOT)
		return total * incomeMult * prestigeMult
	end

	PlayerDataService = {}
	PlayerDataService.ComputeIncomePerSecond = computeIncomePerSecond

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
			local defaults = defaultData()
			for k, v in defaults do
				if data[k] == nil then
					data[k] = v
				end
			end
		else
			data = defaultData()
		end

		-- Credit offline earnings based on income at the moment they left.
		local elapsed = math.clamp(os.time() - (data.LastSeenUnix or os.time()), 0, Config.OFFLINE_EARNINGS_CAP_SECONDS)
		if elapsed > 5 then
			local perSecond = computeIncomePerSecond(data)
			local earned = math.floor(perSecond * elapsed)
			if earned > 0 then
				data.Glimmer += earned
				data.LifetimeGlimmer += earned
				task.defer(function()
					Notify.Send(player, "Welcome back!", ("Your ranch made $%d Glimmer while you were away."):format(earned), "success")
				end)
			end
		end

		-- Ranches always start locked for a short grace period on join.
		data.RanchLocked = true
		data.LockExpiresAt = os.time() + Config.NEW_PLAYER_GRACE_SECONDS

		profiles[player] = data
		PlayerDataService.Push(player)
	end

	function PlayerDataService.Save(player: Player)
		local data = profiles[player]
		if not data then
			return
		end
		data.LastSeenUnix = os.time()
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
-- SECTION: RanchService — assigns each player a physical ranch plot, renders
-- placed Anomalies as touchable world objects, and runs the full steal/
-- defend/tackle mechanic. This is the "walk around in the world" layer that
-- makes stealing feel physical instead of a menu click.
-- ============================================================================
do
	local RANCH_RADIUS = 62
	local PLOT_COLUMNS = 4
	local PLOT_ROWS = 3
	local PLOT_SPACING = 3.2

	local function newPart(props)
		local p = Instance.new("Part")
		p.Anchored = props.Anchored
		if p.Anchored == nil then
			p.Anchored = true
		end
		p.CanCollide = props.CanCollide ~= false
		p.Size = props.Size
		p.CFrame = props.CFrame
		p.Color = props.Color or Color3.fromRGB(200, 200, 200)
		p.Material = props.Material or Enum.Material.SmoothPlastic
		p.Name = props.Name or "Part"
		p.Parent = props.Parent
		return p
	end

	local ranchRoot = Instance.new("Folder")
	ranchRoot.Name = "Ranches"
	ranchRoot.Parent = Workspace

	local slots = {} -- index -> slot table
	local playerToSlot = {} -- Player -> slot table

	for i = 1, Config.RANCH_COUNT do
		local angle = (i / Config.RANCH_COUNT) * math.pi * 2
		local origin = Vector3.new(math.cos(angle) * RANCH_RADIUS, 0, math.sin(angle) * RANCH_RADIUS)
		local ranchCFrame = CFrame.new(origin, Vector3.new(0, origin.Y, 0))

		local folder = Instance.new("Folder")
		folder.Name = "Ranch" .. i
		folder.Parent = ranchRoot

		local floor = newPart({
			Name = "Floor",
			Size = Vector3.new(22, 1, 18),
			CFrame = ranchCFrame * CFrame.new(0, 0.5, 9),
			Color = Color3.fromRGB(255, 150, 60),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})

		local dropOff = newPart({
			Name = "DropOff",
			Size = Vector3.new(5, 0.3, 5),
			CFrame = ranchCFrame * CFrame.new(0, 1.15, 3),
			Color = Color3.fromRGB(255, 210, 70),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})

		local nameBoard = newPart({
			Name = "NameBoard",
			Size = Vector3.new(0.4, 3, 8),
			CFrame = ranchCFrame * CFrame.new(0, 6, -0.5),
			Color = Color3.fromRGB(20, 20, 28),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})
		local nameGui = Instance.new("SurfaceGui")
		nameGui.Face = Enum.NormalId.Back
		nameGui.LightInfluence = 0
		nameGui.PixelsPerStud = 40
		nameGui.Parent = nameBoard
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.fromScale(1, 0.6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Text = "EMPTY RANCH"
		nameLabel.Parent = nameGui
		local lockLabel = Instance.new("TextLabel")
		lockLabel.Size = UDim2.new(1, 0, 0.4, 0)
		lockLabel.Position = UDim2.new(0, 0, 0.6, 0)
		lockLabel.BackgroundTransparency = 1
		lockLabel.Font = Enum.Font.GothamBold
		lockLabel.TextScaled = true
		lockLabel.TextColor3 = Color3.fromRGB(255, 210, 70)
		lockLabel.Text = ""
		lockLabel.Parent = nameGui

		local plotStands = {}
		local plotIndex = 0
		for row = 1, PLOT_ROWS do
			for col = 1, PLOT_COLUMNS do
				plotIndex += 1
				local localX = (col - (PLOT_COLUMNS + 1) / 2) * PLOT_SPACING
				local localZ = 6 + (row - 1) * PLOT_SPACING
				local stand = newPart({
					Name = "Plot" .. plotIndex,
					Size = Vector3.new(1.6, 0.6, 1.6),
					CFrame = ranchCFrame * CFrame.new(localX, 1.3, localZ),
					Color = Color3.fromRGB(80, 80, 96),
					Material = Enum.Material.Metal,
					Parent = folder,
				})
				plotStands[plotIndex] = stand
			end
		end

		slots[i] = {
			index = i,
			cframe = ranchCFrame,
			folder = folder,
			floor = floor,
			dropOff = dropOff,
			nameLabel = nameLabel,
			lockLabel = lockLabel,
			plotStands = plotStands,
			anomalyVisuals = {}, -- [animId] = {part, prompt}
			occupant = nil,
		}
	end

	RanchService = {}

	function RanchService.GetSlot(player: Player)
		return playerToSlot[player]
	end

	local function findFreeSlotIndex()
		for i = 1, Config.RANCH_COUNT do
			if not slots[i].occupant then
				return i
			end
		end
		return nil
	end

	function RanchService.AssignRanch(player: Player)
		local index = findFreeSlotIndex()
		if not index then
			Notify.Send(player, "Ranch Full", "All ranch plots are taken on this server. Try rejoining shortly.", "warning")
			return
		end
		local slot = slots[index]
		slot.occupant = player
		slot.nameLabel.Text = player.Name:upper() .. "'S RANCH"
		playerToSlot[player] = slot
	end

	function RanchService.ReleaseRanch(player: Player)
		local slot = playerToSlot[player]
		if not slot then
			return
		end
		for animId, visual in slot.anomalyVisuals do
			if visual.part then
				visual.part:Destroy()
			end
		end
		slot.anomalyVisuals = {}
		slot.occupant = nil
		slot.nameLabel.Text = "EMPTY RANCH"
		slot.lockLabel.Text = ""
		slot.floor.Color = Color3.fromRGB(255, 150, 60)
		playerToSlot[player] = nil
	end

	function RanchService.RefreshLockVisual(player: Player)
		local slot = playerToSlot[player]
		local data = PlayerDataService.Get(player)
		if not slot or not data then
			return
		end
		if data.RanchLocked then
			slot.floor.Color = Color3.fromRGB(70, 130, 255)
			local remaining = math.max(0, data.LockExpiresAt - os.time())
			slot.lockLabel.Text = ("🔒 LOCKED (%ds)"):format(remaining)
		else
			slot.floor.Color = Color3.fromRGB(255, 150, 60)
			slot.lockLabel.Text = "🔓 UNLOCKED — VULNERABLE"
		end
		for _, visual in slot.anomalyVisuals do
			if visual.prompt then
				visual.prompt.Enabled = not data.RanchLocked
			end
		end
	end

	-- Creates/refreshes the physical proxy + steal prompt for a placed Anomaly.
	function RanchService.RenderAnomaly(player: Player, animId: string)
		local slot = playerToSlot[player]
		local data = PlayerDataService.Get(player)
		if not slot or not data then
			return
		end
		local anomaly = data.Anomalies[animId]
		if not anomaly or not anomaly.placedSlot then
			return
		end
		local def = AnomalyData.ById[anomaly.defId]
		local grade = AnomalyData.GradeById[anomaly.grade] or AnomalyData.Grades[1]
		local stand = slot.plotStands[anomaly.placedSlot]
		if not def or not stand then
			return
		end

		RanchService.RemoveAnomalyVisual(player, animId)

		local part = newPart({
			Name = "Anomaly_" .. animId,
			Size = Vector3.new(2, 2, 2),
			CFrame = stand.CFrame * CFrame.new(0, 1.6, 0),
			Color = def.color,
			Material = grade.id == "normal" and Enum.Material.SmoothPlastic or Enum.Material.Neon,
			CanCollide = false,
			Parent = slot.folder,
		})

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(160, 40)
		billboard.StudsOffset = Vector3.new(0, 1.6, 0)
		billboard.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.6)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Text = def.name
		label.Parent = billboard
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, 0, 0.4, 0)
		sub.Position = UDim2.new(0, 0, 0.6, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamMedium
		sub.TextScaled = true
		sub.TextColor3 = grade.color
		sub.Text = ("%s · $%.1f/s"):format(grade.name, AnomalyData.GetEffectiveIncome(anomaly.defId, anomaly.grade))
		sub.Parent = billboard

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Steal"
		prompt.ObjectText = def.name
		prompt.HoldDuration = 1.2
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = not data.RanchLocked
		prompt.Parent = part

		slot.anomalyVisuals[animId] = { part = part, prompt = prompt }
		RanchService.HookStealPrompt(player, animId, prompt)
	end

	function RanchService.RemoveAnomalyVisual(player: Player, animId: string)
		local slot = playerToSlot[player]
		if not slot then
			return
		end
		local visual = slot.anomalyVisuals[animId]
		if visual and visual.part then
			visual.part:Destroy()
		end
		slot.anomalyVisuals[animId] = nil
	end

	-- ===== Steal / tackle mechanic =====
	local activeCarries = {} -- carryId -> { thief, ownerPlayer, animId, originalSlot, part, startedAt }
	local nextCarryId = 1
	local thiefToCarryId = {} -- Player -> carryId (a thief can only carry one Anomaly at a time)

	function RanchService.HookStealPrompt(ownerPlayer: Player, animId: string, prompt: ProximityPrompt)
		prompt.Triggered:Connect(function(thief: Player)
			if thief == ownerPlayer then
				return
			end
			if thiefToCarryId[thief] then
				Notify.Send(thief, "Hands full", "You're already carrying an Anomaly.", "warning")
				return
			end
			local ownerData = PlayerDataService.Get(ownerPlayer)
			local ownerSlot = playerToSlot[ownerPlayer]
			if not ownerData or not ownerSlot or ownerData.RanchLocked then
				return
			end
			local anomaly = ownerData.Anomalies[animId]
			if not anomaly or not anomaly.placedSlot then
				return -- already stolen/unplaced by someone else / race condition
			end
			local character = thief.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not hrp then
				return
			end

			local def = AnomalyData.ById[anomaly.defId]
			local originalSlot = anomaly.placedSlot

			-- Pull it off the owner's ranch: stop counting toward their income
			-- and stop rendering it there while it's "in transit".
			anomaly.placedSlot = nil
			RanchService.RemoveAnomalyVisual(ownerPlayer, animId)
			PlayerDataService.Push(ownerPlayer)

			local carryPart = newPart({
				Name = "Carried_" .. animId,
				Size = Vector3.new(1.6, 1.6, 1.6),
				CFrame = hrp.CFrame * CFrame.new(0, 3, 0),
				Color = def.color,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = character,
			})
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = carryPart
			weld.Part1 = hrp
			weld.Parent = carryPart
			carryPart.CFrame = hrp.CFrame * CFrame.new(0, 3, 0)

			local originalSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = originalSpeed * Config.STEAL_WALK_SPEED_MULT

			local carryId = nextCarryId
			nextCarryId += 1
			activeCarries[carryId] = {
				thief = thief,
				ownerPlayer = ownerPlayer,
				animId = animId,
				originalSlot = originalSlot,
				originalSpeed = originalSpeed,
				part = carryPart,
				humanoid = humanoid,
				startedAt = os.time(),
			}
			thiefToCarryId[thief] = carryId

			Notify.Send(thief, "Anomaly Stolen!", ("Get %s back to your ranch before someone tackles you!"):format(def.name), "warning")
			Notify.Send(ownerPlayer, "You're being robbed!", ("%s is stealing your %s! Catch them!"):format(thief.Name, def.name), "danger")
		end)
	end

	local function endCarry(carryId: number, reason: string)
		local carry = activeCarries[carryId]
		if not carry then
			return
		end
		activeCarries[carryId] = nil
		thiefToCarryId[carry.thief] = nil
		if carry.part then
			carry.part:Destroy()
		end
		if carry.humanoid and carry.humanoid.Parent then
			carry.humanoid.WalkSpeed = carry.originalSpeed
		end
		return carry
	end

	-- Returns a stolen Anomaly back to its original owner's ranch.
	local function returnToOwner(carry)
		local ownerData = PlayerDataService.Get(carry.ownerPlayer)
		if not ownerData then
			return
		end
		local anomaly = ownerData.Anomalies[carry.animId]
		if not anomaly then
			return
		end
		anomaly.placedSlot = carry.originalSlot
		RanchService.RenderAnomaly(carry.ownerPlayer, carry.animId)
		PlayerDataService.Push(carry.ownerPlayer)
	end

	-- Transfers a stolen Anomaly permanently to the thief.
	local function completeTheft(carry)
		local ownerData = PlayerDataService.Get(carry.ownerPlayer)
		local thiefData = PlayerDataService.Get(carry.thief)
		if not ownerData or not thiefData then
			return
		end
		local anomaly = ownerData.Anomalies[carry.animId]
		if not anomaly then
			return
		end
		ownerData.Anomalies[carry.animId] = nil

		local newId = "anim_" .. thiefData.NextAnomalyId
		thiefData.NextAnomalyId += 1
		local newEntry = { defId = anomaly.defId, grade = anomaly.grade, placedSlot = nil }
		thiefData.Anomalies[newId] = newEntry

		-- Auto-place into the thief's first open plot, if they have one.
		local thiefSlot = playerToSlot[carry.thief]
		if thiefSlot then
			local usedSlots = {}
			for _, a in thiefData.Anomalies do
				if a.placedSlot then
					usedSlots[a.placedSlot] = true
				end
			end
			for i = 1, thiefData.UnlockedPlots do
				if not usedSlots[i] then
					newEntry.placedSlot = i
					RanchService.RenderAnomaly(carry.thief, newId)
					break
				end
			end
		end

		PlayerDataService.Push(carry.ownerPlayer)
		PlayerDataService.Push(carry.thief)
		BattlepassService.AddXP(carry.thief, Config.XP_PER_STEAL_SUCCESS)

		local def = AnomalyData.ById[anomaly.defId]
		Notify.Send(carry.thief, "Heist Complete!", ("%s is now yours."):format(def.name), "success")
		Notify.Send(carry.ownerPlayer, "Anomaly Lost", ("Your %s was stolen by %s."):format(def.name, carry.thief.Name), "danger")
	end

	-- Main steal-resolution loop: tackles, successful heists, and timeouts.
	RunService.Heartbeat:Connect(function()
		for carryId, carry in activeCarries do
			local thief = carry.thief
			if not thief.Parent or not carry.part or not carry.part.Parent then
				endCarry(carryId, "gone")
				returnToOwner(carry)
				continue
			end
			local character = thief.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				local c = endCarry(carryId, "no character")
				if c then
					returnToOwner(c)
				end
				continue
			end

			-- Safety timeout so nothing gets stuck "in transit" forever.
			if os.time() - carry.startedAt > 120 then
				local c = endCarry(carryId, "timeout")
				if c then
					returnToOwner(c)
					Notify.Send(thief, "Too slow!", "The Anomaly slipped away and returned home.", "warning")
				end
				continue
			end

			-- Tackle check: any OTHER player standing close enough reclaims it.
			local tackled = false
			for _, otherPlayer in Players:GetPlayers() do
				if otherPlayer ~= thief and not tackled then
					local otherChar = otherPlayer.Character
					local otherHrp = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
					if otherHrp and (otherHrp.Position - hrp.Position).Magnitude <= Config.STEAL_TACKLE_RADIUS then
						tackled = true
						local c = endCarry(carryId, "tackled")
						if c then
							returnToOwner(c)
							Notify.Send(thief, "Tackled!", ("%s caught you and returned the Anomaly."):format(otherPlayer.Name), "danger")
							Notify.Send(otherPlayer, "Nice Tackle!", "You reclaimed a stolen Anomaly.", "success")
						end
					end
				end
			end
			if tackled then
				continue
			end

			-- Home-run check: reached their own ranch's drop-off pad.
			local thiefSlot = playerToSlot[thief]
			if thiefSlot then
				local dist = (thiefSlot.dropOff.Position - hrp.Position).Magnitude
				if dist <= 6 then
					local c = endCarry(carryId, "delivered")
					if c then
						completeTheft(c)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local carryId = thiefToCarryId[player]
		if carryId then
			local c = endCarry(carryId, "left")
			if c then
				returnToOwner(c)
			end
		end
		RanchService.ReleaseRanch(player)
	end)

	-- ===== Remote handlers: placing / unplacing / locking =====
	remotes.PlaceAnomaly.OnServerEvent:Connect(function(player: Player, animId: string)
		local data = PlayerDataService.Get(player)
		local slot = playerToSlot[player]
		if not data or not slot then
			return
		end
		local anomaly = data.Anomalies[animId]
		if not anomaly or anomaly.placedSlot then
			return
		end
		local usedSlots = {}
		for _, a in data.Anomalies do
			if a.placedSlot then
				usedSlots[a.placedSlot] = true
			end
		end
		for i = 1, data.UnlockedPlots do
			if not usedSlots[i] then
				anomaly.placedSlot = i
				RanchService.RenderAnomaly(player, animId)
				PlayerDataService.Push(player)
				return
			end
		end
		Notify.Send(player, "Ranch Full", "Buy another plot to place more Anomalies.", "warning")
	end)

	remotes.UnplaceAnomaly.OnServerEvent:Connect(function(player: Player, animId: string)
		local data = PlayerDataService.Get(player)
		if not data then
			return
		end
		local anomaly = data.Anomalies[animId]
		if not anomaly or not anomaly.placedSlot then
			return
		end
		anomaly.placedSlot = nil
		RanchService.RemoveAnomalyVisual(player, animId)
		PlayerDataService.Push(player)
	end)

	remotes.ToggleLock.OnServerEvent:Connect(function(player: Player)
		local data = PlayerDataService.Get(player)
		if not data then
			return
		end
		if data.RanchLocked and os.time() < data.LockExpiresAt then
			Notify.Send(player, "Already Locked", "Your ranch is still protected — wait it out.", "info")
			return
		end
		data.RanchLocked = true
		data.LockExpiresAt = os.time() + Config.LOCK_DURATION
		RanchService.RefreshLockVisual(player)
		PlayerDataService.Push(player)
		Notify.Send(player, "Ranch Locked", ("Protected for %ds. It'll auto-unlock after that."):format(Config.LOCK_DURATION), "success")
	end)

	-- ===== Assignment + respawn re-render =====
	Players.PlayerAdded:Connect(function(player)
		RanchService.AssignRanch(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			local data = PlayerDataService.Get(player)
			if not data then
				return
			end
			for animId, anomaly in data.Anomalies do
				if anomaly.placedSlot then
					RanchService.RenderAnomaly(player, animId)
				end
			end
			RanchService.RefreshLockVisual(player)
		end)
	end)

	-- Lazily auto-unlock ranches whose lock has expired, once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = PlayerDataService.Get(player)
				if data and data.RanchLocked and os.time() >= data.LockExpiresAt then
					data.RanchLocked = false
					RanchService.RefreshLockVisual(player)
					PlayerDataService.Push(player)
					Notify.Send(player, "Ranch Unlocked", "Your protection ran out — you're vulnerable again!", "warning")
				elseif data then
					RanchService.RefreshLockVisual(player)
				end
			end
		end
	end)
end

-- ============================================================================
-- SECTION: MarketService — the rotating 4-slot Anomaly shop. Buying a slot
-- raises its price until the market refreshes.
-- ============================================================================
do
	MarketService = {}

	local marketSlots = {} -- [1..MARKET_SLOTS] = {defId, buyCount, basePrice}
	local refreshesAt = 0

	local function randomAnomalyForSlot()
		-- Weighted toward commoner items so the market stays affordable early.
		local weights = { Common = 50, Rare = 30, Epic = 15, Legendary = 5 }
		local pool = {}
		for _, item in AnomalyData.Items do
			for _ = 1, weights[item.rarity] or 1 do
				table.insert(pool, item)
			end
		end
		return pool[math.random(1, #pool)]
	end

	local function refreshMarket()
		for i = 1, Config.MARKET_SLOTS do
			local item = randomAnomalyForSlot()
			marketSlots[i] = { defId = item.id, buyCount = 0, basePrice = item.cost }
		end
		refreshesAt = os.time() + Config.MARKET_REFRESH_SECONDS
	end

	local function currentPrice(slot)
		return math.floor(slot.basePrice * (Config.MARKET_PRICE_ESCALATION ^ slot.buyCount))
	end

	local function broadcastMarket()
		local payload = { slots = {}, refreshesAt = refreshesAt }
		for i, slot in marketSlots do
			payload.slots[i] = { defId = slot.defId, price = currentPrice(slot) }
		end
		for _, player in Players:GetPlayers() do
			remotes.MarketUpdated:FireClient(player, payload)
		end
	end

	-- Exposed so MapBuilder can render live stall signage in the world.
	function MarketService.GetSlots()
		local out = {}
		for i, slot in marketSlots do
			out[i] = { defId = slot.defId, price = currentPrice(slot) }
		end
		return out
	end

	function MarketService.Init()
		refreshMarket()

		remotes.BuyMarketSlot.OnServerInvoke = function(player: Player, slotIndex: number)
			local slot = marketSlots[slotIndex]
			if not slot then
				return false, "Invalid market slot."
			end
			local data = PlayerDataService.Get(player)
			if not data then
				return false, "Data not loaded."
			end
			local price = currentPrice(slot)
			if data.Glimmer < price then
				return false, "Not enough Glimmer."
			end

			data.Glimmer -= price
			slot.buyCount += 1

			local animId = "anim_" .. data.NextAnomalyId
			data.NextAnomalyId += 1
			data.Anomalies[animId] = { defId = slot.defId, grade = "normal", placedSlot = nil }

			BattlepassService.AddXP(player, Config.XP_PER_BUY)
			PlayerDataService.Push(player)
			broadcastMarket()

			local def = AnomalyData.ById[slot.defId]
			return true, ("Bought %s for $%d Glimmer."):format(def.name, price)
		end

		Players.PlayerAdded:Connect(function(player)
			task.wait(0.5)
			local payload = { slots = {}, refreshesAt = refreshesAt }
			for i, slot in marketSlots do
				payload.slots[i] = { defId = slot.defId, price = currentPrice(slot) }
			end
			remotes.MarketUpdated:FireClient(player, payload)
		end)

		task.spawn(function()
			while true do
				task.wait(Config.MARKET_REFRESH_SECONDS)
				refreshMarket()
				broadcastMarket()
			end
		end)
	end

	MarketService.Init()
end

-- ============================================================================
-- SECTION: WeatherService — cycles the server-wide weather state that drives
-- income multipliers and mutation odds.
-- ============================================================================
do
	WeatherService = {}

	local current = WeatherData.States[1]
	local endsAt = os.time() + current.duration

	function WeatherService.GetCurrent()
		return current
	end

	local function broadcastWeather()
		local payload = { id = current.id, name = current.name, icon = current.icon, endsAt = endsAt, incomeMult = current.incomeMult }
		for _, player in Players:GetPlayers() do
			remotes.WeatherUpdated:FireClient(player, payload)
		end
	end

	function WeatherService.Init()
		endsAt = os.time() + current.duration
		Players.PlayerAdded:Connect(function(player)
			task.wait(0.5)
			remotes.WeatherUpdated:FireClient(player, { id = current.id, name = current.name, icon = current.icon, endsAt = endsAt, incomeMult = current.incomeMult })
		end)

		task.spawn(function()
			while true do
				task.wait(current.duration)
				current = WeatherData.RollNext()
				endsAt = os.time() + current.duration
				broadcastWeather()
			end
		end)
	end

	WeatherService.Init()
end

-- ============================================================================
-- SECTION: IncomeService — the core idle loop. Every second: credit income
-- from placed Anomalies, and roll mutation chances while boosted weather is
-- active.
-- ============================================================================
do
	task.spawn(function()
		while true do
			task.wait(Config.INCOME_TICK_SECONDS)
			local weather = WeatherService.GetCurrent()

			for _, player in Players:GetPlayers() do
				local data = PlayerDataService.Get(player)
				local slot = RanchService.GetSlot(player)
				if data and slot then
					local incomeMult = 1 + (data.IncomeLevel * Config.INCOME_UPGRADE_BONUS_PER_LEVEL)
					local prestigeMult = 1 + (data.RebootCount * Config.PRESTIGE_BONUS_PER_REBOOT)
					local earned = 0
					local mutated = false

					for animId, anomaly in data.Anomalies do
						if anomaly.placedSlot then
							local baseIncome = AnomalyData.GetEffectiveIncome(anomaly.defId, anomaly.grade)
							earned += baseIncome * incomeMult * prestigeMult * weather.incomeMult

							if weather.mutateChance > 0 and anomaly.grade == "normal" and math.random() < weather.mutateChance then
								anomaly.grade = AnomalyData.RollMutationGrade()
								mutated = true
								RanchService.RenderAnomaly(player, animId)
								BattlepassService.AddXP(player, Config.XP_PER_MUTATION)
								local def = AnomalyData.ById[anomaly.defId]
								local grade = AnomalyData.GradeById[anomaly.grade]
								Notify.Send(player, "Mutation!", ("Your %s turned %s (%dx value)!"):format(def.name, grade.name, grade.mult), "success")
							end
						end
					end

					if earned > 0 then
						earned = math.floor(earned * 10) / 10
						data.Glimmer += earned
						data.LifetimeGlimmer += earned
					end

					if earned > 0 or mutated then
						PlayerDataService.Push(player)
					end
				end
			end
		end
	end)
end

-- ============================================================================
-- SECTION: UpgradeService — the tycoon layer: buy extra ranch plots and
-- permanent income levels.
-- ============================================================================
do
	UpgradeService = {}

	local function plotCost(currentPlots: number): number
		local extraPlotsOwned = currentPlots - Config.STARTING_PLOTS
		return math.floor(Config.PLOT_COST_BASE * (Config.PLOT_COST_GROWTH ^ extraPlotsOwned))
	end

	local function incomeUpgradeCost(level: number): number
		return math.floor(Config.INCOME_UPGRADE_BASE_COST * (Config.INCOME_UPGRADE_COST_GROWTH ^ level))
	end

	UpgradeService.PlotCost = plotCost
	UpgradeService.IncomeUpgradeCost = incomeUpgradeCost

	remotes.BuyPlot.OnServerInvoke = function(player: Player)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, "Data not loaded."
		end
		if data.UnlockedPlots >= Config.MAX_PLOTS then
			return false, "You already have the maximum number of plots."
		end
		local cost = plotCost(data.UnlockedPlots)
		if data.Glimmer < cost then
			return false, "Not enough Glimmer."
		end
		data.Glimmer -= cost
		data.UnlockedPlots += 1
		PlayerDataService.Push(player)
		Notify.Send(player, "Plot Unlocked!", ("You can now place %d Anomalies."):format(data.UnlockedPlots), "success")
		return true, "Plot purchased."
	end

	remotes.BuyUpgrade.OnServerInvoke = function(player: Player, upgradeId: string)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, "Data not loaded."
		end
		if upgradeId ~= "income" then
			return false, "Unknown upgrade."
		end
		if data.IncomeLevel >= Config.INCOME_UPGRADE_MAX_LEVEL then
			return false, "Income is already maxed out."
		end
		local cost = incomeUpgradeCost(data.IncomeLevel)
		if data.Glimmer < cost then
			return false, "Not enough Glimmer."
		end
		data.Glimmer -= cost
		data.IncomeLevel += 1
		PlayerDataService.Push(player)
		Notify.Send(player, "Income Boosted!", ("Ranch income is now %d%% higher."):format(math.floor(data.IncomeLevel * Config.INCOME_UPGRADE_BONUS_PER_LEVEL * 100)), "success")
		return true, "Upgrade purchased."
	end
end

-- ============================================================================
-- SECTION: PrestigeService — "Reboot": reset Glimmer and upgrades for a
-- permanent income multiplier, once lifetime earnings cross a threshold.
-- ============================================================================
do
	local function rebootThreshold(rebootCount: number): number
		return math.floor(Config.PRESTIGE_BASE_THRESHOLD * (Config.PRESTIGE_THRESHOLD_GROWTH ^ rebootCount))
	end

	remotes.DoReboot.OnServerInvoke = function(player: Player)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, "Data not loaded."
		end
		local threshold = rebootThreshold(data.RebootCount)
		if data.LifetimeGlimmer < threshold then
			return false, ("Earn $%d lifetime Glimmer to Reboot (you're at $%d)."):format(threshold, math.floor(data.LifetimeGlimmer))
		end

		data.RebootCount += 1
		data.Glimmer = Config.STARTING_GLIMMER
		data.UnlockedPlots = Config.STARTING_PLOTS
		data.IncomeLevel = 0
		-- Anomalies (and their mutations) are kept — Reboot resets the economy,
		-- not your collection.
		for _, anomaly in data.Anomalies do
			anomaly.placedSlot = nil
		end
		RanchService.ReleaseRanch(player)
		RanchService.AssignRanch(player)

		BattlepassService.AddXP(player, Config.XP_PER_REBOOT)
		PlayerDataService.Push(player)
		Notify.Send(player, "REBOOT COMPLETE", ("Rank %d reached! +%d%% permanent income."):format(data.RebootCount, math.floor(data.RebootCount * Config.PRESTIGE_BONUS_PER_REBOOT * 100)), "success")
		return true, "Rebooted."
	end
end

-- ============================================================================
-- SECTION: BattlepassService — "Signal Pass" leveling, free/premium reward
-- claiming, and unlocking premium via a Robux Game Pass or a Glimmer buy-out.
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
			Notify.Send(player, "Signal Pass Level Up!", ("You reached level %d."):format(newLevel), "success")
		end
		PlayerDataService.Push(player)
	end

	local function grantReward(player: Player, data, reward)
		if reward.kind == "Glimmer" then
			data.Glimmer += reward.amount
			data.LifetimeGlimmer += reward.amount
		elseif reward.kind == "Anomaly" then
			local animId = "anim_" .. data.NextAnomalyId
			data.NextAnomalyId += 1
			data.Anomalies[animId] = { defId = reward.itemId, grade = "golden", placedSlot = nil }
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
					return false, "Unlock Signal Pass Premium first."
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

		remotes.BuyBattlepassPremiumWithGlimmer.OnServerInvoke = function(player: Player)
			local data = PlayerDataService.Get(player)
			if not data then
				return false, "Data not loaded."
			end
			if data.Battlepass.PremiumOwned then
				return false, "You already own Signal Pass Premium."
			end
			if data.Glimmer < Config.BATTLEPASS_PREMIUM_COST_GLIMMER then
				return false, "Not enough Glimmer."
			end
			data.Glimmer -= Config.BATTLEPASS_PREMIUM_COST_GLIMMER
			data.Battlepass.PremiumOwned = true
			PlayerDataService.Push(player)
			Notify.Send(player, "Signal Pass Premium!", "Unlocked with Glimmer. Go claim your premium rewards.", "success")
			return true, "Unlocked."
		end

		remotes.BuyBattlepassPremiumWithRobux.OnServerEvent:Connect(function(player: Player)
			local gamepassId = ProductIds.GamePasses.SignalPass_Premium
			if gamepassId == 0 then
				Notify.Send(player, "Not Configured", "The developer hasn't set up the Signal Pass Game Pass id yet.", "warning")
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, gamepassId)
		end)

		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
			if wasPurchased and gamepassId == ProductIds.GamePasses.SignalPass_Premium then
				local data = PlayerDataService.Get(player)
				if data and not data.Battlepass.PremiumOwned then
					data.Battlepass.PremiumOwned = true
					PlayerDataService.Push(player)
					Notify.Send(player, "Signal Pass Premium!", "Thanks for the support. Go claim your premium rewards.", "success")
				end
			end
		end)

		Players.PlayerAdded:Connect(function(player)
			local gamepassId = ProductIds.GamePasses.SignalPass_Premium
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
-- SECTION: DailyRewardService — 7-day escalating login streak.
-- ============================================================================
do
	local function isAvailable(daily)
		local secondsSince = os.time() - daily.LastClaimUnix
		return daily.LastClaimUnix == 0 or secondsSince >= 20 * 3600
	end

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

		local amount = Config.DAILY_REWARD_GLIMMER[daily.Streak]
		data.Glimmer += amount
		data.LifetimeGlimmer += amount

		PlayerDataService.Push(player)
		Notify.Send(player, ("Day %d Reward!"):format(daily.Streak), ("+$%d Glimmer."):format(amount), "success")

		return true, daily.Streak
	end
end

-- ============================================================================
-- SECTION: Leaderstats
-- ============================================================================
do
	Players.PlayerAdded:Connect(function(player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		local glimmer = Instance.new("IntValue")
		glimmer.Name = "Glimmer"
		glimmer.Value = 0
		glimmer.Parent = leaderstats

		local reboots = Instance.new("IntValue")
		reboots.Name = "Reboots"
		reboots.Value = 0
		reboots.Parent = leaderstats
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = PlayerDataService.Get(player)
				local leaderstats = player:FindFirstChild("leaderstats")
				if data and leaderstats then
					leaderstats.Glimmer.Value = math.floor(data.Glimmer)
					leaderstats.Reboots.Value = data.RebootCount
				end
			end
		end
	end)
end

-- ============================================================================
-- SECTION: LeaderboardBoard — a physical top-5-by-Glimmer board near the
-- market (session-only, no extra DataStore needed).
-- ============================================================================
do
	local part = Instance.new("Part")
	part.Name = "LeaderboardBoard"
	part.Anchored = true
	part.Size = Vector3.new(0.5, 10, 14)
	part.CFrame = CFrame.new(0, 6, -18) * CFrame.Angles(0, math.pi, 0)
	part.Color = Color3.fromRGB(18, 18, 26)
	part.Parent = Workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.Parent = part

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.16, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 210, 70)
	title.Text = "🏆 TOP RANCHERS"
	title.Parent = gui

	local rows = {}
	for i = 1, 5 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0.15, 0)
		row.Position = UDim2.new(0, 0, 0.16 + (i - 1) * 0.15, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextScaled = true
		row.TextColor3 = Color3.new(1, 1, 1)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ("%d. —"):format(i)
		row.Parent = gui
		rows[i] = row
	end

	task.spawn(function()
		while true do
			task.wait(4)
			local ranked = {}
			for _, player in Players:GetPlayers() do
				local data = PlayerDataService.Get(player)
				if data then
					table.insert(ranked, { name = player.Name, glimmer = data.Glimmer })
				end
			end
			table.sort(ranked, function(a, b)
				return a.glimmer > b.glimmer
			end)
			for i = 1, 5 do
				local entry = ranked[i]
				if entry then
					rows[i].Text = ("%d. %s — $%d"):format(i, entry.name, math.floor(entry.glimmer))
				else
					rows[i].Text = ("%d. —"):format(i)
				end
			end
		end
	end)
end

-- ============================================================================
-- SECTION: MapBuilder — the central plaza (market stalls + spawn) that sits
-- inside the ring of ranch plots RanchService already built. Runs once per
-- server start and rebuilds deterministically.
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
		p.CanCollide = props.CanCollide ~= false
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
	part({ Name = "Baseplate", Size = Vector3.new(320, 4, 320), Position = Vector3.new(0, -2, 0), Color = Color3.fromRGB(30, 30, 40), Material = Enum.Material.Concrete })

	-- Central plaza
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = root
	part({ Name = "PlazaFloor", Size = Vector3.new(40, 0.4, 40), Position = Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(50, 48, 60), Parent = plaza })

	sign({ Text = "GLITCH RANCH", CFrame = CFrame.new(0, 12, -22) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(0.5, 6, 26), TextColor = Color3.fromRGB(255, 62, 165), Parent = plaza })

	-- Spawn ring in the center of the plaza
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.new(math.cos(angle) * 8, 1, math.sin(angle) * 8)
		spawn.Color = Color3.fromRGB(62, 193, 255)
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.3
		spawn.Duration = 0
		spawn.Name = "PlazaSpawn"
		spawn.Parent = plaza
	end

	-- 4 market stalls, one per rotating Market slot, with live-updating signage.
	local stallLabels = {}
	for i = 1, Config.MARKET_SLOTS do
		local angle = (i / Config.MARKET_SLOTS) * math.pi * 2 + math.pi / 4
		local pos = Vector3.new(math.cos(angle) * 15, 0, math.sin(angle) * 15)
		local stallCFrame = CFrame.new(pos, Vector3.new(0, 0, 0))

		local post1 = part({ Size = Vector3.new(0.6, 8, 0.6), CFrame = stallCFrame * CFrame.new(-2.5, 4, 0), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Wood, Parent = plaza })
		part({ Size = Vector3.new(0.6, 8, 0.6), CFrame = stallCFrame * CFrame.new(2.5, 4, 0), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Wood, Parent = plaza })
		part({ Size = Vector3.new(6, 0.5, 4), CFrame = stallCFrame * CFrame.new(0, 8, 0), Color = Color3.fromHSV(i * 0.22, 0.7, 0.85), Material = Enum.Material.Fabric, Parent = plaza })
		local counter = part({ Size = Vector3.new(6, 3, 2), CFrame = stallCFrame * CFrame.new(0, 1.5, -1), Color = Color3.fromRGB(120, 100, 80), Material = Enum.Material.Wood, Parent = plaza })

		local board = part({ Size = Vector3.new(5, 3, 0.2), CFrame = stallCFrame * CFrame.new(0, 5.5, 0.2), Color = Color3.fromRGB(20, 20, 28), Material = Enum.Material.SmoothPlastic, Parent = plaza })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.PixelsPerStud = 40
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextWrapped = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "Loading..."
		label.Parent = gui
		stallLabels[i] = label
	end

	task.spawn(function()
		while true do
			task.wait(3)
			local slots = MarketService.GetSlots()
			for i, label in stallLabels do
				local slot = slots[i]
				if slot then
					local def = AnomalyData.ById[slot.defId]
					label.Text = def and (def.name .. "\n$" .. slot.price) or "..."
				end
			end
		end
	end)

	-- Lighting mood
	Lighting.Ambient = Color3.fromRGB(35, 35, 48)
	Lighting.OutdoorAmbient = Color3.fromRGB(55, 50, 70)
	Lighting.Brightness = 2
	Lighting.ClockTime = 20
	Lighting.FogColor = Color3.fromRGB(25, 18, 40)
	Lighting.FogEnd = 700
	Lighting.Technology = Enum.Technology.Future

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.28
		atmosphere.Color = Color3.fromRGB(150, 130, 200)
		atmosphere.Decay = Color3.fromRGB(70, 40, 90)
		atmosphere.Glare = 0.15
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

	print("[MapBuilder] Generated plaza + market stalls (ranch ring built by RanchService).")
end

print("[GlitchRanch] Server systems online.")
