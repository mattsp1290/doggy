import std/atomics
import doggy/dogstatsd/types, doggy/dogstatsd/client

var gErrors: seq[string] = @[]
var gErrorCount: Atomic[int]

proc resetGlobals() =
  gErrors.setLen(0)
  gErrorCount.store(0)

block socket_error_increments_dropped_and_calls_on_error:
  # Unresolvable hostname causes OSError in connect() at init.
  # The first send() sees connected=false and increments droppedCount.
  # onError was called once during init (at connect failure).
  resetGlobals()
  let cfg = StatsdConfig(
    host:  "invalid.host.doesnotexist.doggy.test",
    port:  12345,
    onError: proc(msg: string) {.gcsafe.} =
      {.cast(gcsafe).}: gErrors.add(msg),
  )
  var c: DogStatsd
  initDogStatsd(c, cfg)         # connect fails: onError called
  c.counter("test.metric")      # connected=false: droppedCount++
  assert c.droppedCount() == 1, "droppedCount must be 1, got: " & $c.droppedCount()
  assert gErrors.len == 1, "onError must be called once, got: " & $gErrors.len
  assert gErrors[0].len > 0, "onError message must not be empty"
  deinitDogStatsd(c)

block no_exception_from_send:
  let cfg = StatsdConfig(
    host:  "invalid.host.doesnotexist.doggy.test",
    port:  12345,
  )
  var c: DogStatsd
  initDogStatsd(c, cfg)  # connect fails silently (no onError set)
  var raised = false
  try:
    c.counter("x")
    c.gauge("g", 1.0)
    c.histogram("h", 1.0)
    c.set("s", 1.0)
    c.timing("t", 1.0)
    c.event(StatsdEvent(title: "ev", text: "body", alertType: satInfo))
    c.serviceCheck(StatsdServiceCheck(name: "sc", status: scOk))
  except:
    raised = true
  assert not raised, "send calls must never raise"
  deinitDogStatsd(c)

block sample_rate_zero_drops_without_socket_attempt:
  # Use 127.0.0.1 so connect() succeeds (UDP, no listener needed).
  # sampleRate=0.0 short-circuits before reaching the socket; onError never fires.
  resetGlobals()
  let cfg = StatsdConfig(
    host:  "127.0.0.1",
    port:  19191,
    onError: proc(msg: string) {.gcsafe.} =
      discard gErrorCount.fetchAdd(1),
  )
  var c: DogStatsd
  initDogStatsd(c, cfg)
  for _ in 0 ..< 10:
    c.counter("test.metric", sampleRate = 0.0)
  assert c.droppedCount() == 10, "droppedCount must equal send count, got: " & $c.droppedCount()
  assert gErrorCount.load() == 0, "onError must NOT be called for sample-rate drops"
  deinitDogStatsd(c)

block sample_rate_one_never_sample_drops:
  # sampleRate=1.0 must never take the sampleDrop path.
  let cfg = StatsdConfig(
    host:  "127.0.0.1",
    port:  19191,
    onError: proc(msg: string) {.gcsafe.} = discard,
  )
  var c: DogStatsd
  initDogStatsd(c, cfg)
  for _ in 0 ..< 5:
    c.counter("x", sampleRate = 1.0)
  # UDP fire-and-forget to 127.0.0.1 does not error at socket level;
  # droppedCount must be 0 (no sample-drop path taken, no socket error).
  assert c.droppedCount() == 0,
    "sampleRate=1.0 must not increment droppedCount via sampling, got: " & $c.droppedCount()
  deinitDogStatsd(c)

when isMainModule:
  echo "DogStatsD client tests passed"
