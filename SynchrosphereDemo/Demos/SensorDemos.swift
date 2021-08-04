// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere
import Pappe
import RealModule

/// Calculates the scalar velocity from the vx, vy vector.
extension SyncsSample {
    var v: Float {
        Float.hypot(vx, vy)
    }
}

/// Shows how to stream sensor samples and log them.
class SensorLogSamplesController : DriveController {
    
    override func makeModule() -> Module {
        Module { name in
            
            activity (name.DriveController, [], [name.speed, name.heading]) { val in
                run (Syncs.SetLocatorFlags, [SyncsLocatorFlags.resetOrientation])
                run (Syncs.ResetLocator, [])
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
                        always {
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
                run (Syncs.ResetLocator, [])
                run (Syncs.ResetHeading, [])
                
                exec { val.sample = SyncsSample.unset }
                cobegin {
                    weak {
                        run (Syncs.SensorStreamer, [self.ctx.config.tickFrequency, self.sensors], [val.loc.sample])
                    }
                    weak {
                        `if` { self.logSamples } then: {
                            always {
                                self.ctx.logInfo("sample: \(val.sample as SyncsSample)")
                            }
                        }
                    }
                    strong {
                        `while` { (val.sample as SyncsSample).sensors.isEmpty } repeat: {
                            pause
                        }
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
                    pause
                }
                exec { val.heading -= Float.pi / 2 }
                `while` { abs((val.sample as SyncsSample).x - 1) > self.precision } repeat: {
                    pause
                }
                exec { val.heading -= Float.pi / 2 }
                `while` { abs((val.sample as SyncsSample).y - 0) > self.precision } repeat: {
                    pause
                }
                exec { val.heading -= Float.pi / 2 }
                `while` { abs((val.sample as SyncsSample).x - 0) > self.precision } repeat: {
                    pause
                }
                exec { val.speed = Float(0) }
            }
        }
    }
}

/// Information about a waypoint.
struct Waypoint {
    let x: Float
    let y: Float
    let t: Float
    var i: Int = -1
}

/// A list of `Waypoints`.
struct WaypointList {
    private var points: [Waypoint] = [Waypoint(x: 0, y: 0, t: 0, i: 0)]
    private var t: Float = 0
    
    mutating func append(_ wp: Waypoint) {
        var wp = wp
        wp.i = points.count
        points.append(wp)
    }
    
    mutating func appendWaypointAt(x: Float, y: Float, withSpeed v: Float) {
        precondition(v > 0, "v needs to be > 0")
        let last = points.last!
        let dx = x - last.x
        let dy = y - last.y
        let dist = Float.hypot(dx, dy)
        let dt = dist / v
        t += dt
        append(Waypoint(x: x, y: y, t: t))
    }

    func pos(at t: Float) -> (x: Float, y: Float) {
        let (wps, wpe) = segment(at: t)
        
        let xs = wps.x
        let ys = wps.y
        
        if wps.i == wpe.i {
            return (xs, ys)
        }

        let ts = wps.t
        let te = wpe.t

        let dt = te - ts
        assert(abs(dt) > Float.ulpOfOne)
        let f = (t - ts) / dt
        
        let x = xs + f * (wpe.x - xs)
        let y = ys + f * (wpe.y - ys)
                
        return (x, y)
    }
    
    func isAtEnd(at t: Float) -> Bool {
        let (a, b) = segment(at: t)
        return a.i == b.i && a.i > 0
    }
    
    func segment(at t: Float) -> (Waypoint, Waypoint) {
        precondition(!points.isEmpty)
        if t == 0 {
            return (points[0], points[0])
        }
        for i in 1..<points.count {
            if t <= points[i].t {
                return (points[i - 1], points[i])
            }
        }
        return (points.last!, points.last!)
    }
}

/// A demo where the robot follows a triangular path.
class SensorFollowPathController : DriveWithSensorController {
    let lookaheadFactor: Float
    let logDetails: Bool
    
    init(lookaheadFactor: Float = 4, logDetails: Bool = false) {
        self.lookaheadFactor = lookaheadFactor
        self.logDetails = logDetails
        super.init(sensors: [.location], logSamples: false)
    }
    
    override func makeDriveWithSensorModule() -> Module {
        Module { name in
            
            activity (name.DriveWithSensorController, [name.sample], [name.speed, name.heading]) { val in
                exec {
                    var wpl = WaypointList()
                    // figure 8
                    wpl.appendWaypointAt(x: -0.7, y: 0.5, withSpeed: 0.5)
                    wpl.appendWaypointAt(x: 0.7, y: 1, withSpeed: 0.5)
                    wpl.appendWaypointAt(x: 0, y: 1.5, withSpeed: 0.5)
                    wpl.appendWaypointAt(x: -0.7, y: 1, withSpeed: 0.5)
                    wpl.appendWaypointAt(x: 0.7, y: 0.5, withSpeed: 0.5)
                    wpl.appendWaypointAt(x: 0, y: 0, withSpeed: 0.5)

                    val.wpl = wpl
                    val.t = Float(0)
                    val.done = false
                }
                when { val.done } abort: {
                    always {
                        let sample: SyncsSample = val.sample
                        let wpl: WaypointList = val.wpl
                        let t: Float = val.t
                        let dt = 1.0 / Float(self.ctx.config.tickFrequency)

                        if wpl.isAtEnd(at: t) {
                            if self.logDetails {
                                self.ctx.logInfo("-----------------------")
                                self.ctx.logInfo("stopped at x: \(sample.x) y: \(sample.y)")
                            }
                            val.speed = Float(0)
                            val.done = true
                            return
                        }
                                            
                        let lookaheadPos = wpl.pos(at: t + dt * self.lookaheadFactor)
                        let dx = lookaheadPos.x - sample.x
                        let dy = lookaheadPos.y - sample.y
                        
                        let heading = Float.atan2(y: -dx, x: dy)
                        let distance = Float.hypot(dx, dy) / self.lookaheadFactor
                        let velocity = distance / dt
                        let speed = min(velocity * 1.0, 1.0)
                        
                        if self.logDetails {
                            self.ctx.logInfo("-----------------------")
                            self.ctx.logInfo("x: \(sample.x) y: \(sample.y)")
                            self.ctx.logInfo("lx: \(lookaheadPos.x) ly: \(lookaheadPos.y)")
                            self.ctx.logInfo("dx: \(dx) dy: \(dy)")
                            self.ctx.logInfo("hd: \(val.heading as Float) spd: \(val.speed as Float)")
                            self.ctx.logInfo("hd': \(heading) spd': \(speed)")
                        }
                            
                        val.t = t + dt
                        val.heading = heading
                        val.speed = speed
                    }
                }
                exec { self.ctx.logInfo("Done") }
            }
        }
    }
}

/// This is a playground demo for your own sensor drive experiments.
class SensorMyDemoController : DriveWithSensorController {
    override func makeDriveWithSensorModule() -> Module {
        Module { name in
            
            activity (name.DriveWithSensorController, [name.sample], [name.speed, name.heading]) { val in
                // Replace these lines with your control code!
                exec { self.ctx.logInfo("My Demo") }
                halt
            }
        }
    }
}
