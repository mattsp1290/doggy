## Integration test: RUM intake against Datadog.
##
## Required env: DD_CLIENT_TOKEN, DD_APPLICATION_ID, DD_SITE
## Optional env: DD_APP_KEY (enables Datadog query assertion via pup)
##
## Test is skipped (exit 0) when required env vars are not set.
## Sends RumSessionEvent, RumViewEvent, RumActionEvent, and a frame_time
## RumVitalEvent, calls forceFlush(), sleeps 5s, then asserts the events
## appear in Datadog RUM if pup + DD_APP_KEY are available.

import std/[os, osproc, json]
import doggy/site
import doggy/rum/types, doggy/rum/vitals, doggy/rum/exporter

when isMainModule:
  let clientToken   = getEnv("DD_CLIENT_TOKEN")
  let applicationId = getEnv("DD_APPLICATION_ID")
  if clientToken.len == 0 or applicationId.len == 0:
    echo "SKIP: DD_CLIENT_TOKEN and DD_APPLICATION_ID must both be set"
    quit(0)

  let siteStr = getEnv("DD_SITE", "datadoghq.com")
  let appKey  = getEnv("DD_APP_KEY")

  var rum: RumExporter
  initRumExporter(rum, defaultRumConfig(clientToken, applicationId, "doggy-rum-integ-test", parseSite(siteStr)))

  discard rum.newView()

  var sessionEv = RumSessionEvent()
  rum.send(sessionEv)

  var viewEv = RumViewEvent(name: "IntegrationTestScreen", url: "test://doggy/integ")
  rum.send(viewEv)

  var actionEv = RumActionEvent(actionType: ratClick, name: "IntegrationTestAction")
  rum.send(actionEv)

  var vitalEv = newFrameTimeVital(16.7)
  rum.send(vitalEv)

  rum.forceFlush()
  rum.shutdown()

  echo "4 RUM events sent. Waiting 5s for Datadog ingestion..."
  sleep(5_000)

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

  # Query RUM events for this application within the last 5 minutes.
  let query   = "@application.id:" & applicationId
  let cmd     = pupBin & " rum events --query=" & quoteShell(query) & " --from=5m --no-agent"
  let (output, exitCode) = execCmdEx(cmd)
  assert exitCode == 0, "pup rum events failed (exit " & $exitCode & "):\n" & output

  let parsed = parseJson(output)
  let count =
    if parsed.kind == JObject and parsed.hasKey("events"): parsed["events"].len
    elif parsed.kind == JArray: parsed.len
    else: 0

  assert count > 0,
    "expected ≥1 RUM event for applicationId=" & applicationId &
    " — got 0 results.\npup output:\n" & output

  echo "PASS: " & $count & " RUM event(s) found in Datadog (applicationId=" & applicationId & ")"
