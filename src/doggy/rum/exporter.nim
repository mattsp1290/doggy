import std/[os, monotimes, times, atomics, options]
import doggy/rum/types
import doggy/rum/session
import doggy/rum/serialize
import doggy/json_emit
import doggy/http_client
import doggy/queue
import doggy/site

const WorkerPollMs = 50

proc monoMs(): int64 {.inline.} =
  getMonoTime().ticks div 1_000_000

proc epochMs(): int64 {.inline.} =
  int64(epochTime() * 1000)

type
  RumState = object
    config:  RumConfig
    queue:   AsyncQueue[string]
    session: RumSession
    done:    Atomic[bool]

  RumExporter* = object
    state:   ptr RumState
    thread:  Thread[ptr RumState]
    running: bool

proc `=copy`*(dst: var RumExporter; src: RumExporter) {.error:
  "RumExporter owns a thread — pass by var".}

proc buildRumUrl(state: ptr RumState): string {.inline.} =
  var url = rumIntakeUrl(state[].config.site)
  let src = if state[].config.ddSource.len > 0: state[].config.ddSource else: "browser"
  url &= "?ddsource=" & src & "&sdkVersion=doggy-0.1.0"
  url &= "&dd-api-key=" & state[].config.clientToken
  if state[].config.service.len > 0:
    url &= "&ddtags=service:" & state[].config.service
  url

proc flushRum(state: ptr RumState; batch: seq[string]) {.inline.} =
  if batch.len == 0: return
  {.cast(gcsafe).}:
    try:
      discard postJson(buildRumUrl(state), toNdjson(batch), "")
    except CatchableError:
      discard

proc workerProc(state: ptr RumState) {.thread.} =
  var batch: seq[string] = @[]
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
      flushRum(state, batch)
      batch.setLen(0)
      nextFlush = monoMs() + state[].config.flushIntervalMs

    if isDone:
      # Final drain: flush all remaining queue items before exiting.
      while true:
        let rest = state[].queue.drain()
        if rest.len == 0: break
        var i = 0
        while i < rest.len:
          let chunkEnd = min(i + state[].config.batchSize, rest.len)
          flushRum(state, rest[i ..< chunkEnd])
          i = chunkEnd
      break

    sleep(WorkerPollMs)

proc fillAndRotate(state: ptr RumState; base: var RumEventBase) =
  if state[].session.isExpired():
    state[].session.newSession()
  base.sessionId     = state[].session.sessionId()
  base.viewId        = state[].session.currentViewId()
  base.applicationId = state[].config.applicationId
  base.service       = state[].config.service
  base.version       = state[].config.version
  base.userAgent     = state[].config.userAgent
  base.timestamp     = epochMs()
  state[].session.touch()

proc enqueueLine(state: ptr RumState; line: string) =
  if not state[].queue.enqueue(line):
    stderr.writeLine("doggy/rum: queue full, dropping event")

proc initRumExporter*(exp: var RumExporter; config: RumConfig) =
  exp.state = cast[ptr RumState](allocShared0(sizeof(RumState)))
  # Safety: config is deep-copied before createThread. After that, only the
  # worker reads config fields — no concurrent mutation of shared GC strings.
  exp.state[].config = config
  initAsyncQueue(exp.state[].queue)
  initRumSession(exp.state[].session)
  exp.state[].done.store(false)
  createThread(exp.thread, workerProc, exp.state)
  exp.running = true

proc newView*(exp: var RumExporter): string =
  if not exp.running: return ""
  exp.state[].session.newView()

proc send*(exp: var RumExporter; ev: var RumSessionEvent) =
  if not exp.running: return
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumViewEvent) =
  if not exp.running: return
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumActionEvent) =
  if not exp.running: return
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumResourceEvent) =
  if not exp.running: return
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumErrorEvent) =
  if not exp.running: return
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumVitalEvent) =
  if not exp.running: return
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc forceFlush*(exp: var RumExporter) =
  # Drains the queue from the calling thread. Races the worker — items go to
  # exactly one consumer (no duplication), but completeness is best-effort.
  # postJson retries with exponential backoff; caller may block for several
  # seconds on a 5xx. Prefer calling from a background thread when possible.
  if not exp.running: return
  var items: seq[string] = @[]
  var item = exp.state[].queue.tryDequeue()
  while item.isSome:
    items.add(item.get())
    item = exp.state[].queue.tryDequeue()
  if items.len > 0:
    try:
      discard postJson(buildRumUrl(exp.state), toNdjson(items), "")
    except CatchableError:
      discard

proc shutdown*(exp: var RumExporter) =
  if not exp.running: return
  exp.running = false  # gate producer procs before joining
  exp.state[].done.store(true)
  joinThread(exp.thread)
  deinitAsyncQueue(exp.state[].queue)
  deinitRumSession(exp.state[].session)
  reset(exp.state[])   # destroy GC'd config/session string fields before raw free
  deallocShared(exp.state)
  exp.state = nil
