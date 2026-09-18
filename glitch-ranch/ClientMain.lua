-- ============================================================================
-- GLITCH RANCH — CLIENT
-- Paste this ENTIRE file into a single LocalScript inside
-- StarterPlayer > StarterPlayerScripts.
--
-- NOTE: Config, AnomalyData, WeatherData and BattlepassData below are
-- duplicated from the server script on purpose (client code can't reach
-- server-only tables). If you tune numbers, change them in BOTH
-- ServerMain and ClientMain. The server is always the source of truth for
-- Glimmer/ownership — this copy only drives what the UI displays.
-- ============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

--== Forward-declared shared tables, filled in by the sections below ==--
local Theme
local Components
local Config
local AnomalyData
local WeatherData
local BattlepassData
local remotes
local State
local notify
local screenGui

local MarketTab
local InventoryTab
local UpgradesTab
local PrestigeTab
local BattlepassTab

local dailyRewardUI

-- ============================================================================
-- SECTION: Config — must match ServerMain's Config.
-- ============================================================================
do
	Config = {}

	Config.STARTING_GLIMMER = 100
	Config.STARTING_PLOTS = 4
	Config.MAX_PLOTS = 12
	Config.PLOT_COST_BASE = 250
	Config.PLOT_COST_GROWTH = 1.6

	Config.MARKET_SLOTS = 4

	Config.LOCK_DURATION = 180
	Config.NEW_PLAYER_GRACE_SECONDS = 60

	Config.INCOME_UPGRADE_BASE_COST = 200
	Config.INCOME_UPGRADE_COST_GROWTH = 1.5
	Config.INCOME_UPGRADE_BONUS_PER_LEVEL = 0.08
	Config.INCOME_UPGRADE_MAX_LEVEL = 15

	Config.PRESTIGE_BASE_THRESHOLD = 5000
	Config.PRESTIGE_THRESHOLD_GROWTH = 1.7
	Config.PRESTIGE_BONUS_PER_REBOOT = 0.10

	Config.BATTLEPASS_XP_PER_LEVEL = 150
	Config.BATTLEPASS_MAX_LEVEL = 40
	Config.BATTLEPASS_PREMIUM_COST_GLIMMER = 4000

	Config.DAILY_REWARD_GLIMMER = { 60, 60, 120, 120, 200, 200, 400 }
	Config.DAILY_STREAK_RESET_HOURS = 48
end

-- ============================================================================
-- SECTION: AnomalyData — must match ServerMain's catalog (ids, names, cost).
-- ============================================================================
do
	AnomalyData = {}

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

	AnomalyData.Grades = {
		{ id = "normal", name = "Normal", mult = 1, color = Color3.fromRGB(200, 200, 200) },
		{ id = "glitched", name = "Glitched", mult = 2, color = Color3.fromRGB(120, 220, 140) },
		{ id = "golden", name = "Golden", mult = 5, color = Color3.fromRGB(255, 210, 70) },
		{ id = "rainbow", name = "Rainbow", mult = 15, color = Color3.fromRGB(220, 100, 255) },
		{ id = "corrupted", name = "Corrupted", mult = 40, color = Color3.fromRGB(255, 60, 60) },
	}

	AnomalyData.GradeById = {}
	for _, g in AnomalyData.Grades do
		AnomalyData.GradeById[g.id] = g
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
-- SECTION: WeatherData — must match ServerMain's weather states (for icons
-- and names; the server decides which one is actually active).
-- ============================================================================
do
	WeatherData = {}
	WeatherData.States = {
		{ id = "normal", name = "Clear Signal", icon = "📡" },
		{ id = "overclock", name = "Overclock Surge", icon = "⚡" },
		{ id = "aurora", name = "Aurora Static", icon = "🌌" },
		{ id = "blackout", name = "Blackout", icon = "🌑" },
		{ id = "goldenhour", name = "Golden Hour", icon = "✨" },
	}
	WeatherData.ById = {}
	for _, w in WeatherData.States do
		WeatherData.ById[w.id] = w
	end
end

-- ============================================================================
-- SECTION: BattlepassData — must match ServerMain's reward table.
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
-- SECTION: Theme
-- ============================================================================
do
	Theme = {}

	Theme.Color = {
		Background = Color3.fromRGB(14, 14, 20),
		Surface = Color3.fromRGB(23, 23, 32),
		SurfaceRaised = Color3.fromRGB(31, 31, 43),
		Border = Color3.fromRGB(47, 47, 63),

		TextPrimary = Color3.fromRGB(245, 245, 250),
		TextSecondary = Color3.fromRGB(160, 160, 178),
		TextMuted = Color3.fromRGB(110, 110, 128),

		Accent = Color3.fromRGB(255, 62, 165),
		AccentAlt = Color3.fromRGB(62, 193, 255),
		Gold = Color3.fromRGB(255, 210, 70),

		Success = Color3.fromRGB(70, 210, 130),
		Warning = Color3.fromRGB(255, 180, 60),
		Danger = Color3.fromRGB(255, 90, 90),

		Glimmer = Color3.fromRGB(120, 230, 150),
	}

	Theme.Font = {
		Heading = Enum.Font.GothamBlack,
		Bold = Enum.Font.GothamBold,
		Body = Enum.Font.Gotham,
		Medium = Enum.Font.GothamMedium,
	}

	Theme.Corner = {
		Small = UDim.new(0, 8),
		Medium = UDim.new(0, 14),
		Large = UDim.new(0, 22),
		Pill = UDim.new(1, 0),
	}

	Theme.Padding = 12
end

