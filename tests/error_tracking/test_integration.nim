## Integration test: Error Tracking intake against Datadog.
##
## Required env: DD_API_KEY, DD_SITE
## Optional env: DD_APP_KEY (enables Datadog query assertion via pup)
##
## Test is skipped (exit 0) when DD_API_KEY is not set.
## Sends one error event, calls forceFlush(), sleeps 10s, then
## asserts the event appears in Datadog logs if pup + DD_APP_KEY are available.

import std/[os, osproc, json]
import doggy/site
import doggy/error_tracking/types, doggy/error_tracking/exporter
import doggy/uuid

when isMainModule:
  let apiKey = getEnv("DD_API_KEY")
  if apiKey.len == 0:
    echo "SKIP: DD_API_KEY not set"
    quit(0)

  let siteStr = getEnv("DD_SITE", "datadoghq.com")
  let appKey  = getEnv("DD_APP_KEY")

  # Unique ID embedded in the error message so we can find exactly this run's event.
  let runId     = newUuid4()
  let service   = "doggy-et-integ-test"
  let errorMsg  = "doggy integration test " & runId

  var exp: ErrorTrackingExporter
  initErrorTrackingExporter(exp, ErrorTrackingConfig(
    apiKey:          apiKey,
    service:         service,
    site:            parseSite(siteStr),
    batchSize:       20,
    flushIntervalMs: 5_000,
  ))

  exp.report(ErrorEvent(
    errorKind:    "IntegrationTestError",
    errorMessage: errorMsg,
    errorStack:   "at tests/error_tracking/test_integration.nim:1\nat doggy/integ:1",
    ddSource:     "nim",
    service:      service,
  ))

  exp.forceFlush()
  exp.shutdown()

  echo "Event sent. Waiting 10s for Datadog ingestion..."
  sleep(10_000)

  # Datadog query assertion — requires pup binary and DD_APP_KEY.
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

  # Use a 30m window to stay well inside DD indexing lag.
  let query  = "service:" & service & " " & quoteShell("@error.message:" & errorMsg)
  let cmd    = pupBin & " logs search --query=" & quoteShell("service:" & service & " @error.message:\"" & errorMsg & "\"") & " --from=30m --no-agent"
  let (output, exitCode) = execCmdEx(cmd)
  assert exitCode == 0, "pup logs search failed (exit " & $exitCode & "):\n" & output

  let parsed = parseJson(output)
  let count =
    if parsed.kind == JObject and parsed.hasKey("logs"): parsed["logs"].len
    elif parsed.kind == JArray: parsed.len
    else: 0

  assert count > 0,
    "expected ≥1 log matching service:" & service & " with runId=" & runId &
    " — got 0 results.\npup output:\n" & output

  echo "PASS: " & $count & " matching log event(s) found in Datadog (runId=" & runId & ")"
