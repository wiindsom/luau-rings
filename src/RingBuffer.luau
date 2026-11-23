--!strict

--[[
Performant RingBuffer by the Wind(@windsomi)

Usage:
	const CircularBuffer = require("@self/CircularBuffer")
	const buf = CircularBuffer.create(256) --default is already 256 bytes btw
	
	const source = buffer.create(4)
	buffer.writeu32(source, 0, 12345)
	buf:Push(source)
	
	const target = buffer.create(4)
	buf:Peek(target) --Read without consuming
	buf:Pop(target)  --Read and consume
-------------------------------------------------------------------------------------------------------
Methods:
	:Reserve(additional)			--Ensure space for additional bytes
	:Push(source, offset?, count?)	--Append bytes
	:Peek(target, offset?, count?)	--Read without consuming
	:Pop(target, offset?, count?)	--Read and consume
	:Discard(count)					--Consume without copying
	:Clear()						--Remove all queued bytes
-------------------------------------------------------------------------------------------------------
Notes:
	-Offsets are ZERO BASED!!! all sizes are in bytes
	-Omitted offsets default to 0 hence why omitted counts use the remaining buffer length
	-Capacity grows automatically, up to 1 GiB(would be surprised if u make it up to this point)
	-Data exposes internal storage as read-only BUT do not modify it directly
]]

type API = {
	read Head: number;
	read Size: number;
	read Capacity: number;
	
	read Reserve: (self: API, additional: number) -> ();
	read Push: (self: API, source: buffer, offset: number?, count: number?) -> ();
	read Peek: (self: API, target: buffer, offset: number?, count: number?) -> ();
	read Pop: (self: API, target: buffer, offset: number?, count: number?) -> ();
	read Discard: (self: API, count: number) -> ();
	read Clear: (self: API) -> ();
}

type Internal = {
	Data: buffer;
	Head: number;
	Size: number;
	Capacity: number;
} & API

const MAX_CAPACITY = 1_073_741_824 --1 GiB is the max buffer size in roblox twin

const function _validRange(offset: number, count: number, length: number)
	return offset >= 0 and count >= 0
		and offset % 1 == 0 and count % 1 == 0
		and offset <= length and count <= length - offset
end

const function reserve(self: Internal, additional: number)
	if additional < 0 or additional % 1 ~= 0 then error("Invalid capacity request") end
	
	const required = self.Size + additional
	if required <= self.Capacity then return end
	if required > MAX_CAPACITY then error("Capacity exceeded") end
	
	local capacity = self.Capacity
	while capacity < required do capacity = math.min(capacity * 2, MAX_CAPACITY) end
	
	const data = buffer.create(capacity)
	const first = math.min(self.Size, self.Capacity - self.Head)
	buffer.copy(data, 0, self.Data, self.Head, first)
	if first < self.Size then
		buffer.copy(data, first, self.Data, 0, self.Size - first)
	end
	
	self.Data = data
	self.Head = 0
	self.Capacity = capacity
end

@native const function push(self: Internal, source: buffer, offset: number?, count: number?)
	const byte = offset or 0
	const length = buffer.len(source)
	const n = count or (length - byte)
	if offset ~= nil or count ~= nil then
		if not _validRange(byte, n, length) then error("Invalid source range") end
	end
	
	if n == 0 then return end
	if source == self.Data then error("Cannot write from internal storage") end
	
	const size = self.Size
	if size + n > self.Capacity then reserve(self, n) end
	
	const data = self.Data
	const capacity = self.Capacity
	local tail = self.Head + self.Size
	if tail >= capacity then tail -= capacity end
	
	if tail + n <= capacity then
		if n == 1 then
			buffer.writeu8(data, tail, buffer.readu8(source, byte))
		elseif n == 2 then
			buffer.writeu16(data, tail, buffer.readu16(source, byte))
		elseif n == 4 then
			buffer.writeu32(data, tail, buffer.readu32(source, byte))
		elseif n == 8 then
			const low = buffer.readu32(source, byte)
			const high = buffer.readu32(source, byte + 4)
			buffer.writeu32(data, tail, low)
			buffer.writeu32(data, tail + 4, high)
		else
			buffer.copy(data, tail, source, byte, n)
		end
	else
		const first = capacity - tail
		buffer.copy(data, tail, source, byte, first)
		buffer.copy(data, 0, source, byte + first, n - first)
	end
	
	self.Size += n