-- ============================================================================
-- SECTION: Components
-- ============================================================================
do
	Components = {}

	function Components.corner(instance: Instance, radius: UDim?)
		local c = Instance.new("UICorner")
		c.CornerRadius = radius or Theme.Corner.Medium
		c.Parent = instance
		return c
	end

	function Components.stroke(instance: Instance, color: Color3?, thickness: number?, transparency: number?)
		local s = Instance.new("UIStroke")
		s.Color = color or Theme.Color.Border
		s.Thickness = thickness or 1
		s.Transparency = transparency or 0
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = instance
		return s
	end

	function Components.gradient(instance: Instance, colorA: Color3, colorB: Color3, rotation: number?)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(colorA, colorB)
		g.Rotation = rotation or 90
		g.Parent = instance
		return g
	end

	function Components.padding(instance: Instance, all: number?)
		local p = Instance.new("UIPadding")
		local n = all or Theme.Padding
		p.PaddingTop = UDim.new(0, n)
		p.PaddingBottom = UDim.new(0, n)
		p.PaddingLeft = UDim.new(0, n)
		p.PaddingRight = UDim.new(0, n)
		p.Parent = instance
		return p
	end

	function Components.listLayout(instance: Instance, direction: Enum.FillDirection?, gap: number?, sortOrder: Enum.SortOrder?)
		local l = Instance.new("UIListLayout")
		l.FillDirection = direction or Enum.FillDirection.Vertical
		l.Padding = UDim.new(0, gap or 8)
		l.SortOrder = sortOrder or Enum.SortOrder.LayoutOrder
		l.Parent = instance
		return l
	end

	function Components.gridLayout(instance: Instance, cellSize: UDim2, gap: number?)
		local g = Instance.new("UIGridLayout")
		g.CellSize = cellSize
		g.CellPadding = UDim2.fromOffset(gap or 10, gap or 10)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = instance
		return g
	end

	function Components.frame(props: { [string]: any }): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.Surface
		f.BackgroundTransparency = props.BackgroundTransparency or 0
		f.BorderSizePixel = 0
		f.Size = props.Size or UDim2.fromScale(1, 1)
		f.Position = props.Position or UDim2.fromScale(0, 0)
		f.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
		f.Visible = props.Visible ~= false
		f.LayoutOrder = props.LayoutOrder or 0
		f.ZIndex = props.ZIndex or 1
		f.ClipsDescendants = props.ClipsDescendants or false
		f.Name = props.Name or "Frame"
		if props.AutomaticSize then
			f.AutomaticSize = props.AutomaticSize
		end
		if props.Corner ~= false then
			Components.corner(f, props.CornerRadius)
		end
		if props.Parent then
			f.Parent = props.Parent
		end
		return f
	end

	function Components.label(props: { [string]: any }): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = props.Text or ""
		l.Font = props.Font or Theme.Font.Body
		l.TextSize = props.TextSize or 16
		l.TextColor3 = props.TextColor3 or Theme.Color.TextPrimary
		l.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
		l.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
		l.TextWrapped = props.TextWrapped ~= false
		l.Size = props.Size or UDim2.new(1, 0, 0, 20)
		l.Position = props.Position or UDim2.fromScale(0, 0)
		l.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
		l.LayoutOrder = props.LayoutOrder or 0
		l.ZIndex = props.ZIndex or 1
		l.TextTruncate = props.TextTruncate or Enum.TextTruncate.None
		l.Name = props.Name or "Label"
		if props.AutomaticSize then
			l.AutomaticSize = props.AutomaticSize
		end
		if props.Parent then
			l.Parent = props.Parent
		end
		return l
	end

	function Components.button(props: { [string]: any }): TextButton
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.Accent
		b.Text = props.Text or "Button"
		b.Font = props.Font or Theme.Font.Bold
		b.TextSize = props.TextSize or 16
		b.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
		b.Size = props.Size or UDim2.new(1, 0, 0, 44)
		b.Position = props.Position or UDim2.fromScale(0, 0)
		b.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
		b.LayoutOrder = props.LayoutOrder or 0
		b.ZIndex = props.ZIndex or 1
		b.Name = props.Name or "Button"
		Components.corner(b, props.CornerRadius or Theme.Corner.Medium)

		local baseColor = b.BackgroundColor3
		local hoverColor = props.HoverColor or baseColor:Lerp(Color3.new(1, 1, 1), 0.12)
		b.MouseEnter:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
		end)
		b.MouseButton1Down:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.06), { Size = (props.Size or UDim2.new(1, 0, 0, 44)) - UDim2.fromOffset(4, 4) }):Play()
		end)
		b.MouseButton1Up:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.08), { Size = props.Size or UDim2.new(1, 0, 0, 44) }):Play()
		end)

		if props.Parent then
			b.Parent = props.Parent
		end
		if props.OnClick then
			b.MouseButton1Click:Connect(props.OnClick)
		end
		return b
	end

	function Components.progressBar(props: { [string]: any })
		local track = Components.frame({
			Name = props.Name or "ProgressTrack",
			Size = props.Size or UDim2.new(1, 0, 0, 10),
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			BackgroundColor3 = props.TrackColor or Theme.Color.SurfaceRaised,
			CornerRadius = Theme.Corner.Pill,
			Parent = props.Parent,
		})
		local fill = Components.frame({
			Name = "Fill",
			Size = UDim2.new(math.clamp(props.Progress or 0, 0, 1), 0, 1, 0),
			BackgroundColor3 = props.FillColor or Theme.Color.Accent,
			CornerRadius = Theme.Corner.Pill,
			Parent = track,
		})
		Components.gradient(fill, props.FillColor or Theme.Color.Accent, props.FillColorB or Theme.Color.AccentAlt, 0)
		return track, fill
	end

	function Components.setProgress(fill: Frame, progress: number, tweenTime: number?)
		local goal = { Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0) }
		if tweenTime and tweenTime > 0 then
			TweenService:Create(fill, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad), goal):Play()
		else
			fill.Size = goal.Size
		end
	end

	function Components.clearChildren(instance: Instance, keepClassNames: { string }?)
		local keep: { [string]: boolean } = {}
		if keepClassNames then
			for _, n in keepClassNames do
				keep[n] = true
			end
		end
		for _, child in instance:GetChildren() do
			if not keep[child.ClassName] then
				child:Destroy()
			end
		end
	end
end

-- ============================================================================
-- SECTION: Remotes
-- ============================================================================
do
	local folder = ReplicatedStorage:WaitForChild("Remotes", 30)
	assert(folder, "Remotes folder never appeared — is ServerMain in ServerScriptService and running?")

	local EVENT_NAMES = { "PlaceAnomaly", "UnplaceAnomaly", "ToggleLock", "BuyBattlepassPremiumWithRobux", "Notify", "DataUpdated", "WeatherUpdated", "MarketUpdated" }
	local FUNCTION_NAMES = { "BuyMarketSlot", "BuyPlot", "BuyUpgrade", "DoReboot", "ClaimDailyReward", "ClaimBattlepassReward", "BuyBattlepassPremiumWithGlimmer" }

	remotes = {}
	for _, name in EVENT_NAMES do
		remotes[name] = folder:WaitForChild(name)
	end
	for _, name in FUNCTION_NAMES do
		remotes[name] = folder:WaitForChild(name)
	end
