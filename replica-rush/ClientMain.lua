-- ============================================================================
-- REPLICA RUSH — CLIENT
-- Paste this ENTIRE file into a single LocalScript inside
-- StarterPlayer > StarterPlayerScripts.
-- (The whole phone UI — shop, orders, closet, market, battlepass, toast
-- notifications, unboxing, daily reward — lives in this one script.)
--
-- NOTE: Config and ItemData below are duplicated from the server script on
-- purpose (client code can't reach server-only modules). If you tune prices
-- or any other number, change it in BOTH ServerMain and ClientMain.
-- ============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

--== Forward-declared shared tables, filled in by the sections below ==--
local Theme
local Components
local Config
local ItemData
local BattlepassData
local remotes
local State
local notify -- function(data) -> shows a toast
local screenGui

local ShopTab
local OrdersTab
local InventoryTab
local MarketTab
local BattlepassTab

local unboxing -- { Open = fn, Close = fn }
local sellModal -- { Open = fn }
local dailyRewardUI -- { TryShow = fn }

-- ============================================================================
-- SECTION: Config — must match ServerMain's Config exactly for prices/labels
-- to make sense (the server is always the source of truth for money).
-- ============================================================================
do
	Config = {}

	Config.STARTING_CASH = 100
	Config.STARTING_COINS = 0

	Config.CUSTOMS_SEIZURE_CHANCE = 0.15
	Config.SHIPPING_TIME_MIN = 75
	Config.SHIPPING_TIME_MAX = 210
	Config.SEIZURE_CONSOLATION_COINS = 5

	Config.RESELL_FEE_PERCENT = 0.10
	Config.QUICK_SELL_PERCENT = 0.55
	Config.MIN_LISTING_PERCENT = 0.4
	Config.MAX_LISTING_PERCENT = 2.5
	Config.LISTING_CHECK_INTERVAL = 20

	Config.XP_PER_SALE = 8
	Config.XP_PER_WEAR = 4
	Config.XP_PER_OPEN = 3

	Config.BATTLEPASS_XP_PER_LEVEL = 120
	Config.BATTLEPASS_MAX_LEVEL = 40
	Config.BATTLEPASS_PREMIUM_COST_COINS = 1800

	Config.DAILY_REWARD_CASH = { 25, 25, 50, 50, 75, 75, 150 }
	Config.DAILY_REWARD_COINS = { 10, 15, 20, 25, 35, 45, 100 }
	Config.DAILY_STREAK_RESET_HOURS = 48
end

-- ============================================================================
-- SECTION: ItemData — must match ServerMain's ItemData exactly (ids, prices,
-- categories). This copy is what the shop/closet/market UI reads to render.
-- ============================================================================
do
	ItemData = {}

	ItemData.QCGrades = {
		{ id = "bootleg", name = "Bootleg", weight = 32, valueMult = 0.4, color = Color3.fromRGB(150, 150, 150) },
		{ id = "gradeA", name = "Grade A", weight = 40, valueMult = 0.85, color = Color3.fromRGB(120, 200, 255) },
		{ id = "aaa", name = "AAA Replica", weight = 21, valueMult = 1.35, color = Color3.fromRGB(180, 120, 255) },
		{ id = "museum", name = "Museum 1:1", weight = 7, valueMult = 2.25, color = Color3.fromRGB(255, 200, 60) },
	}

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
-- SECTION: BattlepassData — must match ServerMain's BattlepassData (used
-- only to render reward labels; the server decides what's actually granted).
-- ============================================================================
do
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
-- SECTION: Theme — shared design tokens so every screen looks like one app.
-- ============================================================================
do
	Theme = {}

	Theme.Color = {
		Background = Color3.fromRGB(16, 16, 22),
		Surface = Color3.fromRGB(24, 24, 33),
		SurfaceRaised = Color3.fromRGB(32, 32, 44),
		Border = Color3.fromRGB(48, 48, 64),

		TextPrimary = Color3.fromRGB(245, 245, 250),
		TextSecondary = Color3.fromRGB(160, 160, 178),
		TextMuted = Color3.fromRGB(110, 110, 128),

		Accent = Color3.fromRGB(255, 62, 165), -- hype pink
		AccentAlt = Color3.fromRGB(62, 193, 255), -- electric blue
		Gold = Color3.fromRGB(255, 210, 70),

		Success = Color3.fromRGB(70, 210, 130),
		Warning = Color3.fromRGB(255, 180, 60),
		Danger = Color3.fromRGB(255, 90, 90),

		Cash = Color3.fromRGB(120, 230, 150),
		Coins = Color3.fromRGB(255, 210, 70),
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
-- SECTION: Components — small reusable UI builder functions so every
-- button/card/bar looks consistent across the app.
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

	-- A horizontal fill bar (progress / shipping timer / xp bar).
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
-- SECTION: Remotes — waits for the RemoteEvents/Functions the server creates.
-- ============================================================================
do
	local folder = ReplicatedStorage:WaitForChild("Remotes", 30)
	assert(folder, "Remotes folder never appeared — is ServerMain in ServerScriptService and running?")

	local EVENT_NAMES = {
		"WearItem",
		"CancelListing",
		"BuyBattlepassPremiumWithRobux",
		"ClaimDailyReward",
		"Notify",
		"DataUpdated",
		"OrderDelivered",
	}
	local FUNCTION_NAMES = {
		"BuyItem",
		"OpenPackage",
		"ListForSale",
		"QuickSell",
		"ClaimBattlepassReward",
		"BuyBattlepassPremiumWithCoins",
	}

	remotes = {}
	for _, name in EVENT_NAMES do
		remotes[name] = folder:WaitForChild(name)
	end
	for _, name in FUNCTION_NAMES do
		remotes[name] = folder:WaitForChild(name)
	end
end

-- ============================================================================
-- SECTION: Root ScreenGui — every UI piece below mounts into this.
-- ============================================================================
do
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ReplicaRushUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")
end

-- ============================================================================
-- SECTION: State — holds the latest data snapshot pushed by the server and
-- lets UI modules subscribe to changes.
-- ============================================================================
do
	State = {
		Data = {
			Cash = 0,
			Coins = 0,
			Orders = {},
			Inventory = {},
			Listings = {},
			Battlepass = { XP = 0, Level = 1, PremiumOwned = false, ClaimedFree = {}, ClaimedPremium = {} },
			DailyReward = { LastClaimUnix = 0, Streak = 0 },
		},
	}

	local changedEvent = Instance.new("BindableEvent")
	State.Changed = changedEvent.Event

	function State.Set(snapshot)
		State.Data = snapshot
		changedEvent:Fire(snapshot)
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
	local KIND_ICON = {
		info = "i",
		success = "✓",
		warning = "!",
		danger = "✕",
	}

	local container = Components.frame({
		Name = "ToastContainer",
		Size = UDim2.new(0, 340, 1, -20),
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
-- SECTION: Unboxing — the "haul" screen: shakes a box, then reveals the
-- item + its QC grade, with Wear / Sell / Quick Sell / Keep actions.
-- ============================================================================
do
	local overlay = Components.frame({
		Name = "UnboxingOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Corner = false,
		Visible = false,
		ZIndex = 50,
		Parent = screenGui,
	})

	local card = Components.frame({
		Name = "Card",
		Size = UDim2.fromOffset(360, 420),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.Surface,
		CornerRadius = Theme.Corner.Large,
		ZIndex = 51,
		Parent = overlay,
	})
	Components.stroke(card, Theme.Color.Border, 1)
	Components.padding(card, 20)

	local title = Components.label({
		Text = "Opening your haul...",
		Font = Theme.Font.Heading,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = card,
	})

	local box = Components.frame({
		Name = "Box",
		Size = UDim2.fromOffset(160, 160),
		Position = UDim2.new(0.5, 0, 0, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		CornerRadius = Theme.Corner.Medium,
		ZIndex = 52,
		Parent = card,
	})
	Components.label({ Text = "📦", TextSize = 64, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, Parent = box })

	local gradeLabel = Components.label({
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 230),
		Visible = false,
		ZIndex = 52,
		Parent = card,
	})

	local itemLabel = Components.label({
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = 16,
		TextColor3 = Theme.Color.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 258),
		Visible = false,
		ZIndex = 52,
		Parent = card,
	})

	local buttonRow = Components.frame({
		Name = "Buttons",
		Size = UDim2.new(1, 0, 0, 110),
		Position = UDim2.new(0, 0, 1, -110),
		BackgroundTransparency = 1,
		Corner = false,
		Visible = false,
		ZIndex = 52,
		Parent = card,
	})
	Components.listLayout(buttonRow, Enum.FillDirection.Vertical, 8)

	local currentInvId: string? = nil

	local function close()
		overlay.Visible = false
	end

	local function makeActionButton(text, color, order, callback)
		Components.button({
			Text = text,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = color,
			LayoutOrder = order,
			ZIndex = 52,
			Parent = buttonRow,
			OnClick = callback,
		})
	end

	makeActionButton("Wear It", Theme.Color.Accent, 1, function()
		if currentInvId then
			remotes.WearItem:FireServer(currentInvId)
			close()
		end
	end)
	makeActionButton("Quick Sell", Theme.Color.Warning, 2, function()
		if currentInvId then
			remotes.QuickSell:InvokeServer(currentInvId)
			close()
		end
	end)
	makeActionButton("Keep in Closet", Theme.Color.SurfaceRaised, 3, function()
		close()
	end)

	local function open(orderId: string)
		overlay.Visible = true
		title.Text = "Opening your haul..."
		gradeLabel.Visible = false
		itemLabel.Visible = false
		buttonRow.Visible = false
		box.Rotation = 0
		box.Size = UDim2.fromOffset(160, 160)

		-- shake
		for _ = 1, 6 do
			TweenService:Create(box, TweenInfo.new(0.06), { Rotation = math.random(-8, 8) }):Play()
			task.wait(0.07)
		end
		TweenService:Create(box, TweenInfo.new(0.08), { Rotation = 0 }):Play()

		local ok, itemId, qcGrade, invIdOrMessage = remotes.OpenPackage:InvokeServer(orderId)

		if not ok then
			title.Text = tostring(invIdOrMessage or "Couldn't open that package.")
			task.delay(1.6, close)
			return
		end

		currentInvId = invIdOrMessage
		local item = ItemData.ById[itemId]
		local grade = ItemData.GetGrade(qcGrade)

		TweenService:Create(box, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(120, 120) }):Play()
		title.Text = "You got:"
		gradeLabel.Text = grade.name
		gradeLabel.TextColor3 = grade.color
		gradeLabel.Visible = true
		itemLabel.Text = ("%s %s"):format(item.brand, item.name)
		itemLabel.Visible = true
		buttonRow.Visible = true
	end

	remotes.OrderDelivered.OnClientEvent:Connect(function(orderId)
		open(orderId)
	end)

	unboxing = { Open = open, Close = close }
end

-- ============================================================================
-- SECTION: DailyRewardUI — modal shown once per session (if a reward is
-- available) presenting the 7-day streak track and a claim button.
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

	Components.label({ Text = "Daily Drop", Font = Theme.Font.Heading, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), ZIndex = 41, Parent = card })
	Components.label({
		Text = "Log in every day to keep your streak alive.",
		Font = Theme.Font.Body,
		TextSize = 13,
		TextColor3 = Theme.Color.TextSecondary,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 28),
		ZIndex = 41,
		Parent = card,
	})

	local track = Components.frame({
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 90),
		Position = UDim2.new(0, 0, 0, 60),
		BackgroundTransparency = 1,
		Corner = false,
		ZIndex = 41,
		Parent = card,
	})
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
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.new(0, 0, 0, 6),
				ZIndex = 41,
				Parent = cell,
			})
			Components.label({
				Text = "$" .. Config.DAILY_REWARD_CASH[day],
				Font = Theme.Font.Medium,
				TextSize = 11,
				TextColor3 = isToday and Color3.new(0, 0, 0) or Theme.Color.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.new(0, 0, 0, 26),
				ZIndex = 41,
				Parent = cell,
			})
			Components.label({
				Text = Config.DAILY_REWARD_COINS[day] .. "c",
				Font = Theme.Font.Medium,
				TextSize = 11,
				TextColor3 = isToday and Color3.new(0, 0, 0) or Theme.Color.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.new(0, 0, 0, 42),
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
-- SECTION: SellModal — popup used from the Closet: List on ThriftLyst at a
-- chosen price, or Quick Sell instantly for a guaranteed (lower) payout.
-- ============================================================================
do
	local overlay = Components.frame({
		Name = "SellModalOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Corner = false,
		Visible = false,
		ZIndex = 45,
		Parent = screenGui,
	})

	local card = Components.frame({
		Size = UDim2.fromOffset(320, 300),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.Surface,
		CornerRadius = Theme.Corner.Large,
		ZIndex = 46,
		Parent = overlay,
	})
	Components.stroke(card, Theme.Color.Border, 1)
	Components.padding(card, 16)

	local title = Components.label({ Font = Theme.Font.Heading, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), ZIndex = 46, Parent = card })
	local subtitle = Components.label({ Font = Theme.Font.Body, TextSize = 12, TextColor3 = Theme.Color.TextSecondary, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, 24), ZIndex = 46, Parent = card })

	local priceBox = Instance.new("TextBox")
	priceBox.Size = UDim2.new(1, 0, 0, 40)
	priceBox.Position = UDim2.new(0, 0, 0, 64)
	priceBox.BackgroundColor3 = Theme.Color.SurfaceRaised
	priceBox.Font = Theme.Font.Bold
	priceBox.TextSize = 18
	priceBox.TextColor3 = Theme.Color.TextPrimary
	priceBox.PlaceholderText = "Listing price"
	priceBox.ClearTextOnFocus = false
	priceBox.ZIndex = 46
	priceBox.Parent = card
	Components.corner(priceBox, Theme.Corner.Small)

	local listButton = Components.button({
		Text = "List on ThriftLyst",
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, 116),
		BackgroundColor3 = Theme.Color.AccentAlt,
		ZIndex = 46,
		Parent = card,
	})

	local quickSellButton = Components.button({
		Text = "Quick Sell",
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, 166),
		BackgroundColor3 = Theme.Color.Gold,
		TextColor3 = Color3.new(0, 0, 0),
		ZIndex = 46,
		Parent = card,
	})

	local cancelButton = Components.button({
		Text = "Cancel",
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.new(0, 0, 1, -36),
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		ZIndex = 46,
		Parent = card,
	})

	local currentInvId: string? = nil

	local function close()
		overlay.Visible = false
	end
	cancelButton.MouseButton1Click:Connect(close)

	listButton.MouseButton1Click:Connect(function()
		local price = tonumber(priceBox.Text)
		if not currentInvId or not price then
			notify({ title = "Enter a price", message = "Type a number first.", kind = "warning" })
			return
		end
		local ok, message = remotes.ListForSale:InvokeServer(currentInvId, price)
		notify({ title = ok and "Listed!" or "Couldn't list", message = message, kind = ok and "success" or "warning" })
		if ok then
			close()
		end
	end)

	quickSellButton.MouseButton1Click:Connect(function()
		if not currentInvId then
			return
		end
		local ok, amount, message = remotes.QuickSell:InvokeServer(currentInvId)
		notify({ title = ok and "Sold!" or "Couldn't sell", message = message, kind = ok and "success" or "warning" })
		if ok then
			close()
		end
	end)

	local function open(invId: string, item, grade, marketValue: number)
		currentInvId = invId
		title.Text = ("Sell %s %s"):format(item.brand, item.name)
		subtitle.Text = ("%s · Market value ~$%d"):format(grade.name, marketValue)
		priceBox.Text = tostring(marketValue)
		quickSellButton.Text = ("Quick Sell — $%d instantly"):format(math.floor(marketValue * Config.QUICK_SELL_PERCENT))
		overlay.Visible = true
	end

	sellModal = { Open = open }
