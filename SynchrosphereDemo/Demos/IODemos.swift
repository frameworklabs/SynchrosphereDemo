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
            exec { ctx.logInfo("Press 's' to start blinking") }
            await { input.key == "s" }
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
            exec { ctx.logInfo("Press 'q' to stop blinking") }
            when { input.key == "q" } abort: {
                run (name.Blink, [SyncsColor.red, 1000])
            }
            exec { ctx.logInfo("Blinking stopped") }
            await { false }
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
            exec { ctx.logInfo("Press 'q' to stop blinking") }
            when { input.key == "q" } abort: {
                run (name.Blink, [SyncsColor.red, 1000, ctx.requests])
            }
            exec { ctx.logInfo("Blinking stopped") }
            await { false }
        }
    }
}

/// This is a playground demo for your IO experiments.
func ioMyDemoFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    engine.makeController(for: config) { name, ctx in
        activity (name.Main, []) { val in
            // Replace these lines with your control code!
            exec { ctx.logInfo("My Demo") }
            await { false }
        }
    }
}
