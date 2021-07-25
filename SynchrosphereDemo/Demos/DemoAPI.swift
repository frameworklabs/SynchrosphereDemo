// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere
import Foundation // For CharacterSet

/// Demo classes have to adopt to this protocol - or adhere to the `FactoryFunction` signature.
protocol DemoController : AnyObject {
    
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
    
    /// Returns `true` if any key input is available.
    var didPressKey: Bool {
        return !key.isEmpty
    }
    
    /// Returns `true` if a key in the set of `candidates` was pressed.
    func didPressKey(in candidates: String) -> Bool {
        return key.rangeOfCharacter(from: CharacterSet(charactersIn: candidates)) != nil
    }
    
    func clear() {
        key = ""
    }
}

func SyncsAdjSpeed(_ spd: SyncsSpeed, _ conf: SyncsControllerConfig) -> SyncsSpeed {
    if conf.deviceSelector == .anyRVR {
        return SyncsSpeed(Float(spd) * 0.2)
    }
    else {
        return spd
    }
}
