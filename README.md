# SynchrosphereDemo

A demo application and playground to control Sphero robots via the [Synchrosphere](https://github.com/frameworklabs/Synchrosphere) framework.

## About

This Swift app shows how a Sphero robot can be controlled via the [Synchrosphere](https://github.com/frameworklabs/Synchrosphere) framework, which is based on the imperative synchronous embedded DSL [Pappe](https://github.com/frameworklabs/Pappe).

It can be also used as a kind of a playground, to easily add new robot behaviors and learn about imperative synchronous language concepts.

## Usage

Compile and Run the app. A window will appear which lets you select a robot type and available demos in drop-down boxes. Pressing the start button will run the selected demo. Because Bluetooth is used for communicating with the Sphero robot, a system dialog will pop-up every time you start the app to get your consent to use Bluetooth from this app.

In the middle part of the window, log output will be displayed.
The bottom part depicts the overall state of the robot by indicators which turn red on individual conditions. Tooltips will give an explanation of the different conditions.

Some demos will automatically stop - others will have to be stopped explicitly. The stop button can be used to end the demo in any case (think emergency stop).

Some demos will require or allow keyboard input from the user to change their behavior - hints will be printed to the log accordingly.

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

This shows the basics of a demo. You define a function adhering to the signature of  `FactoryFunction` and return a `SyncsController` from it. The logic of the demo is provided as a synchronous imperative Pappe program:

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

To make the demo known to the App, you have to add a  `Demo` struct containing a display title and a factory function (and an optional set of supported robot types) to the list of all demos named `Demo.all` (living in "DemoRegistry.swift").

#### IO - Hello by Class

This is the same demo as "IO - Hello" but uses a class instead of a function for its definition. The advantage of this is that you can provide an explanatory text to be displayed in the log area of the UI. Also - but not shown in this demo - the class might be used to parameterize the demo or store state during the run of the demo.

```Swift
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
```

#### IO - Sub Activity

In this demo, the code responsible for continuous blinking is moved to a separate activity and called by the main activity. The new sub-activity is parameterized by color and period.

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

You can see how the Blink activity defines two parameters and how arguments are passed to it from the main activity. 

#### IO - Sub Activity in Module

Because we will use the blink activity in subsequent demos and we don't want to repeat ourselves every time, we move this activity into a module which can be used from other demos.

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

Here we see how `await` is used to wait on the user to press the key "s" before blinking is started. The control flow will stop in `await` until its condition become true in a future step - which is when `input.key` equals to the string "s".

In addition to `await` this demo also shows the `exec` statement. Within the body arbitrary (but non-blocking and non-async) Swift code can be called. In this case we use the `logInfo` method from the `SyncsControllerContext` to log a message to the log window.

```Swift
activity (name.Main, []) { val in
    exec { ctx.logInfo("Press 's' to start blinking") }
    await { input.key == "s" }
    run (name.Blink, [SyncsColor.red, 1000])
}
```

#### IO - Preempt on Input

Here, we want the blink activity to stop when we press a key. A running activity can be preempted by the `when ... abort: ...` statement. When the condition becomes true, the body will immediately be stopped and control flow continues with the next statement after the preemption statement.

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
The `await { false }` statement at the bottom will stop the control flow from proceeding as the condition will never become true obviously. It is present here to see that depending on when you hit "q", the led will either be on or off as you either preempt in the on or off phase of the blinking. The next demo will ensure that the led will always be off when blinking is preempted.

#### IO - Preempt with Defer

In order to turn the led off independent on when the blink activity is preempted, the `defer` statement is used in this demo.
For this, the blink activity is changed to:

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
The code in the `defer` block will be called whenever the blink activity is stopped like by preemption in this case. As the code in `defer` must not call `await` or `run`, a call to the request API is done here to set the main LED to black on leaving the blink activity. The request API issues only requests to the robot without waiting for a reply and should only be used in the `defer` environment.  
Note, that we pass the request object to the activity as argument, as imported modules don't have direct access to the context.

#### IO - Query Color

Let's say we want to query a color from the user before we start blinking the led in that color. For this we create an activity which returns the color chosen from hitting either r, g, or b on the keyboard:

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

Now, instead of choosing the color only at the start, this demo shows how it can be changed while the led is blinking.

As running the blink activity is blocking the current thread (or current trail as we say), we need a construct which allows to open a concurrent trail where the color selection can happen. This construct is called `cobegin`:

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

In our case, two trails will run concurrently with the first trail querying the color from the user and the second to blink at that color. Data exchange is done by the local variable `col` which is pre-set to red before `cobegin`.
When the QueryColor activity returns, it will assign to the `col` variable. This value will be picked up by the Blink activity in the second trail during the same step. Within the Blink activity, the new color will not be used right away but only when its control flow reaches the point where the main led is set.

Note, that the order of the trails is important in Pappe. In each step, the first trail will be run before the second trail. This is different in Blech, where the compiler determines the order according to the the data dependencies between the trails. Its compiler can also check if the data dependencies are causal and don't introduce cyclic dependencies. In Pappe, it's the programmers task to order the trails accordingly and ensure causal dependencies.

Even though - within one step - the trails are processed from top to bottom, when viewed across multiple steps, each trail works concurrently to the others but in a synchronized way.

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
Besides the standard input parameter list, activities can have another list of in-out parameters which follow the input parameter list. Here, we have `col` in the second list and thus defined as a being a streaming (or in-out) parameter. Note, that activities can both have streaming parameters as well as a final return value. 

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
Arguments corresponding to in-out parameters have to be passed in a second argument list. Also, instead of passing the value of the `col` variable as `val.col` argument, we pass the location of the variable with `val.loc.col`, so that the called activity can modify the location external to it. 

#### IO - Weak Preemption

A `cobegin` statement will stop when all its `strong` trails have stopped. When a trail is marked `weak` though, it doesn't participate in the decision when the `cobegin` terminates but rather is preempted when the `strong` trails all have finished. 

This is a second form of preemption - besides the `when ... abort ...` one we already encountered. In contrast to the latter which is named strong preemption, this new form of preemption in a `cobegin` construct is called weak preemption. Whereas strong preemption will happen at the beginning of a step, weak preemption happens at the end - i.e. in a `cobegin`, weak trails will be allowed to complete their step when being preempted.

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
Because the indefinite running of `QueryColor` and `Blink` should not prevent the `cobegin` to finish, their trails are marked as `weak`. The `strong` trail with the `WaitSeconds` activity now determines the lifetime of the `coebegin` statement.

#### IO - Final Control

This last IO demo allows the user to change the blinking period in addition to the color, prints the remaining time to the log window and enables to quit the blinking by user input:

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
    exec { ctx.logInfo("Demo done - press Stop button to quit!") }
    await { false }
}
```

In addition, the blinking itself was improved, so that when the color is changed while the led is on, the color changes immediately. When the period changes, the blinking is reset with the new frequency. A short color change to black will indicate the period change when the led is currently on:

```Swift
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
```
Note the use of the `when ... reset: ...` statement. This is similar to the `when ... abort: ...` construct we already saw but instead of aborting the body when the preemption condition becomes `true`, this variant will repeat it instead. One important point with both constructs is that the condition is *not* checked when it enters the statement for the first time but only after the first direct or indirect `await`. This is because we have a strong preemption behavior here which states that it is the first thing which is checked in a step. But as some other statements might occur before `when` is entered the first time, it can't guarantee this promise.

For the preemption condition we compare the current period to the previous one. In contrast to Blech, where the `prev` operator is available to get access to the previous values of variables, we have to store the previous period explicitly in Pappe to detect changes.

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
You could also think of this as the definition of a net of communicating components with the output ports of the `QueryColor` and `QueryPeriod` components connected to corresponding input ports of the `Blink` component:
```
QueryColor >  ____
                  \____ > Blink
QueryPeriod > ____/
```

In contrast to static component models, Pappe - or Blech - can be seen as dynamic component models controlled by a structured imperative program.

#### IO - RVR Color Circle

A  demo which is specific to the RVR. I.e. this demo is *not*  available for any other robot type as it requires the set of LEDs present only on the RVR.

Here, we send the three primary colors red, green and blue to "circle around the RVR" at different speeds. The RVR has 8 LEDs all around its edges and when
lighting them up in the right order, the illusion appears that the color travels around the robot.

When an LED slot is "occupied" by more than one color, the LED will shine in a color which is the combination (max of each color channel) of all the colors of this slot.
Using prime numbers to derive the speed of each color results in a rich overal color pattern.

```Swift
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
                `await` { ctx.clock.tick }
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
```

We use the helper activity `Cycle` three times to generate three position values from 0 to 7 at varying speeds. These different positions are then converted to 
an LED and mapped to a different primary color each. To reset the colors of the previous step, we map all LEDs to black first. For optimization (not shown here), we could instead remember the past positions and set the LEDs corresponding to them to black only.

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
First, we turn the back LED on to see the current orientation of the robot. The back led shows in the opposite direction than the current heading. Then, we issue a command to roll the robot forward with speed 100 and heading 0. The `await` statement at the end will prevent the demo from finishing automatically.

You will notice, that the robot will roll for 2 seconds before it stops. This is expected and a standard approach in robotics. To prevent that a robot continues to move when communication between control and actuator is broken, the robots actuator will stop when it doesn't get new commands from its control for a defined duration.

To roll the Sphero for a longer period than those 2 seconds, we thus have to re-issue the command every 2 seconds latest. As shown in the next demo, there is also a utility activity which does this for us.

#### Drive - Roll Ahead and Back

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

Instead of using `SyncsDir.backward`, when rolling back, we could change the heading to 180 degrees. In this case, the robot will spin halve around before returning. 

At the end you see the Pappe statement `repeat ... until: ...` which can be used to stop the iteration once a condition becomes true. There is also `while ... repeat ...` which enters and repeats the iteration only if the condition is true. 

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
            `repeat` {
                run (Syncs.Roll, [val.speed, val.heading, val.dir])
                await { ctx.clock.tick }
            }
        }
    }
}
```
The body of the activity consists of two concurrent trails - one for obtaining the input from the user and the other for issuing driving commands to the robot.

With `ctx.clock.tick` we issue roll commands to the robot at the frequency of the clock - which is configurable via the `tickFrequency` property of `SyncsControllerConfig` which is 10 Hz by default. This is short enough so that we don't need to use the `RollForSeconds` command here.

`QueryInput` is structured equivalently to the way we continuously queried the user for a color or period in the IO Demos. The only complication here is that the `Roll` activities input parameter domains are very restricted - the heading has to be given in unsigned integer degrees from 0 to 359. The next demo will simplify things in this regard.

#### Drive - Normalized Manual Mode

To simplify calculations, we want to work with normalized speed and heading values instead of the lower-level encoding needed by the robot. A normalized speed is between -1.0 and +1.0 and a normalized heading uses radians. A new activity called `Actuator` will take these normalized inputs and translate them to the domains required by `Roll`. Also - in the previous demo - we issued the roll command every tick even if the speed or heading did not change, so let's improve that too. 

Here is the main activity which connects the `ManualController` component to the `Actuator`  component:

```Swift
activity (name.Main, []) { val in
    run (Syncs.SetBackLED, [SyncsBrightness(255)])
    exec {
        val.speed = Float(0)
        val.heading = Float(0)
    }
    cobegin {
        strong {
            run (name.ManualController, [], [val.loc.speed, val.loc.heading])
        }
        strong {
            run (name.Actuator, [val.speed, val.heading])
        }
    }
}
```
The `ManualController` activity corresponds to the previous `QueryInput` activity but streams speed and heading as normalized values now.

`Actuator` does two things concurrently:

* Convert the normalized speed and heading floats to corresponding Syncs values - done by  `SpeedAndHeadingConverter`. 
* Call `Syncs.Roll` but only when the values have changed - done by `RollController`.

```Swift
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
            run (name.RollController, [val.syncsSpeed, val.syncsHeading, val.syncsDir])
        }
    }
}
```

This brings us to this component view for the demo (with square brackets indicating the Actuator Sub-Component):

```
ManuallController > ---- > [ SpeedAndHeaddingConverter > ---- > RollController ]
```

The `RollController` takes care of calling `Syncs.Roll` when input values have changed or a second has elapsed to keep the robot rolling if no change is detected. If the speed is 0 we don't have to re-issue the roll command periodically and wait instead indefinitely until the input values change. The different code paths are expressed with the  `if ... then: ... else: ...` statement:

```Swift
activity (name.RollController, [name.speed, name.heading, name.dir]) { val in
    `defer` { ctx.requests.stopRoll(towards: val.heading) }
    
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

#### Drive - Roll and Blink

Let's extend the last demo by having the robot blink while it is driving. When it is driving forward, it should blink green, when driving backward red. The blinking frequency should increase on higher speeds and if the robot does not move, the led should stay white instead without blinking.

The only change needed is the extension of the `Actuator` activity by another concurrent trail to run a  `BlinkController`:

```Swift
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
```

So, the rolling is extended with the aspect of blinking here. The synchronous programming model allows this kind of Aspect-oriented programming (AOP) as the synchronization points pose as general join-points where a program can be extended with code to run before and after it at every step.

The modularity possible by the synchronous programming style prevents you from conflating different aspects like rolling and blinking into one place. Imagine how complex and convoluted this combined behavior would be in a traditional environment.

The  `BlinkController` itself separates the aspect of calculating the color and period from blinking the led itself (note that we could move the code in the first trail to a separate activity but the point of modularity here is is that the Blink code is not sprinkled with calculations of the color and period but cleanly separated from it):

```Swift
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
```
`always` is a statement to run arbitrary Swift code like `exec`, but repeated every step. This statement - as well as the related `every` and `nowAndEvery` statements are not present in Blech and thus regarded as 'unofficial'. You can always use a `repeat` loop with an `await` statement instead though if you prefer that. 

Blinking itself uses a little helper enum (`LEDMode`) to detect mode changes as we don't want to restart the `repeat` loop every time the period changes, but only, when the mode changes from steady to blinking:

```Swift
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
```

#### Drive - Auto Square

Here and in the next demo we want to roll automatically. To reduce repetitive code, we create a subclass of  `DemoController`  called `DriveController` which implements the main activity by connecting a drive controller to the drive actuator. Furthermore, the drive controller will allow to switch between automatic driving and manual driving so that you can navigate "home" at any time if needed. The manual mode can also be used to aim the robot. When the automatic mode is activated, the current heading will be set as heading 0. Also, switching back to manual mode will set the speed to 0 bringing the robot to a stop.	

In this demo, the robot will automatically roll repetitively in a square turning 90 degrees left every 2 seconds:
```Swift
class DriveSquareController : DriveController {
    override func makeModule() -> Module {
        Module { name in            
            activity (name.DriveController, [], [name.speed, name.heading]) { val in
                exec {
                    val.speed = Float(0.5)
                    val.heading = Float(0)
                }
                `repeat` {
                    run (Syncs.WaitMilliseconds, [2000])
                    exec { val.heading += Float.pi / 2 }
                }
            }
        }
    }
}
```
So, we have to override the `makeModule` method in the `DriveController` subclass and define an activity named (again) `DriveController`.

#### Drive - Auto Circle

To drive in a circle, the `DriveController` activity will look like this:

```Swift
activity (name.DriveController, [], [name.speed, name.heading]) { val in
    exec {
        val.deltaRad = Float.pi / 30
        val.speed = Float(0.5)
        val.heading = Float(0)
    }
    every { self.context.clock.tick } do: {
        val.heading += val.deltaRad as Float
    }
}
```

Every clock tick we change the heading angle slightly while we move at constant speed. With a `deltaRad` of `2 * pi / 60` and a clock frequency of 10 Hz a full circle will take 6 seconds. Depending on the speed, the circle will then be smaller or bigger. 

In order to drive a circle with a specific diameter, we have to look at the sensor data sent back by the robot - this is the topic of the next category of demos to come.  

#### Drive - My Demo

This is a playground demo for your own drive experiments.

If you like, use this already registered demo to drive around your Sphero robot.

### Sensor Demos

Contains a list of demos which uses the sensor of the robot to improve driving.

#### Sensor - Log Samples

This first sensor demo shows how to enable the streaming of sensor samples. The `Syncs.SensorStreamer` activity will stream sensor samples at the specified frequency when it is run. Which sensors readings should be enabled in the returned samples is specified as input argument to the `SensorStreamer` activity. Here, we drive straight for a few seconds and write the received sensor samples consisting of yaw, location and velocity to the log:

```Swift
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
```
Note, how we have to pass the set of sensors to be enabled as using an array literal directly would confuse the parameter passing here.

To orient the coordinate system in the direction of the heading, we set the locator flags to reset the orientation first and reset the heading after that. The positive y axis then points down in the direction of the heading. The perpendicular x axis grows to the right.

In this demo, the y-velocity (in meter per second) and y-location (in meter) will be the changing values whereas the yaw (in degrees) and the x-values will mostly be zero.  

#### Sensor - Square Meter

In this demo the location sensor is used to drive the robot in a square of 1 by 1 meter. When the sensor reading in the drive direction approaches the desired distance, the heading is changed by -pi / 2 repeating the process until the robot comes back to the origin:

```Swift
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
```
For this and other demos which use the sensor, a subclass of `DriveController` called `DriveWithSensorController` was created which runs the `Syncs.SensorStreamer` activity concurrently with the `DriveWithSensorController` activity defined by the specific the subclass (`SensorSquareMeterController` in the case of this demo).

#### Sensor - Follow Path

In this last demo, the robot will follow a path given by a list of waypoints. On every tick of the clock, the robots' speed and heading is adjusted to reach a point on the trajectory which is a few time-steps ahead. The algorithm is a variant of the Pure Pursuit Controller algorithm but uses as lookahead a position defined by time and not by location of the robot. The details of algorithm can be seen in the code, but the general outline is like this:

```Swift
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
        nowAndEvery { self.ctx.clock.tick } do: {
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
```	
First, the `WaypointList` is built up and stored in a variable - it could also be stored as instance variable of the Demo class as it does not change from run to run.

Then, on every clock tick, we determine the `lookaheadPos` from the current time which acts as the carrot to chase for the robot. From this position we subtract the current position given by the latest sensor sample and get a resulting delta vector (dx and dy). From this delta vector we calculate the new heading (using arctan) and speed (by assuming a 1:1 relationship between normalized speed and m/s). 

When the end of the waypoint list is detected, the robots' speed is set explicitly to 0 to prevent it to move if the sensor readings oscillate. 

#### Sensor - My Demo

This is a playground demo for your own sensor drive experiments.

If you like, use this already registered demo to drive around your Sphero robot with sensor streaming enabled.

## Summary

Synchrosphere allows you to program your Sphero robot in a Swift DSL which simplifies robotic programming tasks by supporting modular concurrency and preemption constructs enabled by the synchronous programming paradigm.  
