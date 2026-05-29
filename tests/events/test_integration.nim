## Integration test: Custom Events API against Datadog.
##
## Required env: DD_API_KEY, DD_SITE
## Optional env: DD_APP_KEY (enables Datadog query assertion via pup)
##
## Test is skipped (exit 0) when DD_API_KEY is not set.
## Sends one DdEvent and asserts a 2xx response. Optionally queries
## the events stream via pup to confirm the event appeared.

import std/[os, osproc, json]
import doggy/site
import doggy/events/types, doggy/events/client
import doggy/uuid

when isMainModule:
  let apiKey = getEnv("DD_API_KEY")
  if apiKey.len == 0:
    echo "SKIP: DD_API_KEY not set"
    quit(0)

  let siteStr = getEnv("DD_SITE", "datadoghq.com")
  let appKey  = getEnv("DD_APP_KEY")

  let runId  = newUuid4()
  let title  = "doggy integration test " & runId

  let ec = newEventsClient(defaultEventsConfig(apiKey, parseSite(siteStr)))
  let ok = ec.send(DdEvent(
    title:     title,
    text:      "Synthetic event emitted by doggy integration test suite",
    alertType: datInfo,
    tags:      @["env:test", "source:doggy"],
  ))
  assert ok, "EventsClient.send returned false — HTTP post failed"

  echo "Event sent successfully (2xx response confirmed)"

  # Datadog query assertion — optional, requires pup + DD_APP_KEY.
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

  # Datadog events can take a few seconds to appear; use a 5m window.
  let cmd = pupBin & " events search --query=" & quoteShell(runId) & " --from=5m --no-agent"
  let (output, exitCode) = execCmdEx(cmd)
  assert exitCode == 0, "pup events search failed (exit " & $exitCode & "):\n" & output

  let parsed = parseJson(output)
  let count =
    if parsed.kind == JObject and parsed.hasKey("events"): parsed["events"].len
    elif parsed.kind == JArray: parsed.len
    else: 0

  assert count > 0,
    "expected ≥1 event with title containing runId=" & runId &
    " — got 0 results.\npup output:\n" & output

  echo "PASS: " & $count & " matching event(s) found in Datadog (runId=" & runId & ")"
