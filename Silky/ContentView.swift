//
//  ContentView.swift
//  Silky
//
//  Created by Adrian Helfer on 01.11.24.
//

import SwiftUI
import UniformTypeIdentifiers

let partValue = "Part Value"
let partReference = "Part Reference"

struct ContentView: View {
    
    struct PCBFile: Identifiable, Hashable {
        let name: String
        let fullPath: String
        let id = UUID()
    }
    
    struct Component: Identifiable, Hashable {
        let name: String
        let acronym: Character
        let id = UUID()
    }
    
    struct PCBLayer: Identifiable, Hashable {
        let name: String
        let id = UUID()
    }
    
    
    @State private var isPickerPresented = false
    
    @State private var pcbFiles: [PCBFile] = []
    @State private var pcbFileSelection = Set<UUID>()
    
    @State private var fromLayers: [PCBLayer] = [PCBLayer(name: partValue), PCBLayer(name: partReference)]
    @State private var toLayers: [PCBLayer] = []
    
    @State private var fromLayerSelection = Set<UUID>()
    @State private var toLayerSelection = Set<UUID>()
    
    @State private var components: [Component] = []
    @State private var applyToPartsSelection = Set<UUID>()
    
    @State private var isAltPressed = false
    
    let layerNames = ["F.Fab", "B.Fab", "F.CrtYd", "B.CrtYd", "F.SilkS", "B.SilkS", "F.Mask", "B.Mask", "F.Cu", "In1.Cu", "In2.Cu", "B.Cu", "Edge.Cuts", "In3.Cu", "In4.Cu", "In5.Cu", "In6.Cu", "In7.Cu", "In8.Cu", "In9.Cu", "In10.Cu", "In11.Cu"]
    
    var isLayerNameSelected: Bool {
        fromLayers.contains { layer in
            layerNames.contains(layer.name) && fromLayerSelection.contains(layer.id)
        }
    }
    
    var body: some View {
        HStack {
            VStack {
                Text("PCB Files")
                
                List(pcbFiles, selection: $pcbFileSelection) {
                    file in Text(isAltPressed ? file.fullPath : file.name)
                }
                .cornerRadius(10)
                
                HStack {
                    SilkyButton(text: "Add", systemImageName: "plus.square") {
                        isPickerPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    SilkyButton(text: "Remove", systemImageName: "minus.square") {
                        removeSelectedFiles()
                    }
                }
            }
                        
            VStack {
                Text("Change Layers from")
                
                List(fromLayers, selection: $fromLayerSelection) {
                    Text($0.name)
                }
                .onChange(of: fromLayerSelection, { if (isLayerNameSelected) { applyToPartsSelection = Set(components.map { $0.id }) } })
                .cornerRadius(10)
                
                Text("To")
                
                List(toLayers, selection: $toLayerSelection) {
                    Text($0.name)
                }
                .cornerRadius(10)
                
                Text("Apply to Parts")
                
                List(components, selection: $applyToPartsSelection){
                    Text($0.name)
                    
                }
                .disabled(isLayerNameSelected)
                .cornerRadius(10)
                
                HStack {
                    SilkyButton(text: "Add", systemImageName: "plus") {}
                    SilkyButton(text: "Remove", systemImageName: "minus") {}
                }
                
            }
            
            VStack {
                Text("Operations")
                
                List{}
                    .cornerRadius(10)
                
                SilkyButton(text: "Preview", systemImageName: "dot.circle.viewfinder") {}
                
                HStack {
                    SilkyButton(text: "Override all", systemImageName: "square.and.arrow.down") {}
                    
                    SilkyButton(text: "Save a Copy", systemImageName: "square.and.arrow.down.on.square") {}
                }
            }
        }
        .padding()
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [UTType(filenameExtension: "kicad_pcb")!],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            startListeningForKeyEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            stopListeningForKeyEvents()
        }
        
    }
    

    
    func readFileByLine(at path: String) -> [String]? {
        do {
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines)
            return lines
        } catch {
            print("Error selecting file: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            // -------------------------------------------------------
            // Add selected Files to List if they are new
            
            let urls = try result.get()
            let newFiles = urls
                .filter { url in
                    !pcbFiles.contains(where: { $0.fullPath == url.path })
                }
                .map { url in
                    PCBFile(name: url.lastPathComponent, fullPath: url.path)
                }
            
            pcbFiles.append(contentsOf: newFiles)
            
            // ---------------------------------------------------------
            // Extracting Layers
            
            for file in newFiles {
                let lines = readFileByLine(at: file.fullPath)
                if (lines == nil) { return }
                
                var parentheseCount = 0;
                var lineCount = 0;
                
                
                while(lineCount < lines!.count)
                {
                    if (lines![lineCount].contains("(layers")) {
                        parentheseCount += 1
                        break
                    }
                    lineCount += 1
                }
                
                while (parentheseCount > 0)
                {
                    lineCount += 1;
                    if (lines![lineCount].contains("(")) { parentheseCount += 1 }
                    if (lines![lineCount].contains(")")) { parentheseCount -= 1 }
                    for layerName in layerNames {
                        addLayerIfMissing(lines: lines, lineCount: lineCount, layerName: layerName)
                    }
                }
                
                // -----------------------------------------------------
                // Extracting Components
                
                for line in lines! {
                    if let range = line.range(of: "(fp_text reference \"") {
                        let index = line.distance(from: line.startIndex, to: range.upperBound)
                        
                        let acronym = line[line.index(line.startIndex, offsetBy: index)]
                        
                        var componentName: String
                        
                        switch acronym {
                        case "R": componentName = "Resistors"
                        case "C": componentName = "Capacitors"
                        case "L": componentName = "Inductors"
                        case "D": componentName = "Diodes"
                        case "K": componentName = "Relays"
                        case "Q": componentName = "Transistors"
                        case "J": componentName = "Jumpers and Connectors"
                        case "U": componentName = "ICs"
                        case "*": componentName = "entire Layer"
                        default: componentName = "Whatever \(acronym) means"
                        }
                        
                        if (!components.contains{ $0.acronym == acronym }) {
                            components.append(Component(name: componentName, acronym: acronym))
                        }
                    }
                }
            }
        } catch {
            print("Error selecting file: \(error.localizedDescription)")
        }
    }
    
    func addLayerIfMissing(lines: [String]?, lineCount: Int, layerName: String) {
        guard let lines = lines, lineCount < lines.count else { return }
        
        if lines[lineCount].contains(layerName) && !fromLayers.contains(where: { $0.name == layerName }) {
            fromLayers.append(PCBLayer(name: layerName))
            toLayers.append(PCBLayer(name: layerName))
        }
    }
    
    private func removeSelectedFiles() {
        pcbFiles.removeAll { pcbFileSelection.contains($0.id) }
        pcbFileSelection.removeAll()
    }
    
    private func startListeningForKeyEvents() {
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            isAltPressed = event.modifierFlags.contains(.option)
            return event
        }
    }
    
    private func stopListeningForKeyEvents() {
        NSEvent.removeMonitor(self)
    }
}


struct SilkyButton: View {
    let text: String
    let systemImageName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(text, systemImage: systemImageName)
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(5)
        }
        .cornerRadius(10)
    }
}



#Preview {
    ContentView()
}
