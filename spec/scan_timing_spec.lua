local addon = require("support.addon")
local rows, timingLines = addon.rows, addon.timingLines

local PATTERN = "Auctioneer scan: 1200 results | fetch %d+%.%ds | process %d+%.%ds | stats %d+%.%ds$"

describe("scan timing", function()
	local env, A
	before_each(function()
		env, A = addon.start()
	end)

	it("logs and prints one timing line per scan when debug is on", function()
		AuctioneerLocal.debug = true
		A.scan(rows(1200))
		local lines = timingLines(env.printed)
		assert.are.equal(1, #lines)
		assert.truthy(lines[1]:match(PATTERN))
		assert.truthy(AuctioneerLog[#AuctioneerLog]:match(PATTERN))
	end)

	it("prints nothing when debug is off", function()
		A.scan(rows(1200))
		assert.are.equal(0, #timingLines(env.printed))
	end)
end)
