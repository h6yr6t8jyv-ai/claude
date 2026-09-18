--!strict
-- Tiny helper so every service sends notifications the same shape.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local remotes = Remotes.Get()

local Notify = {}

-- kind: "info" | "success" | "warning" | "danger"
function Notify.Send(player: Player, title: string, message: string, kind: string?)
	remotes.Notify:FireClient(player, {
		title = title,
		message = message,
		kind = kind or "info",
	})
end

return Notify
