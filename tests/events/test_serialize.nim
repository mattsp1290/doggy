import std/json
import doggy/events/types

block full_event_round_trip:
  let ev = DdEvent(
    title:          "Deploy completed",
    text:           "v2.1.0 deployed to prod",
    dateHappened:   1_700_000_000'i64,
    alertType:      datSuccess,
    tags:           @["env:prod", "version:2.1.0"],
    sourceTypeName: "my_ci_tool",
  )
  let j = ev.toJson()
  let parsed = j.parseJson()
  assert parsed["title"].getStr() == "Deploy completed"
  assert parsed["text"].getStr() == "v2.1.0 deployed to prod"
  assert parsed["date_happened"].getInt() == 1_700_000_000
  assert parsed["alert_type"].getStr() == "success"
  assert parsed["tags"].kind == JArray
  assert parsed["tags"].len == 2
  assert parsed["tags"][0].getStr() == "env:prod"
  assert parsed["tags"][1].getStr() == "version:2.1.0"
  assert parsed["source_type_name"].getStr() == "my_ci_tool"

block alert_type_literals:
  for (at, expected) in [(datInfo, "info"), (datWarning, "warning"),
                          (datError, "error"), (datSuccess, "success")]:
    let ev = DdEvent(title: "t", text: "x", alertType: at)
    let parsed = ev.toJson().parseJson()
    assert parsed["alert_type"].getStr() == expected,
      "alert_type " & expected & " mismatch"

block empty_tags_omitted:
  let ev = DdEvent(title: "t", text: "x", alertType: datInfo)
  let j = ev.toJson()
  let parsed = j.parseJson()
  assert not parsed.hasKey("tags"), "empty tags must be omitted, got: " & j

block zero_date_omitted:
  let ev = DdEvent(title: "t", text: "x", alertType: datInfo)
  let j = ev.toJson()
  let parsed = j.parseJson()
  assert not parsed.hasKey("date_happened"), "zero date must be omitted: " & j

block empty_source_omitted:
  let ev = DdEvent(title: "t", text: "x", alertType: datInfo)
  let j = ev.toJson()
  let parsed = j.parseJson()
  assert not parsed.hasKey("source_type_name"), "empty source must be omitted: " & j

when isMainModule:
  echo "Events serialize tests passed"
