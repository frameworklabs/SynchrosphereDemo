// Project Synchrosphere
// Copyright 2021, Framework Labs.

/// The registry of all available demos.
///
/// If you add your own demo, add a new case and extend  `demoFactory` below.
enum Demo : String, CaseIterable, Identifiable {
    case ioHello = "IO - Hello"
    case ioHelloByClass = "IO - Hello by Class"
    case ioSubActivity = "IO - Sub Activity"
    case ioSubActivityInModule = "IO - Sub Activity in Module"
    case ioAwaitInput = "IO - Await Input"
    case ioPreemptOnInput = "IO - Preempt on Input"
    case ioPreemptWithDefer = "IO - Preempt with Defer"
    case ioQueryColor = "IO - Query Color"
    case ioConcurrentTrails = "IO - Concurrent Trails"
    case ioStreamingActivity = "IO - Streaming Activity"
    case ioWeakPreemption = "IO - Weak Preemption"
    case ioFinalControl = "IO - Final Control"
    case ioMyDemo = "IO - My Demo"
    case driveRollAhead = "Drive - Roll Ahead"
    case driveRollAheadAndBack = "Drive - Roll Ahead and Back"
    case driveManualMode = "Drive - Manual Mode"
    case driveNormalizedManualMode = "Drive - Normalized Manual Mode"
    case driveRollAndBlink = "Drive - Roll and Blink"
    case driveSquare = "Drive - Square"
    case driveCircle = "Drive - Circle"
    case driveMyDemo = "Drive - My Demo"
    case sensorLogSamples = "Sensor - Log Samples"
    case sensorSquareMeter = "Sensor - Square Meter"
    case sensorFollowPath = "Sensor - Follow Path"
    case sensorMyDemo = "Sensor - My Demo"
    
    var id: Demo {
        return self
    }
}

/// The factory type you want to use for your demo.
enum DemoFactory {
    
    /// The factory is a free function with the signature of `FactoryFunction`.
    case function(FactoryFunction)
    
    /// The factory is an object of a class which adopts the `DemoController` protocol.
    case controller(DemoController)
}

extension Demo {
    
    /// Returns the factory for the demo.
    ///
    /// If you add your own demo, you have to extend this method too.
    var demoFactory:  DemoFactory {
        switch self {
        case .ioHello:
            return .function(ioHelloFunc)
        case .ioHelloByClass:
            return .controller(IOHelloController())
        case .ioSubActivity:
            return .function(ioSubActivityFunc)
        case .ioSubActivityInModule:
            return .function(ioSubActivityInModuleFunc)
        case .ioAwaitInput:
            return .function(ioAwaitInputFunc)
        case .ioPreemptOnInput:
            return .function(ioPreemptOnInputFunc)
        case .ioPreemptWithDefer:
            return .function(ioPreemptWithDeferFunc)
        case .ioQueryColor:
            return .function(ioQueryColorFunc)
        case .ioConcurrentTrails:
            return .function(ioConcurrentTrailsFunc)
        case .ioStreamingActivity:
            return .function(ioStreamingActivityFunc)
        case .ioWeakPreemption:
            return .function(ioWeakPreemptionFunc)
        case .ioFinalControl:
            return .controller(IOFinalController(timeout: 30))
        case .ioMyDemo:
            return .function(ioMyDemoFunc)
        case .driveRollAhead:
            return .function(driveRollAheadFunc)
        case .driveRollAheadAndBack:
            return .function(driveRollAheadAndBackFunc)
        case .driveManualMode:
            return .function(driveManualModeFunc)
        case .driveNormalizedManualMode:
            return .function(driveNormalizedManualModeFunc)
        case.driveRollAndBlink:
            return .function(driveRollAndBlinkFunc)
        case .driveSquare:
            return .controller(DriveSquareController(speed: 0.5, timeMillis: 2000))
        case .driveCircle:
            return .controller(DriveCircleController(speed: 0.5))
        case .driveMyDemo:
            return .controller(DriveMyDemoController())
        case .sensorLogSamples:
            return .controller(SensorLogSamplesController())
        case .sensorSquareMeter:
            return .controller(SensorSquareMeterController())
        case .sensorFollowPath:
            return .controller(SensorFollowPathController())
        case .sensorMyDemo:
            return .controller(SensorMyDemoController())
        }
    }
}
