import doggy/json_emit
import doggy/rum/types

proc addBase(b: var JsonBuilder; base: RumEventBase; eventType: string) =
  b.startObj("_dd")
  b.addInt("format_version", 2'i64)
  b.addInt("drift", 0'i64)
  b.startObj("session")
  b.addInt("plan", 1'i64)  # 1=LITE (no replay), 2=REPLAY
  b.endObj()
  b.endObj()
  b.addStr("type", eventType)
  b.addInt("date", base.timestamp)
  b.startObj("application")
  b.addStr("id", base.applicationId)
  b.endObj()
  b.startObj("session")
  b.addStr("id", base.sessionId)
  b.addStr("type", "user")
  if base.userAgent.len > 0:
    b.addStr("useragent", base.userAgent)
  b.endObj()
  if base.service.len > 0:
    b.addStr("service", base.service)
  if base.version.len > 0:
    b.addStr("version", base.version)
  if base.ddtags.len > 0:
    b.addStr("ddtags", base.ddtags)

proc toJson*(ev: RumSessionEvent): string =
  var b = newJsonObject()
  addBase(b, ev.base, "session")
  b.startObj("view")
  b.addStr("id", ev.base.viewId)
  b.endObj()
  b.build()

proc toJson*(ev: RumViewEvent): string =
  var b = newJsonObject()
  addBase(b, ev.base, "view")
  b.startObj("view")
  b.addStr("id", ev.base.viewId)
  b.addStr("name", ev.name)
  if ev.url.len > 0:
    b.addStr("url", ev.url)
  b.endObj()
  b.build()

proc toJson*(ev: RumActionEvent): string =
  var b = newJsonObject()
  addBase(b, ev.base, "action")
  b.startObj("view")
  b.addStr("id", ev.base.viewId)
  b.endObj()
  b.startObj("action")
  b.addStr("type", $ev.actionType)
  if ev.name.len > 0:
    b.startObj("target")
    b.addStr("name", ev.name)
    b.endObj()
  b.endObj()
  b.build()

proc toJson*(ev: RumResourceEvent): string =
  var b = newJsonObject()
  addBase(b, ev.base, "resource")
  b.startObj("view")
  b.addStr("id", ev.base.viewId)
  b.endObj()
  b.startObj("resource")
  b.addStr("type", $ev.resourceType)
  b.addStr("url", ev.url)
  b.addInt("duration", ev.durationMs)
  b.endObj()
  b.build()

proc toJson*(ev: RumErrorEvent): string =
  var b = newJsonObject()
  addBase(b, ev.base, "error")
  b.startObj("view")
  b.addStr("id", ev.base.viewId)
  b.endObj()
  b.startObj("error")
  b.addStr("message", ev.message)
  if ev.source.len > 0:
    b.addStr("source", ev.source)
  if ev.stack.len > 0:
    b.addStr("stack", ev.stack)
  b.endObj()
  b.build()

proc toJson*(ev: RumVitalEvent): string =
  var b = newJsonObject()
  addBase(b, ev.base, "vital")
  b.startObj("view")
  b.addStr("id", ev.base.viewId)
  b.endObj()
  b.startObj("vital")
  b.addStr("name", ev.name)
  b.addFloat("value", ev.value)
  if ev.unit.len > 0:
    b.addStr("unit", ev.unit)
  b.endObj()
  b.build()
