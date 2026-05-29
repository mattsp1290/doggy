import doggy/site
import doggy/json_emit

type
  DdAlertType* = enum
    datInfo    = "info"
    datWarning = "warning"
    datError   = "error"
    datSuccess = "success"

  DdEvent* = object
    title*:          string
    text*:           string
    dateHappened*:   int64   # epoch seconds; 0 means "omit" (Datadog defaults to now)
    alertType*:      DdAlertType
    tags*:           seq[string]
    sourceTypeName*: string

  EventsConfig* = object
    apiKey*: string
    site*:   DdSite

proc defaultEventsConfig*(apiKey: string; site = SiteUS1): EventsConfig =
  EventsConfig(apiKey: apiKey, site: site)

proc toJson*(ev: DdEvent): string =
  var b = newJsonObject()
  b.addStr("title", ev.title)
  b.addStr("text", ev.text)
  if ev.dateHappened > 0:
    b.addInt("date_happened", ev.dateHappened)
  b.addStr("alert_type", $ev.alertType)
  if ev.tags.len > 0:
    b.startArr("tags")
    for t in ev.tags:
      b.addStrElem(t)
    b.endArr()
  if ev.sourceTypeName.len > 0:
    b.addStr("source_type_name", ev.sourceTypeName)
  b.build()
