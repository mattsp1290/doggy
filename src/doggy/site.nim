import std/os

type DdSite* = enum
  SiteUS1   = "datadoghq.com"
  SiteEU1   = "datadoghq.eu"
  SiteUS3   = "us3.datadoghq.com"
  SiteUS5   = "us5.datadoghq.com"
  SiteAP1   = "ap1.datadoghq.com"

# Hardcoded intake URL tables — no string interpolation.
const rumIntakeUrls: array[DdSite, string] = [
  "https://browser-intake-datadoghq.com/api/v2/rum",
  "https://browser-intake-datadoghq.eu/api/v2/rum",
  "https://browser-intake-us3-datadoghq.com/api/v2/rum",
  "https://browser-intake-us5-datadoghq.com/api/v2/rum",
  "https://browser-intake-ap1-datadoghq.com/api/v2/rum",
]

const logsIntakeUrls: array[DdSite, string] = [
  "https://http-intake.logs.datadoghq.com/api/v2/logs",
  "https://http-intake.logs.datadoghq.eu/api/v2/logs",
  "https://http-intake.logs.us3.datadoghq.com/api/v2/logs",
  "https://http-intake.logs.us5.datadoghq.com/api/v2/logs",
  "https://http-intake.logs.ap1.datadoghq.com/api/v2/logs",
]

const apiBaseUrls: array[DdSite, string] = [
  "https://api.datadoghq.com",
  "https://api.datadoghq.eu",
  "https://api.us3.datadoghq.com",
  "https://api.us5.datadoghq.com",
  "https://api.ap1.datadoghq.com",
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
