## Integration test: DogStatsD against a local Datadog Agent.
##
## No required env vars for the send path — UDP to a local Agent is fire-and-forget.
## Optional env: DD_STATSD_HOST (default: localhost)
##               DD_STATSD_PORT (default: 8125)
##               DD_STATSD_VERIFY_DELIVERY (non-empty enables the Datadog query assertion)
##               DD_API_KEY + DD_APP_KEY (required when DD_STATSD_VERIFY_DELIVERY is set)
##               PUP_BIN (override path to pup binary)
##
## The send path always runs and verifies the client does not self-report drops.
## NOTE: droppedCount==0 proves the client did not internally drop a datagram;
##       for UDP it does NOT prove the Agent received anything (sends to a dead
##       port do not raise). Delivery is verified only via pup when
##       DD_STATSD_VERIFY_DELIVERY is set and a real Agent is running.

import std/[os, osproc, json, strutils]
import doggy/dogstatsd/types, doggy/dogstatsd/client

when isMainModule:
  let sdHost = getEnv("DD_STATSD_HOST", "localhost")
  let sdPort = parseInt(getEnv("DD_STATSD_PORT", "8125"))

  let metricName = "doggy.integ.counter"

  var sd: DogStatsd
  initDogStatsd(sd, StatsdConfig(
    host: sdHost,
    port: sdPort,
    defaultTags: @["env:test", "source:doggy-integ"],
    onError: proc(msg: string) {.gcsafe.} = stderr.writeLine("statsd error: " & msg),
  ))

  sd.counter(metricName, 1.0)
  sd.gauge("doggy.integ.gauge", 42.0)
  sd.histogram("doggy.integ.histogram", 3.14)

  sd.event(StatsdEvent(
    title:     "doggy integration test",
    text:      "DogStatsD integration test event",
    alertType: satInfo,
    tags:      @["env:test"],
  ))

  sd.serviceCheck(StatsdServiceCheck(
    name:    "doggy.integ.check",
    status:  scOk,
    message: "integration test service check",
    tags:    @["env:test"],
  ))

  # droppedCount==0 proves the client did not self-report a drop.
  # For UDP it does NOT prove the Agent received anything.
  let dropped = sd.droppedCount()
  deinitDogStatsd(sd)
  assert dropped == 0, "client self-reported " & $dropped & " dropped datagram(s)"

  echo "UDP send complete. Client reports no self-drops (UDP delivery not verified without local Agent)."

  # Datadog metrics query assertion — requires a local Agent forwarding to Datadog.
  # CI has no Agent, so this section only runs when DD_STATSD_VERIFY_DELIVERY is set.
  if getEnv("DD_STATSD_VERIFY_DELIVERY").len == 0:
    echo "INFO: DD_STATSD_VERIFY_DELIVERY not set — send-only pass (no local Agent assumed)"
    quit(0)

  let apiKey = getEnv("DD_API_KEY")
  let appKey = getEnv("DD_APP_KEY")
  if apiKey.len == 0 or appKey.len == 0:
    echo "INFO: DD_API_KEY/DD_APP_KEY not both set — skipping Datadog query assertion"
    quit(0)

  proc findPupBin(): string =
    result = getEnv("PUP_BIN")
    if result.len > 0 and fileExists(result): return
    result = findExe("pup")

  let pupBin = findPupBin()
  if pupBin.len == 0:
    echo "INFO: pup binary not found (set PUP_BIN env or add pup to PATH) — skipping query assertion"
    quit(0)

  echo "Waiting 10s for Agent flush to Datadog..."
  sleep(10_000)

  let query = "sum:" & metricName & "{*}"
  let cmd   = pupBin & " metrics query --query=" & quoteShell(query) & " --from=5m --no-agent"
  let (output, exitCode) = execCmdEx(cmd)
  assert exitCode == 0, "pup metrics query failed (exit " & $exitCode & "):\n" & output

  let parsed = parseJson(output)
  # Datadog timeseries response has a "series" array; any non-empty series means the metric arrived.
  let hasSeries =
    parsed.kind == JObject and parsed.hasKey("series") and parsed["series"].len > 0
  assert hasSeries,
    "expected metric " & metricName & " to appear in Datadog — got no series.\npup output:\n" & output

  echo "PASS: metric " & metricName & " confirmed in Datadog"
