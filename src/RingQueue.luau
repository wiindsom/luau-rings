--!strict

--[[
Performant RingQueue by the Wind(@windsomi)

Usage:
	const CircularQueue = require("@self/CircularQueue")
	const queue = CircularQueue.create<<number>>(5)
	
	queue:Enqueue(10, 20, 30)
	queue:Enqueue(40)
	
	print(queue:PeekFront()) --10
	print(queue:PeekBack()) --40
	
	print(queue:Dequeue()) --10
	print(queue:Dequeue()) --20
	print(queue:Dequeue()) --30
	print(queue:Dequeue()) --40
-------------------------------------------------------------------------------------------------------
Methods:
	:Reserve(additional)	--Ensure space for additional elements
	:Enqueue(...)			--Enqueue one or multiple elements
	:PeekFront()			--Read first element without consuming
	:PeekBack()				--Read last element without consuming
	:Dequeue()				--Dequeue and return first element
	:Discard(count)			--Consume elements without returning them
	:Clear()				--Remove all queued elements
-------------------------------------------------------------------------------------------------------
Notes:
	-Indices are One based(its luau dawg); capacities are measured in elements
	-Default capacity is 256, growing automatically up to 67,108,864
	-Nil values are not supported(prevent conflicts with removal, not worth the extra complexity + overhead)
	-Removed references are cleared for garbage collection
]]

type API<T> = {
	read Head: number;
	read Size: number;
	read Capacity: number;
	
	read Reserve: (self: API<T>, additional: number) -> ();
	read Enqueue: (self: API<T>, ...T) -> ();
	read PeekFront: (self: API<T>) -> T;
	read PeekBack: (self: API<T>) -> T;
	read Dequeue: (self: API<T>) -> T;
	read Discard: (self: API<T>, count: number) -> ();
	read Clear: (self: API<T>) -> ();
}

type Internal<T> = {
	Data: {T?};
	Head: number;
	Size: number;
	Capacity: number;
} & API<T>

const MAX_CAPACITY = 67_108_864 --Roblox's max array length

const function reserve<T>(self: Internal<T>, additional: number)
	if additional < 0 or additional % 1 ~= 0 then error("Invalid capacity request") end
	
	const size = self.Size
	const required = size + additional
	if required <= self.Capacity then return end
	if required > MAX_CAPACITY then error("Capacity exceeded") end
	
	local capacity = self.Capacity
	while capacity < required do capacity = math.min(capacity * 2, MAX_CAPACITY) end
	
	const data = table.create(capacity) :: {T?}
	const head = self.Head
	const oldCapacity = self.Capacity
	if size > 0 then
		if head + size <= oldCapacity + 1 then
			table.move(self.Data, head, head + size - 1, 1, data)
		else
			const first = oldCapacity - head + 1
			table.move(self.Data, head, oldCapacity, 1, data)
			table.move(self.Data, 1, size - first, first + 1, data)
		end
	end
	
	self.Data = data
	self.Head = 1
	self.Capacity = capacity
end

@native const function enqueue<T>(self: Internal<T>, ...: T)
	const count = select("#", ...)
	if count == 0 then return end
	if count == 1 then
		const value = ...
		if value == nil then error("Cannot enqueue nil") end
		if self.Size == self.Capacity then reserve(self, 1) end
		
		const capacity = self.Capacity
		local tail = self.Head + self.Size
		if tail > capacity then tail -= capacity end
		
		self.Data[tail] = value
		self.Size += 1
		return
	end
	if count == 4 then
		const a, b, c, d = ...
		if a == nil or b == nil or c == nil or d == nil then error("Cannot enqueue nil") end
		if self.Size + 4 > self.Capacity then reserve(self, 4) end
		
		const data = self.Data
		const capacity = self.Capacity
		local tail = self.Head + self.Size
		if tail > capacity then tail -= capacity end
		
		if tail + 3 <= capacity then
			data[tail] = a
			data[tail + 1] = b
			data[tail + 2] = c
			data[tail + 3] = d
		else
			data[tail] = a
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = b
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = c
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = d
		end
		
		self.Size += 4
		return
	end
	if count == 8 then
		const a, b, c, d, e, f, g, h = ...
		if a == nil or b == nil or c == nil or d == nil
			or e == nil or f == nil or g == nil or h == nil then
			error("Cannot enqueue nil")
		end
		if self.Size + 8 > self.Capacity then reserve(self, 8) end
		
		const data = self.Data
		const capacity = self.Capacity
		local tail = self.Head + self.Size
		if tail > capacity then tail -= capacity end
		if tail + 7 <= capacity then
			data[tail] = a
			data[tail + 1] = b
			data[tail + 2] = c
			data[tail + 3] = d
			data[tail + 4] = e
			data[tail + 5] = f
			data[tail + 6] = g
			data[tail + 7] = h
		else
			data[tail] = a
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = b
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = c
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = d
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = e
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = f
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = g
			tail += 1; if tail > capacity then tail = 1 end
			data[tail] = h
		end
		self.Size += 8
		return
	end
	
	for i = 1, count do
		if select(i, ...) == nil then error("Cannot enqueue nil") end
	end
	
	const size = self.Size
	if size + count > self.Capacity then reserve(self, count) end
	
	const data = self.Data
	const capacity = self.Capacity
	local tail = self.Head + self.Size
	if tail > capacity then tail -= capacity end
	
	for i = 1, count do
		data[tail] = select(i, ...)
		tail += 1
		if tail > capacity then tail = 1 end
	end
	
	self.Size += count