end

-- ============================================================================
-- SECTION: ShopTab — "DupeDeal" catalog. Browse and buy counterfeit items.
-- ============================================================================
do
	ShopTab = {}

	function ShopTab.Build(parent: Instance, state, notifyFn)
		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "ShopScroller"
		scroller.BackgroundTransparency = 1
		scroller.Size = UDim2.fromScale(1, 1)
		scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.ScrollBarThickness = 4
		scroller.ScrollBarImageColor3 = Theme.Color.Border
		scroller.Parent = parent

		Components.padding(scroller, 4)
		local grid = Components.gridLayout(scroller, UDim2.fromOffset(148, 168), 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder

		for i, item in ItemData.Items do
			local card = Components.frame({
				Name = item.id,
				BackgroundColor3 = Theme.Color.Surface,
				CornerRadius = Theme.Corner.Medium,
				LayoutOrder = i,
				Parent = scroller,
			})
			Components.stroke(card, Theme.Color.Border, 1)
			Components.padding(card, 8)

			local swatch = Components.frame({
				Name = "Swatch",
				Size = UDim2.new(1, 0, 0, 70),
				BackgroundColor3 = item.accentColor,
				CornerRadius = Theme.Corner.Small,
				Parent = card,
			})
			Components.label({
				Text = item.brand,
				Font = Theme.Font.Heading,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Color3.new(1, 1, 1),
				Size = UDim2.fromScale(1, 1),
				Parent = swatch,
			})

			Components.label({
				Text = item.name,
				Font = Theme.Font.Bold,
				TextSize = 13,
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.new(0, 0, 0, 76),
				Parent = card,
			})
			Components.label({
				Text = item.category,
				Font = Theme.Font.Body,
				TextSize = 11,
				TextColor3 = Theme.Color.TextMuted,
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.new(0, 0, 0, 94),
				Parent = card,
			})

			local buyButton = Components.button({
				Text = ("Buy $%d"):format(item.basePrice),
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, 0, 1, -30),
				BackgroundColor3 = Theme.Color.Accent,
				Parent = card,
				OnClick = function()
					local ok, message = remotes.BuyItem:InvokeServer(item.id)
					if not ok then
						notifyFn({ title = "Can't buy that", message = message, kind = "warning" })
					end
				end,
			})
			buyButton.ZIndex = 2
		end
	end
