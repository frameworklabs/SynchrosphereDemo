// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere
import Pappe

/// Basic demo.
func ioHelloFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            `repeat` {
                run (Syncs.SetMainLED, [SyncsColor.red])
                run (Syncs.WaitSeconds, [1])
                run (Syncs.SetMainLED, [SyncsColor.black])
                run (Syncs.WaitSeconds, [1])
            }
        }
    }
}

/// Using a `DemoController` subclass.
class IOHelloController : DemoController {
    let explanation: String? = "Blinks the LED red at 1 Hz"
    
    func makeSyncsController(engine: SyncsEngine, config: SyncsControllerConfig, input: Input) -> SyncsController {
        engine.makeController(for: config) { name, ctx in
            
            activity (name.Main, []) { val in
                `repeat` {
                    run (Syncs.SetMainLED, [SyncsColor.red])
                    run (Syncs.WaitSeconds, [1])
                    run (Syncs.SetMainLED, [SyncsColor.black])
                    run (Syncs.WaitSeconds, [1])
                }
            }
        }
    }
}

/// Using a sub activity.
func ioSubActivityFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    engine.makeController(for: config) { name, ctx in
        
        activity (name.Blink, [name.color, name.periodMillis]) { val in
            `repeat` {
                run (Syncs.SetMainLED, [val.color])
                run (Syncs.WaitMilliseconds, [val.periodMillis])
                run (Syncs.SetMainLED, [SyncsColor.black])
                run (Syncs.WaitMilliseconds, [val.periodMillis])
            }
        }
        
        activity (name.Main, []) { val in
            run (name.Blink, [SyncsColor.red, 1000])
        }
    }
}

/// A module hosting the blink activity to be shared by subsequent demos.
let blinkModule = Module { name in
    
    activity (name.Blink, [name.color, name.periodMillis]) { val in
        `repeat` {
            run (Syncs.SetMainLED, [val.color])
            run (Syncs.WaitMilliseconds, [val.periodMillis])
            run (Syncs.SetMainLED, [SyncsColor.black])
            run (Syncs.WaitMilliseconds, [val.periodMillis])
        }
    }
}

/// Using activities in an imported module.
func ioSubActivityInModuleFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    var config = config
    config.imports = [blinkModule]
    
    return engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            run (name.Blink, [SyncsColor.red, 1000])
        }
    }
}

/// Awaiting user input.
func ioAwaitInputFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    var config = config
    config.imports = [blinkModule]
    
    return engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            exec { ctx.logNote("Press 's' to start blinking") }
            `await` { input.key == "s" }
            run (name.Blink, [SyncsColor.red, 1000])
        }
    }
}

/// Preempt blinking on user input.
func ioPreemptOnInputFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    var config = config
    config.imports = [blinkModule]
    
    return engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            exec { ctx.logNote("Press 'q' to stop blinking") }
            when { input.key == "q" } abort: {
                run (name.Blink, [SyncsColor.red, 1000])
            }
            exec { ctx.logInfo("Blinking stopped") }
            halt
        }
    }
}

/// An improved blink module which uses `defer` to  set led to off on preemption.
let blinkWithDeferModule = Module { name in
    
    activity (name.Blink, [name.color, name.periodMillis, name.requests]) { val in
        `defer` {
            let requests: SyncsRequests = val.requests
            requests.setMainLED(to: .black)
        }
        `repeat` {
            run (Syncs.SetMainLED, [val.color])
            run (Syncs.WaitMilliseconds, [val.periodMillis])
            run (Syncs.SetMainLED, [SyncsColor.black])
            run (Syncs.WaitMilliseconds, [val.periodMillis])
        }
    }
}

/// Preempt blinking on user input but guarantees led is off.
func ioPreemptWithDeferFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    var config = config
    config.imports = [blinkWithDeferModule]
    
    return engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            exec { ctx.logNote("Press 'q' to stop blinking") }
            when { input.key == "q" } abort: {
                run (name.Blink, [SyncsColor.red, 1000, ctx.requests])
            }
            exec { ctx.logInfo("Blinking stopped") }
            halt
        }
    }
}

