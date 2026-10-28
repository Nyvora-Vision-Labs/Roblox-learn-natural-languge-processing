--!strict
-- Tracks connections, instances, threads, callbacks and objects with destroy();
-- one destroy() call releases all of them, newest first.

export type Cleanup = {
	add: <T>(self: Cleanup, item: T) -> T,
	connect: (self: Cleanup, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	destroy: (self: Cleanup) -> (),
}

local Cleanup = {}
Cleanup.__index = Cleanup

function Cleanup.new(): Cleanup
	local self = setmetatable({ _items = {} :: { any }, _destroyed = false }, Cleanup)
	return (self :: any) :: Cleanup
end

local function release(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "function" then
		item()
	elseif kind == "table" and type(item.destroy) == "function" then
		item:destroy()
	end
end

function Cleanup.add(self: any, item: any): any
	if self._destroyed then
		-- Added after destroy (e.g. from a late callback): release immediately.
		release(item)
	else
		table.insert(self._items, item)
	end
	return item
end

function Cleanup.connect(self: any, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	return self:add(signal:Connect(fn))
end

function Cleanup.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(release, items[i])
		if not ok then
			task.spawn(error, err) -- surface it without skipping the remaining items
		end
	end
end

return Cleanup
