import std/strutils
import doggy/dogstatsd/types, doggy/dogstatsd/encoder

block metric_no_rate_no_tags:
  assert encodeMetric("cpu", "0.5", "g", 1.0, @[]) == "cpu:0.5|g"

block metric_with_rate:
  assert encodeMetric("hits", "1", "c", 0.1, @[]) == "hits:1|c|@0.1"

block metric_with_tags:
  assert encodeMetric("req", "42", "h", 1.0, @["env:prod", "svc:api"]) ==
    "req:42|h|#env:prod,svc:api"

block metric_rate_and_tags:
  assert encodeMetric("m", "1", "c", 0.5, @["k:v"]) == "m:1|c|@0.5|#k:v"

block metric_rate_exactly_1_omitted:
  let d = encodeMetric("m", "1", "c", 1.0, @[])
  assert not d.contains("@"), "sampleRate=1.0 must not emit @rate: " & d

block statsd_metric_wrapper:
  assert encodeStatsdMetric(newCounter("x", 3.0)) == "x:3.0|c"
  assert encodeStatsdMetric(newGauge("g", 7.5)) == "g:7.5|g"
  assert encodeStatsdMetric(newHistogram("h", 1.0)) == "h:1.0|h"
  assert encodeStatsdMetric(newSet("s", 1.0)) == "s:1.0|s"
  assert encodeStatsdMetric(newTiming("t", 16.7)) == "t:16.7|ms"

block event_format:
  let ev = StatsdEvent(title: "Deploy", text: "v1.0", alertType: satSuccess,
                       tags: @["env:prod"])
  let d = encodeEvent(ev)
  assert d == "_e{6,4}:Deploy|v1.0|t:success|#env:prod", d

block event_newline_escaped:
  let ev = StatsdEvent(title: "Alert", text: "line1\nline2", alertType: satError)
  let d = encodeEvent(ev)
  assert not d.contains("\n"), "raw newline must not appear in datagram: " & d
  assert d.contains("\\n"), "newline must be escaped as \\n: " & d
  # escaped text is 12 chars ("line1\nline2" with \ and n = 12)
  assert d.startsWith("_e{5,12}:"), d

block service_check_ok:
  let sc = StatsdServiceCheck(name: "db.ping", status: scOk)
  assert encodeServiceCheck(sc) == "_sc|db.ping|0"

block service_check_critical:
  assert encodeServiceCheck(StatsdServiceCheck(name: "x", status: scCritical)) == "_sc|x|2"

block service_check_status_ordinals:
  assert encodeServiceCheck(StatsdServiceCheck(name: "x", status: scOk))       == "_sc|x|0"
  assert encodeServiceCheck(StatsdServiceCheck(name: "x", status: scWarning))  == "_sc|x|1"
  assert encodeServiceCheck(StatsdServiceCheck(name: "x", status: scCritical)) == "_sc|x|2"
  assert encodeServiceCheck(StatsdServiceCheck(name: "x", status: scUnknown))  == "_sc|x|3"

block service_check_tags_before_message:
  # tags MUST precede message so the terminal |m: field doesn't absorb them
  let sc = StatsdServiceCheck(name: "redis", status: scCritical,
                               message: "Redis down", tags: @["env:prod", "region:us"])
  let d = encodeServiceCheck(sc)
  assert d == "_sc|redis|2|#env:prod,region:us|m:Redis down", d

block service_check_message_only:
  let sc = StatsdServiceCheck(name: "x", status: scOk, message: "all good")
  assert encodeServiceCheck(sc) == "_sc|x|0|m:all good"

block service_check_newline_escaped:
  let sc = StatsdServiceCheck(name: "x", status: scWarning, message: "line1\nline2")
  let d = encodeServiceCheck(sc)
  assert not d.contains("\n"), "raw newline in message: " & d
  assert d.contains("\\n"), "newline not escaped: " & d

when isMainModule:
  echo "DogStatsD encoder tests passed"
