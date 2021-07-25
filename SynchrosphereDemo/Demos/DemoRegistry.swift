// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere

extension Demo {
    
    /// The registry of all available demos.
    ///
    /// If you have a new demo you need to add it here.
    static let all = [
        Demo(title: "IO - Hello", function: ioHelloFunc),
        Demo(title: "IO - Hello by Class", controller: IOHelloController()),
        Demo(title: "IO - Sub Activity", function: ioSubActivityFunc),
        Demo(title: "IO - Sub Activity in Module", function: ioSubActivityInModuleFunc),
        Demo(title: "IO - Await Input", function: ioAwaitInputFunc),
        Demo(title: "IO - Preempt on Input", function: ioPreemptOnInputFunc),
        Demo(title: "IO - Preempt with Defer", function: ioPreemptWithDeferFunc),
        Demo(title: "IO - Query Color", function: ioQueryColorFunc),
        Demo(title: "IO - Concurrent Trails", function: ioConcurrentTrailsFunc),
        Demo(title: "IO - Streaming Activity", function: ioStreamingActivityFunc),
        Demo(title: "IO - Weak Preemption", function: ioWeakPreemptionFunc),
        Demo(title: "IO - Final Control", controller: IOFinalController(timeout: 30)),
        Demo(title: "IO - My Demo", function: ioMyDemoFunc),
        Demo(title: "Drive - Roll Ahead", function: driveRollAheadFunc),
        Demo(title: "Drive - Roll Ahead and Back", function: driveRollAheadAndBackFunc),
        Demo(title: "Drive - Manual Mode", function: driveManualModeFunc),
        Demo(title: "Drive - Normalized Manual Mode", function: driveNormalizedManualModeFunc),
        Demo(title: "Drive - Roll and Blink", function:driveRollAndBlinkFunc),
        Demo(title: "Drive - Square", controller: DriveSquareController(speed: 0.5, timeMillis: 2000)),
        Demo(title: "Drive - Circle", controller: DriveCircleController(speed: 0.5)),
        Demo(title: "Drive - My Demo", controller: DriveMyDemoController()),
        Demo(title: "Sensor - Log Samples", controller: SensorLogSamplesController()),
        Demo(title: "Sensor - Square Meter", controller: SensorSquareMeterController()),
        Demo(title: "Sensor - Follow Path", controller: SensorFollowPathController()),
        Demo(title: "Sensor - My Demo", controller: SensorMyDemoController()),
    ]
    
    static func all(for robot: Robot) -> [Demo] {
        all.filter { $0.supports(robot) }
    }
    
    func supports(_ robot: Robot) -> Bool {
        robots == nil || robots!.contains(robot)
    }
}

/// Holds info about a demo like its title, the supported robots and the way how to instantiate the demo.
struct Demo : Hashable, Identifiable {
    let title: String
    let factory: DemoFactory
    let robots: Set<Robot>?

    /// Creates a Demo description with the given `title` and the provided `function`.
    /// If you don't provide a set of supported `robots` then the demo will be fine for all robot types.
    init(title: String, function: @escaping FactoryFunction, robots: Set<Robot>? = nil) {
        self.title = title
        self.factory = .function(function)
        self.robots = robots
    }

    /// Creates a Demo description with the given `title` and the provided `controller`.
    /// If you don't provide a set of supported `robots` then the demo will be fine for all robot types.
    init(title: String, controller: DemoController, robots: Set<Robot>? = nil) {
        self.title = title
        self.factory = .controller(controller)
        self.robots = robots
    }
    
    static func == (lhs: Demo, rhs: Demo) -> Bool {
        lhs.title == rhs.title
    }

    func hash(into hasher: inout Hasher) {
        title.hash(into: &hasher)
    }
    
    var id: String {
        return title
    }
}

/// The factory type you want to use for your demo.
enum DemoFactory {
    
    /// The factory is a free function with the signature of `FactoryFunction`.
    case function(FactoryFunction)
    
    /// The factory is an object of a class which adopts the `DemoController` protocol.
    case controller(DemoController)
}

enum Robot : String, CaseIterable, Identifiable {
    case rvr = "RVR"
    case mini = "Mini"
    
    var id: Robot {
        return self
    }
    
    var deviceSelector: SyncsDeviceSelector {
        switch self {
        case .rvr: return .anyRVR
        case .mini: return .anyMini
        }
    }
}
