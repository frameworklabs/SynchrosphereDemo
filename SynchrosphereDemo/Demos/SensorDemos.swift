// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere
import Pappe

extension SyncsSample {
    var v: Float {
        (vx * vx + vy * vy).squareRoot()
    }
}

/// Shows how to stream sensor samples and log them.
class SensorLogSamplesController : DriveController {
    
    override func makeModule() -> Module {
        Module { name in
            activity (name.DriveController, [], [name.speed, name.heading]) { val in
                run (Syncs.SetLocatorFlags, [SyncsLocatorFlags.resetOrientation])
                run (Syncs.ResetHeading, [])
                
                exec { val.sample = SyncsSample.unset }
                cobegin {
                    strong {
                        exec { val.speed = Float(0.5) }
                        run (Syncs.WaitSeconds, [3])
                        exec { val.speed = Float(0) }
                    }
                    weak {
                        run (Syncs.SensorStreamer, [self.ctx.config.tickFrequency, SyncsSensors(arrayLiteral: .yaw, .location, .velocity)], [val.loc.sample])
                    }
                    weak {
                        nowAndEvery { self.ctx.clock.tick } do: {
                            self.ctx.logInfo("sample: \(val.sample as SyncsSample)")
                        }
                    }
                }
                await { false }
            }
        }
    }
}
