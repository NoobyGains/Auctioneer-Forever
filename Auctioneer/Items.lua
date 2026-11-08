local Items = Auctioneer:Boot("Items")

local Item = {
	--[[

	id: string, The ID that Auctioneer uses to fetch statistics for this item.
	itemKey: {
		itemID,
		itemLevel,
		itemSuffix,
		battlePetSpeciesID
	},
	itemInfo: {
		itemName,
		battlePetLink,
		quality,
		iconFileID,
		isPet,
		isCommodity,
		isEquipment
	},
	itemData: {
		itemKey,
		appearanceLink,
		totalQuantity,
		minPrice,
		containsOwnerItem
	},

	]]
}

-- Gets additional information from the item's link.
function Item:Info()
	if self._info then
		return self._info
	end

	local info = Items:InfoStruct(self)
	-- Item key info can arrive after the item is first shown; keep the result only once it has.
	if self.itemInfo then
		self._info = info
	end
	return info
end

-- Vendor sell price, only when the client already has the item cached: asking for
-- an uncached item sends a server request, which a scan must not do per item.
function Item:VendorPrice()
	local itemID = self.itemKey.itemID
	if C_Item.IsItemDataCachedByID(itemID) then
		return select(11, C_Item.GetItemInfo(itemID))
	end
end

function Item:ID()
	if not self.id then
		self.id = Auctioneer:ItemKeyKey(self.itemKey)
	end
	return self.id
end

local meta = {__index = Item}
function Items:NewItem(n)
	n = n or {}
	if getmetatable(n) then
		error("Auctioneer: New Item object already has metatable")
	end
	setmetatable(n, meta)
	return n
end

function Items:InfoStruct(item)
	local info = {}

	if not item.itemInfo then
		item.itemInfo = C_AuctionHouse.GetItemKeyInfo(item.itemKey)
	end

	-- Item key info is fetched lazily and may not have arrived yet.
	local keyInfo = item.itemInfo or {}
	info.name = keyInfo.itemName
	info.icon = keyInfo.iconFileID
	info.quality = keyInfo.quality

	if item.itemKey.battlePetSpeciesID > 0 then
		info.link = keyInfo.battlePetLink
	else
		if item.itemData then
			info.link = item.itemData.appearanceLink
		end

		local itemID = item.itemKey.itemID
		if not info.name then
			info.name = C_Item.GetItemNameByID(itemID)
		end
		if not info.quality then
			info.quality = C_Item.GetItemQualityByID(itemID)
		end
		if not info.icon then
			info.icon = C_Item.GetItemIconByID(itemID)
		end

		info.inventoryType = C_Item.GetItemInventoryTypeByID(itemID)
		info.vendorPrice = item:VendorPrice()
	end

	if info.quality then
		info.color = strsub(ITEM_QUALITY_COLORS[info.quality].hex, 3)
	elseif info.link then
		info.color = strmatch(info.link, "^|c([0-9a-f]+)|H")
	end

	if not info.color then
		info.color = "ff604040"
	end

	if not info.name then
		if info.link then
			info.name = select(3, LinkUtil.ExtractLink(info.link))
		else
			info.name = Auctioneer:ItemKeyString(item.itemKey)
		end
	end

	return info
end
