## Error Tracking example — sends crash/exception data to Datadog via logs intake.
## Requires env vars:
##   DD_API_KEY — Datadog API key
##   DD_SITE    — Datadog site (default: datadoghq.com)
##
## Compile: nim c --mm:orc --threads:on -d:ssl -r examples/error_tracking.nim

import std/os
import doggy/site
import doggy/error_tracking/types, doggy/error_tracking/exporter

proc main() =
  let apiKey  = getEnv("DD_API_KEY")
  let siteStr = getEnv("DD_SITE", "datadoghq.com")

  if apiKey.len == 0:
    echo "Error: DD_API_KEY must be set"
    quit(1)

  let ddSite = parseSite(siteStr)
  let cfg    = defaultErrorTrackingConfig(apiKey, "doggy-example", ddSite)

  var et: ErrorTrackingExporter
  initErrorTrackingExporter(et, cfg)
  defer: et.shutdown()

  echo "Sending Error Tracking events to ", siteStr

  et.report(ErrorEvent(
    errorKind:    "IOError",
    errorMessage: "Failed to load level data",
    errorStack:   "at game/loader.nim:87\n  at game/main.nim:42",
    ddSource:     "nim",
    service:      "doggy-example",
    version:      "1.0.0",
  ))
  echo "Sent structured error event"

  et.reportException(
    "NilAccessError",
    "Player entity was nil during update",
    "at game/player.nim:123\n  at game/world.nim:89\n  at game/main.nim:56",
  )
  echo "Sent exception via reportException"

  et.forceFlush()
  echo "Done."

main()
