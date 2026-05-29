# Package
version       = "0.1.0"
author        = "Matt Spurlin"
description   = "Datadog-native observability for Nim: RUM, DogStatsD, Error Tracking, and Events"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "examples", "docs"]

# Dependencies
requires "nim >= 2.0.0"

task test, "Run unit tests":
  exec "testament pattern 'tests/**/test_*.nim'"
