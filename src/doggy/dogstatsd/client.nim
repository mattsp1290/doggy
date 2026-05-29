import std/atomics
import std/net
import std/sysrand
import doggy/dogstatsd/encoder
import doggy/dogstatsd/types

type
  DogStatsd* = object
    config:        StatsdConfig
    sock:          Socket
    droppedField:  Atomic[int64]

proc `=copy`*(dst: var DogStatsd; src: DogStatsd) {.error:
  "DogStatsd owns a Socket and Atomic — pass by var, not by value".}

proc initDogStatsd*(client: var DogStatsd; config: StatsdConfig) =
  client.config = config
  client.sock = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  client.droppedField.store(0)

proc deinitDogStatsd*(client: var DogStatsd) =
  client.sock.close()

proc droppedCount*(client: var DogStatsd): int64 =
  client.droppedField.load()

proc send*(client: var DogStatsd; datagram: string) =
  try:
    client.sock.sendTo(client.config.host, Port(client.config.port), datagram)
  except OSError as e:
    discard client.droppedField.fetchAdd(1)
    if client.config.onError != nil:
      client.config.onError(e.msg)

proc shouldSample(rate: float64): bool {.inline.} =
  if rate >= 1.0:
    return true
  var buf: array[8, byte]
  discard urandom(buf)
  let n = cast[uint64](buf)
  float64(n) / float64(high(uint64)) < rate

proc mergeTags(defaults: seq[string]; extra: seq[string]): seq[string] =
  result = defaults
  result.add(extra)

proc sampleDrop(client: var DogStatsd) {.inline.} =
  discard client.droppedField.fetchAdd(1)

proc counter*(client: var DogStatsd; name: string; value: float64 = 1.0;
              tags: seq[string] = @[]; sampleRate: float64 = 1.0) =
  if not shouldSample(sampleRate): client.sampleDrop(); return
  client.send(encodeStatsdMetric(
    newCounter(name, value, mergeTags(client.config.defaultTags, tags), sampleRate)))

proc gauge*(client: var DogStatsd; name: string; value: float64;
            tags: seq[string] = @[]; sampleRate: float64 = 1.0) =
  if not shouldSample(sampleRate): client.sampleDrop(); return
  client.send(encodeStatsdMetric(
    newGauge(name, value, mergeTags(client.config.defaultTags, tags), sampleRate)))

proc histogram*(client: var DogStatsd; name: string; value: float64;
                tags: seq[string] = @[]; sampleRate: float64 = 1.0) =
  if not shouldSample(sampleRate): client.sampleDrop(); return
  client.send(encodeStatsdMetric(
    newHistogram(name, value, mergeTags(client.config.defaultTags, tags), sampleRate)))

proc set*(client: var DogStatsd; name: string; value: float64;
          tags: seq[string] = @[]; sampleRate: float64 = 1.0) =
  if not shouldSample(sampleRate): client.sampleDrop(); return
  client.send(encodeStatsdMetric(
    newSet(name, value, mergeTags(client.config.defaultTags, tags), sampleRate)))

proc timing*(client: var DogStatsd; name: string; value: float64;
             tags: seq[string] = @[]; sampleRate: float64 = 1.0) =
  if not shouldSample(sampleRate): client.sampleDrop(); return
  client.send(encodeStatsdMetric(
    newTiming(name, value, mergeTags(client.config.defaultTags, tags), sampleRate)))

proc event*(client: var DogStatsd; ev: StatsdEvent) =
  client.send(encodeEvent(ev))

proc serviceCheck*(client: var DogStatsd; sc: StatsdServiceCheck) =
  client.send(encodeServiceCheck(sc))
