import std/strutils
import doggy/events/types
import doggy/site

block tojson_basic:
  let ev = DdEvent(title: "deploy", text: "v1.2 deployed", alertType: datInfo)
  let j = ev.toJson()
  assert j.contains(""""title":"deploy""""), j
  assert j.contains(""""text":"v1.2 deployed""""), j
  assert j.contains(""""alert_type":"info""""), j

block tojson_no_date_when_zero:
  let ev = DdEvent(title: "t", text: "x", alertType: datInfo)
  let j = ev.toJson()
  assert not j.contains("date_happened"), "zero timestamp must be omitted: " & j

block tojson_date_when_set:
  let ev = DdEvent(title: "t", text: "x", alertType: datInfo, dateHappened: 1_700_000_000'i64)
  let j = ev.toJson()
  assert j.contains("date_happened"), j
  assert j.contains("1700000000"), j

block tojson_tags_as_array:
  let ev = DdEvent(title: "t", text: "x", alertType: datWarning,
                   tags: @["env:prod", "version:1"])
  let j = ev.toJson()
  assert j.contains(""""tags":["env:prod","version:1"]"""), "tags must be JSON array: " & j

block tojson_no_empty_tags:
  let ev = DdEvent(title: "t", text: "x", alertType: datInfo)
  let j = ev.toJson()
  assert not j.contains("tags"), "empty tags must be omitted: " & j

block tojson_source_type:
  let ev = DdEvent(title: "t", text: "x", alertType: datSuccess,
                   sourceTypeName: "my_tool")
  let j = ev.toJson()
  assert j.contains(""""source_type_name":"my_tool""""), j

block tojson_no_source_type_when_empty:
  let ev = DdEvent(title: "t", text: "x", alertType: datInfo)
  let j = ev.toJson()
  assert not j.contains("source_type_name"), j

block alert_types:
  for (at, expected) in [(datInfo, "info"), (datWarning, "warning"),
                          (datError, "error"), (datSuccess, "success")]:
    let ev = DdEvent(title: "t", text: "x", alertType: at)
    let j = ev.toJson()
    assert j.contains(expected), "alert_type '" & expected & "' not found: " & j

block default_events_config:
  let cfg = defaultEventsConfig("mykey")
  assert cfg.apiKey == "mykey"
  assert cfg.site == SiteUS1

when isMainModule:
  echo "Events types tests passed"
