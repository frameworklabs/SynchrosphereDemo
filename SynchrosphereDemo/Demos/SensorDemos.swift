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
            }
        }
    }
}

/// Specialization of `DriveController` which sets up the sensor streamer.
class DriveWithSensorController : DriveController {
    
    let sensors: SyncsSensors
    let logSamples: Bool
    
    init(sensors: SyncsSensors = [.yaw, .location, .velocity], logSamples: Bool = false) {
        self.sensors = sensors
        self.logSamples = logSamples
    }
    
    override func makeModule() -> Module {
        Module(imports: [makeDriveWithSensorModule()]) { name in
            
            activity (name.DriveController, [], [name.speed, name.heading]) { val in
                run (Syncs.SetLocatorFlags, [SyncsLocatorFlags.resetOrientation])
                run (Syncs.ResetHeading, [])
                
                exec { val.sample = SyncsSample.unset }
                cobegin {
                    weak {
                        run (Syncs.SensorStreamer, [self.ctx.config.tickFrequency, self.sensors], [val.loc.sample])
                    }
                    weak {
                        `if` { self.logSamples } then: {
                            nowAndEvery { self.ctx.clock.tick } do: {
                                self.ctx.logInfo("sample: \(val.sample as SyncsSample)")
                            }
                        }
                    }
                    strong {
                        run (name.DriveWithSensorController, [val.sample], [val.loc.speed, val.loc.heading])
                    }
                }
            }
        }
    }

    /// Hook to overwrite in subclass to return a `DriveWithSensorController` activity.
    func makeDriveWithSensorModule() -> Module {
        fatalError("Implement me in subclass!")
    }
}

/// Drives a square of one meter in each dimension.
class SensorSquareMeterController : DriveWithSensorController {
    
    let precision: Float = 0.05
    
    init() {
        super.init(sensors: [.location], logSamples: true)
    }
    
    override func makeDriveWithSensorModule() -> Module {
        Module { name in
            
            activity (name.DriveWithSensorController, [name.sample], [name.speed, name.heading]) { val in
                exec {
                    val.speed = Float(0.5)
                    val.heading = Float(0)
                }
                `while` { abs((val.sample as SyncsSample).y - 1) > self.precision } repeat: {
                    await { self.ctx.clock.tick }
                }
                exec { val.heading -= Float.pi / 2 }
                `while` { abs((val.sample as SyncsSample).x - 1) > self.precision } repeat: {
                    await { self.ctx.clock.tick }
                }
                exec { val.heading -= Float.pi / 2 }
                `while` { abs((val.sample as SyncsSample).y - 0) > self.precision } repeat: {
                    await { self.ctx.clock.tick }
                }
                exec { val.heading -= Float.pi / 2 }
                `while` { abs((val.sample as SyncsSample).x - 0) > self.precision } repeat: {
                    await { self.ctx.clock.tick }
                }
                exec { val.speed = Float(0) }
            }
        }
    }
}
