local wow, addon = require("support.wow"), require("support.addon")

describe("Auctioneer:Statistics", function()
	it("accepts a numeric item id", function()
		local A = addon.boot(wow.install())
		local seen
		table.insert(A.parts.Internal.modules, {name = "Probe", hooks = {}, Stats = function(_, _, id) seen = id end})
		A.Auctioneer:Statistics(2589)
		assert.are.equal("2589", seen)
	end)
end)
