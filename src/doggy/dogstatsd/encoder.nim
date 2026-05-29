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

proc dsdEscape(s: string): string =
  # DogStatsD receivers are commonly line-split; escape newlines per convention
  s.replace("\n", "\\n")

proc encodeEvent*(ev: StatsdEvent): string =
  let title = dsdEscape(ev.title)
  let text  = dsdEscape(ev.text)
  result = fmt"_e{{{title.len},{text.len}}}:{title}|{text}"
  result.add("|t:" & $ev.alertType)
  if ev.tags.len > 0:
    result.add("|#" & ev.tags.join(","))

proc encodeServiceCheck*(sc: StatsdServiceCheck): string =
  # status ordinal: ok=0, warning=1, critical=2, unknown=3
  let statusCode = ord(sc.status)
  result = "_sc|" & sc.name & "|" & $statusCode
  # tags must precede message — the message field runs to end-of-packet and
  # a parser reading from |m: absorbs everything after it, including |#tags
  if sc.tags.len > 0:
    result.add("|#" & sc.tags.join(","))
  if sc.message.len > 0:
    result.add("|m:" & dsdEscape(sc.message))
