if not Auctioneer then return end

-- Create a new Auctioneer module.
local Module = Auctioneer:Module("Scanner")
local Const = Auctioneer:Const()

-- We will fire this off when we have items.
Const.Trigger:Add("ScannerItemsPush")
Const.Trigger:Add("ScannerItemsCompleted")

local progressFrame

local PUSH_BLOCK_SIZE = 50
-- Soft budget for saving statistics, in ms per frame: checked after each block, so a frame can
-- run one block over it, and the first frame also carries Collect().
-- ponytail: fixed 8ms; tie it to the frame rate if 8ms ever stutters
local PUSH_FRAME_BUDGET_MS = 8

-- Hook our method
function Module:Boot(hook)
	hook(Const.BrowseResultsAvailable, Module.BrowseResultsAvailable)
	hook(Const.AuctionHouseOpened, Module.AuctionHouseOpened)
	hook(Const.AuctionHouseClosed, Module.AuctionHouseClosed)
	hook(Const.DisplayModeChanged, Module.DisplayModeChanged)
	hook(Const.ThrottledSystemReady, Module.ThrottledSystemReady)

	Module:CreateProgress()
end

-- Our job:
--   Page through the browse results until the auction house has sent them all.
--   Build an item from each browse result. Item key info (name, icon, quality)
--   is not needed to record prices, so the scan never waits for it; display
--   code fetches it lazily.
--   Push the items to the statistics modules.

function Module:BrowseResultsAvailable(type, results)
	-- We have some browse results here, so lets process them.
	self:Fetch(type, results)
end

function Module:AuctionHouseOpened()
	print("Welcome to Auctioneer, click the \"Search\" button to begin a scan")
	self:Reset()
end

function Module:AuctionHouseClosed()
	self:Push()
	self:Reset()
end

function Module:DisplayModeChanged(displayMode)
	if self.scanning and displayMode ~= AuctionHouseFrameDisplayMode.Buy then
		self:Push()
		self:Reset()
	end
end