end

const function peekFront<T>(self: Internal<T>): T
	if self.Size == 0 then error("Queue is empty") end
	return self.Data[self.Head] :: T
end

const function peekBack<T>(self: Internal<T>): T
	const size = self.Size
	if size == 0 then error("Queue is empty") end
	
	local index = self.Head + size - 1
	if index > self.Capacity then index -= self.Capacity end
	
	return self.Data[index] :: T
end

@native const function dequeue<T>(self: Internal<T>): T
	const size = self.Size
	if size == 0 then error("Queue is empty") end
	
	const head = self.Head
	const data = self.Data
	const value = data[head] :: T
	data[head] = nil
	
	if size == 1 then
		self.Size = 0
		self.Head = 1
	else
		self.Size = size - 1
		self.Head = if head == self.Capacity then 1 else head + 1
	end
	
	return value
end

@native const function discard<T>(self: Internal<T>, count: number)
	const size = self.Size
	if count < 0 or count % 1 ~= 0 or count > size then error("Invalid discard count") end
	if count == 0 then return end
	
	const data = self.Data
	const capacity = self.Capacity
	const head = self.Head
	
	if count == 1 then
		data[head] = nil
		
		const remaining = size - 1
		local nextHead = head + 1
		if nextHead > capacity then nextHead = 1 end
		
		self.Size = remaining
		self.Head = if remaining == 0 then 1 else nextHead
		return
	end
	if count == size and size * 16 >= capacity then
		table.clear(data)
		self.Head = 1
		self.Size = 0
		return
	end
	
	const first = math.min(count, capacity - head + 1)
	for i = head, head + first - 1 do
		data[i] = nil
	end
	if first < count then
		for i = 1, count - first do
			data[i] = nil
		end
	end
	
	local nextHead = head + count
	if nextHead > capacity then nextHead -= capacity end
	
	self.Head = if count == size then 1 else nextHead
	self.Size = size - count
end

@native const function clear<T>(self: Internal<T>)
	const size = self.Size
	if size == 0 then return end
	
	const data = self.Data
	const capacity = self.Capacity
	if size * 16 < capacity then
		const head = self.Head
		const first = math.min(size, capacity - head + 1)
		for i = head, head + first - 1 do
			data[i] = nil
		end
		if first < size then
			for i = 1, size - first do
				data[i] = nil
			end
		end
	else
		table.clear(data)
	end
	
	self.Head = 1
	self.Size = 0
end

const function create<T>(capacity: number?): Internal<T>
	const n = capacity or 256
	if n <= 0 or n > MAX_CAPACITY or n % 1 ~= 0 then error("Invalid capacity") end
	
	return {
		Data = table.create(n);
		Head = 1;
		Size = 0;
		Capacity = n;
		
		Reserve = reserve;
		Enqueue = enqueue;
		PeekFront = peekFront;
		PeekBack = peekBack;
		Dequeue = dequeue;
		Discard = discard;
		Clear = clear;
	} :: Internal<T>
end

return table.freeze({create = (create :: any) :: <T>(capacity: number?) -> API<T>})