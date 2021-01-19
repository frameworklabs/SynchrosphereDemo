// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere
import Pappe
import Foundation

/// The model for the application.
///
/// Creates, starts and stopps the current demo. Provides the state of the demo to the UI.
class Model: ObservableObject {
    
    @Published var selectedDemo = Demo.ioHello
    
    @Published var isRunning = false
    @Published var isBluetoothAvailable = false
    @Published var isScanning = false
    @Published var foundDevice = false
    @Published var isConnecting = false
    @Published var isConnected = false
    @Published var isIntrospecting = false
    @Published var isAwake = false
    @Published var isBatteryLow = false
    @Published var isBatteryCritical = false

    @Published var logLines = [String]()
        
    private let engine = SyncsEngine()
    private let keyInput = KeyInput()
    private var config = SyncsControllerConfig()
    private var demoController: DemoController?
    private var syncsController: SyncsController?

    init() {
        config.stateDidChangeCallback = { [unowned self] state in
            self.isRunning = state.contains(.isRunning)
            self.isBluetoothAvailable = state.contains(.isBluetoothAvailable)
            self.isScanning = state.contains(.isScanning)
            self.foundDevice = state.contains(.foundDevice)
            self.isConnecting = state.contains(.isConnecting)
            self.isConnected = state.contains(.isConnected)
            self.isIntrospecting = state.contains(.isIntrospecting)
            self.isAwake = state.contains(.isAwake)
            self.isBatteryLow = state.contains(.isBatteryLow)
            self.isBatteryCritical = state.contains(.isBatteryCritical)
        }
        config.logFunction = { [unowned self] msg, level in
            self.logLines.append("[\(level)] \(msg)")
        }
        config.didTickCallback = { [unowned self] in
            self.keyInput.clear()
        }
    }
            
    func start() {
        logLines.removeAll()

        demoController = selectedDemo.demoFactory.demoController
        syncsController = demoController?.makeSyncsController(engine: engine, config: config, keyInput: keyInput)
        
        if let explanation = demoController?.explanation {
            syncsController?.context.logInfo(explanation)
        }
        
        syncsController?.start()
    }
    
    func stop() {
        syncsController?.stop()
        syncsController = nil
        demoController = nil
    }

    func setKeyCharacters(_ keyCharacters: String) {
        guard let ctrl = syncsController else { return }
        ctrl.context.logInfo("keys pressed: \(keyCharacters)")
        keyInput.input = keyCharacters
        ctrl.context.tick()
    }
}

private extension DemoFactory {
    var demoController: DemoController {
        switch self {
        case .function(let f):
            return DefaultDemoController(factoryFunction: f)
        case .controller(let c):
            return c
        }
    }
}

/// Wraps a `FactoryFunction` into a `DemoController` for uniform handling.
private class DefaultDemoController : DemoController {
    
    private let factoryFunction: FactoryFunction
    
    init(factoryFunction: @escaping FactoryFunction) {
        self.factoryFunction = factoryFunction
    }
    
    func makeSyncsController(engine: SyncsEngine, config: SyncsControllerConfig, keyInput: KeyInput) -> SyncsController {
        factoryFunction(engine, config, keyInput)
    }
}
