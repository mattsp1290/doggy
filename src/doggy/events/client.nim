import std/httpclient
import doggy/events/types
import doggy/http_client
import doggy/site

type
  EventsClient* = object
    config: EventsConfig

proc newEventsClient*(config: EventsConfig): EventsClient =
  EventsClient(config: config)

proc send*(client: EventsClient; ev: DdEvent): bool =
  let url = apiBaseUrl(client.config.site) & "/api/v2/events"
  try:
    let resp = postJson(url, toJson(ev), client.config.apiKey)
    if resp.code.is2xx():
      return true
    stderr.writeLine("doggy/events: HTTP " & $resp.code & " when posting event")
    return false
  except:
    return false
