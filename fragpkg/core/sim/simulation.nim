import
  os,
  sequtils,
  times

type
  Simulation* = object
    maxFPS, maxInactiveFPS, minFPS, smoothingStep: uint
    frame: uint64
    lastFrameTimepoint: DateTime
    previousTimesteps: seq[Duration]
    timestep: Duration

proc simulation*(): Simulation =
  result = Simulation(
    maxFPS: 200,
    maxInactiveFPS: 20,
    minFPS: 0,
    lastFrameTimepoint: now(),
    smoothingStep: 11,
    previousTimesteps: @[],
    timestep: initDuration(),
    frame: 0
  )

proc runOneFrame*(s: var Simulation, isActive: bool) =
  if not isActive and s.maxFPS > 0u:
    s.maxFPS = min(s.maxInactiveFPS, s.maxFPS)

  var elapsed = now() - s.lastFrameTimepoint
  if s.maxFPS > 0u:
    let targetDuration = initDuration(milliseconds = 1000 div s.maxFPS.int)

    while true:
      elapsed = now() - s.lastFrameTimepoint
      
      if elapsed >= targetDuration:
        break
      
      if elapsed < DurationZero:
        break
      
      var sleepTime = targetDuration - elapsed
      let ms = milliseconds(sleepTime)
      if sleepTime > initDuration(microseconds = 1000):
        let stms = milliseconds(sleepTime)
        if stms > 0:
          sleepTime = initDuration(milliseconds = stms div ms)
          sleep(milliseconds(sleepTime))
  
  if elapsed < DurationZero:
    elapsed = DurationZero
  
  s.lastFrameTimepoint = now()

  if s.minFPS > 0u:
    let targetDuration = initDuration(milliseconds = 1000 div s.minFPS.int)
    if elapsed > targetDuration:
      elapsed = targetDuration
  
  if s.smoothingStep > 0u:
    s.previousTimesteps.add(elapsed)
    if s.previousTimesteps.len > s.smoothingStep.int:
      let begin = s.previousTimesteps.low()
      s.previousTimesteps.delete(begin, begin + s.previousTimesteps.len - s.smoothingStep.int)

      for step in s.previousTimesteps:
        s.timestep += step
      
      s.timestep = s.timestep div s.previousTimesteps.len
    else:
      s.timestep = s.previousTimesteps[s.previousTimesteps.high]
  else:
    s.timestep = elapsed
  
  inc s.frame

proc fps*(s: var Simulation): uint =
  let dt = milliseconds(s.timestep)
  result = if dt == 0: 0u else: (1000 div dt).uint