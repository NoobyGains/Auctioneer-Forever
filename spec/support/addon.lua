-- Loads the real Auctioneer files against the stubs from support.wow.
local addon = {}

local function run(path, ...)
	local chunk, err = loadfile(path)
	if not chunk then error(err) end
	return chunk(...)
end

function addon.boot(env, opts)
	opts = opts or {}
	local A = {triggers = {}}

	run("Auctioneer/Main.lua", "Auctioneer", {})
	for _, file in ipairs({"Const", "Internal", "Handlers", "Statistics", "Items"}) do
		run("Auctioneer/" .. file .. ".lua")
	end

	local Auctioneer = _G.Auctioneer
	local gui = Auctioneer:Boot("GUI")
	gui.Components = {}
	gui.Money = function() end
	local parts = gui._

	Auctioneer:Booted()

	local trigger = Auctioneer.Trigger
	Auctioneer.Trigger = function(self, event, ...)
		table.insert(A.triggers, {name = parts.Const:Name(event), at = env.clock.now, args = {...}})
		return trigger(self, event, ...)
	end

	run("Auctioneer/Modules/Scanner/Scanner.lua")
	run("Auctioneer/Modules/Tooltip/Tooltip.lua")
	for _, file in ipairs(opts.files or {}) do
		run(file)
	end

	A.Auctioneer = Auctioneer
	A.parts = parts
	function A.module(name)
		for _, module in ipairs(parts.Internal.modules) do
			if module.name == name then return module end
		end
	end

	if opts.patch then opts.patch(A) end

	env.dispatch = function(event, ...) parts.Internal:OnEvent(event, ...) end
	env.dispatch("PLAYER_ENTERING_WORLD")
	env.dispatch("AUCTION_HOUSE_SHOW")

	function A.scan(rows, scanOpts)
		local first = #A.triggers + 1
		env.ah:load(rows, scanOpts)
		env.ah:search()
		env.clock:runUntilIdle(env.clock.now + 3600)

		local res = {items = {}}
		for i = first, #A.triggers do
			local t = A.triggers[i]
			if t.name == "ScannerItemsPush" then
				for _, item in ipairs(t.args[1]) do table.insert(res.items, item) end
			elseif t.name == "ScannerItemsCompleted" then
				res.completed, res.completedAt = t.args[1], t.at
			end
		end
		return res
	end

	return A
end

-- Spec helpers.
function addon.rows(n)
	local rows = {}
	for id = 1, n do rows[id] = {itemID = id, minPrice = 100 * id, totalQuantity = 1} end
	return rows
end

function addon.all(n)
	return addon.every(1, n)
end

function addon.every(k, n)
	local set = {}
	for id = k, n, k do set[id] = true end
	return set
end

function addon.pushedItems(A)
	local items = {}
	for _, t in ipairs(A.triggers) do
		if t.name == "ScannerItemsPush" then
			for _, item in ipairs(t.args[1]) do table.insert(items, item) end
		end
	end
	return items
end

function addon.completedCount(A)
	local n = 0
	for _, t in ipairs(A.triggers) do
		if t.name == "ScannerItemsCompleted" then n = n + 1 end
	end
	return n
end

function addon.timingLines(printed)
	local lines = {}
	for _, line in ipairs(printed) do
		if line:find("Auctioneer scan:", 1, true) == 1 then table.insert(lines, line) end
	end
	return lines
end

function addon.errorLines(printed)
	local n = 0
	for _, line in ipairs(printed) do
		if line:find("Error triggering", 1, true) then n = n + 1 end
	end
	return n
end

return addon
