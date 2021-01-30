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

#### IO - Query Color

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
    `return` { val.col }
}
```
`await` is used to wait for the exact set of possible keys before they are translated into colors in the `exec` statement. The local variable `col` is used to store the color so that it can be returned in the `return` statement.

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

#### IO - Concurrent Trails

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

The `cobegin` statement marks the beginning of concurrent trails, which are defined by an arbitrary number of blocks introduced with the identifiers `strong` or `weak` (`weak` trails will be explained in a subsequent demo).

In our case, two trails will run concurrently with the first trail querying the color from the user and the second to blink at that color. Data exchange is done by the local variable `col` which is preset to red before `cobegin`.
When the QueryColor activity returns, it will assign to the `col` variable. This value will be picked up by Blink activity in the second trail during the same step. Within the Blink activity, the new color will not be used right away but only when its control flow reaches the point where the main led is set.

Note, that the order of the trails is important in Pappe. In each step, the first trail will be run before the second trail. This is different in Blech, where the compiler determines the order according to the the data dependencies between the trails. The compiler can also check if the data dependencies are causal and don't introduce cyclic dependencies. In Pappe, it's the programmers task to order the trails accordingly and ensure causal dependencies.

Even though within one step, the trails are processed from top to bottom, when viewed across multiple steps, each trail works concurrently to the others but in a  synchronized way.

#### IO - Streaming Activity

In the last demo, `QueryColor` had to be called repeatedly as it ended every time the user made a color choice. This is actually not necessary, as activities are able to continuously stream values to their callers while they are running:

```Swift
activity (name.QueryColor, [], [name.col]) { val in
    `repeat` {
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
    }
}
```
Besides the standard input parameter list, activities can have another list of in-out parameters which follow the input parameter list. Here, we have `col` in the second list and thus defined as a being a streaming (or in-out) parameter. Note that activities can both have streaming parameters as well as a final return value. 

The streaming version of  the `QueryColor` activity has to be called differently now:

```Swift
activity (name.Main, []) { val in
    exec { val.col = SyncsColor.red }
    cobegin {
        strong {
            run (name.QueryColor, [], [val.loc.col])
        }
        strong {
            run (name.Blink, [val.col, 1000, ctx.requests])
        }
    }
}
```
Arguments corresponding to in-out parameters have to be passed in a second argument list. Also, instead of passing the value of the `col` variable as `val.col` argument we pass the location of the variable with `val.loc.col`, so that the called activity can modify the location external to it. 

#### IO - Weak Preemption

A `cobegin` statement will stop when all its `strong` trails have stopped. When a trail is marked `weak` though, it doesn't participate in the decision when the `cobegin` terminates but rather is preempted when the `strong` trails all have finished. 

This is a second form of preemption - besides the `when ... abort ...` one we already saw. In contrast to the latter one which is named strong preemption, this new form of preemption in a `cobegin` construct is called weak preemption. Whereas strong preemption will happen at the beginning of a step, weak preemption happens at the end - i.e. in a `cobegin`, weak trails will be allowed to complete their step when being preempted.

As an example of this, let's extend the last demo with a timer which ends the blinking after 10 seconds:

```Swift
activity (name.Main, []) { val in
    exec { val.col = SyncsColor.red }
    cobegin {
        strong {
            run (Syncs.WaitSeconds, [10])
        }
        weak {
            run (name.QueryColor, [], [val.loc.col])
        }
        weak {
            run (name.Blink, [val.col, 1000, ctx.requests])
        }
    }
}
```
Because the indefinite running of `QueryColor` or `Blink` should not prevent the `cobegin` to finish, their trails are marked as `weak`. The `strong` trail with the `WaitSeconds` activity now determines the lifetime of the `coebegin` statement.

#### IO - Final Control

This last IO demo allows the user also to change the blinking period in addition to the color, prints the remaining time to the log window and allows to quit the blinking by user input:

```Swift
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
                        ctx.logInfo("\(remaining)s remainging time")
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
    exec { ctx.logInfo("Demo done - press Stop button to quit!") }
    await { false }
}
```

Also, the blinking itself was improved so that when the color is changed while the led is on, the color changes immediately. When the period changes, the blinking is reset with the new frequency. A short reset to black will indicate the period change when the led is currently on:

```Swift
activity (name.Blink, [name.col, name.period]) { val in
    `repeat` {
        exec { val.lastPeriod = val.period as Int }
        when { val.period != val.lastPeriod as Int } abort: {
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
                            await { val.col != val.lastCol as SyncsColor }
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
}
```
In contrast to Blech, where the `prev` operator is available to get access to the previous values of variables, we have to store and assign the last color and period explicitly in Pappe to detect changes.

Finally, let's look at these lines again:
```Swift
cobegin {
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
```
You could also think of this as the definition of a net of communicating components with the output ports of the `QueryColor` and `QueryPeriod` componets connected to corresponding input ports of the `Blink` component.:
```
QueryColor >  ____
                  \____ > Blink
QueryPeriod > ____/
```

In contrast to static component models, Pappe - or Blech - can be seen as dynamic component models controlled by a structured imperative program.

#### IO - My Demo

This is a playground demo for your IO experiments.

If you like, use this already registered demo to play around with the LEDs on your Sphero by yourself. 

### Drive Demos

In these demos we drive the robot around.

#### Drive - Roll Ahead

Let's start with rolling straight ahead at medium speed:

```Swift
activity (name.Main, []) { val in
    run (Syncs.SetBackLED, [SyncsBrightness(255)])
    run (Syncs.Roll, [SyncsSpeed(100), SyncsHeading(0), SyncsDir.forward])
    await { false }
}
```
First, we turn on the back LED to see the current orientation of the robot. The back led shows in the oppositite direction than the current heading. Then we issue a command to roll the robot forward with speed 100 and heading 0. The `await` statement at the end will prevent the demo from finishing automatically.

You will notice, that the robot will roll for 2 seconds before it stops. This is expected and a standard approach in robotics. To prevent that a robot continues moving when communication between control and actuator is broken, the robots actuator will stop when it doesn't get new commands from its control for a defined duration.

To roll the Sphero for a longer period than those 2 seconds, we thus have to re-issue the command every 2 seconds. As shown in the next demo, there is also a utility activity which does this for us.

#### IO - Roll Ahead and Back

Here, we use the utility activity `RollForSeconds` to roll ahead for 3 seconds, pause for 2 seconds and then roll backwards for 3 seconds again:

```Swift
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
```

Instead of using `SyncsDir.backward`, when rolling back we could change the heading to 180 degrees. In this case the robot will spin halve around before returning. 

At the end you see the Pappe statement `repeat ... until: ...` which can be used to stop the iteration once a condition becomes true. There is also the `while ... repeat ...` which enters and repeats the iteration only if the condition is true. 

#### Drive - Manual Mode

In this demo the robots speed, heading and direction are controlled manually by pressing up, down, left and right on the keyboard.

The main activity looks like this:

```Swift
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
```
The body of the activity consists of two concurrent trails - one for obtaining the input from the user and the other for issuing driving commands to the robot.

`nowAndEvery` is an (unofficial - as it is not a Blech construct) shorthand for a `repeat` loop with an `await` at the end - so in our case it's equivalent to:
```Swift
`repeat` {
    run (Syncs.Roll, [val.speed, val.heading, val.dir])
    await { ctx.clock.tick }
}
```
(There is also a variant called `every` which has the `await` at the beginning of the loop)

Independent of the style used,  with `ctx.clock.tick` we issue roll commands to the robot at the frequency of the clock - which is configurable via the `tickFrequency` property of `SyncsControllerConfig` which is 10 Hz by default. This is short enough so that we don't need to use the `RollForSeconds` command here.

`QueryInput` is structured equivalently to the way we continously queried the user for a color or period in the IO Demos. The only complication here is that the `Roll` activities input parameter domains are very restricted - the heading has to be given in unsigned integer degrees from 0 to 359. The next demo will simplify things in this regard.

#### Drive - Normalized Manual Mode

To simplify calculations, we want to work with normalized speed and heading values instead of the lower level encoding needed by the robot. A new activity called `Actuator` will take normalized inputs and translate them to the domains required by `Roll`. Also, in the previous demo, we issued a roll command every tick - even if the speed or heading did not change - so we optimize this too. Here is the main activity which connects the `Controller` component to the `Acttuator`  component:

```Swift
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
```
The `Controller` activity corresponds to the previous `QueryInput` activity but streams speed and heading as normalized values now.

`Actuator` does two things concurrently:

* Convert the normalized speed and heading floats to corresponding Syncs values at the rate of the clock. Note, that we moved the conversion logic to a separate function.
* Run the `RollController`

```Swift
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
```

Finally, the `RollController` takes care of calling `Syncs.Roll` when input values have changed or a second has elapsed to keep the robot rolling if no change is detected. If the speed is 0 we don't have to re-issue the roll command, so we wait a second conditionally on the speed with the help of the `if ... then: ... else: ...` statement:

```Swift
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
```

#### Drive - My Demo

This is a playground demo for your Drive experiments.

If you like, use this already registered demo to drive around your Sphero robot.

### Sensor Demos

Will contain a list of demos which uses the sensor of the robot to improve driving.
