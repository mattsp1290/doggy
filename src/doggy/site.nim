import std/os

type DdSite* = enum
  SiteUS1   = "datadoghq.com"
  SiteEU1   = "datadoghq.eu"
  SiteUS3   = "us3.datadoghq.com"
  SiteUS5   = "us5.datadoghq.com"
  SiteAP1   = "ap1.datadoghq.com"

# Hardcoded intake URL tables — no string interpolation.
# Enum-keyed so a reorder of DdSite members cannot silently mismap a site's URLs.
const rumIntakeUrls: array[DdSite, string] = [
  SiteUS1: "https://browser-intake-datadoghq.com/api/v2/rum",
  SiteEU1: "https://browser-intake-datadoghq.eu/api/v2/rum",
  SiteUS3: "https://browser-intake-us3-datadoghq.com/api/v2/rum",
  SiteUS5: "https://browser-intake-us5-datadoghq.com/api/v2/rum",
  SiteAP1: "https://browser-intake-ap1-datadoghq.com/api/v2/rum",
]

const logsIntakeUrls: array[DdSite, string] = [
  SiteUS1: "https://http-intake.logs.datadoghq.com/api/v2/logs",
  SiteEU1: "https://http-intake.logs.datadoghq.eu/api/v2/logs",
  SiteUS3: "https://http-intake.logs.us3.datadoghq.com/api/v2/logs",
  SiteUS5: "https://http-intake.logs.us5.datadoghq.com/api/v2/logs",
  SiteAP1: "https://http-intake.logs.ap1.datadoghq.com/api/v2/logs",
]

const apiBaseUrls: array[DdSite, string] = [
  SiteUS1: "https://api.datadoghq.com",
  SiteEU1: "https://api.datadoghq.eu",
  SiteUS3: "https://api.us3.datadoghq.com",
  SiteUS5: "https://api.us5.datadoghq.com",
  SiteAP1: "https://api.ap1.datadoghq.com",
]

proc parseSite*(s: string): DdSite =
  case s
  of "datadoghq.com":    SiteUS1
  of "datadoghq.eu":     SiteEU1
  of "us3.datadoghq.com": SiteUS3
  of "us5.datadoghq.com": SiteUS5
  of "ap1.datadoghq.com": SiteAP1
  else:
    raise newException(ValueError,
      "Unknown DD_SITE value: '" & s & "'. Valid values: datadoghq.com, datadoghq.eu, us3.datadoghq.com, us5.datadoghq.com, ap1.datadoghq.com")

proc initSite*(): DdSite =
  let env = getEnv("DD_SITE", "datadoghq.com")
  parseSite(env)

proc rumIntakeUrl*(site: DdSite): string = rumIntakeUrls[site]
proc logsIntakeUrl*(site: DdSite): string = logsIntakeUrls[site]
proc apiBaseUrl*(site: DdSite): string = apiBaseUrls[site]
