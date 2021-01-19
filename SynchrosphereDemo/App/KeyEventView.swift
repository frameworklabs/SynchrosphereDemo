// Project Synchrosphere
// Copyright 2021, Framework Labs.

import SwiftUI

/// A helper Swift-UI view which bridges to an NSView to gather key input and forward it to the `Model`.
struct KeyEventView: NSViewRepresentable {
    
    @EnvironmentObject private var model: Model
        
    private class View: NSView {
        private let model: Model
        
        init(_ model: Model) {
            self.model = model
            super.init(frame: NSRect.zero)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override var acceptsFirstResponder: Bool {
            true
        }
        
        override func keyDown(with event: NSEvent) {
            model.setKeyCharacters(event.charactersIgnoringModifiers ?? "")
        }
    }

    func makeNSView(context: Context) -> NSView {
        let view = View(model)
        DispatchQueue.main.async { // Wait till next event cycle.
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }
}
