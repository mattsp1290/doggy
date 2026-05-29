import std/nativesockets
import doggy/site

type
  ErrorEvent* = object
    errorStack*:   string
    errorKind*:    string  # exception type name
    errorMessage*: string
    ddSource*:     string
    service*:      string
    hostname*:     string
    ddTags*:       string
    version*:      string

  ErrorTrackingConfig* = object
    apiKey*:         string
    service*:        string
    hostname*:       string
    version*:        string
    site*:           DdSite
    batchSize*:      int
    flushIntervalMs*: int

proc defaultErrorTrackingConfig*(apiKey, service: string;
                                  site = SiteUS1): ErrorTrackingConfig =
  ErrorTrackingConfig(
    apiKey:          apiKey,
    service:         service,
    hostname:        getHostname(),
    site:            site,
    batchSize:       20,
    flushIntervalMs: 5_000,
  )
