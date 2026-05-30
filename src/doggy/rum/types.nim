import doggy/site

type
  RumActionType* = enum
    ratClick = "click"
    ratTap   = "tap"
    ratSwipe = "swipe"
    ratCustom = "custom"

  RumResourceType* = enum
    rrtImage = "image"
    rrtAudio = "audio"
    rrtOther = "other"

  RumDeviceInfo* = object
    deviceType*:    string  ## "desktop", "mobile", "tablet", "tv", "other"
    name*:          string  ## e.g. "MacBook Pro"
    model*:         string  ## e.g. "Mac16,6"
    brand*:         string  ## e.g. "Apple"
    architecture*:  string  ## e.g. "arm64"

  RumOsInfo* = object
    osType*:        string  ## "macos", "ios", "android", "windows", "linux"
    name*:          string  ## e.g. "macOS"
    version*:       string  ## e.g. "26.5"
    versionMajor*:  string  ## e.g. "26"
    build*:         string  ## e.g. "25F71"

  # Common fields shared across all RUM event types.
  RumEventBase* = object
    sessionId*:     string
    viewId*:        string
    applicationId*: string
    timestamp*:     int64
    ddtags*:        string
    service*:       string
    version*:       string
    userAgent*:     string
    ddSource*:      string      ## copied from config; emitted as _dd.source
    device*:        RumDeviceInfo
    os*:            RumOsInfo

  RumSessionEvent* = object
    base*: RumEventBase

  RumViewEvent* = object
    base*:     RumEventBase
    name*:     string
    url*:      string

  RumActionEvent* = object
    base*:        RumEventBase
    actionType*:  RumActionType
    name*:        string

  RumResourceEvent* = object
    base*:         RumEventBase
    resourceType*: RumResourceType
    url*:          string
    durationMs*:   int64

  RumErrorEvent* = object
    base*:    RumEventBase
    message*: string
    source*:  string
    stack*:   string

  RumVitalEvent* = object
    base*:  RumEventBase
    name*:  string
    value*: float64
    unit*:  string

  RumConfig* = object
    clientToken*:    string
    applicationId*:  string
    service*:        string
    version*:        string
    site*:           DdSite
    batchSize*:      int
    flushIntervalMs*: int
    userAgent*:      string      ## HTTP User-Agent header + session.useragent
    ddSource*:       string      ## ddsource= URL param and _dd.source in payload
    device*:         RumDeviceInfo
    os*:             RumOsInfo

proc defaultRumConfig*(clientToken, applicationId, service: string;
                       site = SiteUS1): RumConfig =
  RumConfig(
    clientToken:     clientToken,
    applicationId:   applicationId,
    service:         service,
    site:            site,
    batchSize:       50,
    flushIntervalMs: 10_000,
    ddSource:        "browser",
  )
