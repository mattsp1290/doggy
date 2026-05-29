import std/json
import doggy/rum/types, doggy/rum/serialize

proc makeBase(sessionId: string = "sess-1"; viewId: string = "view-1";
              appId: string = "app-1"; ts: int64 = 1_000_000): RumEventBase =
  RumEventBase(sessionId: sessionId, viewId: viewId,
               applicationId: appId, timestamp: ts,
               service: "my-service", version: "1.0")

block session_event_required_fields:
  let ev = RumSessionEvent(base: makeBase())
  let j = toJson(ev).parseJson()
  assert j["_dd"]["format_version"].getInt() == 2
  assert j["type"].getStr() == "session"
  assert j["date"].getInt() == 1_000_000
  assert j["application"]["id"].getStr() == "app-1"
  assert j["session"]["id"].getStr() == "sess-1"
  assert j["view"]["id"].getStr() == "view-1"

block view_event_has_name_and_url:
  let ev = RumViewEvent(base: makeBase(), name: "MainMenu", url: "game://main")
  let j = toJson(ev).parseJson()
  assert j["type"].getStr() == "view"
  assert j["view"]["name"].getStr() == "MainMenu"
  assert j["view"]["url"].getStr() == "game://main"
  assert j["view"]["id"].getStr() == "view-1"

block view_event_omits_empty_url:
  let ev = RumViewEvent(base: makeBase(), name: "Loading")
  let j = toJson(ev).parseJson()
  assert not j["view"].hasKey("url"), "empty url must be omitted"

block action_event_type_and_target:
  let ev = RumActionEvent(base: makeBase(), actionType: ratClick, name: "Play")
  let j = toJson(ev).parseJson()
  assert j["type"].getStr() == "action"
  assert j["action"]["type"].getStr() == "click"
  assert j["action"]["target"]["name"].getStr() == "Play"

block action_event_empty_name_omits_target:
  let ev = RumActionEvent(base: makeBase(), actionType: ratTap, name: "")
  let j = toJson(ev).parseJson()
  assert not j["action"].hasKey("target"), "empty name must omit target"

block resource_event_fields:
  let ev = RumResourceEvent(base: makeBase(), resourceType: rrtImage,
                             url: "game://asset.png", durationMs: 42)
  let j = toJson(ev).parseJson()
  assert j["type"].getStr() == "resource"
  assert j["resource"]["type"].getStr() == "image"
  assert j["resource"]["url"].getStr() == "game://asset.png"
  assert j["resource"]["duration"].getInt() == 42

block error_event_fields:
  let ev = RumErrorEvent(base: makeBase(), message: "oops",
                          source: "source", stack: "at main:1")
  let j = toJson(ev).parseJson()
  assert j["type"].getStr() == "error"
  assert j["error"]["message"].getStr() == "oops"
  assert j["error"]["source"].getStr() == "source"
  assert j["error"]["stack"].getStr() == "at main:1"

block vital_event_fields:
  let ev = RumVitalEvent(base: makeBase(), name: "frame_time",
                          value: 16.7, unit: "ms")
  let j = toJson(ev).parseJson()
  assert j["type"].getStr() == "vital"
  assert j["vital"]["name"].getStr() == "frame_time"
  assert j["vital"]["value"].getFloat() == 16.7
  assert j["vital"]["unit"].getStr() == "ms"

block service_and_version_propagated:
  let ev = RumSessionEvent(base: makeBase(sessionId = "s", viewId = "v",
                                          appId = "a", ts = 0'i64))
  let j = toJson(ev).parseJson()
  assert j["service"].getStr() == "my-service"
  assert j["version"].getStr() == "1.0"

block optional_ddtags_omitted_when_empty:
  let ev = RumSessionEvent(base: makeBase())
  let j = toJson(ev).parseJson()
  assert not j.hasKey("ddtags"), "ddtags must be omitted when empty"

block optional_ddtags_included_when_set:
  var base = makeBase()
  base.ddtags = "env:prod,region:us"
  let ev = RumSessionEvent(base: base)
  let j = toJson(ev).parseJson()
  assert j["ddtags"].getStr() == "env:prod,region:us"

when isMainModule:
  echo "RUM serialize tests passed"
