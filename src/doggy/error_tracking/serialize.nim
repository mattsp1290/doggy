import doggy/json_emit
import doggy/error_tracking/types

proc toJson*(ev: ErrorEvent): string =
  var b = newJsonObject()
  # error fields must be nested under "error" — flat dotted-key strings
  # (error.stack etc.) are NOT parsed as structured fields by the logs intake
  b.startObj("error")
  b.addStr("stack",   ev.errorStack)
  b.addStr("kind",    ev.errorKind)
  b.addStr("message", ev.errorMessage)
  b.endObj()
  b.addStr("ddsource", if ev.ddSource.len > 0: ev.ddSource else: "nim")
  b.addStr("service",  ev.service)
  b.addStr("hostname", ev.hostname)
  if ev.ddTags.len > 0:
    b.addStr("ddtags", ev.ddTags)
  if ev.version.len > 0:
    b.addStr("version", ev.version)
  b.build()

proc toJsonArray*(events: seq[ErrorEvent]): string =
  var b = newJsonArray()
  for ev in events:
    b.addRawElem(toJson(ev))
  b.build()
