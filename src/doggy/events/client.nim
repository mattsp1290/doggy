import std/httpclient
import doggy/events/types
import doggy/http_client
import doggy/site

type
  EventsClient* = object
    config:  EventsConfig
    baseUrl: string  # empty => derive from config.site; injectable for testing

proc newEventsClient*(config: EventsConfig; baseUrl = ""): EventsClient =
  EventsClient(config: config, baseUrl: baseUrl)

proc send*(client: EventsClient; ev: DdEvent): bool =
  let base = if client.baseUrl.len > 0: client.baseUrl
             else: apiBaseUrl(client.config.site)
  let url = base & "/api/v2/events"
  try:
    let resp = postJson(url, toJson(ev), client.config.apiKey)
    if resp.code.is2xx():
      return true
    stderr.writeLine("doggy/events: HTTP " & $resp.code & " when posting event")
    return false
  except CatchableError:
    return false
