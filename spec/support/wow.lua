-- Stubbed WoW client API for running the real addon files under busted.
-- Time is virtual: nothing waits, timers run when the clock is advanced.
local wow = {}

-- Null object: PascalCase keys (WoW methods and child frames) give another callable null
-- object, so UI code runs without a client. Lowercase keys are plain fields and read nil,
-- like on a real frame (Main.lua stores its own state, e.g. `booted`, on a frame).
local nullMT = {}
local function null() return setmetatable({}, nullMT) end
nullMT.__index = function(_, key)
	if type(key) == "string" and key:match("^%u") then return null() end
end
nullMT.__call = function() return null() end
nullMT.__concat = function() return "" end
nullMT.__tostring = function() return "" end
-- Sizes and offsets read from a null frame (e.g. -frame:GetWidth()) count as 0.
local function zero() return 0 end
nullMT.__unm, nullMT.__add, nullMT.__sub, nullMT.__mul, nullMT.__div = zero, zero, zero, zero, zero
wow.null = null

local function newClock()
	local clock = {now = 0, timers = {}, seq = 0}

	function clock:after(delay, fn)
		self.seq = self.seq + 1
		table.insert(self.timers, {at = self.now + (delay or 0), seq = self.seq, fn = fn})
	end

	local function popDue(self, limit)
		local best, index
		for i, t in ipairs(self.timers) do
			if not best or t.at < best.at or (t.at == best.at and t.seq < best.seq) then
				best, index = t, i
			end
		end
		if best and best.at <= limit then
			table.remove(self.timers, index)
			return best
		end
	end

	function clock:runUntilIdle(limit)
		limit = limit or math.huge
		while true do
			local t = popDue(self, limit)
			if not t then return end
			if t.at > self.now then self.now = t.at end
			t.fn()
		end
	end

	function clock:advance(dt)
		local target = self.now + dt
		self:runUntilIdle(target)
		self.now = target
	end

	return clock
end

local function toBrowseResult(row)
	return {
		itemKey = {
			itemID = row.itemID,
			itemLevel = row.itemLevel or 0,
			itemSuffix = row.itemSuffix or 0,
			battlePetSpeciesID = row.battlePetSpeciesID or 0,
		},
		minPrice = row.minPrice,
		totalQuantity = row.totalQuantity,
		containsOwnerItem = false,
	}
end

