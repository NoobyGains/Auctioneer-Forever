local addon = require("support.addon")

describe("harness", function()
	it("boots the addon and records a 3-row scan", function()
		local env, A = addon.start()
		local res = A.scan({
			{itemID = 1, minPrice = 100, totalQuantity = 5},
			{itemID = 2, minPrice = 200, totalQuantity = 1},
			{itemID = 3, minPrice = 300, totalQuantity = 2},
		})
		assert.are.equal(3, #res.items)
		assert.are.equal(3, #res.completed)
		assert.are.equal("2", res.items[2].id)
	end)
end)
