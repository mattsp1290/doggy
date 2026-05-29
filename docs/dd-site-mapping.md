# DD_SITE URL Mapping

The `DD_SITE` environment variable selects the Datadog site. Default: `datadoghq.com`.

## Supported Sites

| DD_SITE value | RUM intake | Logs intake | API base |
|---------------|-----------|-------------|----------|
| `datadoghq.com` | `browser-intake-datadoghq.com` | `http-intake.logs.datadoghq.com` | `api.datadoghq.com` |
| `datadoghq.eu` | `browser-intake-datadoghq.eu` | `http-intake.logs.datadoghq.eu` | `api.datadoghq.eu` |
| `us3.datadoghq.com` | `browser-intake-us3-datadoghq.com` | `http-intake.logs.us3.datadoghq.com` | `api.us3.datadoghq.com` |
| `us5.datadoghq.com` | `browser-intake-us5-datadoghq.com` | `http-intake.logs.us5.datadoghq.com` | `api.us5.datadoghq.com` |
| `ap1.datadoghq.com` | `browser-intake-ap1-datadoghq.com` | `http-intake.logs.ap1.datadoghq.com` | `api.ap1.datadoghq.com` |

All RUM intake URLs use full HTTPS paths:
- `https://<rum-host>/api/v2/rum`

All logs intake URLs:
- `https://<logs-host>/api/v2/logs`

All API base URLs:
- `https://<api-host>` (Custom Events: append `/api/v2/events`)

## Signal Authentication Summary

| Signal | Auth method |
|--------|------------|
| RUM | `?dd-api-key=<clientToken>` query parameter |
| Error Tracking | `DD-API-KEY: <apiKey>` HTTP header |
| Custom Events | `DD-API-KEY: <apiKey>` HTTP header |
| DogStatsD | No auth (local Agent UDP) |

## Usage in Code

```nim
import doggy/site

let site = parseSite(getEnv("DD_SITE", "datadoghq.com"))
let rumUrl = site.rumIntakeUrl()          # https://browser-intake-datadoghq.com/api/v2/rum
let logsUrl = site.logsIntakeUrl()        # https://http-intake.logs.datadoghq.com/api/v2/logs
let apiBase = site.apiBaseUrl()           # https://api.datadoghq.com
```

Unknown `DD_SITE` values raise a `ValueError` at `parseSite()` time.
