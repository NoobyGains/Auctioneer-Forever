if not Auctioneer then return end

-- Create a new Auctioneer module.
local Module = Auctioneer:Module("Tooltip")
local Const = Auctioneer:Const()
Module.bootType = Const.BootType.PlayerEnteringWorld

-- Hook our methods.
function Module:Boot(hook)
	hook(Const.DisplayTooltip, Module.DisplayTooltip)
end

function Module:DisplayTooltip(type, tooltip, tip, ...)
	local link, quantity, name, quality
	if type == "item" then
		_, quantity, name, link, quality = ...
	elseif type == "battlepet" then
		link, quantity, name, _, breedQuality = ...
	else
		return
	end

	-- 1. Initialize the frame first
	tooltip:SetFrame(tip)

	-- 2. SAFE EXTRA FETCH
	-- We wrap this in a pcall or a check to prevent the nTipHelper error
	local additional
	local ok, err = pcall(function() additional = tooltip:GetExtra() end)
	
	-- If nTipHelper isn't ready, we create a dummy table to prevent crashes
	if not ok or not additional then
		additional = { event = "UNKNOWN" } 
	end

	quantity = tonumber(quantity) or 1
	tooltip:SetColor(0.3, 0.9, 0.8)
	tooltip:SetEmbed(true)

	local itemKey

	-- 3. PRIORITIZE THE DIRECT LINK (Like Informant/ATT)
	-- This bypasses the need for 'additional' data entirely for many items
	if link then
		itemKey = Auctioneer:ItemKeyFromLink(link)
	end

	-- 4. TRADESKILL SCRAPING (If link failed and we have UI context)
	if not itemKey and ProfessionsFrame and ProfessionsFrame:IsShown() then
		local schematicForm = ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
		if schematicForm and schematicForm.reagentSlots then
			for _, slot in ipairs(schematicForm.reagentSlots) do
				if slot.Button and slot.Button:IsMouseOver() then
					link = slot.Button:GetItemLink()
					if link then
						itemKey = Auctioneer:ItemKeyFromLink(link)
						break
					end
				end
			end
		end
	end

    -- ... Rest of your logic for SetBagItem / SetInventoryItem ...
    -- 3. FINAL VALIDATION (Safety from ATT)
    if not itemKey and link then
        itemKey = Auctioneer:ItemKeyFromLink(link)
    end

    if not itemKey then return end

	if not AuctioneerData.itemHasLevel[itemKey.itemID] then
		-- We have never even seen this item
		tooltip:AddLine("Never seen at auction")
	else
		local stats = Auctioneer:Statistics(Auctioneer:ItemKeyKey(itemKey))
		local variants
		if #stats == 0 then
			-- Random-suffix items ("of the Bear") are recorded per variant, which a link
			-- does not carry: find the variant by name.
			local variantKey
			variantKey, variants = self:MatchVariant(link, itemKey)
			if variantKey then
				itemKey = variantKey
				stats = Auctioneer:Statistics(Auctioneer:ItemKeyKey(itemKey))
			end
		end

		if variants then
			self:ShowAllVariants(tooltip, variants)
		else
			self:ShowStats(tooltip, stats)
		end
	end

	if Auctioneer:Debugging() then
		self:LogKey(link, itemKey)
	end

	tooltip:ClearFrame(tip)
end

-- The variant of a random-suffix item whose name matches the link's text. While the
-- variant names are still on their way (first hover), returns nil and all recorded variants.
function Module:MatchVariant(link, itemKey)
	local variants = Auctioneer:ItemVariants(itemKey.itemID)
	if not variants or not link then
		return
	end
	local name = select(3, LinkUtil.ExtractLink(link))
	name = name and (name:match("^%[(.*)%]$") or name)

	local keys = {}
	for suffix, level in pairs(variants) do
		local variantKey = C_AuctionHouse.MakeItemKey(itemKey.itemID, level, suffix)
		local info = C_AuctionHouse.GetItemKeyInfo(variantKey)
		if info and info.itemName == name then
			return variantKey
		end
		tinsert(keys, variantKey)
	end
	return nil, keys
end

-- Price range across all variants of an item, until the linked one is known.
function Module:ShowAllVariants(tooltip, variantKeys)
	local low, high
	for _, variantKey in ipairs(variantKeys) do
		for _, stat in ipairs(Auctioneer:Statistics(Auctioneer:ItemKeyKey(variantKey))) do
			local best = stat:Best()
			if best and best > 0 then
				if not low or best < low then low = best end
				if not high or best > high then high = best end
			end
		end
	end

	if not low then
		tooltip:AddLine("No statistics for this variant")
		return
	end
	tooltip:AddLine(format("Statistics (all %d variants):", #variantKeys))
	tooltip:AddLine("  lowest", low)
	tooltip:AddLine("  highest", high)
end

function Module:ShowStats(tooltip, stats)
	local header = "Statistics:"
	for _, stat in ipairs(stats) do
		local best, number, method = stat:Best()

		if best and number > 0 and best > 0 then
			if IsShiftKeyDown() then
				tooltip:AddLine(format("%s statistics:", stat.name))

				tooltip:AddLine(format(" - %s", method), best)

				local min, exact = stat:Minimum()
				if exact and min == exact and method ~= "minimum" then
					tooltip:AddLine(" - minimum", min)
				end

				local max, exact = stat:Maximum()
				if exact and max == exact and method ~= "maximum" then
					tooltip:AddLine(" - maximum", max)
				end

				local pct = stat:Percentile(10)
				if pct then
					tooltip:AddLine(" - 10th percentile", pct)
				end

				tooltip:AddLine(" - data points", "x"..number)
			else
				if header then
					tooltip:AddLine(header)
				end

				tooltip:AddLine(format("  %s %s (%d)", stat.name, method, number), best)
			end
			header = false
		end
	end

	if header then
		tooltip:AddLine("No statistics for this variant")
	end
end

-- Debug log of the item key a tooltip looked up. Tooltips rebuild constantly, so each
-- link is logged once per key (again only if a later scan changes its key).
function Module:LogKey(link, itemKey)
	local key = tostring(Auctioneer:ItemKeyKey(itemKey))
	local seen = tostring(link).."="..key
	self.loggedKeys = self.loggedKeys or {}
	if self.loggedKeys[seen] then
		return
	end
	self.loggedKeys[seen] = true
	Auctioneer:Log("tooltip %s -> item key %s (grouped by level: %s)",
		tostring(link), key, tostring(AuctioneerData.itemHasLevel[itemKey.itemID]))
end