/// A module containing the QueryColor activity.
let queryColorOnceModule = Module { name in
    
    activity (name.QueryColor, [name.log, name.input]) { val in
        exec { (val.log as SyncsLogging).logNote("Select color by pressing 'r', 'g' or 'b'") }
        `await` { (val.input as Input).didPressKey(in: "rgb") }
        exec {
            let input: Input = val.input
            switch input.key {
            case "r": val.col = SyncsColor.red
            case "g": val.col = SyncsColor.green
            case "b": val.col = SyncsColor.blue
            default: break
            }
        }
        `return` { val.col }
    }
}

/// Queries the color from the user before starting to blink in that color.
func ioQueryColorFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    var config = config
    config.imports = [blinkWithDeferModule, queryColorOnceModule]
    
    return engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            run (name.QueryColor, [ctx, input]) { col in
                val.col = col!
            }
            run (name.Blink, [val.col, 1000, ctx.requests])
        }
    }
}

/// Change the color while blinking.
func ioConcurrentTrailsFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    var config = config
    config.imports = [blinkWithDeferModule, queryColorOnceModule]
    
    return engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            exec { val.col = SyncsColor.red }
            cobegin {
                strong {
                    `repeat` {
                        run (name.QueryColor, [ctx, input]) { col in
                            val.col = col!
                        }
                    }
                }
                strong {
                    run (name.Blink, [val.col, 1000, ctx.requests])
                }
            }
        }
    }
}

/// A module containing the QueryColor activity.
let queryColorModule = Module { name in
    
    activity (name.QueryColor, [name.log, name.input], [name.col]) { val in
        `repeat` {
            exec { (val.log as SyncsLogging).logNote("Select color by pressing 'r', 'g' or 'b'") }
            `await` { (val.input as Input).didPressKey(in: "rgb") }
            exec {
                let input: Input = val.input
                switch input.key {
                case "r": val.col = SyncsColor.red
                case "g": val.col = SyncsColor.green
                case "b": val.col = SyncsColor.blue
                default: break
                }
            }
        }
    }
}

/// Change the color while blinking with a streaming activity instead of a returning one.
func ioStreamingActivityFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    var config = config
    config.imports = [blinkWithDeferModule, queryColorModule]
    
    return engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            exec { val.col = SyncsColor.red }
            cobegin {
                strong {
                    run (name.QueryColor, [ctx, input], [val.loc.col])
                }
                strong {
                    run (name.Blink, [val.col, 1000, ctx.requests])
                }
            }
        }
    }
}

/// Preempts the blinking when a timer activity expires.
func ioWeakPreemptionFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    var config = config
    config.imports = [blinkWithDeferModule, queryColorModule]
    
    return engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            exec { val.col = SyncsColor.red }
            cobegin {
                strong {
                    run (Syncs.WaitSeconds, [10])
                }
                weak {
                    run (name.QueryColor, [ctx, input], [val.loc.col])
                }
                weak {
                    run (name.Blink, [val.col, 1000, ctx.requests])
                }
            }
        }
    }
}

/// The final IO control demo showing most of the discussed topics so far; allows to control the blinking color period.
class IOFinalController : DemoController {
    private let timeout: Int
    private let periodIncrement: Int
    
    init(timeout: Int, periodIncrement: Int = 100) {
        self.timeout = timeout
        self.periodIncrement = periodIncrement
    }
    
    let explanation: String? = "Blinks the LED in a color and period chosen by the user"