end

-- ============================================================================
-- SECTION: OrdersTab — shows every order: shipping progress, delivered
-- (open it), or seized.
-- ============================================================================
do
	OrdersTab = {}

	local STATUS_COLOR = {
		Shipping = Theme.Color.AccentAlt,
		Delivered = Theme.Color.Success,
		Seized = Theme.Color.Danger,
		Opened = Theme.Color.TextMuted,
	}

	function OrdersTab.Build(parent: Instance, state, notifyFn, unboxingHandle)
		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "OrdersScroller"
		scroller.BackgroundTransparency = 1
		scroller.Size = UDim2.fromScale(1, 1)
		scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.ScrollBarThickness = 4
		scroller.ScrollBarImageColor3 = Theme.Color.Border
		scroller.Parent = parent
		Components.padding(scroller, 4)
		Components.listLayout(scroller, Enum.FillDirection.Vertical, 8)

		local function refresh()
			Components.clearChildren(scroller, { "UIPadding", "UIListLayout" })

			local orders = state.Data.Orders or {}
			local sorted = {}
			for orderId, order in orders do
				if order.status ~= "Opened" then
					table.insert(sorted, { id = orderId, order = order })
				end
			end
			table.sort(sorted, function(a, b)
				return a.order.boughtAt > b.order.boughtAt
			end)

			if #sorted == 0 then
				Components.label({
					Text = ("No orders yet. Head to the Shop — every order has a %d%% chance of getting seized by customs, so QC hauls are always a gamble!"):format(
						math.floor(Config.CUSTOMS_SEIZURE_CHANCE * 100)
					),
					Font = Theme.Font.Body,
					TextSize = 13,
					TextColor3 = Theme.Color.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 60),
					Parent = scroller,
				})
				return
			end

			for i, entry in sorted do
				local orderId, order = entry.id, entry.order
				local item = ItemData.ById[order.itemId]
				if not item then
					continue
				end

				local card = Components.frame({
					Name = orderId,
					Size = UDim2.new(1, 0, 0, 86),
					BackgroundColor3 = Theme.Color.Surface,
					CornerRadius = Theme.Corner.Medium,
					LayoutOrder = i,
					Parent = scroller,
				})
				Components.stroke(card, STATUS_COLOR[order.status] or Theme.Color.Border, 1)
				Components.padding(card, 10)

				Components.label({
					Text = ("%s %s"):format(item.brand, item.name),
					Font = Theme.Font.Bold,
					TextSize = 14,
					Size = UDim2.new(1, -80, 0, 18),
					Parent = card,
				})
				Components.label({
					Text = order.status,
					Font = Theme.Font.Heading,
					TextSize = 12,
					TextColor3 = STATUS_COLOR[order.status] or Theme.Color.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Right,
					Size = UDim2.new(0, 80, 0, 18),
					Position = UDim2.new(1, -80, 0, 0),
					Parent = card,
				})

				if order.status == "Shipping" then
					local total = order.deliverAt - order.boughtAt
					local progress = math.clamp((os.time() - order.boughtAt) / math.max(total, 1), 0, 1)
					Components.progressBar({
						Size = UDim2.new(1, 0, 0, 8),
						Position = UDim2.new(0, 0, 0, 30),
						Progress = progress,
						FillColor = Theme.Color.AccentAlt,
						FillColorB = Theme.Color.Accent,
						Parent = card,
					})
					local remaining = math.max(0, order.deliverAt - os.time())
					Components.label({
						Text = ("~%ds remaining"):format(remaining),
						Font = Theme.Font.Body,
						TextSize = 12,
						TextColor3 = Theme.Color.TextMuted,
						Size = UDim2.new(1, 0, 0, 16),
						Position = UDim2.new(0, 0, 0, 42),
						Parent = card,
					})
				elseif order.status == "Delivered" then
					Components.button({
						Text = "Open Haul",
						Size = UDim2.new(1, 0, 0, 30),
						Position = UDim2.new(0, 0, 1, -30),
						BackgroundColor3 = Theme.Color.Success,
						Parent = card,
						OnClick = function()
							unboxingHandle.Open(orderId)
						end,
					})
				elseif order.status == "Seized" then
					Components.label({
						Text = ("Seized by customs — you got %d Coins as a consolation."):format(Config.SEIZURE_CONSOLATION_COINS),
						Font = Theme.Font.Body,
						TextSize = 12,
						TextColor3 = Theme.Color.TextMuted,
						Size = UDim2.new(1, 0, 0, 32),
						Position = UDim2.new(0, 0, 0, 32),
						Parent = card,
					})
				end
			end
		end

		refresh()
		return refresh
	end
