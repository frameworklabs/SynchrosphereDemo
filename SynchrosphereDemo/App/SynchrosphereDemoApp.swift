// Project Synchrosphere
// Copyright 2021, Framework Labs.

import SwiftUI
import Combine

/// The App.
@main
struct SynchrosphereDemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate;
    @StateObject private var model = Model()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    delegate.model = model
                }
        }
    }
}

/// The AppDelegate which handles stopping a running controller on termination.
private class AppDelegate : NSObject, NSApplicationDelegate {
    var model: Model?
    private var connection: AnyCancellable?
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let model = model, model.isRunning {
            connection = model.$isRunning.sink { isRunning in
                if !isRunning {
                    sender.reply(toApplicationShouldTerminate: true)
                    self.connection = nil
                }
            }
            model.stop()
            return .terminateLater
        } else {
            return .terminateNow
        }
    }
}