end

-- ============================================================================
-- SECTION: Root ScreenGui
-- ============================================================================
do
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GlitchRanchUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")
end

-- ============================================================================
-- SECTION: State
-- ============================================================================
do
	State = {
		Data = {
			Glimmer = 0,
			LifetimeGlimmer = 0,
			RebootCount = 0,
			UnlockedPlots = 4,
			IncomeLevel = 0,
			Anomalies = {},
			RanchLocked = true,
			LockExpiresAt = 0,
			Battlepass = { XP = 0, Level = 1, PremiumOwned = false, ClaimedFree = {}, ClaimedPremium = {} },
			DailyReward = { LastClaimUnix = 0, Streak = 0 },
		},
		Market = { slots = {}, refreshesAt = 0 },
		Weather = { id = "normal", name = "Clear Signal", icon = "📡", endsAt = 0, incomeMult = 1 },
	}

	local changedEvent = Instance.new("BindableEvent")
	State.Changed = changedEvent.Event

	function State.Set(snapshot)
		State.Data = snapshot
		changedEvent:Fire()
	end
end

-- ============================================================================
-- SECTION: Notifications — toast notifications stacked top-center.
-- ============================================================================
do
	local KIND_COLOR = {
		info = Theme.Color.AccentAlt,
		success = Theme.Color.Success,
		warning = Theme.Color.Warning,
		danger = Theme.Color.Danger,
	}
	local KIND_ICON = { info = "i", success = "✓", warning = "!", danger = "✕" }

	local container = Components.frame({
		Name = "ToastContainer",
		Size = UDim2.new(0, 360, 1, -20),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Corner = false,
		Parent = screenGui,
	})
	Components.listLayout(container, Enum.FillDirection.Vertical, 8, Enum.SortOrder.LayoutOrder)

	local order = 0

	notify = function(data)
		order += 1
		local kind = data.kind or "info"
		local color = KIND_COLOR[kind] or Theme.Color.AccentAlt

		local toast = Components.frame({
			Name = "Toast",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Color.SurfaceRaised,
			CornerRadius = Theme.Corner.Medium,
			LayoutOrder = order,
			Parent = container,
		})
		Components.stroke(toast, color, 1.5)
		Components.padding(toast, 12)

		local row = Components.frame({ Name = "Row", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Corner = false, Parent = toast })
		Components.listLayout(row, Enum.FillDirection.Horizontal, 10)

		local badge = Components.frame({ Name = "Badge", Size = UDim2.fromOffset(28, 28), BackgroundColor3 = color, CornerRadius = Theme.Corner.Pill, Parent = row })
		Components.label({ Text = KIND_ICON[kind] or "i", Font = Theme.Font.Heading, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = badge })

		local textCol = Components.frame({ Name = "Text", Size = UDim2.new(1, -38, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Corner = false, Parent = row })
		Components.listLayout(textCol, Enum.FillDirection.Vertical, 2)

		Components.label({ Text = data.title or "", Font = Theme.Font.Bold, TextSize = 15, Size = UDim2.new(1, 0, 0, 18), Parent = textCol })
		Components.label({
			Text = data.message or "",
			Font = Theme.Font.Body,
			TextSize = 13,
			TextColor3 = Theme.Color.TextSecondary,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = textCol,
		})

		toast.Position = UDim2.new(1.4, 0, 0, 0)
		toast.Parent = container
		TweenService:Create(toast, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()

		task.delay(4.2, function()
			if toast.Parent then
				local tw = TweenService:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1.4, 0, 0, 0) })
				tw:Play()
				tw.Completed:Connect(function()
					toast:Destroy()
				end)
			end
		end)
	end
end

-- ============================================================================
-- SECTION: HUD — persistent top-left readout: Glimmer, plots, weather timer.
-- ============================================================================
do
	local hud = Components.frame({
		Name = "HUD",
		Size = UDim2.fromOffset(280, 118),
		Position = UDim2.new(0, 14, 0, 14),
		BackgroundColor3 = Theme.Color.Surface,
		CornerRadius = Theme.Corner.Medium,
		Parent = screenGui,
	})
	Components.stroke(hud, Theme.Color.Border, 1)
	Components.padding(hud, 12)

	local glimmerLabel = Components.label({ Font = Theme.Font.Heading, TextSize = 22, TextColor3 = Theme.Color.Glimmer, Size = UDim2.new(1, 0, 0, 26), Parent = hud })
	local plotsLabel = Components.label({ Font = Theme.Font.Medium, TextSize = 13, TextColor3 = Theme.Color.TextSecondary, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 28), Parent = hud })
	local rankLabel = Components.label({ Font = Theme.Font.Medium, TextSize = 13, TextColor3 = Theme.Color.Gold, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 46), Parent = hud })

	local weatherRow = Components.frame({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 70), BackgroundColor3 = Theme.Color.SurfaceRaised, CornerRadius = Theme.Corner.Small, Parent = hud })
	local weatherLabel = Components.label({ Font = Theme.Font.Bold, TextSize = 13, Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 8, 0, 0), Parent = weatherRow })

	local function refresh()
		local data = State.Data
		glimmerLabel.Text = ("💠 $%d Glimmer"):format(math.floor(data.Glimmer or 0))
		local placed = 0
		for _, a in data.Anomalies or {} do
			if a.placedSlot then
				placed += 1
			end
		end
		plotsLabel.Text = ("🐾 %d / %d plots filled"):format(placed, data.UnlockedPlots or 0)
		rankLabel.Text = ("🏅 Reboot Rank %d"):format(data.RebootCount or 0)

		local w = State.Weather
		local remaining = math.max(0, (w.endsAt or 0) - os.time())
		weatherLabel.Text = ("%s %s — %ds"):format(w.icon or "📡", w.name or "Clear Signal", remaining)
		weatherLabel.TextColor3 = (w.incomeMult or 1) > 1 and Theme.Color.Success or ((w.incomeMult or 1) < 1 and Theme.Color.Danger or Theme.Color.TextPrimary)
	end

	refresh()
	State.Changed:Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)

	remotes.WeatherUpdated.OnClientEvent:Connect(function(payload)
		local previousId = State.Weather.id
		State.Weather = payload
		refresh()
		if payload.id ~= previousId and payload.id ~= "normal" then
			notify({ title = ("%s %s!"):format(payload.icon, payload.name), message = "Mutation odds and income are shifting — check your ranch!", kind = "info" })
		end
	end)

	remotes.MarketUpdated.OnClientEvent:Connect(function(payload)
		State.Market = payload
	end)
