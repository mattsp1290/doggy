## RUM example — sends real events to the Datadog browser intake.
## Requires env vars:
##   DD_CLIENT_TOKEN   — RUM client token (not DD_API_KEY)
##   DD_APPLICATION_ID — Datadog application ID
##   DD_SITE           — Datadog site (default: datadoghq.com)
##
## Compile: nim c --mm:orc --threads:on -d:ssl -r examples/rum.nim

import std/os
import doggy/site
import doggy/rum/types, doggy/rum/vitals, doggy/rum/exporter

proc main() =
  let clientToken   = getEnv("DD_CLIENT_TOKEN")
  let applicationId = getEnv("DD_APPLICATION_ID")
  let siteStr       = getEnv("DD_SITE", "datadoghq.com")

  if clientToken.len == 0 or applicationId.len == 0:
    echo "Error: DD_CLIENT_TOKEN and DD_APPLICATION_ID must be set"
    quit(1)

  let ddSite = parseSite(siteStr)
  let cfg    = defaultRumConfig(clientToken, applicationId, "doggy-example", ddSite)

  var rum: RumExporter
  initRumExporter(rum, cfg)
  defer: rum.shutdown()

  echo "Sending RUM events to ", siteStr

  let viewId = rum.newView()
  echo "View ID: ", viewId

  var sessionEv = RumSessionEvent()
  rum.send(sessionEv)

  var viewEv = RumViewEvent(name: "ExampleScreen", url: "game://example")
  rum.send(viewEv)

  var actionEv = RumActionEvent(actionType: ratClick, name: "StartButton")
  rum.send(actionEv)

  var resourceEv = RumResourceEvent(
    resourceType: rrtImage,
    url:          "game://assets/logo.png",
    durationMs:   18,
  )
  rum.send(resourceEv)

  var errorEv = RumErrorEvent(
    message: "Example error from doggy",
    source:  "custom",
    stack:   "at examples/rum.nim:48",
  )
  rum.send(errorEv)

  var vitalEv = newFrameTimeVital(16.7)
  rum.send(vitalEv)
  echo "Sent 6 RUM events (session, view, action, resource, error, vital)"

  rum.forceFlush()
  echo "Done."

main()
