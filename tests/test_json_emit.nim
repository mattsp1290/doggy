import std/strutils
import doggy/json_emit

block basic_types:
  var b = newJsonObject()
  b.addStr("s", "hello")
  b.addInt("i", 42'i64)
  b.addFloat("f", 3.14)
  b.addBool("t", true)
  b.addBool("fl", false)
  b.addNull("n")
  let json = b.build()
  assert json == """{"s":"hello","i":42,"f":3.14,"t":true,"fl":false,"n":null}""", json

block string_escaping_quote:
  var b = newJsonObject()
  b.addStr("v", "say \"hi\"")
  let json = b.build()
  assert json.contains("\\\"hi\\\""), "double-quote not escaped: " & json

block string_escaping_newline:
  var b = newJsonObject()
  b.addStr("v", "a\nb")
  let json = b.build()
  assert json.contains("\\n"), "newline not escaped: " & json
  assert not json.contains("\n"), "raw newline should not appear in JSON: " & json

block string_escaping_tab:
  var b = newJsonObject()
  b.addStr("v", "a\tb")
  let json = b.build()
  assert json.contains("\\t"), "tab not escaped: " & json

block string_escaping_backslash:
  var b = newJsonObject()
  b.addStr("v", "a\\b")
  let json = b.build()
  assert json.contains("\\\\"), "backslash not escaped: " & json

block string_escaping_control:
  var b = newJsonObject()
  b.addStr("v", "a\x01b")
  let json = b.build()
  assert json.contains("\\u0001"), "control char not escaped: " & json

block nested_objects:
  var b = newJsonObject()
  b.addStr("a", "1")
  b.startObj("inner")
  b.addStr("x", "y")
  b.endObj()
  b.addStr("b", "2")
  let json = b.build()
  assert json == """{"a":"1","inner":{"x":"y"},"b":"2"}""", json

block empty_object:
  var b = newJsonObject()
  assert b.build() == "{}"

block addFloat_nonfinite:
  var b = newJsonObject()
  b.addFloat("nan", NaN)
  b.addFloat("inf", Inf)
  b.addFloat("neginf", NegInf)
  b.addFloat("ok", 1.5)
  let json = b.build()
  assert json == """{"nan":null,"inf":null,"neginf":null,"ok":1.5}""", json

block top_level_array:
  var b = newJsonArray()
  b.addStrElem("a")
  b.addIntElem(1'i64)
  b.addBoolElem(true)
  b.addNullElem()
  let json = b.build()
  assert json == """["a",1,true,null]""", json

block array_of_objects:
  var b = newJsonArray()
  b.startObjElem()
  b.addStr("id", "1")
  b.endObj()
  b.startObjElem()
  b.addStr("id", "2")
  b.endObj()
  let json = b.build()
  assert json == """[{"id":"1"},{"id":"2"}]""", json

block array_in_object:
  var b = newJsonObject()
  b.startArr("tags")
  b.addStrElem("env:prod")
  b.addStrElem("v:1")
  b.endArr()
  let json = b.build()
  assert json == """{"tags":["env:prod","v:1"]}""", json

block ndjson_join:
  let lines = toNdjson(@["""{"a":1}""", """{"b":2}""", """{"c":3}"""])
  assert lines == "{\"a\":1}\n{\"b\":2}\n{\"c\":3}", lines

block ndjson_empty:
  assert toNdjson(@[]) == ""

block balance_guard:
  var fired = false
  try:
    var b = newJsonObject()
    b.startObj("x")
    discard b.build()
  except AssertionDefect:
    fired = true
  assert fired, "expected AssertionDefect for unbalanced build"

when isMainModule:
  echo "JSON emitter tests passed"