end

-- ============================================================================
-- SECTION: DailyRewardUI — 7-day streak modal, shown once per session when
-- a reward is available.
-- ============================================================================
do
	local overlay = Components.frame({
		Name = "DailyRewardOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Corner = false,
		Visible = false,
		ZIndex = 40,
		Parent = screenGui,
	})

	local card = Components.frame({
		Name = "Card",
		Size = UDim2.fromOffset(420, 260),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.Surface,
		CornerRadius = Theme.Corner.Large,
		ZIndex = 41,
		Parent = overlay,
	})
	Components.stroke(card, Theme.Color.Gold, 1.5)
	Components.padding(card, 20)

	Components.label({ Text = "Daily Signal Boost", Font = Theme.Font.Heading, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), ZIndex = 41, Parent = card })
	Components.label({
		Text = "Log in every day to keep your streak — and your Glimmer — growing.",
		Font = Theme.Font.Body,
		TextSize = 13,
		TextColor3 = Theme.Color.TextSecondary,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 28),
		ZIndex = 41,
		Parent = card,
	})

	local track = Components.frame({ Name = "Track", Size = UDim2.new(1, 0, 0, 90), Position = UDim2.new(0, 0, 0, 60), BackgroundTransparency = 1, Corner = false, ZIndex = 41, Parent = card })
	Components.listLayout(track, Enum.FillDirection.Horizontal, 6)

	local closeButton = Components.button({
		Text = "Claim & Continue",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.new(0, 0, 1, -44),
		BackgroundColor3 = Theme.Color.Gold,
		TextColor3 = Color3.new(0, 0, 0),
		ZIndex = 41,
		Parent = card,
	})

	local function render(currentStreak: number)
		Components.clearChildren(track)
		Components.listLayout(track, Enum.FillDirection.Horizontal, 6)
		for day = 1, 7 do
			local isToday = day == (currentStreak % 7) + 1
			local isPast = day <= currentStreak
			local cell = Components.frame({
				Name = "Day" .. day,
				Size = UDim2.new(0, 52, 1, 0),
				BackgroundColor3 = isToday and Theme.Color.Gold or (isPast and Theme.Color.SurfaceRaised or Theme.Color.Background),
				CornerRadius = Theme.Corner.Small,
				ZIndex = 41,
				Parent = track,
			})
			Components.label({
				Text = "D" .. day,
				Font = Theme.Font.Bold,
				TextSize = 12,
				TextColor3 = isToday and Color3.new(0, 0, 0) or Theme.Color.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 20),
				Position = UDim2.new(0, 0, 0, 10),
				ZIndex = 41,
				Parent = cell,
			})
			Components.label({
				Text = "$" .. Config.DAILY_REWARD_GLIMMER[day],
				Font = Theme.Font.Medium,
				TextSize = 12,
				TextColor3 = isToday and Color3.new(0, 0, 0) or Theme.Color.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.new(0, 0, 0, 34),
				ZIndex = 41,
				Parent = cell,
			})
		end
	end

	local function tryShow()
		local daily = State.Data.DailyReward
		local secondsSince = os.time() - (daily.LastClaimUnix or 0)
		local available = (daily.LastClaimUnix or 0) == 0 or secondsSince >= 20 * 3600
		if not available then
			return
		end
		render(daily.Streak)
		overlay.Visible = true
	end

	closeButton.MouseButton1Click:Connect(function()
		local ok, result = remotes.ClaimDailyReward:InvokeServer()
		if ok then
			render(result)
		end
		overlay.Visible = false
	end)

	dailyRewardUI = { TryShow = tryShow }
end

-- ============================================================================
-- SECTION: Lock button — a standalone always-visible control since locking
-- is the single most time-sensitive action in the game.
-- ============================================================================
do
	local lockButton = Components.button({
		Name = "LockButton",
		Size = UDim2.fromOffset(280, 40),
		Position = UDim2.new(0, 14, 0, 140),
		BackgroundColor3 = Theme.Color.AccentAlt,
		TextSize = 14,
		Parent = screenGui,
	})

	local function refresh()
		local data = State.Data
		if data.RanchLocked then
			local remaining = math.max(0, (data.LockExpiresAt or 0) - os.time())
			lockButton.Text = ("🔒 Locked — %ds left"):format(remaining)
			lockButton.BackgroundColor3 = Theme.Color.SurfaceRaised
		else
			lockButton.Text = "🔓 UNLOCKED — Tap to Lock Ranch"
			lockButton.BackgroundColor3 = Theme.Color.Danger
		end
	end

	lockButton.MouseButton1Click:Connect(function()
		remotes.ToggleLock:FireServer()
	end)

	refresh()
	State.Changed:Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

