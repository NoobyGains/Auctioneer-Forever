local wow, addon = require("support.wow"), require("support.addon")

describe("Valuer", function()
	local env, A, valuer, shown

	before_each(function()
		env = wow.install()
		A = addon.boot(env, {files = {"Auctioneer_Util_Valuer/Main.lua"}})
		valuer = A.module("Util:Valuer")
		C_AuctionHouse.GetItemKeyFromItem = function() return C_AuctionHouse.MakeItemKey(2589, 0, 0, 0) end
		shown = 0
		local show = valuer.SellItemLoaded
		valuer.SellItemLoaded = function(...) shown = shown + 1; return show(...) end
	end)

	it("shows the sell item again once its item key info arrives", function()
		valuer:SellItemLoaded("SellItems", {})
		env.clock:runUntilIdle(10)
		assert.are.equal(2, shown)
	end)

	it("does not show it again when the item key info was already there", function()
		env.ah.infoCache[2589] = {itemName = "Linen Cloth", quality = 1, iconFileID = 1}
		valuer:SellItemLoaded("SellItems", {})
		env.clock:runUntilIdle(10)
		assert.are.equal(1, shown)
	end)
end)