end

-- ============================================================================
-- SECTION: InventoryTab — "Closet". Wear/unwear, or send to ThriftLyst /
-- Quick Sell.
-- ============================================================================
do
	InventoryTab = {}

	function InventoryTab.Build(parent: Instance, state, notifyFn, openSellModal)
		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "ClosetScroller"
		scroller.BackgroundTransparency = 1
		scroller.Size = UDim2.fromScale(1, 1)
		scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.ScrollBarThickness = 4
		scroller.ScrollBarImageColor3 = Theme.Color.Border
		scroller.Parent = parent
		Components.padding(scroller, 4)

		local function refresh()
			Components.clearChildren(scroller, { "UIPadding" })
			local grid = Components.gridLayout(scroller, UDim2.fromOffset(148, 190), 10)
			grid.SortOrder = Enum.SortOrder.LayoutOrder

			local inv = state.Data.Inventory or {}
			local ids = {}
			for invId in inv do
				table.insert(ids, invId)
			end
			table.sort(ids, function(a, b)
				return (inv[a].obtainedAt or 0) > (inv[b].obtainedAt or 0)
			end)

			if #ids == 0 then
				grid:Destroy()
				Components.label({
					Text = "Your closet is empty. Open a haul from the Orders tab to get your first piece.",
					Font = Theme.Font.Body,
					TextSize = 13,
					TextColor3 = Theme.Color.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 60),
					Parent = scroller,
				})
				return
			end

			for i, invId in ids do
				local invItem = inv[invId]
				local item = ItemData.ById[invItem.itemId]
				if not item then
					continue
				end
				local grade = ItemData.GetGrade(invItem.qcGrade)
				local marketValue = ItemData.GetMarketValue(invItem.itemId, invItem.qcGrade)

				local card = Components.frame({
					Name = invId,
					BackgroundColor3 = Theme.Color.Surface,
					CornerRadius = Theme.Corner.Medium,
					LayoutOrder = i,
					Parent = scroller,
				})
				Components.stroke(card, invItem.equipped and Theme.Color.Accent or Theme.Color.Border, invItem.equipped and 2 or 1)
				Components.padding(card, 8)

				local swatch = Components.frame({ Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = item.accentColor, CornerRadius = Theme.Corner.Small, Parent = card })
				Components.label({ Text = item.brand, Font = Theme.Font.Heading, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = swatch })

				Components.label({ Text = item.name, Font = Theme.Font.Bold, TextSize = 12, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 62), Parent = card })
				Components.label({ Text = grade.name .. (" · $%d"):format(marketValue), Font = Theme.Font.Body, TextSize = 11, TextColor3 = grade.color, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 78), Parent = card })

				Components.button({
					Text = invItem.equipped and "Unwear" or "Wear",
					Size = UDim2.new(1, 0, 0, 26),
					Position = UDim2.new(0, 0, 0, 98),
					BackgroundColor3 = invItem.equipped and Theme.Color.SurfaceRaised or Theme.Color.Accent,
					TextSize = 13,
					Parent = card,
					OnClick = function()
						remotes.WearItem:FireServer(invId)
					end,
				})

				Components.button({
					Text = "Sell",
					Size = UDim2.new(1, 0, 0, 26),
					Position = UDim2.new(0, 0, 0, 128),
					BackgroundColor3 = Theme.Color.Gold,
					TextColor3 = Color3.new(0, 0, 0),
					TextSize = 13,
					Parent = card,
					OnClick = function()
						if invItem.equipped then
							notifyFn({ title = "Unwear first", message = "Take it off before selling.", kind = "warning" })
							return
						end
						openSellModal(invId, item, grade, marketValue)
					end,
				})
			end
		end

		refresh()
		return refresh
	end
