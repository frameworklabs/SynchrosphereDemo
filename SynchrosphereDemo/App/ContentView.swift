// Project Synchrosphere
// Copyright 2021, Framework Labs.

import SwiftUI

/// The main view.
struct ContentView: View {
    @EnvironmentObject private var model: Model
    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    Picker("Demo:", selection: $model.selectedDemo) {
                        ForEach(Demo.allCases) { demo in
                            Text(demo.rawValue)
                        }
                    }
                    .disabled(model.isRunning)

                    Button("Start") {
                        model.start()
                    }
                    .frame(width: 50)
                    .controlSize(.small)
                    .disabled(model.isRunning)
                }
                HStack {
                    ScrollView {
                        ScrollViewReader { scrollView in
                            LazyVStack(alignment: .leading) {
                                ForEach(0..<model.logLines.count, id: \.self) { i in
                                    Text(model.logLines[i]).id(i)
                                }
                            }
                            .onChange(of: model.logLines) { _ in
                                scrollView.scrollTo(model.logLines.count - 1)
                            }
                        }
                    }
                    .frame(minWidth: 300, minHeight: 200)
                    .background(Color.black)
                    .cornerRadius(10)

                    Button("Stop") {
                        model.stop()
                    }
                    .frame(width: 50)
                    .controlSize(.large)
                    .foregroundColor(.red)
                    .disabled(!model.isRunning)
                }
            }
            HStack {
                LED(name: "ON", isOn: model.isRunning)
                    .help("is running")
                LED(name: "BT", isOn: model.isBluetoothAvailable)
                    .help("is Bluetooth available")
                LED(name: "SCN", isOn: model.isScanning)
                    .help("is scanning")
                LED(name: "DEV", isOn: model.foundDevice)
                    .help("device found")
                LED(name: "CO", isOn: model.isConnecting)
                    .help("is connecting")
                LED(name: "CON", isOn: model.isConnected)
                    .help("is connected")
                LED(name: "INT", isOn: model.isIntrospecting)
                    .help("retrieving services and characteristics")
                LED(name: "AWK", isOn: model.isAwake)
                    .help("is awake")
                LED(name: "LOW", isOn: model.isBatteryLow)
                    .help("is battery low")
                LED(name: "CRI", isOn: model.isBatteryCritical)
                    .help("is battery criticial")
            }
        }
        .colorScheme(.dark)
        .padding()
        .background(KeyEventView())
    }
}
