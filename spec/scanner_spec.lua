local addon = require("support.addon")
local rows, all, every = addon.rows, addon.all, addon.every
local pushedItems, completedCount = addon.pushedItems, addon.completedCount

describe("scanner", function()
	local env, A
	before_each(function()
		env, A = addon.start()
	end)

	it("records every browse result even when item key info never arrives", function()
		local res = A.scan(rows(2000), {missingInfo = all(2000)})
		assert.are.equal(2000, #res.items)
		assert.are.equal(1500 * 100, res.items[1500].itemData.minPrice)
		assert.are.equal(0, env.ah.infoCalls)
	end)

	it("finishes within 2 virtual seconds of the last page", function()
		local res = A.scan(rows(2000), {missingInfo = every(20, 2000)})
		assert.is_true(res.completedAt - env.ah.fullAt < 2)
	end)

	it("saves a full scan's statistics within one second of the last page", function()
		local res = A.scan(rows(9876))
		assert.are.equal(9876, #res.items)
		assert.is_true(res.completedAt - env.ah.fullAt < 1)
	end)

	it("keeps each frame's statistics work within the frame budget", function()
		env.pushCostMs = 5
		A.scan(rows(2000))
		local perFrame, most = {}, 0
		for _, t in ipairs(A.triggers) do
			if t.name == "ScannerItemsPush" then
				perFrame[t.at] = (perFrame[t.at] or 0) + 1
				most = math.max(most, perFrame[t.at])
			end
		end
		-- 8ms budget, plus the one block that crosses it
		assert.is_true(most * env.pushCostMs <= 8 + env.pushCostMs)
		assert.are.equal(2000, #pushedItems(A))
	end)

	it("pushes a single-result scan", function()
		assert.are.equal(1, #A.scan(rows(1)).items)
	end)

	it("completes an empty scan", function()
		local res = A.scan({})
		assert.are.same({}, res.completed)
	end)

	it("learns whether the auction house groups an item by level", function()
		A.scan({
			{itemID = 10, minPrice = 1, totalQuantity = 1},
			{itemID = 20, itemLevel = 60, minPrice = 1, totalQuantity = 1},
		})
		assert.are.equal(0, AuctioneerData.itemHasLevel[10])
		assert.are.equal(1, AuctioneerData.itemHasLevel[20])
	end)

	it("records the pages received when the auction house closes mid-scan", function()
		env.ah:load(rows(2000), {pageLatency = 1.0})
		env.ah:scan()
		env.clock:advance(1.5) -- first page plus one more page = 1000 rows
		env.dispatch("AUCTION_HOUSE_CLOSED")
		env.clock:runUntilIdle(3600)
		assert.are.equal(1000, #pushedItems(A))
	end)

	it("does not push again when the auction house closes after a finished scan", function()
		A.scan(rows(300))
		env.dispatch("AUCTION_HOUSE_CLOSED")
		env.clock:runUntilIdle(3600)
		assert.are.equal(300, #pushedItems(A))
	end)

	it("records both scans when a new scan starts while statistics are pushing", function()
		env.ah:load(rows(2000))
		env.ah:scan()
		repeat env.clock:advance(0.01) until #pushedItems(A) > 0 -- first scan is now pushing
		env.ah:load(rows(100))
		env.ah:scan()
		env.clock:runUntilIdle(3600)
		assert.are.equal(2100, #pushedItems(A))
		assert.are.equal(2, completedCount(A))
	end)
end)
