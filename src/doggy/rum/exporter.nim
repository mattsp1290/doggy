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
      {.cast(gcsafe).}:
        try:
          let baseUrl = rumIntakeUrl(state[].config.site)
          let url = baseUrl & "?dd-api-key=" & state[].config.clientToken
          discard postJson(url, toNdjson(batch), "")
        except:
          discard
      batch.setLen(0)
      nextFlush = monoMs() + state[].config.flushIntervalMs

    if isDone:
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
  base.timestamp     = epochMs()
  state[].session.touch()

proc enqueueLine(state: ptr RumState; line: string) =
  if not state[].queue.enqueue(line):
    stderr.writeLine("doggy/rum: queue full, dropping event")

proc initRumExporter*(exp: var RumExporter; config: RumConfig) =
  exp.state = cast[ptr RumState](allocShared0(sizeof(RumState)))
  exp.state[].config = config
  initAsyncQueue(exp.state[].queue)
  initRumSession(exp.state[].session)
  exp.state[].done.store(false)
  createThread(exp.thread, workerProc, exp.state)
  exp.running = true

proc newView*(exp: var RumExporter): string =
  exp.state[].session.newView()

proc send*(exp: var RumExporter; ev: var RumSessionEvent) =
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumViewEvent) =
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumActionEvent) =
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumResourceEvent) =
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumErrorEvent) =
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc send*(exp: var RumExporter; ev: var RumVitalEvent) =
  fillAndRotate(exp.state, ev.base)
  enqueueLine(exp.state, toJson(ev))

proc forceFlush*(exp: var RumExporter) =
  var items: seq[string] = @[]
  var item = exp.state[].queue.tryDequeue()
  while item.isSome:
    items.add(item.get())
    item = exp.state[].queue.tryDequeue()
  if items.len > 0:
    try:
      let baseUrl = rumIntakeUrl(exp.state[].config.site)
      let url = baseUrl & "?dd-api-key=" & exp.state[].config.clientToken
      discard postJson(url, toNdjson(items), "")
    except:
      discard

proc shutdown*(exp: var RumExporter) =
  if not exp.running: return
  exp.state[].done.store(true)
  joinThread(exp.thread)
  deinitAsyncQueue(exp.state[].queue)
  deinitRumSession(exp.state[].session)
  deallocShared(exp.state)
  exp.state = nil
  exp.running = false
