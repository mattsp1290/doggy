import std/options
import doggy/queue

block enqueue_and_dequeue:
  var q: AsyncQueue[string]
  initAsyncQueue(q)
  defer: deinitAsyncQueue(q)
  assert q.enqueue("hello"), "enqueue must succeed on empty queue"
  let v = q.tryDequeue()
  assert v.isSome, "dequeue must return value"
  assert v.get() == "hello"

block dequeue_empty_returns_none:
  var q: AsyncQueue[int]
  initAsyncQueue(q)
  defer: deinitAsyncQueue(q)
  let v = q.tryDequeue()
  assert v.isNone, "empty queue must return none"

block drain_returns_all:
  var q: AsyncQueue[int]
  initAsyncQueue(q)
  defer: deinitAsyncQueue(q)
  discard q.enqueue(1)
  discard q.enqueue(2)
  discard q.enqueue(3)
  let items = q.drain()
  assert items.len == 3
  assert items[0] == 1
  assert items[1] == 2
  assert items[2] == 3

block drain_empty_returns_empty_seq:
  var q: AsyncQueue[string]
  initAsyncQueue(q)
  defer: deinitAsyncQueue(q)
  let items = q.drain()
  assert items.len == 0

block enqueue_full_returns_false:
  var q: AsyncQueue[int]
  initAsyncQueue(q, maxSize = 2)
  defer: deinitAsyncQueue(q)
  assert q.enqueue(1)
  assert q.enqueue(2)
  assert not q.enqueue(3), "third enqueue on size-2 queue must return false"

block queue_max_size_constant:
  assert QueueMaxSize == 8192

when isMainModule:
  echo "Queue tests passed"
