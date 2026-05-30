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

  # Common fields shared across all RUM event types.
  # All events reference the same session + view ancestry.
  RumEventBase* = object
    sessionId*:     string
    viewId*:        string
    applicationId*: string
    timestamp*:     int64   # ms since epoch
    ddtags*:        string
    service*:       string
    version*:       string
    userAgent*:     string  # session.useragent; empty = omit

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
    userAgent*:      string  # set in session.useragent; empty = omit
    ddSource*:       string  # ddsource URL param; defaults to "browser"

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
