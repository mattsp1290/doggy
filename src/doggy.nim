# doggy — Datadog-native observability for Nim
# Import this module to get the full public API.
#
# Export aliasing convention:
#   RUM is the unprefixed public surface (types, session, vitals, exporter).
#   DogStatsD / Error Tracking / Events are imported under prefixed aliases
#   (statsd_*, et_*, ev_*) to avoid symbol collisions across subsystems.

import doggy/site
import doggy/uuid
import doggy/rum/types
import doggy/rum/session
import doggy/rum/vitals
import doggy/rum/exporter
import doggy/dogstatsd/types as statsd_types
import doggy/dogstatsd/client
import doggy/error_tracking/types as et_types
import doggy/error_tracking/exporter as et_exporter
import doggy/events/types as ev_types
import doggy/events/client as ev_client

export site
export uuid
export types
export session
export vitals
export exporter
export statsd_types
export client
export et_types
export et_exporter
export ev_types
export ev_client