end

-- ============================================================================
-- SECTION: MarketTab — "ThriftLyst" active listings, with a cancel option.
-- ============================================================================
do
	MarketTab = {}

	function MarketTab.Build(parent: Instance, state, notifyFn)
		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "MarketScroller"
		scroller.BackgroundTransparency = 1
		scroller.Size = UDim2.fromScale(1, 1)
		scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.ScrollBarThickness = 4
		scroller.ScrollBarImageColor3 = Theme.Color.Border
		scroller.Parent = parent
		Components.padding(scroller, 4)

		local function refresh()
			Components.clearChildren(scroller, { "UIPadding" })
			Components.listLayout(scroller, Enum.FillDirection.Vertical, 8)

			local listings = state.Data.Listings or {}
			local ids = {}
			for listingId in listings do
				table.insert(ids, listingId)
			end

			if #ids == 0 then
				Components.label({
					Text = "You have no active ThriftLyst listings. List an item from your Closet to start earning while you're away.",
					Font = Theme.Font.Body,
					TextSize = 13,
					TextColor3 = Theme.Color.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 60),
					Parent = scroller,
				})
				return
			end

			table.sort(ids, function(a, b)
				return (listings[a].listedAt or 0) > (listings[b].listedAt or 0)
			end)

			for i, listingId in ids do
				local listing = listings[listingId]
				local item = ItemData.ById[listing.itemId]
				if not item then
					continue
				end
				local grade = ItemData.GetGrade(listing.qcGrade)

				local card = Components.frame({
					Size = UDim2.new(1, 0, 0, 64),
					BackgroundColor3 = Theme.Color.Surface,
					CornerRadius = Theme.Corner.Medium,
					LayoutOrder = i,
					Parent = scroller,
				})
				Components.stroke(card, Theme.Color.Border, 1)
				Components.padding(card, 10)

				Components.label({
					Text = ("%s %s"):format(item.brand, item.name),
					Font = Theme.Font.Bold,
					TextSize = 14,
					Size = UDim2.new(1, -90, 0, 18),
					Parent = card,
				})
				Components.label({
					Text = ("%s · Listed $%d"):format(grade.name, listing.price),
					Font = Theme.Font.Body,
					TextSize = 12,
					TextColor3 = grade.color,
					Size = UDim2.new(1, -90, 0, 16),
					Position = UDim2.new(0, 0, 0, 20),
					Parent = card,
				})

				Components.button({
					Text = "Cancel",
					Size = UDim2.new(0, 80, 0, 28),
					Position = UDim2.new(1, -80, 0, 6),
					BackgroundColor3 = Theme.Color.Danger,
					TextSize = 12,
					Parent = card,
					OnClick = function()
						remotes.CancelListing:FireServer(listingId)
					end,
				})
			end
		end

		refresh()
		return refresh
	end
