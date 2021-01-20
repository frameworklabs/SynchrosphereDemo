// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere

/// Demo classes have to adopt to this protocol - or adhere to the `FactoryFunction` signature.
protocol DemoController : class {
    
    /// Needs to be implemented to create a `SyncsController` to control the spehro robot.
    func makeSyncsController(engine: SyncsEngine, config: SyncsControllerConfig, input: Input) -> SyncsController
    
    /// An explanation of what this demo is doing - e.g. giving help about possible input or expected behavior.
    ///
    /// Will be printed to log on start of demo.
    var explanation: String? { get }
}

extension DemoController {
    var explanation: String? {
        return nil
    }
}

/// Alternatively, the demo can be a function with this signature.
typealias FactoryFunction = (_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ input: Input) -> SyncsController

/// Stores the current user input during a step.
///
/// When the step is over, the input is cleared.
class Input {
    
    /// The key input - a single character string or an empty string.
    var key = ""
    
    /// Returns `true` if any key input is avlaiable.
    var didPressKey: Bool {
        return !key.isEmpty
    }
    
    func clear() {
        key = ""
    }
}
