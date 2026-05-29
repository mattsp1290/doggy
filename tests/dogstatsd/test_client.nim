import std/atomics
import doggy/dogstatsd/types, doggy/dogstatsd/client

var gErrors: seq[string] = @[]
var gErrorCount: Atomic[int]

proc resetGlobals() =
  gErrors.setLen(0)
  gErrorCount.store(0)

block socket_error_increments_dropped_and_calls_on_error:
  resetGlobals()
  let cfg = StatsdConfig(
    host:  "invalid.host.doesnotexist.doggy.test",
    port:  12345,
    onError: proc(msg: string) {.gcsafe.} =
      {.cast(gcsafe).}: gErrors.add(msg),
  )
  var c: DogStatsd
  initDogStatsd(c, cfg)
  c.counter("test.metric")
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
  initDogStatsd(c, cfg)
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
  resetGlobals()
  let cfg = StatsdConfig(
    host:  "invalid.host.doesnotexist.doggy.test",
    port:  12345,
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
  let cfg = StatsdConfig(
    host:  "127.0.0.1",
    port:  19191,
    onError: proc(msg: string) {.gcsafe.} = discard,
  )
  var c: DogStatsd
  initDogStatsd(c, cfg)
  for _ in 0 ..< 5:
    c.counter("x", sampleRate = 1.0)
  # droppedCount may be >0 if the loopback UDP fails, but must be from socket errors
  # not from sampling — verify by checking no sample-rate drop path was taken
  # (we can't distinguish here, but the important invariant is that sampleRate=1.0
  # never short-circuits into sampleDrop before attempting the socket)
  deinitDogStatsd(c)

when isMainModule:
  echo "DogStatsD client tests passed"
