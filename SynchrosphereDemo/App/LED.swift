// Project Synchrosphere
// Copyright 2021, Framework Labs.

import SwiftUI

/// Depicts an LED with a label.
struct LED: View {
    let name: String
    let isOn: Bool
    
    var body: some View {
        VStack {
            Text(name)
            Circle()
                .foregroundColor(isOn ? .red : .white)
                .frame(width: 20, height: 20)
        }
        .frame(width: 40)
    }
}
