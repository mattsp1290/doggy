import doggy/rum/vitals, doggy/rum/types

block frame_time:
  let v = newFrameTimeVital(16.7)
  assert v.name == "frame_time"
  assert v.value == 16.7
  assert v.unit == "ms"

block fps:
  let v = newFpsVital(60.0)
  assert v.name == "fps"
  assert v.value == 60.0
  assert v.unit == "fps"

block memory:
  let v = newMemoryVital(1024 * 1024)
  assert v.name == "memory"
  assert v.value == float64(1024 * 1024)
  assert v.unit == "byte"

block custom:
  let v = newCustomVital("gpu_load", 0.75, "ratio")
  assert v.name == "gpu_load"
  assert v.value == 0.75
  assert v.unit == "ratio"

block base_fields_default:
  # base fields should be zero-valued until the exporter fills them in
  let v = newFrameTimeVital(8.33)
  assert v.base.sessionId == ""
  assert v.base.viewId == ""
  assert v.base.timestamp == 0

when isMainModule:
  echo "RUM vitals tests passed"
