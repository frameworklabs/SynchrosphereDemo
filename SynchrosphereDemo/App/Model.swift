// Project Synchrosphere
// Copyright 2021, Framework Labs.

import Synchrosphere
import Pappe
import Foundation

/// The model for the application.
///
/// Creates, starts and stopps the current demo. Provides the state of the demo to the UI.
class Model: ObservableObject {

    @Published var selectedRobot = Robot.rvr
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

    struct LogLine : Equatable {
        let message: String
        let level: SyncsLogLevel
    }
    @Published var logLines = [LogLine]()
        
    private let engine = SyncsEngine()
    private let input = Input()
    private var config: SyncsControllerConfig!
    private var demoController: DemoController?
    private var syncsController: SyncsController?

    func makeConfig() {
        config = SyncsControllerConfig(deviceSelector: selectedRobot.deviceSelector)
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
            self.logLines.append(LogLine(message: msg, level: level))
        }
        config.didTickCallback = { [unowned self] in
            self.input.clear()
        }
    }
            
    func start() {
        logLines.removeAll()

        demoController = selectedDemo.demoFactory.demoController
        makeConfig()
        syncsController = demoController?.makeSyncsController(engine: engine, config: config, input: input)
        
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
        ctrl.context.logInfo("key pressed: \(keyCharacters)")
        input.key = keyCharacters
        ctrl.context.tick()
    }
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
    
    func makeSyncsController(engine: SyncsEngine, config: SyncsControllerConfig, input: Input) -> SyncsController {
        factoryFunction(engine, config, input)
    }
}
