# SynchrosphereDemo

A demo application and playground to control Sphero robots via the [Synchrosphere](https://github.com/frameworklabs/Synchrosphere) framework.

## About

This Swift app shows how a Sphero robot can be controlled via the [Synchrosphere](https://github.com/frameworklabs/Synchrosphere) framework, which is based on the synchronous embedded DSL [Pappe](https://github.com/frameworklabs/Pappe).

It can be also used as a kind of a playground, to easily add new robot behaviors and learn about imperative synchronous language concepts.

## Usage

Compile and Run the app. A window will appear which lets you select from available demos in a drop-down box. Pressing the start button will run the selected demo. Because Bluetooth is used for communicating with the Sphero robot, a system dialog will pop-up every time you start the app to get your consent to use Bluetooth from this app.

In the middle part of the window, log output will be displayed.
The bottom part depicts the overall state of the robot by indicators which turn red on individual conditions. Tooltips will give an explanation of the different conditions.

Some demos will automatically stop - others will have to be stopped explicitly. The stop button can be used to end the demo in any case (think emergency stop).

Some demos will require or allow keyboard input from the user to change their behavior - see the header docs of the demos or the explanation below.

## Demos

Three different demo categories exist:  
* IO
* Drive
* Sensor

### IO Demos

In these demos, the LEDs of the robot are controlled.

This chapter is also meant as a tutorial on the key concepts of the imperative synchronous language Pappe, so some demos essential have the same behavior but show a different programming style.

#### IO - Hello

An introductory demo. It will blink the main LED by alternating between red and black (off) every second. To stop the demo, press the stop button - or quit the app.

This shows the basics of a demo. You define a function adhering to the signature of  `FactoryFunction` and return a `SyncsController` from it. The logic of the demo is provides as a synchronous imperative Pappe program:

```Swift
func ioHelloFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ keyInput: KeyInput) -> SyncsController {
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
```
Each controller needs an activity called "Main" as its entry-point. In this demo the main activity will repeat forever the following steps:  
* set the main led red
* wait for 1 second
* set the main led black
* wait for 1 second

To make the demo known to the App, you have to register it by:  
* adding a new case to the Demo enum using an explicit raw value string for the display in the UI drop-down.
* returning a factory for the new enum case.

#### IO - Hello by Class

This is the same demo as "IO - Hello" but uses a class instead of a function for its definition. The advantage of this is that you can provide an explanatory text to be displayed in the log area of the UI. Also - but not shown in this demo - the class might be used to parameterize the demo or store state during the run of the demo.

#### IO - Sub Activity

In this demo, the code responsible for continous blinking is moved to a separate activity and called by the main activity. The new sub activity is parameterized by the color and the period.

```Swift
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
```

You can see how the Blink activity defines two parameters and how arguments are passed  to it in the main activity. 

#### IO - Sub Activity in Module

Because we will use the blink activity in the subsequent demos and we don't want to repeat ourselves every time, we move this activity into a module which can be used from other demos.

A module hosting activities is created like this:

```Swift
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
```

To use this module from the demo you have to import it by adding it to the `imports` property of the config:

```Swift
func ioSubActivityInModuleFunc(_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController {
    var config = config
    config.imports = [blinkModule]
    
    return engine.makeController(for: config) { name, ctx in
        activity (name.Main, []) { val in
            run (name.Blink, [SyncsColor.red, 1000])
        }
    }
}
```

#### IO - Await Input

Here we see how `await` is used to wait on the user to press the key "s" before  blinking is started. The control flow will stop in `await` until its condition become true in a future step - which is when `input.key` equals to the string "s".

In addition to `await` this demo also shows the `exec` statement. Within the body arbitrary Swift code can be called. In this case we use the `logInfo` method from the `SyncsControllerContext` to log a message to the log window.

```Swift
activity (name.Main, []) { val in
    exec { ctx.logInfo("Press 's' to start blinking") }
    await { input.key == "s" }
    run (name.Blink, [SyncsColor.red, 1000])
}
```

#### IO - Preempt on Input

Here, we want the blink activity to stop when we press a key. A running activity can be preempted by the `when ... abort: ...` statement. When the conditon becomes true, the body will immediately be stopped and the control flow continues with the next statement after the preemption statement.

```Swift
activity (name.Main, []) { val in
    exec { ctx.logInfo("Press 'q' to stop blinking") }
    when { input.key == "q" } abort: {
        run (name.Blink, [SyncsColor.red, 1000])
    }
    exec { ctx.logInfo("Blinking stopped") }
    await { false }
}
```
The `await { false }` statement at the bottom will stop the control flow from proceeding as the condition will never become true obviously. It is here to see that depending on when you hit "q", the led will either be on or off as you either preempt in the on or off phase of the blinking. The next demo will ensure that the led will be always off when blinking is preempted.

#### IO - Preempt with Defer

In order to turn the led off independent on when the blink activity is preempted, the `defer` statement is used in this demo.
For this, the blink activity is changed like this:

```Swift
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
```
The code in the `defer` block will be called whenever the blink activity is stopped like by preemption in this case. As the code in `defer` must not call `await` or `run`, a call to the request API is done here to set the main LED to black on leaving the blink activity. The request API issues only requests to the robot without waiting for their reply and should only be used in the `defer` environment.  
Note, that we pass the request object to the activity as imported modules don't have direct access to the context.

#### IO - Query color

Let's say we want to query a color from the user before we start blinking the led in that color. For this we create an activty which returns the color chosen from hitting either r, g, or b on the keyboard:

```Swift
activity (name.QueryColor, []) { val in
    exec { ctx.logInfo("Select color by pressing 'r', 'g' or 'b'") }
    await { input.didPressKey(in: "rgb") }
    exec {
        switch input.key {
        case "r": val.col = SyncsColor.red
        case "g": val.col = SyncsColor.green
        case "b": val.col = SyncsColor.blue
        default: break
        }
    }
    exit { val.col }
}
```
`await` is used to wait for the exact set of possible keys before they are translated into colors in the `exec` statement. The local variable `col` is used to store the color so that it can be returned in the `exit` statement.

When calling an activity that returns, the returned value is passed as the parameter of a closure like this:

```Swift
activity (name.Main, []) { val in
    run (name.QueryColor, []) { col in
        val.col = col!
    }
    run (name.Blink, [val.col, 1000, ctx.requests])
}
```
Again, we assign the returned value to a local variable so that it can be used for calling the blink activity. As the returned value of an activity is optional, we force unwrap it here  - you might use an `if let` or `guard let` instead of course.

#### IO - Concurrent trails

Now, instead of chosing the color only at the start, this demo shows how it can be changed while the led is blinking.

As running the blink activity is blocking the current thread (or current thread as we say), we need a construct which allows to open a concurrent trail where the color selection can happen. This construct is called `cobegin`:

```Swift
activity (name.Main, []) { val in
    exec { val.col = SyncsColor.red }
    cobegin {
        strong {
            `repeat` {
                run (name.QueryColor, []) { col in
                    val.col = col!
                }
            }
        }
        strong {
            run (name.Blink, [val.col, 1000, ctx.requests])
        }
    }
}
```

The `cobegin` statement marks the beginning of concurrent trails, which are defined by blocks introduced with the identifiers `strong` or `weak` (`weak` trails will be explained in a subsequent demo).

In our case, both trails will run concurrently with the first trail querying the color from the user and the second to blink at that color. Data exchange is done by the local variable `col` which is preset to red before `cobegin`.
When the QueryColor activity returns, it will assign to the `col` variable. This value will be picked up by Blink activity in the second trail during the same step. Within the Blink activity, the new color will not be used right away but only when its control flow reaches the point where the main led is set.

Note, that the order of the trails is important in Pappe. In each step, the first trail will be run before the second trail. This is different in Blech, where the compiler determines the order according to the the data dependencies between the trails. It can also check if the data dependencies are causal and don't introduce cyclic dependencies. In Pappe, its the programmers task to order the trails accordingly and ensure causal dependencies.

Even though within one step, the trails are processed from top to bottom, when viewed across multiple steps, each trail works concurrently to the others but in a  synchronized way.

#### IO - My Demo

This is a playground demo for your IO experiments.

If you like, use this already registered demo to play around with the LEDs on your Sphero by yourself. 

### Drive Demos

Will contain a list of demos which drives the robot around.

### Sensor Demos

Will contain a list of demos which uses the sensor of the robot to improve driving.
