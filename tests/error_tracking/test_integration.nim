## Integration test: Error Tracking intake against Datadog.
##
## Required env: DD_API_KEY, DD_SITE
## Optional env: DD_APP_KEY + DD_API_KEY (enables Datadog query assertion via pup)
##               PUP_BIN (override path to pup binary)
##
## Test is skipped (exit 0) when DD_API_KEY is not set.
## Sends one error event and calls forceFlush(). The exporter returns void
## so without pup this is a smoke test (verifies calls do not raise).
## With pup + DD_APP_KEY set, sleeps 10s and asserts the event appears in Datadog logs.

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
  let runId    = newUuid4()
  let service  = "doggy-et-integ-test"
  let errorMsg = "doggy integration test " & runId

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

  echo "Event sent (smoke test: calls completed without raising)."

  # Datadog query assertion — requires pup binary, DD_APP_KEY, and DD_API_KEY.
  # (pup --no-agent authenticates with DD_API_KEY, not the RUM client token.)
  if appKey.len == 0 or apiKey.len == 0:
    echo "INFO: DD_APP_KEY/DD_API_KEY not both set — skipping Datadog query assertion (send-only pass)"
    quit(0)

  proc findPupBin(): string =
    result = getEnv("PUP_BIN")
    if result.len > 0 and fileExists(result): return
    result = findExe("pup")

  let pupBin = findPupBin()
  if pupBin.len == 0:
    echo "INFO: pup binary not found (set PUP_BIN env or add pup to PATH) — skipping query assertion (send-only pass)"
    quit(0)

  echo "Waiting 10s for Datadog ingestion..."
  sleep(10_000)

  # Use a 30m window to stay well inside DD indexing lag.
  let qStr = "service:" & service & " @error.message:\"" & errorMsg & "\""
  let cmd  = pupBin & " logs search --query=" & quoteShell(qStr) & " --from=30m --no-agent"
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
