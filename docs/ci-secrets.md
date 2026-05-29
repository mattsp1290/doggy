# CI Secrets Reference

This document describes the GitHub repository secrets required for the CI integration-test job.

## Required Secrets

| Secret | Used by | How to get |
|--------|---------|-----------|
| `DD_API_KEY` | Error Tracking, Custom Events integration tests | Datadog → Organization Settings → API Keys |
| `DD_CLIENT_TOKEN` | RUM integration tests | Datadog → UX Monitoring → Application → RUM Application → Client Token |
| `DD_APPLICATION_ID` | RUM integration tests | Datadog → UX Monitoring → Application → RUM Application → Application ID |

## Setting Secrets in GitHub

1. Go to your repository on GitHub.
2. Navigate to **Settings → Secrets and variables → Actions**.
3. Click **New repository secret** for each secret above.
4. Paste the value from the Datadog console.

## CI Behavior

- **Unit tests** (`unit-tests` job): Run on every push and pull request. No secrets required. Safe for PRs from forks.
- **Integration tests** (`integration-tests` job): Run only on pushes to `main`. Requires all three secrets above. Skipped silently if `DD_API_KEY` is not set (fork PRs are unaffected).

## Recommended DD_SITE for CI

Use `us3.datadoghq.com` (US3) for CI integration tests — it's the site configured in the workflow. If your team uses a different site, update `DD_SITE` in `.github/workflows/ci.yml` accordingly.

## Local Testing

To run integration tests locally with real credentials:

```bash
export DD_API_KEY=your-api-key
export DD_CLIENT_TOKEN=your-client-token
export DD_APPLICATION_ID=your-app-id
export DD_SITE=us3.datadoghq.com

# Run integration tests (when written)
nim c --mm:orc --threads:on -d:ssl -r tests/integration/test_rum.nim
```

Or run the examples directly to verify connectivity:

```bash
nim c --mm:orc --threads:on -d:ssl -r examples/rum.nim
nim c --mm:orc --threads:on -d:ssl -r examples/error_tracking.nim
nim c --mm:orc --threads:on -d:ssl -r examples/events.nim
```