-- ============================================================================
-- SECTION: MarketTab — the rotating 4-slot Anomaly shop.
-- ============================================================================
do
	MarketTab = {}

	function MarketTab.Build(parent: Instance, state, notifyFn)
		local header = Components.label({
			Text = "New stock rotates in periodically. Prices climb the more a slot gets bought before it refreshes.",
			Font = Theme.Font.Body,
			TextSize = 12,
			TextColor3 = Theme.Color.TextSecondary,
			Size = UDim2.new(1, 0, 0, 32),
			Parent = parent,
		})

		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "MarketScroller"
		scroller.BackgroundTransparency = 1
		scroller.Size = UDim2.new(1, 0, 1, -36)
		scroller.Position = UDim2.new(0, 0, 0, 36)
		scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.ScrollBarThickness = 4
		scroller.ScrollBarImageColor3 = Theme.Color.Border
		scroller.Parent = parent

		local function refresh()
			Components.clearChildren(scroller, {})
			Components.gridLayout(scroller, UDim2.fromOffset(160, 190), 10)

			local market = state.Market
			for i = 1, Config.MARKET_SLOTS do
				local slotData = market.slots[i]
				local card = Components.frame({
					BackgroundColor3 = Theme.Color.Surface,
					CornerRadius = Theme.Corner.Medium,
					LayoutOrder = i,
					Parent = scroller,
				})
				Components.stroke(card, Theme.Color.Border, 1)
				Components.padding(card, 8)

				if not slotData then
					Components.label({ Text = "...", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
					continue
				end

				local def = AnomalyData.ById[slotData.defId]
				local swatch = Components.frame({ Size = UDim2.new(1, 0, 0, 80), BackgroundColor3 = def.color, CornerRadius = Theme.Corner.Small, Parent = card })
				Components.label({ Text = def.rarity, Font = Theme.Font.Heading, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = swatch })

				Components.label({ Text = def.name, Font = Theme.Font.Bold, TextSize = 13, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, 86), TextWrapped = true, Parent = card })
				Components.label({
					Text = ("%.1f Glimmer/s"):format(def.income),
					Font = Theme.Font.Body,
					TextSize = 11,
					TextColor3 = Theme.Color.TextMuted,
					Size = UDim2.new(1, 0, 0, 14),
					Position = UDim2.new(0, 0, 0, 118),
					Parent = card,
				})

				Components.button({
					Text = ("Buy $%d"):format(slotData.price),
					Size = UDim2.new(1, 0, 0, 30),
					Position = UDim2.new(0, 0, 1, -30),
					BackgroundColor3 = Theme.Color.Accent,
					Parent = card,
					OnClick = function()
						local ok, message = remotes.BuyMarketSlot:InvokeServer(i)
						if not ok then
							notifyFn({ title = "Can't buy that", message = message, kind = "warning" })
						end
					end,
				})
			end

			Components.label({
				Text = ("Market refreshes in %ds"):format(math.max(0, market.refreshesAt - os.time())),
				Font = Theme.Font.Body,
				TextSize = 11,
				TextColor3 = Theme.Color.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 20),
				LayoutOrder = 99,
				Parent = scroller,
			})
		end

		refresh()
		return refresh
	end
end

-- ============================================================================
-- SECTION: BattlepassTab — "Signal Pass" level progress and reward rows.
-- ============================================================================
do
	BattlepassTab = {}

	local function rewardText(reward)
		if reward.kind == "Glimmer" then
			return ("$%d Glimmer"):format(reward.amount)
		elseif reward.kind == "Anomaly" then
			local item = AnomalyData.ById[reward.itemId]
			return item and (item.name .. " (Golden)") or "Exclusive Anomaly"
		end
		return "?"
	end

	function BattlepassTab.Build(parent: Instance, state, notifyFn)
		local header = Components.frame({ Name = "Header", Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, Corner = false, Parent = parent })
		local levelLabel = Components.label({ Font = Theme.Font.Heading, TextSize = 18, Size = UDim2.new(1, 0, 0, 20), Parent = header })
		local xpTrack, xpFill = Components.progressBar({ Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 0, 26), FillColor = Theme.Color.Gold, FillColorB = Theme.Color.Accent, Parent = header })

		local unlockButton = Components.button({
			Text = ("Unlock Premium — $%d Glimmer"):format(Config.BATTLEPASS_PREMIUM_COST_GLIMMER),
			Size = UDim2.new(1, 0, 0, 32),
			Position = UDim2.new(0, 0, 0, 42),
			BackgroundColor3 = Theme.Color.Gold,
			TextColor3 = Color3.new(0, 0, 0),
			TextSize = 13,
			Parent = header,
		})
		local unlockRobuxButton = Components.button({
			Text = "Unlock Premium with Robux",
			Size = UDim2.new(1, 0, 0, 32),
			Position = UDim2.new(0, 0, 0, 42),
			BackgroundColor3 = Theme.Color.Accent,
			TextSize = 13,
			Visible = false,
			Parent = header,
		})

		unlockButton.MouseButton1Click:Connect(function()
			local ok, message = remotes.BuyBattlepassPremiumWithGlimmer:InvokeServer()
			notifyFn({ title = ok and "Premium Unlocked!" or "Couldn't unlock", message = message, kind = ok and "success" or "warning" })
		end)
		unlockRobuxButton.MouseButton1Click:Connect(function()
			remotes.BuyBattlepassPremiumWithRobux:FireServer()
		end)

		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "PassScroller"
		scroller.BackgroundTransparency = 1
		scroller.Size = UDim2.new(1, 0, 1, -78)
		scroller.Position = UDim2.new(0, 0, 0, 78)
		scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.ScrollBarThickness = 4
		scroller.ScrollBarImageColor3 = Theme.Color.Border
		scroller.Parent = parent
		Components.listLayout(scroller, Enum.FillDirection.Vertical, 6)

		local function refresh()
			local bp = state.Data.Battlepass
			levelLabel.Text = ("Signal Pass — Level %d / %d"):format(bp.Level, Config.BATTLEPASS_MAX_LEVEL)
			local xpIntoLevel = bp.XP % Config.BATTLEPASS_XP_PER_LEVEL
			Components.setProgress(xpFill, xpIntoLevel / Config.BATTLEPASS_XP_PER_LEVEL, 0.25)

			unlockButton.Visible = not bp.PremiumOwned
			unlockRobuxButton.Visible = not bp.PremiumOwned

			Components.clearChildren(scroller, {})
			Components.listLayout(scroller, Enum.FillDirection.Vertical, 6)

			for level = 1, Config.BATTLEPASS_MAX_LEVEL do
				local rewardRow = BattlepassData.Rewards[level]
				local unlocked = level <= bp.Level

				local row = Components.frame({
					Size = UDim2.new(1, 0, 0, 56),
					BackgroundColor3 = unlocked and Theme.Color.Surface or Theme.Color.Background,
					CornerRadius = Theme.Corner.Small,
					LayoutOrder = level,
					Parent = scroller,
				})
				Components.stroke(row, unlocked and Theme.Color.Border or Theme.Color.Background, 1)
				Components.padding(row, 8)

				Components.label({
					Text = "Lv " .. level,
					Font = Theme.Font.Heading,
					TextSize = 13,
					Size = UDim2.new(0, 48, 1, 0),
					TextColor3 = unlocked and Theme.Color.TextPrimary or Theme.Color.TextMuted,
					Parent = row,
				})

				local freeClaimed = bp.ClaimedFree[tostring(level)]
				local freeCell = Components.frame({
					Size = UDim2.new(0.5, -30, 1, 0),
					Position = UDim2.new(0, 52, 0, 0),
					BackgroundColor3 = Theme.Color.SurfaceRaised,
					CornerRadius = Theme.Corner.Small,
					Parent = row,
				})
				Components.label({ Text = "FREE: " .. rewardText(rewardRow.free), Font = Theme.Font.Body, TextSize = 11, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0, 4, 0, 2), Parent = freeCell })
				Components.button({
					Text = freeClaimed and "Claimed" or (unlocked and "Claim" or "Locked"),
					Size = UDim2.new(1, -8, 0, 20),
					Position = UDim2.new(0, 4, 0, 22),
					BackgroundColor3 = freeClaimed and Theme.Color.SurfaceRaised or (unlocked and Theme.Color.Success or Theme.Color.Background),
					TextSize = 11,
					Parent = freeCell,
					OnClick = function()
						if unlocked and not freeClaimed then
							local ok, message = remotes.ClaimBattlepassReward:InvokeServer(level, "free")
							if not ok then
								notifyFn({ title = "Can't claim", message = message, kind = "warning" })
							end
						end
					end,
				})

				local premiumClaimed = bp.ClaimedPremium[tostring(level)]
				local premiumCell = Components.frame({
					Size = UDim2.new(0.5, -30, 1, 0),
					Position = UDim2.new(0.5, 22, 0, 0),
					BackgroundColor3 = Theme.Color.SurfaceRaised,
					CornerRadius = Theme.Corner.Small,
					Parent = row,
				})
				Components.stroke(premiumCell, Theme.Color.Gold, 1)
				Components.label({ Text = "PREMIUM: " .. rewardText(rewardRow.premium), Font = Theme.Font.Body, TextSize = 11, TextColor3 = Theme.Color.Gold, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0, 4, 0, 2), Parent = premiumCell })
				Components.button({
					Text = premiumClaimed and "Claimed" or (unlocked and bp.PremiumOwned and "Claim" or (bp.PremiumOwned and "Locked" or "Need Premium")),
					Size = UDim2.new(1, -8, 0, 20),
					Position = UDim2.new(0, 4, 0, 22),
					BackgroundColor3 = premiumClaimed and Theme.Color.SurfaceRaised or (unlocked and bp.PremiumOwned and Theme.Color.Gold or Theme.Color.Background),
					TextColor3 = (unlocked and bp.PremiumOwned and not premiumClaimed) and Color3.new(0, 0, 0) or Theme.Color.TextPrimary,
					TextSize = 11,
					Parent = premiumCell,
					OnClick = function()
						if unlocked and bp.PremiumOwned and not premiumClaimed then
							local ok, message = remotes.ClaimBattlepassReward:InvokeServer(level, "premium")
							if not ok then
								notifyFn({ title = "Can't claim", message = message, kind = "warning" })
							end
						end
					end,
				})
			end
		end

		refresh()
		return refresh
	end
