# luau-rings

RingBuffer and RingQueue implementations for Roblox Luau. Both use circular storage and grow automatically when needed.

### Download the usage example from [GitHub Releases](https://github.com/wiindsom/luau-rings/releases/latest)

## Usage

### RingBuffer

```lua
local RingBuffer = require("@self/RingBuffer")

local ring = RingBuffer.create(8)
local source = buffer.create(4)
buffer.writeu32(source, 0, 12345)

ring:Push(source)

local target = buffer.create(4)
ring:Pop(target)
print(buffer.readu32(target, 0)) --12345
```

`Push`, `Peek`, and `Pop` transfer bytes. `Peek` does NOT consume them. `Discard` and `Clear` only update the ring's state, so both are O(1).

### RingQueue

```lua
local RingQueue = require("@self/RingQueue")

local queue = RingQueue.create<<number>>(5)
queue:Enqueue(10, 20, 30)

print(queue:PeekFront())    --10
print(queue:PeekBack())     --30
print(queue:Dequeue())      --10

queue:Discard(1)            --Discards 20
print(queue:Dequeue())      --30
```

RingQueue supports any non-nil Luau value, including strings, Instances, Vector3s, tables, and union types. Removed values are cleared from storage so they can be garbage-collected.

Both modules expose `Head`, `Size`, and `Capacity` as read-only fields in their public types. Initial capacity defaults to 256 (bytes for RingBuffer, elements for RingQueue).

## Optimizations(most are just common unrolling methods)

### RingBuffer

- **Small transfers:** Direct reads/writes for 1, 2, 4, and 8 contiguous bytes instead of `buffer.copy`.
- **Contiguous-first copying:** Transfers use a single copy when possible and split only when the data wraps around.
- **Conditional validation:** Skips some range checks when optional arguments are omitted.
- **Storage protection:** Rejects transfers that use the ring's own backing buffer as the source or target.

### RingQueue

- **Batch enqueues:** Unrolled paths for exactly 4 or 8 values, avoiding repeated `select()` calls and loop overhead.
- **Contiguous-first insertion:** The 4 and 8 value paths skip per-element wrap checks when the batch fits contiguously.
- **Adaptive clearing:** Clears occupied slots individually when the queue is sparse; uses `table.clear` when it is dense.
- **Adaptive full discard:** Uses the same sparse/dense strategy when discarding the entire queue.
- **Batch discard:** Clears contiguous ranges without checking wraparound for every element.
- **Small fast paths:** Dedicated single-element discard and last-element dequeue paths.

The adaptive clearing is most useful when a queue has grown large but contains only a few elements afterward. For example:

```lua
-- this is considered niche/situational hence why adaptive clearing + discard may not always be as effective in non-bulk operations...
local queue = RingQueue.create<<number>>(256)

for i = 1, 4000 do
    queue:Enqueue(i)
end

queue:Discard(3997) --Size = 3, Capacity = 4096
queue:Clear()       --Clears the 3 occupied slots, not all 4096
```

## Time complexity

`C` = allocated capacity
`n` = existing elements/bytes copied during growth
`k` = elements/bytes processed

### RingBuffer

| Method | Complexity |
| --- | --- |
| `Create` | O(C) |
| `Reserve` | O(1) / O(n) on growth |
| `Push` | O(1) fixed-size / O(k) variable-size / O(n + k) on growth |
| `Peek` | O(1) fixed-size / O(k) variable-size |
| `Pop` | O(1) fixed-size / O(k) variable-size |
| `Discard` | O(1) |
| `Clear` | O(1) |

### RingQueue

| Method | Complexity |
| --- | --- |
| `Create` | O(C) |
| `Reserve` | O(1) / O(n) on growth |
| `Enqueue(value)` | O(1) amortized |
| `Enqueue(...values)` | O(k) amortized |
| `PeekFront` | O(1) |
| `PeekBack` | O(1) |
| `Dequeue` | O(1) |
| `Discard` | O(k) for sparse discard / O(C) for dense full discard |
| `Clear` | O(k) sparse / O(C) dense |

Fixed-size byte transfers are O(1) when no growth is needed btw. Also growth can require copying the existing contents into new storage.
