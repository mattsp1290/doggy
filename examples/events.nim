## Custom Events example — posts game lifecycle events to the Datadog Events API.
## Requires env vars:
##   DD_API_KEY — Datadog API key
##   DD_SITE    — Datadog site (default: datadoghq.com)
##
## Compile: nim c --mm:orc --threads:on -d:ssl -r examples/events.nim

import std/os
import doggy/site
import doggy/events/types, doggy/events/client

proc main() =
  let apiKey  = getEnv("DD_API_KEY")
  let siteStr = getEnv("DD_SITE", "datadoghq.com")

  if apiKey.len == 0:
    echo "Error: DD_API_KEY must be set"
    quit(1)

  let ddSite   = parseSite(siteStr)
  let cfg      = defaultEventsConfig(apiKey, ddSite)
  let evClient = newEventsClient(cfg)

  echo "Sending Custom Event to ", siteStr

  let ok = evClient.send(DdEvent(
    title:          "Game Session Started",
    text:           "Player started a new session in doggy-example v1.0.0",
    alertType:      datInfo,
    tags:           @["env:dev", "game:doggy-example", "version:1.0.0"],
    sourceTypeName: "nim",
  ))

  echo if ok: "Event sent successfully" else: "Event send failed (check DD_API_KEY and DD_SITE)"

main()
