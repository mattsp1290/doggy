import doggy/site
import doggy/json_emit
import std/strutils

type
  DdAlertType* = enum
    datInfo    = "info"
    datWarning = "warning"
    datError   = "error"
    datSuccess = "success"

  DdEvent* = object
    title*:          string
    text*:           string
    dateHappened*:   int64   # epoch seconds
    alertType*:      DdAlertType
    tags*:           seq[string]
    sourceTypeName*: string

  EventsConfig* = object
    apiKey*: string
    site*:   DdSite

proc toJson*(ev: DdEvent): string =
  var b = newJsonObject()
  b.addStr("title", ev.title)
  b.addStr("text", ev.text)
  b.addInt("date_happened", ev.dateHappened)
  b.addStr("alert_type", $ev.alertType)
  if ev.tags.len > 0:
    b.addStr("tags", ev.tags.join(","))
  if ev.sourceTypeName.len > 0:
    b.addStr("source_type_name", ev.sourceTypeName)
  b.build()
