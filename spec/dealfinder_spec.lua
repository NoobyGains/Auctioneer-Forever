local wow, addon = require("support.wow"), require("support.addon")
local errorLines = addon.errorLines

describe("DealFinder", function()
	local env, A, statsFor

	local function stat(price, n)
		return {
			name = "S",
			Number = function() return n end,
			Percentile = function() return price end,
			Minimum = function() return price end,
		}
	end

	before_each(function()
		statsFor = {}
		env = wow.install()
		A = addon.boot(env, {
			files = {"Auctioneer_Util_DealFinder/Main.lua"},
			patch = function(A)
				A.module("Util:DealFinder").Display = function() end
				A.Auctioneer.Statistics = function() return statsFor end
			end,
		})
	end)

	it("compares several statistics without a Lua error", function()
		statsFor = {stat(500, 10), stat(400, 10)}
		A.scan({{itemID = 1, minPrice = 100, totalQuantity = 1}})
		assert.are.equal(0, errorLines(env.printed))
		assert.are.equal("arbitrage", A.module("Util:DealFinder").deals[1][3])
	end)

	it("flags an item below its vendor price when the item is cached", function()
		env.items[1] = {vendorPrice = 300, cached = true}
		A.scan({{itemID = 1, minPrice = 100, totalQuantity = 1}})
		assert.are.equal("vendor", A.module("Util:DealFinder").deals[1][3])
	end)

	it("redraws once for a burst of item key info arrivals", function()
		local finder = A.module("Util:DealFinder")
		local draws = 0
		finder.Display = function() draws = draws + 1 end
		finder.deals = {}
		for itemID = 1, 10 do env.dispatch("ITEM_KEY_ITEM_INFO_RECEIVED", itemID) end
		env.clock:advance(0.5)
		assert.are.equal(1, draws)
	end)

	it("skips a statistic that has no price", function()
		statsFor = {stat(400, 10), stat(nil, 10)}
		A.scan({{itemID = 1, minPrice = 100, totalQuantity = 1}})
		assert.are.equal(0, errorLines(env.printed))
	end)
end)