    func makeSyncsController(engine: SyncsEngine, config: SyncsControllerConfig, input: Input) -> SyncsController {
        engine.makeController(for: config) { name, ctx in
            
            activity (name.QueryColor, [], [name.col]) { val in
                `repeat` {
                    exec { ctx.logNote("Select color by pressing 'r', 'g' or 'b'") }
                    `await` { input.didPressKey(in: "rgb") }
                    exec {
                        switch input.key {
                        case "r": val.col = SyncsColor.red
                        case "g": val.col = SyncsColor.green
                        case "b": val.col = SyncsColor.blue
                        default: break
                        }
                    }
                }
            }
            
            activity (name.QueryPeriod, [], [name.period]) { val in
                `repeat` {
                    exec { ctx.logNote("Increase period by pressing '+', decrease it by '-'") }
                    `await` { input.didPressKey(in: "+-") }
                    exec {
                        let period: Int = val.period
                        switch input.key {
                        case "+": val.period = period + self.periodIncrement
                        case "-": val.period = max(self.periodIncrement, period - self.periodIncrement)
                        default: break
                        }
                    }
                }
            }
            
            activity (name.Blink, [name.col, name.period]) { val in
                when { val.period != val.prevPeriod as Int } reset: {
                    exec { val.prevPeriod = val.period as Int }
                    `defer` { ctx.requests.setMainLED(to: .black) }
                    `repeat` {
                        cobegin {
                            strong {
                                run (Syncs.WaitMilliseconds, [val.period])
                            }
                            weak {
                                `repeat` {
                                    exec { val.lastCol = val.col as SyncsColor }
                                    run (Syncs.SetMainLED, [val.col])
                                    `await` { val.col != val.lastCol as SyncsColor }
                                }
                            }
                        }
                        cobegin {
                            strong {
                                run (Syncs.WaitMilliseconds, [val.period])
                            }
                            weak {
                                run (Syncs.SetMainLED, [SyncsColor.black])
                            }
                        }
                    }
                }
            }

            activity (name.Main, []) { val in
                exec {
                    val.col = SyncsColor.red
                    val.period = 1000
                    val.remaining = self.timeout
                }
                when { input.key == "q" } abort: {
                    cobegin {
                        strong {
                            run (Syncs.WaitSeconds, [self.timeout])
                        }
                        weak {
                            `repeat` {
                                exec {
                                    let remaining: Int = val.remaining
                                    ctx.logInfo("\(remaining)s remaining time")
                                    val.remaining -= 1
                                }
                                run (Syncs.WaitSeconds, [1])
                            }
                        }
                        weak {
                            run (name.QueryColor, [], [val.loc.col])
                        }
                        weak {
                            run (name.QueryPeriod, [], [val.loc.period])
                        }
                        weak {
                            run (name.Blink, [val.col, val.period])
                        }
                    }
                }
                exec { ctx.logNote("Demo done - press Stop button to quit!") }
                halt
            }
        }
    }
}

/// Lets the three primary colors r, g, b rotate around the robot at different speeds.
func rvrColorCircleFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    let orderedLEDs: [SyncsRVRLEDs] = [
        .headlightRight, .powerButtonFront, .powerButtonRear, .breaklightRight,
        .breaklightLeft, .batteryDoorRear, .batteryDoorFront, .headlightLeft
    ]
    func posToLED(_ pos: Int) -> SyncsRVRLEDs {
        orderedLEDs[pos]
    }
    
    return engine.makeController(for: config) { name, ctx in
                
        activity (name.Main, []) { val in
            exec {
                val.pos1 = Int(0)
                val.pos2 = Int(0)
                val.pos3 = Int(0)
            }
            cobegin {
                strong {
                    run (name.Cycle, [5], [val.loc.pos1])
                }
                strong {
                    run (name.Cycle, [7], [val.loc.pos2])
                }
                strong {
                    run (name.Cycle, [11], [val.loc.pos3])
                }
                strong {
                    `repeat` {
                        exec {
                            var mapping = [SyncsRVRLEDs.all: SyncsColor.black]
                            mapping[posToLED(val.pos1)] = .red
                            mapping[posToLED(val.pos2)] = .green
                            mapping[posToLED(val.pos3)] = .blue
                            val.mapping = mapping
                        }
                        run (Syncs.SetRVRLEDs, [val.mapping])
                    }
                }
            }
        }
        
        activity (name.Cycle, [name.ticks], [name.pos]) { val in
            `repeat` {
                run (Syncs.WaitTicks, [val.ticks])
                exec {
                    let oldPos: Int = val.pos
                    let newPos = (oldPos + 1) % 8
                    val.pos = newPos
                }
            }
        }
    }
}

/// This is a playground demo for your IO experiments.
func ioMyDemoFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    engine.makeController(for: config) { name, ctx in
        
        activity (name.Main, []) { val in
            // Replace these lines with your control code!
            exec { ctx.logInfo("My Demo") }
            run (Syncs.SetBackLED, [SyncsBrightness(100)])
            halt
        }
    }
}
