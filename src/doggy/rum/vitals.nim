import doggy/rum/types

proc newFrameTimeVital*(ms: float64): RumVitalEvent =
  RumVitalEvent(name: "frame_time", value: ms, unit: "ms")

proc newFpsVital*(fps: float64): RumVitalEvent =
  RumVitalEvent(name: "fps", value: fps, unit: "fps")

proc newMemoryVital*(bytes: int64): RumVitalEvent =
  RumVitalEvent(name: "memory", value: float64(bytes), unit: "byte")

proc newCustomVital*(name: string; value: float64; unit: string): RumVitalEvent =
  RumVitalEvent(name: name, value: value, unit: unit)
