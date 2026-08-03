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
		local key = Auctioneer:ItemKeyKey(itemKey)

		local stats = Auctioneer:Statistics(key)

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

	tooltip:ClearFrame(tip)
end
