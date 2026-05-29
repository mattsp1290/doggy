import std/strformat, std/strutils
import doggy/dogstatsd/types

proc encodeMetric*(name: string; value: string; metricType: string;
                   sampleRate: float64; tags: seq[string]): string =
  result = name & ":" & value & "|" & metricType
  if sampleRate < 1.0:
    result.add("|@" & $sampleRate)
  if tags.len > 0:
    result.add("|#" & tags.join(","))

proc encodeStatsdMetric*(m: StatsdMetric): string =
  encodeMetric(m.name, $m.value, m.metricType, m.sampleRate, m.tags)

proc encodeEvent*(ev: StatsdEvent): string =
  let titleLen = ev.title.len
  let textLen  = ev.text.len
  result = fmt"_e{{{titleLen},{textLen}}}:{ev.title}|{ev.text}"
  result.add("|t:" & $ev.alertType)
  if ev.tags.len > 0:
    result.add("|#" & ev.tags.join(","))

proc encodeServiceCheck*(sc: StatsdServiceCheck): string =
  # status ordinal: ok=0, warning=1, critical=2, unknown=3
  let statusCode = ord(sc.status)
  result = "_sc|" & sc.name & "|" & $statusCode
  if sc.message.len > 0:
    result.add("|m:" & sc.message)
  if sc.tags.len > 0:
    result.add("|#" & sc.tags.join(","))
