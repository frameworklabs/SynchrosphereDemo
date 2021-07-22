// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere
import Pappe
import AppKit // For ArrowFunctionKeys

/// Rolls straight ahead.
func driveRollAheadFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            run (Syncs.SetBackLED, [SyncsBrightness(255)])
            run (Syncs.Roll, [SyncsAdjSpeed(100, config), SyncsHeading(0), SyncsDir.forward])
            await { false }
        }
    }
}

/// Rolls straight ahead for 3 seconds, pauses for 2 seconds and rolls back for 3 seconds again.
func driveRollAheadAndBackFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            `repeat` {
                run (Syncs.SetBackLED, [SyncsBrightness(255)])
                run (Syncs.RollForSeconds, [SyncsAdjSpeed(100, config), SyncsHeading(0), SyncsDir.forward, 3])
                run (Syncs.WaitSeconds, [2])
                run (Syncs.RollForSeconds, [SyncsAdjSpeed(100, config), SyncsHeading(0), SyncsDir.backward, 3])
                run (Syncs.SetBackLED, [SyncsBrightness(0)])
                
                exec { ctx.logNote("Press q to quit, r to run again") }
                await { input.didPressKey(in: "rq") }
            } until: { input.key == "q" }
        }
    }
}

/// Drive robot manually by keyboard.
func driveManualModeFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    engine.makeController(for: config) { name, ctx in
        
        activity (name.QueryInput, [], [name.speed, name.heading, name.dir]) { val in
            every { input.didPressKey } do: {
                let speed: SyncsSpeed = val.speed
                var dir: SyncsDir = val.dir
                let heading: SyncsHeading = val.heading
                
                var intSpeed: Int = Int(speed)
                if dir == .backward {
                    intSpeed = -intSpeed
                }
                var intHeading: Int = Int(heading)
                
                switch Int(input.key.utf16.first!) {
                case NSUpArrowFunctionKey:
                    intSpeed += 10
                case NSDownArrowFunctionKey:
                    intSpeed -= 10
                case NSLeftArrowFunctionKey:
                    intHeading -= 10
                case NSRightArrowFunctionKey:
                    intHeading += 10
                default:
                    break
                }

                if intSpeed > 250 {
                    intSpeed = 250
                    dir = .forward
                } else if intSpeed < -250 {
                    intSpeed = 250
                    dir = .backward
                } else if intSpeed >= 0 {
                    dir = .forward
                } else { // intSpeed < 0
                    intSpeed = -intSpeed
                    dir = .backward
                    dir = .forward
                }
                val.speed = SyncsSpeed(intSpeed)
                val.dir = dir
                
                if intHeading < 0 {
                    intHeading += 360
                } else if intHeading >= 360 {
                    intHeading -= 360
                }
                val.heading = SyncsHeading(intHeading)
            }
        }
        
        activity (name.Main, []) { val in
            run (Syncs.SetBackLED, [SyncsBrightness(255)])
            exec {
                val.speed = SyncsSpeed(0)
                val.heading = SyncsHeading(0)
                val.dir = SyncsDir.forward
            }
            cobegin {
                strong {
                    run (name.QueryInput, [], [val.loc.speed, val.loc.heading, val.loc.dir])
                }
                strong {
                    `repeat` {
                        run (Syncs.Roll, [SyncsAdjSpeed(val.speed, config), val.heading, val.dir])
                        await { ctx.clock.tick }
                    }
                }
            }
        }
    }
}

/// Module containing the activity to manually control (generate) speed and heading  as normalized values.
let manualControllerModule = Module { name in
    
    activity (name.ManualController, [name.input], [name.speed, name.heading]) { val in
        every { (val.input as Input).didPressKey } do: {
            let input: Input = val.input
            var speed: Float = val.speed
            var heading: Float = val.heading
                        
            let steps: Float = 20
            let speedIncrement: Float = 1 / steps
            let headingIncrement: Float = .pi / steps
            
            switch Int(input.key.utf16.first!) {
            case NSUpArrowFunctionKey:
                speed += speedIncrement
            case NSDownArrowFunctionKey:
                speed -= speedIncrement
            case NSLeftArrowFunctionKey:
                heading += headingIncrement
            case NSRightArrowFunctionKey:
                heading -= headingIncrement
            default:
                if input.key == " " {
                    speed = 0
                } else if input.key == "\r" {
                    heading = 0
                }
                break
            }
            
            val.speed = max(-1.0, min(1.0, speed))
            val.heading = heading
        }
    }
}

