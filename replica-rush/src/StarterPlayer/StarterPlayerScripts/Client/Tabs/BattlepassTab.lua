--!strict
-- "Heat Pass" battlepass — level progress, free/premium reward rows, and
-- the unlock-premium buttons (Robux gamepass or Coins).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)
local Config = require(Shared.Config)
local BattlepassData = require(Shared.BattlepassData)
local ItemData = require(Shared.ItemData)
local Remotes = require(Shared.Remotes)

local remotes = Remotes.Get()

local BattlepassTab = {}

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

function BattlepassTab.Build(parent: Instance, state, notify)
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
		notify({ title = ok and "Premium Unlocked!" or "Couldn't unlock", message = message, kind = ok and "success" or "warning" })
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
							notify({ title = "Can't claim", message = message, kind = "warning" })
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
							notify({ title = "Can't claim", message = message, kind = "warning" })
						end
					end
				end,
			})
		end
	end

	refresh()
	return refresh
end

return BattlepassTab
