--!strict
-- Client entry point: builds the root ScreenGui, wires the data snapshot
-- stream, and mounts every UI module.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local remotes = Remotes.Get()

local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local Unboxing = require(script.Parent.Unboxing)
local DailyRewardUI = require(script.Parent.DailyRewardUI)
local SellModal = require(script.Parent.SellModal)
local PhoneUI = require(script.Parent.PhoneUI)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ReplicaRushUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local notify = Notifications.Mount(screenGui)

local sellModal = SellModal.Mount(screenGui, notify, function()
	-- inventory/market tabs refresh themselves off State.Changed already
end)

local unboxing = Unboxing.Mount(screenGui, function()
	-- closet/orders refresh off State.Changed already
end)

local dailyRewardUI = DailyRewardUI.Mount(screenGui, State)

local phone = PhoneUI.Mount(screenGui, State, notify, unboxing, function(invId, item, grade, marketValue)
	sellModal.Open(invId, item, grade, marketValue)
end)

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