end

-- ============================================================================
-- SECTION: InventoryTab — every Anomaly you own. Place onto your ranch (to
-- earn income and become stealable) or pull back into safekeeping.
-- ============================================================================
do
	InventoryTab = {}

	function InventoryTab.Build(parent: Instance, state, notifyFn)
		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "InventoryScroller"
		scroller.BackgroundTransparency = 1
		scroller.Size = UDim2.fromScale(1, 1)
		scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.ScrollBarThickness = 4
		scroller.ScrollBarImageColor3 = Theme.Color.Border
		scroller.Parent = parent

		local function refresh()
			Components.clearChildren(scroller, {})
			Components.gridLayout(scroller, UDim2.fromOffset(160, 190), 10)

			local anomalies = state.Data.Anomalies or {}
			local ids = {}
			for animId in anomalies do
				table.insert(ids, animId)
			end
			table.sort(ids)

			if #ids == 0 then
				Components.label({
					Text = "No Anomalies yet. Buy one from the Market tab to get started.",
					Font = Theme.Font.Body,
					TextSize = 13,
					TextColor3 = Theme.Color.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 60),
					Parent = scroller,
				})
				return
			end

			for i, animId in ids do
				local anomaly = anomalies[animId]
				local def = AnomalyData.ById[anomaly.defId]
				if not def then
					continue
				end
				local grade = AnomalyData.GradeById[anomaly.grade] or AnomalyData.Grades[1]
				local income = AnomalyData.GetEffectiveIncome(anomaly.defId, anomaly.grade)

				local card = Components.frame({ BackgroundColor3 = Theme.Color.Surface, CornerRadius = Theme.Corner.Medium, LayoutOrder = i, Parent = scroller })
				Components.stroke(card, anomaly.placedSlot and Theme.Color.Success or Theme.Color.Border, anomaly.placedSlot and 2 or 1)
				Components.padding(card, 8)

				local swatch = Components.frame({ Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = def.color, CornerRadius = Theme.Corner.Small, Parent = card })
				Components.label({ Text = def.rarity, Font = Theme.Font.Heading, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = swatch })

				Components.label({ Text = def.name, Font = Theme.Font.Bold, TextSize = 12, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 70), TextWrapped = true, Parent = card })
				Components.label({
					Text = ("%s · %.1f/s"):format(grade.name, income),
					Font = Theme.Font.Body,
					TextSize = 11,
					TextColor3 = grade.color,
					Size = UDim2.new(1, 0, 0, 14),
					Position = UDim2.new(0, 0, 0, 100),
					Parent = card,
				})

				Components.button({
					Text = anomaly.placedSlot and "Recall" or "Place on Ranch",
					Size = UDim2.new(1, 0, 0, 28),
					Position = UDim2.new(0, 0, 1, -28),
					BackgroundColor3 = anomaly.placedSlot and Theme.Color.SurfaceRaised or Theme.Color.Accent,
					TextSize = 12,
					Parent = card,
					OnClick = function()
						if anomaly.placedSlot then
							remotes.UnplaceAnomaly:FireServer(animId)
						else
							remotes.PlaceAnomaly:FireServer(animId)
						end
					end,
				})
			end
		end

		refresh()
		return refresh
	end
end

