// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere
import Pappe
import AppKit

/// Rolls straight ahead.
func driveRollAheadFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            run (Syncs.SetBackLED, [SyncsBrightness(255)])
            run (Syncs.Roll, [SyncsSpeed(100), SyncsHeading(0), SyncsDir.forward])
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
                run (Syncs.RollForSeconds, [SyncsSpeed(100), SyncsHeading(0), SyncsDir.forward, 3])
                run (Syncs.WaitSeconds, [2])
                run (Syncs.RollForSeconds, [SyncsSpeed(100), SyncsHeading(0), SyncsDir.backward, 3])
                run (Syncs.SetBackLED, [SyncsBrightness(0)])
                
                exec { ctx.logInfo("Press q to quit, r to run again") }
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
                exec {
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
                    nowAndEvery { ctx.clock.tick } do: {
                        run (Syncs.Roll, [val.speed, val.heading, val.dir])
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
            exec {
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
                    break
                }
                
                val.speed = max(-1.0, min(1.0, speed))
                val.heading = heading
            }
        }
    }
}

/// Module containing activities to roll the robot with normalized speed and heading values.
let rollControllerModule = Module { name in
    
    activity (name.SpeedAndHeadingConverter, [name.normSpeed, name.normHeading], [name.speed, name.heading, name.dir]) { val in
        nowAndEvery { true } do: {
            exec {
                let normSpeed: Float = val.normSpeed
                var normHeading: Float = val.normHeading
                
                if normSpeed >= 0 {
                    val.speed = SyncsSpeed(normSpeed * 255)
                    val.dir = SyncsDir.forward
                } else {
                    val.speed = SyncsSpeed(-normSpeed * 255)
                    val.dir = SyncsDir.backward
                }
                
                if normHeading > 0 {
                    while normHeading > 2 * Float.pi {
                        normHeading -= 2 * .pi
                    }
                    let degrees: Float = normHeading / (2 * .pi) * 360
                    val.heading = SyncsHeading(360 - degrees)
                } else { // heading <= 0
                    while normHeading < -2 * Float.pi {
                        normHeading += 2 * .pi
                    }
                    let degrees: Float = -normHeading / (2 * .pi) * 360
                    val.heading = SyncsHeading(degrees)
                }
            }
        }
    }
    
    activity (name.RollController, [name.speed, name.heading, name.dir, name.requests]) { val in
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
                run (Syncs.Roll, [val.speed, val.heading, val.dir])
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
                    run (name.RollController, [val.syncsSpeed, val.syncsHeading, val.syncsDir, ctx.requests])
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
                nowAndEvery { true } do: {
                    exec {
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

/// Normalized manual mode driving and blinking.
func driveRollAndBlinkFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    
    var config = config
    config.imports = [manualControllerModule, rollControllerModule, blinkControllerModule]
    
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
                    run (name.RollController, [val.syncsSpeed, val.syncsHeading, val.syncsDir, ctx.requests])
                }
                strong {
                    run (name.BlinkController, [val.speed, val.heading, ctx.requests])
                }
            }
        }
    }
}

/// This is a playground demo for your Drive experiments.
func driveMyDemoFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    engine.makeController(for: config) { name, ctx in
        activity (name.Main, []) { val in
            // Replace these lines with your control code!
            exec { ctx.logInfo("My Demo") }
            await { false }
        }
    }
}