-- Add the current browse results to our list and keep fetching more until we
-- have all the results loaded.
function Module:Fetch(type, results)
	if AuctionHouseFrame:GetDisplayMode() ~= AuctionHouseFrameDisplayMode.Buy then
		if self.scanning then
			self:Push()
			self:Reset()
		end
		return
	end

	if type == "updated" then
		self.scanning = true
		self.browseResults = C_AuctionHouse.GetBrowseResults()
		self.browseSize = 12000
		self:InvertedProgress(false)
		self.marks = {}
		self:Mark("start")
		Auctioneer:Log("scan started")
	elseif not self.scanning then
		return
	else
		tAppendAll(self.browseResults, results)
		Auctioneer:Log("page received: %d results so far", #self.browseResults)
	end

	local numResults = #self.browseResults
	if C_AuctionHouse.HasFullBrowseResults() then
		self:Mark("fetched")
		return self:Push()
	end

	if numResults > self.browseSize - 1000 then
		self.browseSize = self.browseSize + 1000
	end

	self:SetProgress(numResults/self.browseSize * 100,
		("Getting results: %d"):format(numResults))

	self:RequestMore()
end

-- Ask for the next page as soon as the client's throttle allows it. When it does
-- not, wait for AUCTION_HOUSE_THROTTLED_SYSTEM_READY, with a 1s retry as backstop
-- in case that event never comes.
function Module:RequestMore()
	if not self.scanning then
		return
	end
	if AuctionHouseFrame:GetDisplayMode() ~= AuctionHouseFrameDisplayMode.Buy then
		self:Push()
		self:Reset()
		return
	end

	if C_AuctionHouse.IsThrottledMessageSystemReady() then
		self.waitingThrottle = false
		C_AuctionHouse.RequestMoreBrowseResults()
		return
	end

	Auctioneer:Log("throttle wait")
	self.waitingThrottle = true
	if not self.backstopPending then
		self.backstopPending = true
		C_Timer.After(1.0, self.BackstopCallback)
	end
end

-- Retry the page request we are holding back for the throttle, if any.
function Module:ResumeAfterThrottle(reason)
	if self.waitingThrottle then
		Auctioneer:Log(reason)
		self:RequestMore()
	end
end

function Module:ThrottledSystemReady()
	self:ResumeAfterThrottle("throttle ready")
end

-- Static callback function to use in C_Timer.After calls
function Module.BackstopCallback()
	Module.backstopPending = false
	Module:ResumeAfterThrottle("throttle backstop retry")
end

-- Build an item from every browse result received so far.
function Module:Collect()
	local items = {}
	for _, itemData in ipairs(self.browseResults or {}) do
		--[[
		itemData = { itemKey, appearanceLink, totalQuantity, minPrice, containsOwnerItem }
		itemKey = { itemID, itemLevel, itemSuffix, battlePetSpeciesID }
		]]
		local itemKey = itemData.itemKey
		Auctioneer:RecordItemLevel(itemKey)
		Auctioneer:RecordVariant(itemKey)
		tinsert(items, Auctioneer:Item{
			id = Auctioneer:ItemKeyKey(itemKey),
			itemKey = itemKey,
			itemData = itemData,
		})
	end
	return items
end

-- Collate the browse results received so far and push them to the stats modules.
function Module:Push()
	if not self.scanning then
		return
	end
	self.scanning = false

	local items = self:Collect()
	-- This scan's timing travels with its push: a new scan may start meanwhile.
	local marks = self.marks
	self.marks = nil
	if marks then
		marks.processed = GetTime()
	end

	self:InvertedProgress(false)
	self:SetProgress(0, "Sending items")

	-- Push the items to the stats modules in blocks, as many blocks per frame as fit in
	-- the frame budget: a big scan is saved in a few frames without stalling the game.
	coroutine.wrap(function ()
		local co = coroutine.running()
		local function resume() coroutine.resume(co) end

		local pos = 1
		local size = #items
		local frameStart = debugprofilestop()
		while pos <= size do
			local to = math.min(pos + PUSH_BLOCK_SIZE - 1, size)
			Auctioneer:Trigger(Const.ScannerItemsPush, {unpack(items, pos, to)})
			self:SetProgress(to / size * 100, ("Statistics: %d"):format(to))
			pos = to + 1

			if pos <= size and debugprofilestop() - frameStart >= PUSH_FRAME_BUDGET_MS then
				C_Timer.After(0, resume)
				coroutine.yield()
				frameStart = debugprofilestop()
			end
		end
		-- Only the progress bar: a new scan may already be running.
		self:ClearProgress()

		-- The ScannerItemsCompleted listeners (Deal finder) are heavy: give them a frame of their own.
		C_Timer.After(0, resume)
		coroutine.yield()

		if marks then
			marks.pushed = GetTime()
		end
		self:ReportTiming(#items, marks)
		Auctioneer:Trigger(Const.ScannerItemsCompleted, items)
	end)()
end

-- Reset state.
function Module:Reset()
	self.scanning = false
	self:ClearProgress()
end

-- Scan timing: phases are marked as the scan goes; one line per finished scan.
function Module:Mark(phase)
	if self.marks then
		self.marks[phase] = GetTime()
	end
end

function Module:ReportTiming(count, marks)
	if not Auctioneer:Debugging() then
		return
	end
	if not (marks and marks.start and marks.fetched and marks.processed and marks.pushed) then
		return
	end
	local line = format("Auctioneer scan: %d results | fetch %.1fs | process %.1fs | stats %.1fs",
		count, marks.fetched - marks.start, marks.processed - marks.fetched, marks.pushed - marks.processed)
	Auctioneer:Log("%s", line)
	print(line)
end

function Module:CreateProgress()
	progressFrame = CreateFrame("STATUSBAR", "AuctioneerScannerFrame", AuctionHouseFrame)
	progressFrame:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT")
	progressFrame:SetWidth(200)
	progressFrame:SetHeight(20)
	progressFrame:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	progressFrame:GetStatusBarTexture():SetHorizTile(false)
	progressFrame:GetStatusBarTexture():SetVertTile(false)
	progressFrame:SetMinMaxValues(0, 100)
	progressFrame:Hide()

	progressFrame.bg = progressFrame:CreateTexture(nil, "BACKGROUND")
	progressFrame.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	progressFrame.bg:SetAllPoints(true)

	progressFrame.value = progressFrame:CreateFontString(nil, "OVERLAY")
	progressFrame.value:SetPoint("LEFT", progressFrame, "LEFT", 4, 0)
	progressFrame.value:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	progressFrame.value:SetJustifyH("LEFT")
	progressFrame.value:SetTextColor(0.6, 0.6, 0.6)

	progressFrame.Set = Module.SetProgress
	progressFrame.Clear = Module.ClearProgress
	progressFrame.Inverted = Module.InvertedProgress

	self:InvertedProgress(false)
end

function Module:InvertedProgress(invert)
	if invert then
		progressFrame:SetStatusBarColor(0.1, 0.1, 0.1)
		progressFrame.bg:SetVertexColor(0, 0.35, 0.65)
	else
		progressFrame:SetStatusBarColor(0, 0.35, 0.65)
		progressFrame.bg:SetVertexColor(0.1, 0.1, 0.1)
	end
	progressFrame.invert = invert
end

function Module:SetProgress(percent, text)
	progressFrame:Show()
	progressFrame:SetValue(percent)
	progressFrame.value:SetText(text)
end

function Module:ClearProgress()
	progressFrame:Hide()
end
