//
//  SilkyApp.swift
//  Silky
//
//  Created by Adrian Helfer on 01.11.24.
//

import SwiftUI

@main
struct SilkyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands() {
            CommandMenu("Presets") {
                Button("Hand soldering") {
                    
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                
                Button("Blank PCB") {
                    
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                
                Button("HTL Wien 10 - Values") {
                    
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                
                Button("HTL Wien 10 - References") {
                    
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
