# Package
version       = "0.1.0"
author        = "Matt Spurlin"
description   = "Datadog-native observability for Nim: RUM, DogStatsD, Error Tracking, and Events"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "examples", "docs"]

# No Nimble package dependencies — zero-dependency library.
# The only external requirement is OpenSSL (system library, not a Nimble package).
requires "nim >= 2.0.0"

# Run all unit tests
task test, "Run unit tests":
  let flags = "--mm:orc --threads:on -d:ssl --hints:off"
  let testFiles = @[
    "tests/test_json_emit.nim",
    "tests/test_site.nim",
    "tests/test_uuid.nim",
    "tests/test_statsd_types.nim",
    "tests/test_queue.nim",
    "tests/test_events_types.nim",
    "tests/test_http_client.nim",
    "tests/dogstatsd/test_encoder.nim",
    "tests/dogstatsd/test_client.nim",
    "tests/rum/test_session.nim",
    "tests/rum/test_vitals.nim",
    "tests/rum/test_serialize.nim",
    "tests/error_tracking/test_serialize.nim",
  ]
  for f in testFiles:
    exec "nim c " & flags & " -r " & f

# Run integration tests (require DD_API_KEY / DD_CLIENT_TOKEN; skipped otherwise)
task integration, "Run integration tests against Datadog":
  let flags = "--mm:orc --threads:on -d:ssl --hints:off"
  let testFiles = @[
    "tests/error_tracking/test_integration.nim",
    "tests/rum/test_integration.nim",
    "tests/events/test_integration.nim",
    "tests/dogstatsd/test_integration.nim",
  ]
  for f in testFiles:
    exec "nim c " & flags & " -r " & f

# Check all library modules compile
task check, "Check library modules":
  let flags = "--mm:orc --threads:on -d:ssl --hints:off"
  let modules = @[
    "src/doggy.nim",
    "src/doggy/queue.nim",
    "src/doggy/http_client.nim",
    "src/doggy/dogstatsd/client.nim",
    "src/doggy/rum/serialize.nim",
    "src/doggy/rum/exporter.nim",
    "src/doggy/error_tracking/exporter.nim",
    "src/doggy/events/client.nim",
  ]
  for m in modules:
    exec "nim check " & flags & " " & m
