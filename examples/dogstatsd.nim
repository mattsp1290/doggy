## DogStatsD example — run against the Datadog Agent at localhost:8125.
## Reads DD_STATSD_HOST and DD_STATSD_PORT from env (defaults: localhost, 8125).
##
## Compile: nim c --mm:orc --threads:on -d:ssl -r examples/dogstatsd.nim

import std/[os, strutils]
import doggy/dogstatsd/types, doggy/dogstatsd/client

proc main() =
  let host = getEnv("DD_STATSD_HOST", "localhost")
  let port = parseInt(getEnv("DD_STATSD_PORT", "8125"))
  let cfg  = defaultStatsdConfig(host, port)

  var statsd: DogStatsd
  initDogStatsd(statsd, cfg)
  defer: deinitDogStatsd(statsd)

  echo "Sending DogStatsD metrics to ", host, ":", port

  statsd.counter("doggy.example.requests", 1.0, tags = @["method:GET", "status:200"])
  statsd.gauge("doggy.example.queue_depth", 42.0, tags = @["service:demo"])
  statsd.histogram("doggy.example.response_time", 123.4, tags = @["endpoint:/api/v1"])
  statsd.timing("doggy.example.db_query", 45.2, tags = @["query:select"])
  statsd.counter("doggy.example.sampled_hits", 1.0, sampleRate = 0.1)

  statsd.event(StatsdEvent(
    title:     "Doggy Example Run",
    text:      "Successfully sent DogStatsD metrics.",
    alertType: satSuccess,
    tags:      @["env:dev"],
  ))

  statsd.serviceCheck(StatsdServiceCheck(
    name:    "doggy.example.health",
    status:  scOk,
    message: "All systems nominal",
    tags:    @["env:dev"],
  ))

  echo "Sent. dropped=", statsd.droppedCount()

main()
