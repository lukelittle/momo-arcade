--!strict
--[[
	Trove: collects things that need cleaning up, then cleans them all at once.

		local trove = Trove.new()
		trove:Connect(RunService.Heartbeat, onHeartbeat)
		trove:Add(part)                 -- Instance -> :Destroy()
		trove:Add(function() ... end)   -- function -> called
		trove:Clean()                   -- everything above is released, newest first

	Supported items: Instance, RBXScriptConnection, thread, function, and tables with a
	Destroy or Disconnect method (e.g. Signal connections or another Trove).
]]

local Trove = {}
Trove.__index = Trove

type TroveData = {
	_items: { any },
	_cleaning: boolean,
}

export type Trove = typeof(setmetatable({} :: TroveData, Trove))

function Trove.new(): Trove
	return setmetatable({ _items = {}, _cleaning = false } :: TroveData, Trove)
end

function Trove.Add<T>(self: Trove, item: T): T
	table.insert(self._items, item)
	return item
end

function Trove.Connect(self: Trove, signal: RBXScriptSignal, handler: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(handler)
	table.insert(self._items, connection)
	return connection
end

local function cleanItem(item: any): ()
	local kind = typeof(item)
	if kind == "Instance" then
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "function" then
		item()
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Trove.Clean(self: Trove)
	if self._cleaning then
		return
	end
	self._cleaning = true
	-- Swap the list first so items added during cleanup land in a fresh list.
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		local result = table.pack(pcall(cleanItem, items[index]))
		if not result[1] then
			warn("[Trove] cleanup error:", result[2])
		end
	end
	self._cleaning = false
end

function Trove.Destroy(self: Trove)
	self:Clean()
end

return Trove
