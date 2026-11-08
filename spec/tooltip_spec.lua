local wow, addon = require("support.wow"), require("support.addon")

describe("tooltip debug log", function()
	local env, A, tooltip

	before_each(function()
		env, A = addon.start()
		tooltip = A.module("Tooltip")
		AuctioneerLocal.debug = true
	end)

	local function hover(link)
		tooltip:DisplayTooltip("item", wow.null(), wow.null(), nil, 1, "Item", link, 1)
	end

	local function tooltipLines()
		local n = 0
		for _, line in ipairs(AuctioneerLog or {}) do
			if line:find("tooltip ", 1, true) then n = n + 1 end
		end
		return n
	end

	it("logs a link's item key once while its tooltip keeps refreshing", function()
		hover(wow.link(2589)); hover(wow.link(2589)); hover(wow.link(2589))
		assert.are.equal(1, tooltipLines())
	end)

	it("does not log a link again when the mouse moves back to it", function()
		hover(wow.link(2589)); hover(wow.link(4306)); hover(wow.link(2589))
		assert.are.equal(2, tooltipLines())
	end)

	it("does not throw on a link without an item number", function()
		hover("|cffffffff|Hitem:abc::|h[Broken]|h|r")
	end)
end)
