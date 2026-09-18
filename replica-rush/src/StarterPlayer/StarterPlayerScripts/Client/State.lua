--!strict
-- Holds the latest data snapshot pushed by the server and lets UI modules
-- subscribe to changes without every tab wiring its own remote listener.

local State = {}

State.Data = {
	Cash = 0,
	Coins = 0,
	Orders = {},
	Inventory = {},
	Listings = {},
	Battlepass = { XP = 0, Level = 1, PremiumOwned = false, ClaimedFree = {}, ClaimedPremium = {} },
	DailyReward = { LastClaimUnix = 0, Streak = 0 },
}

local changedEvent = Instance.new("BindableEvent")
State.Changed = changedEvent.Event

function State.Set(snapshot)
	State.Data = snapshot
	changedEvent:Fire(snapshot)
end

return State