-- ============================================================================
-- SECTION: UpgradesTab — buy extra ranch plots and permanent income levels.
-- ============================================================================
do
	UpgradesTab = {}

	local function plotCost(currentPlots: number): number
		return math.floor(Config.PLOT_COST_BASE * (Config.PLOT_COST_GROWTH ^ (currentPlots - Config.STARTING_PLOTS)))
	end

	local function incomeUpgradeCost(level: number): number
		return math.floor(Config.INCOME_UPGRADE_BASE_COST * (Config.INCOME_UPGRADE_COST_GROWTH ^ level))
	end

	function UpgradesTab.Build(parent: Instance, state, notifyFn)
		local plotCard = Components.frame({ Size = UDim2.new(1, 0, 0, 130), BackgroundColor3 = Theme.Color.Surface, CornerRadius = Theme.Corner.Medium, Parent = parent })
		Components.stroke(plotCard, Theme.Color.Border, 1)
		Components.padding(plotCard, 12)
		Components.label({ Text = "🐾 Extra Ranch Plot", Font = Theme.Font.Heading, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), Parent = plotCard })
		local plotDesc = Components.label({ Font = Theme.Font.Body, TextSize = 12, TextColor3 = Theme.Color.TextSecondary, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 24), Parent = plotCard })
		local plotButton = Components.button({ Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 1, -36), BackgroundColor3 = Theme.Color.Accent, Parent = plotCard })

		local incomeCard = Components.frame({ Size = UDim2.new(1, 0, 0, 130), Position = UDim2.new(0, 0, 0, 142), BackgroundColor3 = Theme.Color.Surface, CornerRadius = Theme.Corner.Medium, Parent = parent })
		Components.stroke(incomeCard, Theme.Color.Border, 1)
		Components.padding(incomeCard, 12)
		Components.label({ Text = "⚡ Income Boost", Font = Theme.Font.Heading, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), Parent = incomeCard })
		local incomeDesc = Components.label({ Font = Theme.Font.Body, TextSize = 12, TextColor3 = Theme.Color.TextSecondary, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 24), Parent = incomeCard })
		local incomeButton = Components.button({ Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 1, -36), BackgroundColor3 = Theme.Color.Gold, TextColor3 = Color3.new(0, 0, 0), Parent = incomeCard })

		plotButton.MouseButton1Click:Connect(function()
			local ok, message = remotes.BuyPlot:InvokeServer()
			if not ok then
				notifyFn({ title = "Can't buy that", message = message, kind = "warning" })
			end
		end)
		incomeButton.MouseButton1Click:Connect(function()
			local ok, message = remotes.BuyUpgrade:InvokeServer("income")
			if not ok then
				notifyFn({ title = "Can't buy that", message = message, kind = "warning" })
			end
		end)

		local function refresh()
			local data = state.Data
			if data.UnlockedPlots >= Config.MAX_PLOTS then
				plotDesc.Text = "Maxed out! You have every available plot."
				plotButton.Text = "MAXED"
				plotButton.BackgroundColor3 = Theme.Color.SurfaceRaised
			else
				local cost = plotCost(data.UnlockedPlots)
				plotDesc.Text = ("You have %d / %d plots. Buy another to place more Anomalies."):format(data.UnlockedPlots, Config.MAX_PLOTS)
				plotButton.Text = ("Buy Plot — $%d"):format(cost)
				plotButton.BackgroundColor3 = Theme.Color.Accent
			end

			if data.IncomeLevel >= Config.INCOME_UPGRADE_MAX_LEVEL then
				incomeDesc.Text = "Maxed out! Income is as high as it goes (without a Reboot)."
				incomeButton.Text = "MAXED"
				incomeButton.BackgroundColor3 = Theme.Color.SurfaceRaised
			else
				local cost = incomeUpgradeCost(data.IncomeLevel)
				local currentBonus = math.floor(data.IncomeLevel * Config.INCOME_UPGRADE_BONUS_PER_LEVEL * 100)
				incomeDesc.Text = ("Level %d/%d — currently +%d%% income."):format(data.IncomeLevel, Config.INCOME_UPGRADE_MAX_LEVEL, currentBonus)
				incomeButton.Text = ("Upgrade — $%d"):format(cost)
				incomeButton.BackgroundColor3 = Theme.Color.Gold
			end
		end

		refresh()
		return refresh
	end
end

-- ============================================================================
-- SECTION: PrestigeTab — "Reboot": reset for a permanent income multiplier.
-- ============================================================================
do
	PrestigeTab = {}

	local function rebootThreshold(rebootCount: number): number
		return math.floor(Config.PRESTIGE_BASE_THRESHOLD * (Config.PRESTIGE_THRESHOLD_GROWTH ^ rebootCount))
	end

	function PrestigeTab.Build(parent: Instance, state, notifyFn)
		Components.label({ Text = "🔁 Reboot", Font = Theme.Font.Heading, TextSize = 20, Size = UDim2.new(1, 0, 0, 26), Parent = parent })
		Components.label({
			Text = "Resets your Glimmer and upgrades in exchange for a PERMANENT income multiplier. Your Anomalies and their mutations are kept.",
			Font = Theme.Font.Body,
			TextSize = 12,
			TextColor3 = Theme.Color.TextSecondary,
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.new(0, 0, 0, 28),
			Parent = parent,
		})

		local rankLabel = Components.label({ Font = Theme.Font.Bold, TextSize = 15, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 82), Parent = parent })
		local track, fill = Components.progressBar({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 106), FillColor = Theme.Color.Gold, FillColorB = Theme.Color.Accent, Parent = parent })
		local progressLabel = Components.label({
			Font = Theme.Font.Body,
			TextSize = 12,
			TextColor3 = Theme.Color.TextSecondary,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.new(0, 0, 0, 124),
			Parent = parent,
		})

		local rebootButton = Components.button({
			Size = UDim2.new(1, 0, 0, 46),
			Position = UDim2.new(0, 0, 0, 156),
			BackgroundColor3 = Theme.Color.Danger,
			Text = "REBOOT",
			Parent = parent,
		})

		local armed = false
		rebootButton.MouseButton1Click:Connect(function()
			if not armed then
				armed = true
				rebootButton.Text = "Tap again to confirm"
				task.delay(3, function()
					if armed then
						armed = false
						rebootButton.Text = "REBOOT"
					end
				end)
				return
			end
			armed = false
			local ok, message = remotes.DoReboot:InvokeServer()
			notifyFn({ title = ok and "Rebooted!" or "Can't Reboot yet", message = message, kind = ok and "success" or "warning" })
		end)

		local function refresh()
			local data = state.Data
			local threshold = rebootThreshold(data.RebootCount)
			local progress = math.clamp((data.LifetimeGlimmer or 0) / threshold, 0, 1)
			rankLabel.Text = ("Current Rank: %d (+%d%% permanent income)"):format(data.RebootCount, math.floor(data.RebootCount * Config.PRESTIGE_BONUS_PER_REBOOT * 100))
			Components.setProgress(fill, progress, 0.25)
			progressLabel.Text = ("$%d / $%d lifetime Glimmer"):format(math.floor(data.LifetimeGlimmer or 0), threshold)
			rebootButton.BackgroundColor3 = progress >= 1 and Theme.Color.Danger or Theme.Color.SurfaceRaised
		end

		refresh()
		return refresh
	end
