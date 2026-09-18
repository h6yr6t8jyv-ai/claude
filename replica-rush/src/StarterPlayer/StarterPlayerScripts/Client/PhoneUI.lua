--!strict
-- The phone-styled shell: top bar (Cash/Coins), content area, bottom nav.
-- Delegates each screen's content to the Tabs/* modules.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)

local ShopTab = require(script.Parent.Tabs.ShopTab)
local OrdersTab = require(script.Parent.Tabs.OrdersTab)
local InventoryTab = require(script.Parent.Tabs.InventoryTab)
local MarketTab = require(script.Parent.Tabs.MarketTab)
local BattlepassTab = require(script.Parent.Tabs.BattlepassTab)

local PhoneUI = {}

local TABS = {
	{ id = "Shop", label = "🛍️ Shop", module = ShopTab },
	{ id = "Orders", label = "📦 Orders", module = OrdersTab },
	{ id = "Closet", label = "👕 Closet", module = InventoryTab },
	{ id = "Market", label = "💸 Market", module = MarketTab },
	{ id = "Pass", label = "🎟️ Pass", module = BattlepassTab },
}

function PhoneUI.Mount(screenGui: ScreenGui, state, notify, unboxing, openSellModal)
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
			tabRefreshers[tab.id] = tab.module.Build(tabFrame, state, notify, openSellModal)
		elseif tab.id == "Orders" then
			tabRefreshers[tab.id] = tab.module.Build(tabFrame, state, notify, unboxing)
		else
			tabRefreshers[tab.id] = tab.module.Build(tabFrame, state, notify)
		end
	end

	setActiveTab("Shop")

	local function refreshTopBar()
		cashLabel.Text = ("$%d"):format(state.Data.Cash or 0)
		coinsLabel.Text = ("%d 🪙"):format(state.Data.Coins or 0)
	end
	refreshTopBar()

	local function refreshAll()
		refreshTopBar()
		local refresher = tabRefreshers[activeTabId]
		if refresher then
			refresher()
		end
	end

	state.Changed:Connect(refreshAll)

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

	return { Toggle = togglePhone, SetTab = setActiveTab }
end

return PhoneUI
