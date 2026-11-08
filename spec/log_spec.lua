local wow, addon = require("support.wow"), require("support.addon")

describe("Auctioneer:Log", function()
	local env, A
	before_each(function()
		env = wow.install()
		A = addon.boot(env)
	end)

	it("logs nothing when debug is off", function()
		A.Auctioneer:Log("hello %d", 1)
		assert.is_nil(AuctioneerLog)
		assert.are.same({}, env.etrace)
	end)

	it("writes to Event Trace and AuctioneerLog when debug is on", function()
		AuctioneerLocal.debug = true
		A.Auctioneer:Log("hello %d", 1)
		assert.are.same({"Auctioneer: hello 1"}, env.etrace)
		assert.truthy(AuctioneerLog[1]:match("^%d%d:%d%d:%d%d %d+%.%d%d%d hello 1$"))
	end)

	it("loads Blizzard_EventTrace when it is not loaded yet", function()
		AuctioneerLocal.debug = true
		_G.EventTrace = nil
		A.Auctioneer:Log("x")
		assert.are.same({"Blizzard_EventTrace"}, env.loadedAddOns)
	end)

	it("keeps only the last 2000 lines", function()
		AuctioneerLocal.debug = true
		for i = 1, 2005 do A.Auctioneer:Log("line %d", i) end
		assert.are.equal(2000, #AuctioneerLog)
		assert.truthy(AuctioneerLog[1]:match(" line 6$"))
	end)
end)
