--!strict
-- Buying, shipping timers, the 15% customs seizure roll, and opening the
-- delivered package into a "haul" (the QC grade reveal).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemData = require(Shared.ItemData)
local Remotes = require(Shared.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local Notify = require(script.Parent.Notify)
local BattlepassService = require(script.Parent.BattlepassService)

local remotes = Remotes.Get()

local OrderService = {}

local function startShippingTimer(player: Player, orderId: string)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	local order = data.Orders[orderId]
	if not order then
		return
	end

	local wait = order.deliverAt - os.time()
	if wait > 0 then
		task.wait(wait)
	end

	-- Player could have left; re-fetch fresh state in case data changed.
	data = PlayerDataService.Get(player)
	if not data then
		return
	end
	order = data.Orders[orderId]
	if not order or order.status ~= "Shipping" then
		return -- cancelled/already resolved
	end

	local item = ItemData.ById[order.itemId]
	local seized = math.random() < Config.CUSTOMS_SEIZURE_CHANCE

	if seized then
		order.status = "Seized"
		data.Coins += Config.SEIZURE_CONSOLATION_COINS
		Notify.Send(
			player,
			"Package Seized!",
			("Customs flagged your %s %s. It's gone — here's %d Coins for the trouble."):format(item.brand, item.name, Config.SEIZURE_CONSOLATION_COINS),
			"danger"
		)
	else
		order.status = "Delivered"
		order.qcGrade = ItemData.RollQCGrade()
		Notify.Send(player, "Package Delivered!", ("Your %s %s just landed. Go open your haul!"):format(item.brand, item.name), "success")
		remotes.OrderDelivered:FireClient(player, orderId)
	end

	PlayerDataService.Push(player)
end

function OrderService.Init()
	remotes.BuyItem.OnServerInvoke = function(player: Player, itemId: string)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, "Data not loaded yet, try again."
		end
		local item = ItemData.ById[itemId]
		if not item then
			return false, "That item doesn't exist."
		end
		if data.Cash < item.basePrice then
			return false, "Not enough Cash."
		end

		data.Cash -= item.basePrice

		local orderId = "order_" .. data.NextOrderId
		data.NextOrderId += 1

		local now = os.time()
		local shipTime = math.random(Config.SHIPPING_TIME_MIN, Config.SHIPPING_TIME_MAX)

		data.Orders[orderId] = {
			itemId = itemId,
			boughtAt = now,
			deliverAt = now + shipTime,
			status = "Shipping",
			qcGrade = nil,
		}

		PlayerDataService.Push(player)
		Notify.Send(player, "Order Placed", ("Your %s %s is on the way. ~%ds shipping."):format(item.brand, item.name, shipTime), "info")

		task.spawn(startShippingTimer, player, orderId)

		return true, "Order placed."
	end

	remotes.OpenPackage.OnServerInvoke = function(player: Player, orderId: string)
		local data = PlayerDataService.Get(player)
		if not data then
			return false, nil, nil, "Data not loaded."
		end
		local order = data.Orders[orderId]
		if not order then
			return false, nil, nil, "Order not found."
		end
		if order.status ~= "Delivered" then
			return false, nil, nil, "This order isn't ready to open."
		end

		local invId = "inv_" .. data.NextInvId
		data.NextInvId += 1

		data.Inventory[invId] = {
			itemId = order.itemId,
			qcGrade = order.qcGrade,
			obtainedAt = os.time(),
			equipped = false,
		}

		order.status = "Opened"
		BattlepassService.AddXP(player, Config.XP_PER_OPEN)
		PlayerDataService.Push(player)

		return true, order.itemId, order.qcGrade, invId
	end

	-- Resume any orders that were mid-shipping when the server last saved
	-- (handles the case where a player rejoins while an order is in flight).
	game:GetService("Players").PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- Wait until PlayerDataService has actually loaded this player.
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
			for orderId, order in data.Orders do
				if order.status == "Shipping" then
					task.spawn(startShippingTimer, player, orderId)
				end
			end
		end)
	end)
end

return OrderService
