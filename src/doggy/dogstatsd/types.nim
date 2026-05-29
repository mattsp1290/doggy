type
  StatsdAlertType* = enum
    satInfo    = "info"
    satWarning = "warning"
    satError   = "error"
    satSuccess = "success"

  StatsdServiceCheckStatus* = enum
    scOk       = "ok"
    scWarning  = "warning"
    scCritical = "critical"
    scUnknown  = "unknown"

  StatsdConfig* = object
    host*:        string
    port*:        int
    defaultTags*: seq[string]
    # Called on send errors; must be {.gcsafe.} — invoked from any thread
    onError*:     proc(msg: string) {.gcsafe.}

  StatsdMetric* = object
    name*:       string
    value*:      float64
    metricType*: string  # "c" | "g" | "h" | "s" | "ms"
    tags*:       seq[string]
    sampleRate*: float64

  StatsdEvent* = object
    title*:     string
    text*:      string
    alertType*: StatsdAlertType
    tags*:      seq[string]

  StatsdServiceCheck* = object
    name*:    string
    status*:  StatsdServiceCheckStatus
    message*: string
    tags*:    seq[string]

proc defaultStatsdConfig*(host = "localhost"; port = 8125): StatsdConfig =
  StatsdConfig(host: host, port: port, defaultTags: @[],
               onError: proc(msg: string) {.gcsafe.} = discard)

proc newCounter*(name: string; value: float64 = 1.0;
                 tags: seq[string] = @[]; sampleRate: float64 = 1.0): StatsdMetric =
  StatsdMetric(name: name, value: value, metricType: "c", tags: tags, sampleRate: sampleRate)

proc newGauge*(name: string; value: float64;
               tags: seq[string] = @[]; sampleRate: float64 = 1.0): StatsdMetric =
  StatsdMetric(name: name, value: value, metricType: "g", tags: tags, sampleRate: sampleRate)

proc newHistogram*(name: string; value: float64;
                   tags: seq[string] = @[]; sampleRate: float64 = 1.0): StatsdMetric =
  StatsdMetric(name: name, value: value, metricType: "h", tags: tags, sampleRate: sampleRate)

proc newSet*(name: string; value: float64;
             tags: seq[string] = @[]; sampleRate: float64 = 1.0): StatsdMetric =
  StatsdMetric(name: name, value: value, metricType: "s", tags: tags, sampleRate: sampleRate)

proc newTiming*(name: string; value: float64;
                tags: seq[string] = @[]; sampleRate: float64 = 1.0): StatsdMetric =
  StatsdMetric(name: name, value: value, metricType: "ms", tags: tags, sampleRate: sampleRate)
