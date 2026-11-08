local wow, addon = require("support.wow"), require("support.addon")
local rows = addon.rows

describe("browse paging", function()
	local env, A
	before_each(function()
		env = wow.install()
		A = addon.boot(env)
	end)

	it("requests the next page as soon as the throttle allows", function()
		A.scan(rows(10000)) -- 20 pages, no throttle gap
		assert.is_true(env.ah.fullAt < 1.5)
	end)

	it("waits for the throttle-ready event instead of dropping requests", function()
		AuctioneerLocal.debug = true
		local res = A.scan(rows(10000), {throttleGap = 0.3})
		assert.are.equal(10000, #res.items)
		assert.are.equal(0, env.ah.droppedRequests)
		assert.is_true(env.ah.fullAt < 19 * 0.3 + 20 * 0.05 + 0.5)
		assert.truthy(table.concat(AuctioneerLog, "\n"):find("throttle wait", 1, true))
	end)

	it("finishes when the throttle-ready event never fires", function()
		local res = A.scan(rows(10000), {throttleGap = 0.3, silentThrottle = true})
		assert.are.equal(10000, #res.items)
	end)
end)
