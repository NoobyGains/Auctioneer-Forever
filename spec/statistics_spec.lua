local addon = require("support.addon")

describe("Auctioneer:Statistics", function()
	it("accepts an item key given as a plain item number", function()
		local _, A = addon.start()
		local seen
		table.insert(A.parts.Internal.modules, {name = "Probe", hooks = {}, Stats = function(_, _, id) seen = id end})
		A.Auctioneer:Statistics(2589)
		assert.are.equal("2589", seen)
	end)
end)
