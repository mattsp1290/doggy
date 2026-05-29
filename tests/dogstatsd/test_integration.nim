## Integration test: DogStatsD against a local Datadog Agent.
##
## Required env: DD_API_KEY (used to query via pup; also gates skip)
## Optional env: DD_APP_KEY (enables Datadog metrics query assertion via pup)
##               DD_STATSD_HOST (default: localhost)
##               DD_STATSD_PORT (default: 8125)
##               DD_SITE       (default: datadoghq.com)
##
## Test is skipped (exit 0) when DD_API_KEY is not set.
## Sends counter, gauge, histogram, event, and service check to the Agent,
## waits 10s, then asserts via pup that the counter metric appears.
## Verifies droppedCount is zero after all sends.

import std/[os, osproc, json, strutils]
import doggy/dogstatsd/types, doggy/dogstatsd/client

when isMainModule:
  let apiKey = getEnv("DD_API_KEY")
  if apiKey.len == 0:
    echo "SKIP: DD_API_KEY not set"
    quit(0)

  let siteStr  = getEnv("DD_SITE", "datadoghq.com")
  let sdHost   = getEnv("DD_STATSD_HOST", "localhost")
  let sdPort   = parseInt(getEnv("DD_STATSD_PORT", "8125"))
  let appKey   = getEnv("DD_APP_KEY")

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

  let dropped = sd.droppedCount()
  deinitDogStatsd(sd)

  assert dropped == 0, "expected 0 dropped datagrams, got " & $dropped

  echo "All datagrams sent (droppedCount=0). Waiting 10s for Agent flush to Datadog..."
  sleep(10_000)

  # Datadog metrics query — requires pup + DD_APP_KEY.
  if appKey.len == 0:
    echo "INFO: DD_APP_KEY not set — skipping Datadog query assertion (send-only pass)"
    quit(0)

  proc findPupBin(): string =
    result = findExe("pup")
    if result.len == 0:
      const localPup = "/Users/punk1290/git/pup/target/release/pup"
      if fileExists(localPup):
        result = localPup

  let pupBin = findPupBin()
  if pupBin.len == 0:
    echo "INFO: pup binary not found — skipping Datadog query assertion (send-only pass)"
    quit(0)

  let query  = "sum:" & metricName & "{*}"
  let cmd    = pupBin & " metrics query --query=" & quoteShell(query) & " --from=5m --no-agent"
  let (output, exitCode) = execCmdEx(cmd)
  assert exitCode == 0, "pup metrics query failed (exit " & $exitCode & "):\n" & output

  let parsed = parseJson(output)
  # Datadog timeseries response has a "series" array; any non-empty series means the metric arrived.
  let hasSeries =
    parsed.kind == JObject and parsed.hasKey("series") and parsed["series"].len > 0
  assert hasSeries,
    "expected metric " & metricName & " to appear in Datadog — got no series.\npup output:\n" & output

  echo "PASS: metric " & metricName & " confirmed in Datadog"
