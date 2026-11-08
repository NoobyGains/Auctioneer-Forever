local wow, addon = require("support.wow"), require("support.addon")

describe("item:Info without item key info", function()
	local env, A
	before_each(function()
		env = wow.install()
		A = addon.boot(env)
	end)

	local function linen()
		return A.Auctioneer:Item{itemKey = C_AuctionHouse.MakeItemKey(2589, 0, 0, 0)}
	end

	it("falls back to C_Item when item key info is not cached", function()
		env.items[2589] = {name = "Linen Cloth", quality = 1}
		env.ah:load({}, {missingInfo = {[2589] = true}})
		local info = linen():Info()
		assert.are.equal("Linen Cloth", info.name)
		assert.are.equal("ffffffff", info.color)
	end)

	it("falls back to the item key string when nothing is cached", function()
		env.ah:load({}, {missingInfo = {[2589] = true}})
		assert.are.equal("item:2589::::::0::0", linen():Info().name)
	end)

	it("uses item key info once it arrives", function()
		env.ah:load({}, {missingInfo = {[2589] = true}})
		local item = linen()
		item:Info()
		env.ah.infoCache[2589] = {itemName = "Linen Cloth (AH)", quality = 1, iconFileID = 1}
		assert.are.equal("Linen Cloth (AH)", item:Info().name)
	end)
end)
