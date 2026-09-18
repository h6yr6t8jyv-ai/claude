--!strict
-- The counterfeit catalog. All brand names are original wordplay/parody names
-- (no real trademarks) in the spirit of Roblox "replica/knockoff" simulators.
--
-- icon = decal/asset id string. Placeholder "rbxassetid://0" — swap in real
-- uploaded images from Studio > Asset Manager once you have art.

local ItemData = {}

-- Quality Control grades rolled when a package is delivered. Higher grades are
-- rarer and multiply both the "flex value" (what it looks like worn) and the
-- resale market value.
ItemData.QCGrades = {
	{ id = "bootleg", name = "Bootleg", weight = 32, valueMult = 0.4, color = Color3.fromRGB(150, 150, 150) },
	{ id = "gradeA", name = "Grade A", weight = 40, valueMult = 0.85, color = Color3.fromRGB(120, 200, 255) },
	{ id = "aaa", name = "AAA Replica", weight = 21, valueMult = 1.35, color = Color3.fromRGB(180, 120, 255) },
	{ id = "museum", name = "Museum 1:1", weight = 7, valueMult = 2.25, color = Color3.fromRGB(255, 200, 60) },
}

function ItemData.RollQCGrade(): string
	local totalWeight = 0
	for _, grade in ItemData.QCGrades do
		totalWeight += grade.weight
	end
	local roll = math.random() * totalWeight
	local cursor = 0
	for _, grade in ItemData.QCGrades do
		cursor += grade.weight
		if roll <= cursor then
			return grade.id
		end
	end
	return ItemData.QCGrades[1].id
end

function ItemData.GetGrade(gradeId: string)
	for _, grade in ItemData.QCGrades do
		if grade.id == gradeId then
			return grade
		end
	end
	return ItemData.QCGrades[1]
end

export type Item = {
	id: string,
	name: string,
	brand: string,
	category: string,
	basePrice: number,
	icon: string,
	shirtId: number?,
	pantsId: number?,
	accessoryId: number?,
	accentColor: Color3,
}

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

return ItemData