end

-- ============================================================================
-- SECTION: BattlepassTab — "Heat Pass" level progress, free/premium reward
-- rows, and the unlock-premium buttons.
-- ============================================================================
do
	BattlepassTab = {}

	local function rewardText(reward)
		if reward.kind == "Cash" then
			return ("$%d Cash"):format(reward.amount)
		elseif reward.kind == "Coins" then
			return ("%d Coins"):format(reward.amount)
		elseif reward.kind == "Item" then
			local item = ItemData.ById[reward.itemId]
			return item and (item.brand .. " " .. item.name) or "Exclusive Item"
		end
		return "?"
	end

	function BattlepassTab.Build(parent: Instance, state, notifyFn)
		local header = Components.frame({ Name = "Header", Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, Corner = false, Parent = parent })
		local levelLabel = Components.label({ Font = Theme.Font.Heading, TextSize = 18, Size = UDim2.new(1, 0, 0, 20), Parent = header })
		local xpTrack, xpFill = Components.progressBar({ Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 0, 26), FillColor = Theme.Color.Gold, FillColorB = Theme.Color.Accent, Parent = header })

		local unlockButton = Components.button({
			Text = ("Unlock Premium — %d Coins"):format(Config.BATTLEPASS_PREMIUM_COST_COINS),
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
			local ok, message = remotes.BuyBattlepassPremiumWithCoins:InvokeServer()
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
			levelLabel.Text = ("Heat Pass — Level %d / %d"):format(bp.Level, Config.BATTLEPASS_MAX_LEVEL)
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

				-- Free reward cell
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

				-- Premium reward cell
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
-- SECTION: PhoneUI — the phone-styled shell: top bar (Cash/Coins), content
-- area, bottom nav. Delegates each screen's content to the Tab sections above.
-- ============================================================================
do
	local TABS = {
		{ id = "Shop", label = "🛍️ Shop", module = ShopTab },
		{ id = "Orders", label = "📦 Orders", module = OrdersTab },
		{ id = "Closet", label = "👕 Closet", module = InventoryTab },
		{ id = "Market", label = "💸 Market", module = MarketTab },
		{ id = "Pass", label = "🎟️ Pass", module = BattlepassTab },
	}

	local function openSellModalFromClosetTab(invId, item, grade, marketValue)
		sellModal.Open(invId, item, grade, marketValue)
	end

	-- Floating toggle button
	local toggleButton = Components.button({
		Name = "PhoneToggle",
		Text = "📱",
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.new(1, -84, 1, -84),
		BackgroundColor3 = Theme.Color.Accent,
		CornerRadius = Theme.Corner.Pill,
		TextSize = 28,
		ZIndex = 10,
		Parent = screenGui,
	})

	local phoneFrame = Components.frame({
		Name = "PhoneFrame",
		Size = UDim2.fromOffset(380, 620),
		Position = UDim2.new(1, -84, 1, -84),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Theme.Color.Background,
		CornerRadius = Theme.Corner.Large,
		Visible = false,
		ZIndex = 5,
		Parent = screenGui,
	})
	Components.stroke(phoneFrame, Theme.Color.Border, 2)

	-- Top bar
	local topBar = Components.frame({
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Theme.Color.Surface,
		CornerRadius = Theme.Corner.Large,
		ZIndex = 6,
		Parent = phoneFrame,
	})
	Components.padding(topBar, 12)

	Components.label({ Text = "REPLICA RUSH", Font = Theme.Font.Heading, TextSize = 16, Size = UDim2.new(0, 160, 1, 0), TextColor3 = Theme.Color.Accent, ZIndex = 6, Parent = topBar })

	local cashLabel = Components.label({
		Font = Theme.Font.Bold,
		TextSize = 15,
		TextColor3 = Theme.Color.Cash,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 90, 1, 0),
		Position = UDim2.new(1, -190, 0, 0),
		ZIndex = 6,
		Parent = topBar,
	})
	local coinsLabel = Components.label({
		Font = Theme.Font.Bold,
		TextSize = 15,
		TextColor3 = Theme.Color.Coins,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 70, 1, 0),
		Position = UDim2.new(1, -96, 0, 0),
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

	-- Content area
	local content = Components.frame({
		Name = "Content",
		Size = UDim2.new(1, -16, 1, -128),
		Position = UDim2.new(0, 8, 0, 62),
		BackgroundTransparency = 1,
		Corner = false,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = phoneFrame,
	})

	-- Bottom nav
	local nav = Components.frame({
		Name = "BottomNav",
		Size = UDim2.new(1, 0, 0, 58),
		Position = UDim2.new(0, 0, 1, -58),
		BackgroundColor3 = Theme.Color.Surface,
		CornerRadius = Theme.Corner.Large,
		ZIndex = 6,
		Parent = phoneFrame,
	})
	Components.listLayout(nav, Enum.FillDirection.Horizontal, 0)
	local navLayout = nav:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local tabFrames = {}
	local tabRefreshers = {}
	local navButtons = {}
	local activeTabId = "Shop"

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
		local tabFrame = Components.frame({
			Name = tab.id .. "Panel",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Corner = false,
			Visible = false,
			Parent = content,
		})
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

		if tab.id == "Closet" then
			tabRefreshers[tab.id] = tab.module.Build(tabFrame, State, notify, openSellModalFromClosetTab)
		elseif tab.id == "Orders" then
			tabRefreshers[tab.id] = tab.module.Build(tabFrame, State, notify, unboxing)
		else
			tabRefreshers[tab.id] = tab.module.Build(tabFrame, State, notify)
		end
	end

	setActiveTab("Shop")

	local function refreshTopBar()
		cashLabel.Text = ("$%d"):format(State.Data.Cash or 0)
		coinsLabel.Text = ("%d 🪙"):format(State.Data.Coins or 0)
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

	-- Live-tick the active tab (order shipping progress bars, xp bars) even
	-- when no server push happened.
	task.spawn(function()
		while true do
			task.wait(1)
			if phoneFrame.Visible then
				local refresher = tabRefreshers[activeTabId]
				if refresher then
					refresher()
				end
				refreshTopBar()
			end
		end
	end)

	local function togglePhone()
		phoneFrame.Visible = not phoneFrame.Visible
		if phoneFrame.Visible then
			refreshAll()
		end
	end

	toggleButton.MouseButton1Click:Connect(togglePhone)
	closeButton.MouseButton1Click:Connect(togglePhone)
end

-- ============================================================================
-- SECTION: Data stream — receives the server's data snapshots and server
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
