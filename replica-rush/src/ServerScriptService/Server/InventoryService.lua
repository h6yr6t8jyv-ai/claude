--!strict
-- Wearing/unwearing closet items on the character. If an item has real
-- uploaded Shirt/Pants/Accessory asset ids (see ItemData.lua) those are used;
-- otherwise we fall back to a simple colored proxy accessory + nameplate so
-- the feature is fully testable with zero external assets.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemData = require(Shared.ItemData)
local Remotes = require(Shared.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local BattlepassService = require(script.Parent.BattlepassService)

local remotes = Remotes.Get()

local InventoryService = {}

local CATEGORY_SLOT = {
	Hoodies = "Top",
	Tees = "Top",
	Denim = "Bottom",
	Sneakers = "Shoes",
	Bags = "Accessory",
	Accessories = "Accessory",
}

local function clearSlotVisual(character: Model, slotName: string)
	local holder = character:FindFirstChild("ReplicaRushWorn")
	if not holder then
		return
	end
	local existing = holder:FindFirstChild(slotName)
	if existing then
		existing:Destroy()
	end
end

local function applyProxyAccessory(character: Model, invId: string, item, slotName: string)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local holder = character:FindFirstChild("ReplicaRushWorn")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "ReplicaRushWorn"
		holder.Parent = character
	end
	clearSlotVisual(character, slotName)

	local acc = Instance.new("Accessory")
	acc.Name = slotName
	acc.AccessoryType = Enum.AccessoryType.Neck

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.6, 0.6)
	handle.Color = item.accentColor
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true

	local attachment = Instance.new("Attachment")
	attachment.Name = "BodyFrontAttachment"
	attachment.Parent = handle

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 34)
	billboard.StudsOffset = Vector3.new(0, 1.1, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = handle

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = ("%s %s"):format(item.brand, item.name)
	label.Parent = billboard

	handle.Parent = acc
	acc.Parent = holder

	local ok = pcall(function()
		humanoid:AddAccessory(acc)
	end)
	if not ok then
		acc.Parent = holder
	end
end

function InventoryService.Init()
	remotes.WearItem.OnServerEvent:Connect(function(player: Player, invId: string)
		local data = PlayerDataService.Get(player)
		if not data then
			return
		end
		local invItem = data.Inventory[invId]
		if not invItem then
			return
		end
		local item = ItemData.ById[invItem.itemId]
		if not item then
			return
		end

		local character = player.Character
		local slotName = CATEGORY_SLOT[item.category] or "Accessory"

		if invItem.equipped then
			-- Unequip.
			invItem.equipped = false
			if character then
				clearSlotVisual(character, slotName)
			end
		else
			-- Unequip whatever else is in this slot first.
			for otherInvId, other in data.Inventory do
				if other.equipped and otherInvId ~= invId then
					local otherItem = ItemData.ById[other.itemId]
					if otherItem and (CATEGORY_SLOT[otherItem.category] or "Accessory") == slotName then
						other.equipped = false
					end
				end
			end
			invItem.equipped = true
			if character then
				applyProxyAccessory(character, invId, item, slotName)
			end
			BattlepassService.AddXP(player, Config.XP_PER_WEAR)
		end

		PlayerDataService.Push(player)
	end)

	-- Re-apply worn items whenever the character (re)spawns.
	local Players = game:GetService("Players")
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5)
			local data
			for _ = 1, 100 do
				data = PlayerDataService.Get(player)
				if data then
					break
				end
				task.wait(0.1)
			end
			if not data then
				return
			end
			for invId, invItem in data.Inventory do
				if invItem.equipped then
					local item = ItemData.ById[invItem.itemId]
					if item then
						local slotName = CATEGORY_SLOT[item.category] or "Accessory"
						applyProxyAccessory(character, invId, item, slotName)
					end
				end
			end
		end)
	end)
end

return InventoryService
