local wow, addon = require("support.wow"), require("support.addon")

-- Random-suffix items ("of the Bear") are recorded per variant (itemID:level:suffix),
-- while a link names the variant only by its text.
describe("tooltip price of a random-suffix item", function()
	local env, A, tooltip, lines

	local BEAR, FALCON = 14302, 14304
	local BEAR_LINK = wow.link(9756, nil, "Calçotes Nômades do Urso")

	before_each(function()
		env, A = addon.start({files = {"Auctioneer_Stats_OverTime/Main.lua"}})
		tooltip = A.module("Tooltip")
		env.variantNames["9756:" .. BEAR] = "Calçotes Nômades do Urso"
		env.variantNames["9756:" .. FALCON] = "Calçotes Nômades do Falcão"
		A.scan({
			{itemID = 9756, itemLevel = 14, itemSuffix = BEAR, minPrice = 500, totalQuantity = 1},
			{itemID = 9756, itemLevel = 14, itemSuffix = FALCON, minPrice = 900, totalQuantity = 1},
		})
	end)

	local function hover(link)
		lines = {}
		local tt = wow.null()
		rawset(tt, "AddLine", function(_, text, money) table.insert(lines, {text = text, money = money}) end)
		tooltip:DisplayTooltip("item", tt, wow.null(), nil, 1, "Item", link, 2)
	end

	local function prices()
		local found = {}
		for _, line in ipairs(lines) do
			if type(line.money) == "number" then table.insert(found, line.money) end
		end
		table.sort(found)
		return found
	end

	it("records which variants each item was seen with", function()
		assert.are.same({[BEAR] = 14, [FALCON] = 14}, AuctioneerData.itemVariants[9756])
	end)

	it("records variants into saved data from before the variants list existed", function()
		-- The client loads saved variables after the addon's files ran, replacing AuctioneerData.
		_G.AuctioneerData = {itemHasLevel = {}}
		A.scan({{itemID = 6269, itemLevel = 12, itemSuffix = 14308, minPrice = 1, totalQuantity = 1}})
		assert.are.same({[14308] = 12}, AuctioneerData.itemVariants[6269])
	end)

	it("shows all variants together while their names are still loading", function()
		hover(BEAR_LINK)
		assert.are.equal("Statistics (all 2 variants):", lines[1].text)
		assert.are.same({500, 900}, prices())
	end)

	it("shows the linked variant's own price once the names have arrived", function()
		hover(BEAR_LINK)
		env.clock:runUntilIdle(env.clock.now + 1)
		hover(BEAR_LINK)
		assert.are.equal("Statistics:", lines[1].text)
		assert.are.same({500}, prices())
	end)
end)