end

-- ============================================================================
-- SECTION: RanchMenu — the toggleable control panel shell: top bar (Glimmer),
-- content area, bottom nav across the 5 tabs above.
-- ============================================================================
do
	local TABS = {
		{ id = "Market", label = "🛒 Market", module = MarketTab },
		{ id = "Inventory", label = "🐾 Ranch", module = InventoryTab },
		{ id = "Upgrades", label = "⚙️ Upgrade", module = UpgradesTab },
		{ id = "Prestige", label = "🔁 Reboot", module = PrestigeTab },
		{ id = "Pass", label = "🎟️ Pass", module = BattlepassTab },
	}

	local toggleButton = Components.button({
		Name = "MenuToggle",
		Text = "📋",
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.new(1, -84, 1, -84),
		BackgroundColor3 = Theme.Color.Accent,
		CornerRadius = Theme.Corner.Pill,
		TextSize = 28,
		ZIndex = 10,
		Parent = screenGui,
	})

	local menuFrame = Components.frame({
		Name = "MenuFrame",
		Size = UDim2.fromOffset(420, 620),
		Position = UDim2.new(1, -84, 1, -84),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Theme.Color.Background,
		CornerRadius = Theme.Corner.Large,
		Visible = false,
		ZIndex = 5,
		Parent = screenGui,
	})
	Components.stroke(menuFrame, Theme.Color.Border, 2)

	local topBar = Components.frame({ Name = "TopBar", Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Theme.Color.Surface, CornerRadius = Theme.Corner.Large, ZIndex = 6, Parent = menuFrame })
	Components.padding(topBar, 12)
	Components.label({ Text = "GLITCH RANCH", Font = Theme.Font.Heading, TextSize = 16, Size = UDim2.new(0, 180, 1, 0), TextColor3 = Theme.Color.Accent, ZIndex = 6, Parent = topBar })
	local glimmerLabel = Components.label({
		Font = Theme.Font.Bold,
		TextSize = 15,
		TextColor3 = Theme.Color.Glimmer,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 150, 1, 0),
		Position = UDim2.new(1, -190, 0, 0),
		ZIndex = 6,
		Parent = topBar,
	})
	local closeButton = Components.button({
		Text = "✕",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -28, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		CornerRadius = Theme.Corner.Pill,
		TextSize = 14,
		ZIndex = 6,
		Parent = topBar,
	})

	local content = Components.frame({
		Name = "Content",
		Size = UDim2.new(1, -16, 1, -124),
		Position = UDim2.new(0, 8, 0, 58),
		BackgroundTransparency = 1,
		Corner = false,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = menuFrame,
	})

	local nav = Components.frame({ Name = "BottomNav", Size = UDim2.new(1, 0, 0, 58), Position = UDim2.new(0, 0, 1, -58), BackgroundColor3 = Theme.Color.Surface, CornerRadius = Theme.Corner.Large, ZIndex = 6, Parent = menuFrame })
	Components.listLayout(nav, Enum.FillDirection.Horizontal, 0)
	local navLayout = nav:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local tabFrames = {}
	local tabRefreshers = {}
	local navButtons = {}
	local activeTabId = "Market"

	local function setActiveTab(tabId: string)
		activeTabId = tabId
		for id, frame in tabFrames do
			frame.Visible = id == tabId
		end
		for id, btn in navButtons do
			btn.BackgroundColor3 = id == tabId and Theme.Color.SurfaceRaised or Theme.Color.Surface
			btn.TextColor3 = id == tabId and Theme.Color.Accent or Theme.Color.TextSecondary
		end
		local refresher = tabRefreshers[tabId]
		if refresher then
			refresher()
		end
	end

	for _, tab in TABS do
		local tabFrame = Components.frame({ Name = tab.id .. "Panel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Corner = false, Visible = false, Parent = content })
		tabFrames[tab.id] = tabFrame

		local navButton = Components.button({
			Text = tab.label,
			Size = UDim2.new(1 / #TABS, 0, 1, 0),
			BackgroundColor3 = Theme.Color.Surface,
			TextColor3 = Theme.Color.TextSecondary,
			TextSize = 12,
			CornerRadius = Theme.Corner.Small,
			ZIndex = 6,
			Parent = nav,
			OnClick = function()
				setActiveTab(tab.id)
			end,
		})
		navButtons[tab.id] = navButton
		tabRefreshers[tab.id] = tab.module.Build(tabFrame, State, notify)
	end

	setActiveTab("Market")

	local function refreshTopBar()
		glimmerLabel.Text = ("$%d"):format(math.floor(State.Data.Glimmer or 0))
	end
	refreshTopBar()

	local function refreshAll()
		refreshTopBar()
		local refresher = tabRefreshers[activeTabId]
		if refresher then
			refresher()
		end
	end

	State.Changed:Connect(refreshAll)

	task.spawn(function()
		while true do
			task.wait(1)
			if menuFrame.Visible then
				local refresher = tabRefreshers[activeTabId]
				if refresher then
					refresher()
				end
				refreshTopBar()
			end
		end
	end)

	local function toggleMenu()
		menuFrame.Visible = not menuFrame.Visible
		if menuFrame.Visible then
			refreshAll()
		end
	end

	toggleButton.MouseButton1Click:Connect(toggleMenu)
	closeButton.MouseButton1Click:Connect(toggleMenu)
end

-- ============================================================================
-- SECTION: Data stream — receives the server's data snapshots and
-- notifications.
-- ============================================================================
do
	local hasLoadedOnce = false
	remotes.DataUpdated.OnClientEvent:Connect(function(snapshot)
		State.Set(snapshot)
		if not hasLoadedOnce then
			hasLoadedOnce = true
			task.wait(1)
			dailyRewardUI.TryShow()
		end
	end)

	remotes.Notify.OnClientEvent:Connect(function(data)
		notify(data)
	end)
end
