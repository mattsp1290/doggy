import std/strutils, std/os
import doggy/site

block all_rum_urls:
  assert rumIntakeUrl(SiteUS1) == "https://browser-intake-datadoghq.com/api/v2/rum"
  assert rumIntakeUrl(SiteEU1) == "https://browser-intake-datadoghq.eu/api/v2/rum"
  assert rumIntakeUrl(SiteUS3) == "https://browser-intake-us3-datadoghq.com/api/v2/rum"
  assert rumIntakeUrl(SiteUS5) == "https://browser-intake-us5-datadoghq.com/api/v2/rum"
  assert rumIntakeUrl(SiteAP1) == "https://browser-intake-ap1-datadoghq.com/api/v2/rum"

block all_logs_urls:
  assert logsIntakeUrl(SiteUS1) == "https://http-intake.logs.datadoghq.com/api/v2/logs"
  assert logsIntakeUrl(SiteEU1) == "https://http-intake.logs.datadoghq.eu/api/v2/logs"
  assert logsIntakeUrl(SiteUS3) == "https://http-intake.logs.us3.datadoghq.com/api/v2/logs"
  assert logsIntakeUrl(SiteUS5) == "https://http-intake.logs.us5.datadoghq.com/api/v2/logs"
  assert logsIntakeUrl(SiteAP1) == "https://http-intake.logs.ap1.datadoghq.com/api/v2/logs"

block all_api_urls:
  assert apiBaseUrl(SiteUS1) == "https://api.datadoghq.com"
  assert apiBaseUrl(SiteEU1) == "https://api.datadoghq.eu"
  assert apiBaseUrl(SiteUS3) == "https://api.us3.datadoghq.com"
  assert apiBaseUrl(SiteUS5) == "https://api.us5.datadoghq.com"
  assert apiBaseUrl(SiteAP1) == "https://api.ap1.datadoghq.com"

block parse_valid:
  assert parseSite("datadoghq.com")    == SiteUS1
  assert parseSite("datadoghq.eu")     == SiteEU1
  assert parseSite("us3.datadoghq.com") == SiteUS3
  assert parseSite("us5.datadoghq.com") == SiteUS5
  assert parseSite("ap1.datadoghq.com") == SiteAP1

block parse_invalid:
  var fired = false
  try:
    discard parseSite("invalid.example.com")
  except ValueError as e:
    fired = true
    assert "Unknown DD_SITE" in e.msg
    assert "invalid.example.com" in e.msg
  assert fired, "expected ValueError for unknown site"

block parse_empty:
  var fired = false
  try:
    discard parseSite("")
  except ValueError:
    fired = true
  assert fired, "expected ValueError for empty site"

block default_site:
  putEnv("DD_SITE", "datadoghq.com")
  assert initSite() == SiteUS1
  delEnv("DD_SITE")

block default_site_eu:
  putEnv("DD_SITE", "datadoghq.eu")
  assert initSite() == SiteEU1
  delEnv("DD_SITE")

when isMainModule:
  echo "Site resolver tests passed"
