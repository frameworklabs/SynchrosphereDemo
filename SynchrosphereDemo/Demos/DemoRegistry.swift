// Project Synchrosphere
// Copyright 2021, Framework Labs.

/// The registry of all available demos.
///
/// If you add your own demo, add a new case and extend  `demoFactory` below.
enum Demo : String, CaseIterable, Identifiable {
    case ioHello = "IO - Hello"
    case ioHelloByClass = "IO - Hello by Class"
    case ioPreemptByKey = "IO - Preempt by Key"
    case ioMyDemo = "IO - My Demo"
    
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
        case .ioPreemptByKey:
            return .function(ioPreemptByKeyFunc)
        case .ioMyDemo:
            return .function(ioMyDemoFunc)
        }
    }
}
