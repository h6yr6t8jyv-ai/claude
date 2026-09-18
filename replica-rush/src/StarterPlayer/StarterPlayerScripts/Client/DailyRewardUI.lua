--!strict
-- Modal shown once per session (if a reward is available) presenting the
-- 7-day streak track and a claim button.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Components = require(Shared.UI.Components)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local remotes = Remotes.Get()

local DailyRewardUI = {}

function DailyRewardUI.Mount(screenGui: ScreenGui, state)
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
		local daily = state.Data.DailyReward
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

	return { TryShow = tryShow }
end

return DailyRewardUI
