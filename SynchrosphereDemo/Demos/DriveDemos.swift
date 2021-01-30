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

/// Drive robot manually by keyboard.
func driveNormalizedManualModeFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    
    func convertSpeedAndHeading(_ val: Ctx) {
        let speed: Float = val.speed
        var heading: Float = val.heading
        
        if speed >= 0 {
            val.syncsSpeed = SyncsSpeed(speed * 255)
            val.syncsDir = SyncsDir.forward
        } else {
            val.syncsSpeed = SyncsSpeed(-speed * 255)
            val.syncsDir = SyncsDir.backward
        }
        
        if heading > 0 {
            while heading > 2 * Float.pi {
                heading -= 2 * .pi
            }
            let degrees: Float = heading / (2 * .pi) * 360
            val.syncsHeading = SyncsHeading(360 - degrees)
        } else { // heading <= 0
            while heading < -2 * Float.pi {
                heading += 2 * .pi
            }
            let degrees: Float = -heading / (2 * .pi) * 360
            val.syncsHeading = SyncsHeading(degrees)
        }
    }
    
    return engine.makeController(for: config) { name, ctx in
        
        activity (name.Controller, [], [name.speed, name.heading]) { val in
            every { input.didPressKey } do: {
                exec {
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
        
        activity (name.RollController, [name.speed, name.heading, name.dir]) { val in
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
        
        activity (name.Actuator, [name.speed, name.heading]) { val in
            cobegin {
                strong {
                    nowAndEvery { ctx.clock.tick } do: {
                        exec {
                            convertSpeedAndHeading(val)
                        }
                    }
                }
                strong {
                    run (name.RollController, [val.syncsSpeed, val.syncsHeading, val.syncsDir])
                }
            }
        }
        
        activity (name.Main, []) { val in
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
                    run (name.Actuator, [val.speed, val.heading])
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
