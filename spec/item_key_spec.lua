local wow, addon = require("support.wow"), require("support.addon")

describe("item key from a link", function()
	local env, A
	before_each(function()
		env = wow.install()
		A = addon.boot(env)
	end)

	local function keyOf(link)
		return A.Auctioneer:ItemKeyKey(A.Auctioneer:ItemKeyFromLink(link))
	end

	it("maps a link to the level-less key when the AH does not group the item by level", function()
		env.items[2589] = {level = 5}
		AuctioneerData.itemHasLevel[2589] = 0
		assert.are.equal("2589", keyOf(wow.link(2589)))
	end)

	it("keeps the level when the AH groups the item by level", function()
		env.items[19019] = {level = 80}
		AuctioneerData.itemHasLevel[19019] = 1
		assert.are.equal("19019:80", keyOf(wow.link(19019)))
	end)

	it("drops the level for an item never seen at auction", function()
		env.items[2589] = {level = 5}
		assert.are.equal("2589", keyOf(wow.link(2589)))
	end)

	it("finds the key a scan recorded", function()
		env.items[2589] = {level = 5}
		local res = A.scan({{itemID = 2589, minPrice = 10, totalQuantity = 20}})
		assert.are.equal(res.items[1].id, keyOf(wow.link(2589)))
	end)

	it("logs a link's item key once while the same tooltip keeps refreshing", function()
		AuctioneerLocal.debug = true
		env.items[2589] = {level = 5}
		keyOf(wow.link(2589))
		keyOf(wow.link(2589))
		local n = 0
		for _, line in ipairs(AuctioneerLog) do
			if line:find("link item key", 1, true) then n = n + 1 end
		end
		assert.are.equal(1, n)
	end)

	it("leaves battle pet keys unchanged", function()
		assert.are.equal(":::1234", keyOf(wow.petLink(1234)))
	end)
end)
