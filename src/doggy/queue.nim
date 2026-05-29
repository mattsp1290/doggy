import std/options

const QueueMaxSize* = 8192

type
  AsyncQueue*[T] = object
    chan: Channel[T]

proc `=copy`*[T](dst: var AsyncQueue[T]; src: AsyncQueue[T]) {.error:
  "AsyncQueue owns a Channel and must not be copied; pass by var".}

proc initAsyncQueue*[T](q: var AsyncQueue[T]; maxSize: int = QueueMaxSize) =
  q.chan.open(maxSize)

proc deinitAsyncQueue*[T](q: var AsyncQueue[T]) =
  q.chan.close()

proc enqueue*[T](q: var AsyncQueue[T]; item: sink T): bool =
  q.chan.trySend(item)

proc tryDequeue*[T](q: var AsyncQueue[T]): Option[T] =
  var r = q.chan.tryRecv()
  if r.dataAvailable:
    some(r.msg)
  else:
    none(T)

proc drain*[T](q: var AsyncQueue[T]): seq[T] =
  result = @[]
  while true:
    var r = q.chan.tryRecv()
    if not r.dataAvailable:
      break
    result.add(r.msg)
