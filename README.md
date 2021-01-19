# SynchrosphereDemo

A demo application and playground to control Sphero robots via the [Synchrosphere](https://github.com/frameworklabs/Synchrosphere) framework.

## About

This Swift app shows how a Sphero robot can be controlled via the [Synchrosphere](https://github.com/frameworklabs/Synchrosphere) framework, which is based on the synchronous embedded DSL [Pappe](https://github.com/frameworklabs/Pappe).

It can be also used as a kind of a playground, to easily add new robot behaviours and learn about imperative synchronous language concepts.

## Usage

Compile and Run the app. A window will appear which lets you select from available demos in a drop-down box. Pressing the start button will run the selected demo. Because Bluetooth is used for communicating with the Sphero robot, a system dialog will pop-up every time you start the app to get your consent to use Bluetooth from this app.

In the middle part of the window, log output will be displayed.
The bottom part depicts the overall state of the robot by indicators which turn red on individual conditions. Tooltips will give an explanation of the different conditions.

Some demos will automatically stop - others will have to be stopped explicitly. The stop button can be used to end the demo in any case (emergency stop).

Some demos will require or allow keyboard input from the user to change its behavior - see the header docs of the demos or the explanation below.

## Demos

Three different demo categories exist:  
* IO
* Drive
* Sensor

### IO Demos

In these demos, the LEDs of the robot are controlled.

#### IO - Hello

An introductory demo. It will blink the main LED by alternating between red and black (out) every second. To stop the demo, press the stop button - or quit the app.

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
Each controller needs an activity called "Main" as its entry-point. In this demo this activity will repeat forever the following steps:  
* set the main led red
* wait for 1 second
* set the main led black
* wait for 1 second

To make the demo known to the App, you have to register it by:  
* add a new case in the Demo enum using an explicit raw value string for the display in the UI drop-down.
* return a factory for the new enum case.

#### IO - Hello by Class

This is the same demo as "IO - Hello" but uses a class instead of a function for its definition. The advantage of this is that you can provide an explanatory text to be displayed in the log area of the UI. Also - but not shown in this demo - the class might be used to parameterize the demo or store state during the run of the demo.

#### IO - Preempt with Key

This is a variation of the "IO - Hello" demos and uses the preemption statement `while ... abort: ...` to quit the demo when the user presses the key "q".

```Swift
activity (name.Main, []) { val in
    when { keyInput.input == "q" } abort: {
        `repeat` {
            run (Syncs.SetMainLED, [SyncsColor.red])
            run (Syncs.WaitSeconds, [1])
            run (Syncs.SetMainLED, [SyncsColor.black])
            run (Syncs.WaitSeconds, [1])
        }
    }
```

The preemption statement aborts its body - repeat in this case - when the condition becomes true - comparing the key input to "q" in this case.

#### IO - My Demo

This is a playground demo for your IO experiments.

If you like, use this already registered demo to play around with the LEDs on your Sphero by yourself. 

### Drive Demos

Will contain a list of demos which drives the robot around.

### Sensor Demos

Will contain a list of demos which uses the sensor of the robot to improve driving.