/// Module containing activities to roll the robot with normalized speed and heading values.
let rollControllerModule = Module { name in
    
    activity (name.SpeedAndHeadingConverter, [name.normSpeed, name.normHeading], [name.speed, name.heading, name.dir]) { val in
        always {
            let normSpeed: Float = val.normSpeed
            var normHeading: Float = val.normHeading
            
            if normSpeed >= 0 {
                val.speed = SyncsSpeed(normSpeed * 255)
                val.dir = SyncsDir.forward
            } else {
                val.speed = SyncsSpeed(-normSpeed * 255)
                val.dir = SyncsDir.backward
            }
            
            var heading: SyncsHeading
            if normHeading > 0 {
                while normHeading > 2 * Float.pi {
                    normHeading -= 2 * .pi
                }
                let degrees: Float = normHeading / (2 * .pi) * 360
                heading = SyncsHeading(360 - degrees)
            } else { // heading <= 0
                while normHeading < -2 * Float.pi {
                    normHeading += 2 * .pi
                }
                let degrees: Float = -normHeading / (2 * .pi) * 360
                heading = SyncsHeading(degrees)
            }
            val.heading = heading == 360 ? 0 : heading
        }
    }
    
    activity (name.RollController, [name.speed, name.heading, name.dir, name.requests, name.config]) { val in
        `defer` { (val.requests as SyncsRequests).stopRoll(towards: val.heading) }
        
        when {  val.prevSpeed != val.speed as SyncsSpeed
                || val.prevHeading != val.heading as SyncsHeading
                || val.prevDir != val.dir as SyncsDir } reset: {
            exec {
                val.prevSpeed = val.speed as SyncsSpeed
                val.prevHeading = val.heading as SyncsHeading
                val.prevDir = val.dir as SyncsDir
            }
            `repeat` {
                run (Syncs.Roll, [SyncsAdjSpeed(val.speed, val.config), val.heading, val.dir])
                
                `if` { val.speed as SyncsSpeed == 0 } then: {
                    await { false }
                } else: {
                    run (Syncs.WaitSeconds, [1])
                }
            }
        }
    }
}

/// Drive robot manually by keyboard.
func driveNormalizedManualModeFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    
    var config = config
    config.imports = [manualControllerModule, rollControllerModule]
    
    return engine.makeController(for: config) { name, ctx in
                    
        activity (name.Main, []) { val in
            run (Syncs.SetBackLED, [SyncsBrightness(255)])
            exec {
                val.speed = Float(0)
                val.heading = Float(0)
            }
            cobegin {
                strong {
                    run (name.ManualController, [input], [val.loc.speed, val.loc.heading])
                }
                strong {
                    run (name.Actuator, [val.speed, val.heading])
                }
            }
        }
        
        activity (name.Actuator, [name.speed, name.heading]) { val in
            exec {
                val.syncsSpeed = SyncsSpeed(0)
                val.syncsHeading = SyncsHeading(0)
                val.syncsDir = SyncsDir.forward
            }
            cobegin {
                strong {
                    run (name.SpeedAndHeadingConverter, [val.speed, val.heading], [val.loc.syncsSpeed, val.loc.syncsHeading, val.loc.syncsDir])
                }
                strong {
                    run (name.RollController, [val.syncsSpeed, val.syncsHeading, val.syncsDir, ctx.requests, ctx.config])
                }
            }
        }
    }
}

/// Helper type to store the mode of the led.
enum LEDMode : Equatable {
    case steady
    case blinking
    
    static func make(from period: Int) -> LEDMode {
        period == 0 ? .steady : .blinking
    }
}

/// Module to blink while driving.
let blinkControllerModule = Module { name in

    activity (name.BlinkController, [name.speed, name.heading, name.requests]) { val in
        cobegin {
            strong {
                always {
                    let speed: Float = val.speed
                    if abs(speed - 0.0) < 0.001 {
                        val.col = SyncsColor(red: 0x20, green: 0x20, blue: 0x20)
                        val.period = 0
                    } else {
                        val.col = speed > 0 ? SyncsColor.green : SyncsColor.red
                        val.period = Int(1000 - 900 * abs(speed))
                    }
                }
            }
            strong {
                run (name.Blink, [val.col, val.period, val.requests])
            }
        }
    }
    
    activity (name.Blink, [name.col, name.period, name.requests]) { val in
        `defer` { (val.requests as SyncsRequests).setMainLED(to: .black) }
        
        when { LEDMode.make(from: val.period) != val.prevMode } reset: {
            exec { val.prevMode = LEDMode.make(from: val.period) }
            
            `if` { val.prevMode == LEDMode.steady } then: {
                run (Syncs.SetMainLED, [val.col])
                await { false }
            } else: {
                `repeat` {
                    run (Syncs.SetMainLED, [val.col])
                    run (Syncs.WaitMilliseconds, [val.period])
                    run (Syncs.SetMainLED, [SyncsColor.black])
                    run (Syncs.WaitMilliseconds, [val.period])
                }
            }
        }
    }
}

/// Module to drive the actuator.
let actuatorModule = Module { name in
    
    activity (name.Actuator, [name.speed, name.heading, name.shouldBlink, name.requests, name.config]) { val in
        exec {
            val.syncsSpeed = SyncsSpeed(0)
            val.syncsHeading = SyncsHeading(0)
            val.syncsDir = SyncsDir.forward
        }
        cobegin {
            strong {
                run (name.SpeedAndHeadingConverter, [val.speed, val.heading], [val.loc.syncsSpeed, val.loc.syncsHeading, val.loc.syncsDir])
            }
            strong {
                run (name.RollController, [val.syncsSpeed, val.syncsHeading, val.syncsDir, val.requests, val.config])
            }
            strong {
                `if` { val.shouldBlink } then: {
                    run (name.BlinkController, [val.speed, val.heading, val.requests])
                }
            }
        }
    }
}

