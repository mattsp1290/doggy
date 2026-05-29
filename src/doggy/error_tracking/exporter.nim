import std/[os, monotimes, atomics, options, nativesockets]
import doggy/error_tracking/types
import doggy/error_tracking/serialize
import doggy/http_client
import doggy/queue
import doggy/site

const WorkerPollMs = 50

proc monoMs(): int64 {.inline.} =
  getMonoTime().ticks div 1_000_000

type
  ETState = object
    config:    ErrorTrackingConfig
    queue:     AsyncQueue[ErrorEvent]
    done:      Atomic[bool]

  ErrorTrackingExporter* = object
    state:   ptr ETState
    thread:  Thread[ptr ETState]
    running: bool

proc `=copy`*(dst: var ErrorTrackingExporter; src: ErrorTrackingExporter) {.error:
  "ErrorTrackingExporter owns a thread — pass by var".}

proc flushET(state: ptr ETState; batch: seq[ErrorEvent]) {.inline.} =
  if batch.len == 0: return
  {.cast(gcsafe).}:
    try:
      let url = logsIntakeUrl(state[].config.site)
      discard postJson(url, toJsonArray(batch), state[].config.apiKey)
    except CatchableError:
      discard

proc workerProc(state: ptr ETState) {.thread.} =
  var batch: seq[ErrorEvent] = @[]
  var nextFlush = monoMs() + state[].config.flushIntervalMs

  while true:
    let isDone = state[].done.load(moRelaxed)

    var item = state[].queue.tryDequeue()
    while item.isSome:
      batch.add(item.get())
      if batch.len >= state[].config.batchSize:
        break
      item = state[].queue.tryDequeue()

    let shouldFlush = batch.len >= state[].config.batchSize or
                      monoMs() >= nextFlush or isDone

    if batch.len > 0 and shouldFlush:
      flushET(state, batch)
      batch.setLen(0)
      nextFlush = monoMs() + state[].config.flushIntervalMs

    if isDone:
      # Final drain: flush all remaining queue items before exiting.
      # The main batch loop breaks at batchSize; drain the rest here.
      while true:
        let rest = state[].queue.drain()
        if rest.len == 0: break
        var i = 0
        while i < rest.len:
          let chunkEnd = min(i + state[].config.batchSize, rest.len)
          flushET(state, rest[i ..< chunkEnd])
          i = chunkEnd
      break

    sleep(WorkerPollMs)

proc initErrorTrackingExporter*(exp: var ErrorTrackingExporter;
                                  config: ErrorTrackingConfig) =
  exp.state = cast[ptr ETState](allocShared0(sizeof(ETState)))
  # Safety: config is deep-copied before createThread. After that, only the
  # worker reads config fields — no concurrent mutation of shared GC strings.
  exp.state[].config = config
  initAsyncQueue(exp.state[].queue)
  exp.state[].done.store(false)
  createThread(exp.thread, workerProc, exp.state)
  exp.running = true

proc report*(exp: var ErrorTrackingExporter; ev: ErrorEvent) =
  if not exp.running: return
  if not exp.state[].queue.enqueue(ev):
    {.cast(gcsafe).}: stderr.writeLine("doggy/et: queue full, dropping event")

proc reportException*(exp: var ErrorTrackingExporter;
                       name, msg, stack: string) =
  if not exp.running: return
  let hostname = try: getHostname() except OSError: ""
  report(exp, ErrorEvent(
    errorKind:    name,
    errorMessage: msg,
    errorStack:   stack,
    ddSource:     "nim",
    service:      exp.state[].config.service,
    hostname:     hostname,
    version:      exp.state[].config.version,
  ))

proc forceFlush*(exp: var ErrorTrackingExporter) =
  # Drains the queue from the calling thread. Races the worker — items go to
  # exactly one consumer (no duplication), but completeness is best-effort.
  # postJson retries up to MaxRetries with exponential backoff; caller may block
  # for several seconds on a 5xx. Call from the worker thread (background) when
  # possible; avoid from latency-sensitive paths.
  if not exp.running: return
  var items: seq[ErrorEvent] = @[]
  var item = exp.state[].queue.tryDequeue()
  while item.isSome:
    items.add(item.get())
    item = exp.state[].queue.tryDequeue()
  if items.len > 0:
    try:
      let url = logsIntakeUrl(exp.state[].config.site)
      discard postJson(url, toJsonArray(items), exp.state[].config.apiKey)
    except CatchableError:
      discard

proc shutdown*(exp: var ErrorTrackingExporter) =
  if not exp.running: return
  exp.running = false  # gate producer procs before joining
  exp.state[].done.store(true)
  joinThread(exp.thread)
  deinitAsyncQueue(exp.state[].queue)
  reset(exp.state[])   # destroy GC'd config string fields before raw free
  deallocShared(exp.state)
  exp.state = nil