-- Fake auction house server behind C_AuctionHouse.
local function newAH(env)
	local ah = {gen = 0}

	function ah:load(rows, opts)
		opts = opts or {}
		self.gen = self.gen + 1 -- callbacks from an earlier load are dropped
		self.rows = rows or {}
		self.opts = opts
		self.pageSize = opts.pageSize or 500
		self.pageLatency = opts.pageLatency or 0.05
		self.throttleGap = opts.throttleGap or 0
		self.infoLatency = opts.infoLatency or 0.05
		self.missingInfo = opts.missingInfo or {}
		self.delivered = {}
		self.readyAt = 0
		self.fullAt = nil
		self.infoCalls, self.pageRequests, self.droppedRequests = 0, 0, 0
		self.infoCache, self.infoScheduled = {}, {}
	end

	function ah:deliver()
		local page = {}
		local from = #self.delivered + 1
		for i = from, math.min(from + self.pageSize - 1, #self.rows) do
			local result = toBrowseResult(self.rows[i])
			table.insert(self.delivered, result)
			table.insert(page, result)
		end
		if #self.delivered == #self.rows and not self.fullAt then
			self.fullAt = env.clock.now
		end
		return page
	end

	function ah:scan()
		self.delivered = {}
		self.fullAt = nil
		self:deliver()
		env.dispatch("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
	end

	local api = {}

	function api.GetBrowseResults()
		local copy = {}
		for i, r in ipairs(ah.delivered) do copy[i] = r end
		return copy
	end

	function api.HasFullBrowseResults()
		return #ah.delivered == #ah.rows
	end

	function api.IsThrottledMessageSystemReady()
		return env.clock.now >= ah.readyAt
	end

	function api.RequestMoreBrowseResults()
		if env.clock.now < ah.readyAt then
			ah.droppedRequests = ah.droppedRequests + 1
			return
		end
		ah.pageRequests = ah.pageRequests + 1
		ah.readyAt = env.clock.now + ah.throttleGap
		local gen = ah.gen
		env.clock:after(ah.pageLatency, function()
			if gen ~= ah.gen then return end
			env.dispatch("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", ah:deliver())
		end)
		if ah.throttleGap > 0 and not ah.opts.silentThrottle then
			env.clock:after(ah.throttleGap, function()
				if gen ~= ah.gen then return end
				env.dispatch("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
			end)
		end
	end

	-- Item key info is per variant: cached under the itemID, or "itemID:suffix" for a
	-- random-suffix variant, whose name comes from env.variantNames["itemID:suffix"].
	function api.GetItemKeyInfo(itemKey)
		ah.infoCalls = ah.infoCalls + 1
		local id = itemKey.itemID
		local suffix = itemKey.itemSuffix or 0
		local cacheKey = suffix ~= 0 and (id .. ":" .. suffix) or id
		if ah.infoCache[cacheKey] then
			return ah.infoCache[cacheKey]
		end
		if not ah.missingInfo[id] and not ah.infoScheduled[cacheKey] then
			ah.infoScheduled[cacheKey] = true
			local gen = ah.gen
			env.clock:after(ah.infoLatency, function()
				if gen ~= ah.gen then return end
				local item = env.items[id]
				ah.infoCache[cacheKey] = {
					itemName = env.variantNames[cacheKey] or item and item.name or ("Item " .. id),
					quality = 1, iconFileID = 1,
					isPet = false, isCommodity = false, isEquipment = false,
				}
				env.dispatch("ITEM_KEY_ITEM_INFO_RECEIVED", id)
			end)
		end
		return nil
	end

	function api.MakeItemKey(itemID, itemLevel, itemSuffix, battlePetSpeciesID)
		return {
			itemID = itemID,
			itemLevel = itemLevel or 0,
			itemSuffix = itemSuffix or 0,
			battlePetSpeciesID = battlePetSpeciesID or 0,
		}
	end

	function api.GetItemKeyFromItem()
		return nil
	end

	ah.api = api
	ah:load({})
	return ah
end

local function linkItemID(link)
	return tonumber(tostring(link):match("|Hitem:(%d+)"))
end

local function strsplit(delim, str)
	local out, start = {}, 1
	while true do
		local i, j = string.find(str, delim, start, true)
		if not i then
			table.insert(out, string.sub(str, start))
			break
		end
		table.insert(out, string.sub(str, start, i - 1))
		start = j + 1
	end
	return unpack(out)
end

function wow.link(itemID, suffix, name)
	return ("|cffffffff|Hitem:%d::::::%s::|h[%s]|h|r"):format(itemID, suffix and tostring(suffix) or "", name or ("Item " .. itemID))
end

function wow.petLink(speciesID)
	return ("|cff0070dd|Hbattlepet:%d:1:3:100:10:10:0|h[Pet]|h|r"):format(speciesID)
end

-- Installs fresh globals. Call once per test.
function wow.install()
	local env = {printed = {}, etrace = {}, loadedAddOns = {}, items = {}, variantNames = {}}
	env.clock = newClock()
	env.dispatch = function() end
	env.ah = newAH(env)

	_G.Auctioneer = nil
	_G.AuctioneerData = nil
	_G.AuctioneerLocal = nil
	_G.AuctioneerLog = nil
	_G.AuctioneerStatsOverTimeData = nil
	_G.AuctioneerUtilDealFinderData = nil

	-- Lua aliases the client defines.
	_G.strsplit = strsplit
	_G.strsub = string.sub
	_G.strmatch = string.match
	_G.format = string.format
	_G.floor = math.floor
	_G.tinsert = table.insert
	_G.sort = table.sort
	_G.date = os.date
	_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
	_G.tAppendAll = function(t, src) for _, v in ipairs(src) do table.insert(t, v) end end

	_G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		table.insert(env.printed, table.concat(parts, " "))
	end

	_G.GetTime = function() return env.clock.now end
	_G.GetServerTime = function() return 1800000000 + math.floor(env.clock.now) end
	_G.GetRealmName = function() return "TestRealm" end
	_G.IsShiftKeyDown = function() return false end
	-- In the client no timer fires before the next frame, whatever delay it asks for.
	local FRAME = 1 / 60
	_G.C_Timer = {After = function(delay, fn) env.clock:after(math.max(delay or 0, FRAME), fn) end}
	-- CPU milliseconds; time spent inside a frame. Specs advance it (see env.pushCostMs).
	env.cpuMs = 0
	_G.debugprofilestop = function() return env.cpuMs end

	_G.Stubby = true
	_G.LibStub = function() return null() end
	_G.hooksecurefunc = function() end
	_G.CreateFrame = function(_, name)
		local frame = null()
		if name then
			rawset(frame, "GetName", function() return name end)
			_G[name] = frame
			_G[name .. "Low"], _G[name .. "High"], _G[name .. "Text"] = null(), null(), null()
		end
		return frame
	end

	_G.C_AddOns = {
		IsAddOnLoaded = function() return false end,
		LoadAddOn = function(name) table.insert(env.loadedAddOns, name) end,
	}
	_G.EventTrace = {LogMessage = function(_, msg) table.insert(env.etrace, msg) end}

	_G.Enum = {AuctionHouseSortOrder = {Price = 0, Name = 1}}
	_G.AuctionHouseFrameDisplayMode = setmetatable({}, {__index = function(_, k) return k end})
	_G.AuctionHouseFrame = null()
	rawset(_G.AuctionHouseFrame, "GetDisplayMode", function() return AuctionHouseFrameDisplayMode.Buy end)
	_G.ITEM_QUALITY_COLORS = setmetatable({}, {__index = function() return {hex = "|cffffffff"} end})

	_G.LinkUtil = {
		ExtractLink = function(link)
			-- Same pattern as the client's LinkUtil: the display text keeps its [brackets].
			return tostring(link):match("|H([^:]*):([^|]*)|h(.*)|h")
		end,
	}

	local function item(id) return env.items[id] end
	_G.C_Item = {
		GetItemNameByID = function(id) return item(id) and item(id).name end,
		GetItemQualityByID = function(id) return item(id) and item(id).quality end,
		GetItemIconByID = function(id) return item(id) and 1 end,
		GetItemInventoryTypeByID = function() return 0 end,
		IsItemDataCachedByID = function(id) return item(id) and item(id).cached or false end,
		GetItemInfo = function(id)
			local it = item(id)
			if not it then return end
			return it.name, nil, it.quality, it.level, 1, nil, nil, 1, nil, 1, it.vendorPrice
		end,
		GetDetailedItemLevelInfo = function(link)
			local it = item(linkItemID(link))
			return it and it.level
		end,
	}

	_G.C_AuctionHouse = env.ah.api
	return env
end

return wow