/// Normalized manual mode driving and blinking.
func driveRollAndBlinkFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    
    var config = config
    config.imports = [manualControllerModule, rollControllerModule, blinkControllerModule, actuatorModule]
    
    return engine.makeController(for: config) { name, ctx in
                    
        activity (name.Main, []) { val in
            run (Syncs.SetBackLED, [SyncsBrightness(255)])
            exec {
                val.speed = Float(0)
                val.heading = Float(0)
            }
            cobegin {
                strong {
                    run (name.ManualController, [input], [val.loc.speed, val.loc.heading])
                }
                strong {
                    run (name.Actuator, [val.speed, val.heading, true, ctx.requests, ctx.config])
                }
            }
        }
    }
}

/// A baseclass for drive demos.
class DriveController : DemoController {
    
    var ctx: SyncsControllerContext!
    var input: Input!
        
    func makeSyncsController(engine: SyncsEngine, config: SyncsControllerConfig, input: Input) -> SyncsController {
        
        self.input = input
        
        var config = config
        config.imports = [manualControllerModule, rollControllerModule, blinkControllerModule, actuatorModule, makeModule()]
        config = prepare(config)
        
        return engine.makeController(for: config) { name, ctx in
                                    
            activity (name.Main, []) { val in
                exec { self.ctx = ctx }
                run (Syncs.SetBackLED, [SyncsBrightness(255)])
                
                exec {
                    val.speed = Float(0)
                    val.heading = Float(0)
                }
                cobegin {
                    strong {
                        run (name.Controller, [], [val.loc.speed, val.loc.heading])
                    }
                    strong {
                        run (name.Actuator, [val.speed, val.heading, true, ctx.requests, ctx.config])
                    }
                }
            }
                  
            activity (name.Controller, [], [name.speed, name.heading]) { val in
                exec {
                    ctx.logNote("Press 'a' to start auto mode, 'm' to start manual mode")
                }
                await { input.didPressKey(in: "am") }
                when { input.didPressKey(in: "am") && input.key != val.prevKey } reset: {
                    exec { val.prevKey = input.key }
                    
                    `if` { input.key == "a" } then: {
                        exec { ctx.logInfo("Auto mode") }
                        run (Syncs.ResetHeading, [])
                        exec { val.heading = Float(0) }
                        run (name.DriveController, [], [val.loc.speed, val.loc.heading])
                    } else: {
                        exec { ctx.logInfo("Manual mode") }
                        exec { val.speed = Float(0) }
                        run (name.ManualController, [input], [val.loc.speed, val.loc.heading])
                    }
                    await { false }
                }
            }
        }
    }
    
    /// Optional hook to further prepare the config in a subclass.
    func prepare(_ config: SyncsControllerConfig) -> SyncsControllerConfig {
        return config
    }
    
    /// Needs to be overwritten in subclass and implemented to return an activity called  `DriveController`,
    func makeModule() -> Module {
        fatalError("Implement me in subclass!")
    }
}

/// A demo which moves the robot automatically in a square.
class DriveSquareController : DriveController {
    private let speed: Float
    private let timeMillis: Int
    
    init(speed: Float, timeMillis: Int) {
        self.speed = speed
        self.timeMillis = timeMillis
    }
    
    override func makeModule() -> Module {
        Module { name in
            
            activity (name.DriveController, [], [name.speed, name.heading]) { val in
                exec {
                    val.speed = self.speed
                    val.heading = Float(0)
                }
                `repeat` {
                    run (Syncs.WaitMilliseconds, [self.timeMillis])
                    exec { val.heading += Float.pi / 2 }
                }
            }
        }
    }
}

/// A demo which moves the robot automatically in a circle.
class DriveCircleController : DriveController {
    private let speed: Float
    private let deltaRad: Float
    
    init(speed: Float, deltaRad: Float = Float.pi / 30) {
        self.speed = speed
        self.deltaRad = deltaRad
    }

    override func makeModule() -> Module {
        Module { name in
            
            activity (name.DriveController, [], [name.speed, name.heading]) { val in
                exec {
                    val.deltaRad = self.deltaRad
                    val.speed = self.speed
                    val.heading = Float(0)
                }
                every { self.ctx.clock.tick } do: {
                    val.heading += val.deltaRad as Float
                }
            }
        }
    }
}

/// This is a playground demo for your own drive experiments.
class DriveMyDemoController : DriveController {
    override func makeModule() -> Module {
        Module { name in
            
            activity (name.DriveController, [], [name.speed, name.heading]) { val in
                // Replace these lines with your control code!
                exec { self.ctx.logInfo("My Demo") }
                await { false }
            }
        }
    }
}
