import std/json
import doggy/error_tracking/types, doggy/error_tracking/serialize

block nested_error_object:
  let ev = ErrorEvent(errorStack: "at main.nim:42", errorKind: "IOError",
                      errorMessage: "file not found", service: "api",
                      hostname: "host1")
  let parsed = toJson(ev).parseJson()
  assert parsed.hasKey("error"), "must have nested 'error' object"
  assert parsed["error"]["stack"].getStr() == "at main.nim:42"
  assert parsed["error"]["kind"].getStr() == "IOError"
  assert parsed["error"]["message"].getStr() == "file not found"

block ddsource_default:
  let ev = ErrorEvent(errorStack: "s", errorKind: "E", errorMessage: "m",
                      service: "svc", hostname: "h")
  let parsed = toJson(ev).parseJson()
  assert parsed["ddsource"].getStr() == "nim", "ddsource must default to 'nim'"

block ddsource_override:
  let ev = ErrorEvent(errorStack: "s", errorKind: "E", errorMessage: "m",
                      ddSource: "custom", service: "svc", hostname: "h")
  let parsed = toJson(ev).parseJson()
  assert parsed["ddsource"].getStr() == "custom"

block optional_fields_omitted_when_empty:
  let ev = ErrorEvent(errorStack: "s", errorKind: "E", errorMessage: "m")
  let parsed = toJson(ev).parseJson()
  assert not parsed.hasKey("ddtags"), "ddtags must be omitted when empty"
  assert not parsed.hasKey("version"), "version must be omitted when empty"
  assert not parsed.hasKey("service"), "empty service must be omitted"
  assert not parsed.hasKey("hostname"), "empty hostname must be omitted"

block optional_fields_present_when_set:
  let ev = ErrorEvent(errorStack: "s", errorKind: "E", errorMessage: "m",
                      service: "api", hostname: "h", ddTags: "env:prod",
                      version: "1.2.3")
  let parsed = toJson(ev).parseJson()
  assert parsed["service"].getStr() == "api"
  assert parsed["hostname"].getStr() == "h"
  assert parsed["ddtags"].getStr() == "env:prod"
  assert parsed["version"].getStr() == "1.2.3"

block json_array_round_trip:
  let evs = @[
    ErrorEvent(errorStack: "s1", errorKind: "E1", errorMessage: "m1",
               service: "svc", hostname: "h"),
    ErrorEvent(errorStack: "s2", errorKind: "E2", errorMessage: "m2",
               service: "svc", hostname: "h"),
  ]
  let arr = toJsonArray(evs).parseJson()
  assert arr.kind == JArray and arr.len == 2
  assert arr[0]["error"]["kind"].getStr() == "E1"
  assert arr[1]["error"]["kind"].getStr() == "E2"

block empty_array:
  let arr = toJsonArray(@[]).parseJson()
  assert arr.kind == JArray and arr.len == 0

when isMainModule:
  echo "Error Tracking serialize tests passed"
