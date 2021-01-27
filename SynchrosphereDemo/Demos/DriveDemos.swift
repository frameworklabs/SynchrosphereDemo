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
        
        activity (name.ObtainInput, [], [name.speed, name.heading, name.dir]) { val in
            every { input.didPressKey } do: {
                exec {
                    let currentSpeed: SyncsSpeed = val.speed
                    var currentDir: SyncsDir = val.dir
                    let currentHeading: SyncsHeading = val.heading
                    
                    var speed: Int = Int(currentSpeed)
                    if currentDir == .backward {
                        speed = -speed
                    }
                    var heading: Int = Int(currentHeading)
                    
                    switch Int(input.key.utf16.first!) {
                    case NSUpArrowFunctionKey:
                        speed += 10
                    case NSDownArrowFunctionKey:
                        speed -= 10
                    case NSLeftArrowFunctionKey:
                        heading -= 10
                    case NSRightArrowFunctionKey:
                        heading += 10
                    default:
                        break
                    }

                    if speed > 250 {
                        speed = 250
                        currentDir = .forward
                    } else if speed < -250 {
                        speed = 250
                        currentDir = .backward
                    } else if speed < 0 {
                        speed = -speed
                        currentDir = .backward
                    } else {
                        currentDir = .forward
                    }
                    val.speed = SyncsSpeed(speed)
                    val.dir = currentDir
                    
                    if heading < 0 {
                        heading += 360
                    }
                    if heading >= 360 {
                        heading -= 360
                    }
                    val.heading = SyncsHeading(heading)
                }
            }
        }
        
        activity (name.Main, []) { val in
            when { input.key == "q" } abort: {
                run (Syncs.SetBackLED, [SyncsBrightness(255)])
                exec {
                    val.speed = SyncsSpeed(0)
                    val.heading = SyncsHeading(0)
                    val.dir = SyncsDir.forward
                }
                cobegin {
                    strong {
                        run (name.ObtainInput, [], [val.loc.speed, val.loc.heading, val.loc.dir])
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