end

@native const function peek(self: Internal, target: buffer, offset: number?, count: number?)
	const byte = offset or 0
	const length = buffer.len(target)
	const n = count or (length - byte)
	if offset ~= nil or count ~= nil then
		if not _validRange(byte, n, length) then error("Invalid target range") end
	end
	
	if n > self.Size then error("Insufficient data") end
	if n == 0 then return end
	
	const data = self.Data
	if target == data then error("Cannot read into internal storage") end
	
	const head = self.Head
	const capacity = self.Capacity
	if head + n <= capacity then
		if n == 1 then
			buffer.writeu8(target, byte, buffer.readu8(data, head))
		elseif n == 2 then
			buffer.writeu16(target, byte, buffer.readu16(data, head))
		elseif n == 4 then
			buffer.writeu32(target, byte, buffer.readu32(data, head))
		elseif n == 8 then
			const low = buffer.readu32(data, head)
			const high = buffer.readu32(data, head + 4)
			buffer.writeu32(target, byte, low)
			buffer.writeu32(target, byte + 4, high)
		else
			buffer.copy(target, byte, data, head, n)
		end
	else
		const first = capacity - head
		buffer.copy(target, byte, data, head, first)
		buffer.copy(target, byte + first, data, 0, n - first)
	end
end

@native const function pop(self: Internal, target: buffer, offset: number?, count: number?)
	const byte = offset or 0
	const length = buffer.len(target)
	const n = count or (length - byte)
	if offset ~= nil or count ~= nil then
		if not _validRange(byte, n, length) then error("Invalid target range") end
	end
	
	const size = self.Size
	if n > size then error("Insufficient data") end
	if n == 0 then return end
	
	const data = self.Data
	if target == data then error("Cannot read into internal storage") end
	
	const head = self.Head
	const capacity = self.Capacity
	if head + n <= capacity then
		if n == 1 then
			buffer.writeu8(target, byte, buffer.readu8(data, head))
		elseif n == 2 then
			buffer.writeu16(target, byte, buffer.readu16(data, head))
		elseif n == 4 then
			buffer.writeu32(target, byte, buffer.readu32(data, head))
		elseif n == 8 then
			const low = buffer.readu32(data, head)
			const high = buffer.readu32(data, head + 4)
			buffer.writeu32(target, byte, low)
			buffer.writeu32(target, byte + 4, high)
		else
			buffer.copy(target, byte, data, head, n)
		end
	else
		const first = capacity - head
		buffer.copy(target, byte, data, head, first)
		buffer.copy(target, byte + first, data, 0, n - first)
	end
	
	const remaining = size - n
	local nextHead = head + n
	if nextHead >= capacity then nextHead -= capacity end
	
	self.Size = remaining
	self.Head = if remaining == 0 then 0 else nextHead
end

const function discard(self: Internal, count: number)
	if count < 0 or count % 1 ~= 0 or count > self.Size then error("Invalid discard count") end
	self.Head = (self.Head + count) % self.Capacity
	self.Size -= count
	if self.Size == 0 then self.Head = 0 end
end

const function clear(self: Internal)
	self.Head = 0
	self.Size = 0
end

const function create(capacity: number?): Internal
	const n = capacity or 256
	if n <= 0 or n > MAX_CAPACITY or n % 1 ~= 0 then error("Invalid capacity") end
	
	return {
		Data = buffer.create(n);
		Head = 0;
		Size = 0;
		Capacity = n;
		
		Reserve = reserve;
		Push = push;
		Peek = peek;
		Pop = pop;
		Discard = discard;
		Clear = clear;
	} :: Internal
end

return table.freeze({create = create :: (capacity: number?) -> API})