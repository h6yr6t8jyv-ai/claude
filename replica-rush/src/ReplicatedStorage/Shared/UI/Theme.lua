--!strict
-- Shared design tokens so every screen looks like one app, not five.

local Theme = {}

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

return Theme
