// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere

/// Demo classes have to adopt to this protocol - or adhere to the `FactoryFunction` signature.
protocol DemoController : class {
    
    /// Needs to be implemented to create a `SyncsController` to control the spehro robot.
    func makeSyncsController(engine: SyncsEngine, config: SyncsControllerConfig, keyInput: KeyInput) -> SyncsController
    
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
typealias FactoryFunction = (_ engine: SyncsEngine, _ config: SyncsControllerConfig, _ keyInput: KeyInput) -> SyncsController

/// If the user presses a key, it will be available here during the next step.
///
/// When the step is over, the input is cleared.
class KeyInput {
    
    /// The key input - a single character or empty string.
    var input = ""
    
    /// Returns `true` if any input is avlaiable.
    var hasInput: Bool {
        return !input.isEmpty
    }
    
    func clear() {
        input.removeAll()
    }
}
