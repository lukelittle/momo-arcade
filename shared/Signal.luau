--!strict
--[[
	Signal: a tiny typed event, no BindableEvent required.

		local changed = Signal.new() :: Signal.Signal<number>
		local conn = changed:Connect(function(value) print(value) end)
		changed:Fire(5)
		conn:Disconnect()

	Handlers run synchronously in the order they connected, so they should not yield.
	It is safe to disconnect (or connect) from inside a handler.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Slot<T...> = {
	connection: Connection,
	handler: (T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local slots: { Slot<T...> } = {}

	local function connect(_self: Signal<T...>, handler: (T...) -> ()): Connection
		local slot: Slot<T...>
		local connection: Connection = {
			Connected = true,
			Disconnect = function(self: Connection)
				if not self.Connected then
					return
				end
				self.Connected = false
				local index = table.find(slots, slot)
				if index then
					table.remove(slots, index)
				end
			end,
		}
		slot = { connection = connection, handler = handler }
		table.insert(slots, slot)
		return connection
	end

	local signal: Signal<T...>
	signal = {
		Connect = connect,
		Once = function(self: Signal<T...>, handler: (T...) -> ()): Connection
			local connection: Connection
			connection = connect(self, function(...: T...)
				connection:Disconnect()
				handler(...)
			end)
			return connection
		end,
		Fire = function(_self: Signal<T...>, ...: T...)
			-- Snapshot so handlers can safely disconnect while we iterate.
			for _, slot in table.clone(slots) do
				if slot.connection.Connected then
					slot.handler(...)
				end
			end
		end,
		DisconnectAll = function(_self: Signal<T...>)
			for _, slot in table.clone(slots) do
				slot.connection:Disconnect()
			end
		end,
	}
	return signal
end

return Signal
