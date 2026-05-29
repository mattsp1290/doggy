import doggy/dogstatsd/types

block metric_constructors:
  assert newCounter("c").metricType == "c"
  assert newCounter("c").value == 1.0
  assert newCounter("c").sampleRate == 1.0
  assert newGauge("g", 2.5).metricType == "g"
  assert newGauge("g", 2.5).value == 2.5
  assert newHistogram("h", 1.0).metricType == "h"
  assert newSet("s", 1.0).metricType == "s"
  assert newTiming("t", 16.7).metricType == "ms"
  assert newTiming("t", 16.7).value == 16.7

block metric_tags_and_rate:
  let m = newCounter("hits", 1.0, @["env:prod", "svc:api"], 0.1)
  assert m.name == "hits"
  assert m.tags == @["env:prod", "svc:api"]
  assert m.sampleRate == 0.1

block default_config:
  let cfg = defaultStatsdConfig()
  assert cfg.host == "localhost"
  assert cfg.port == 8125
  assert cfg.defaultTags.len == 0
  assert cfg.onError != nil, "default onError must not be nil"

block default_config_custom:
  let cfg = defaultStatsdConfig("agent.internal", 9125)
  assert cfg.host == "agent.internal"
  assert cfg.port == 9125

when isMainModule:
  echo "DogStatsD types tests passed"
