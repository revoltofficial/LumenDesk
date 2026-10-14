import SwiftUI

struct OutputSettingsView: View {
    @EnvironmentObject var store: LightingStore
    private var transport: OutputTransport { store.project.outputTransport ?? .artNet }
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text("Lighting output").font(.headline)
                Picker("Connection",selection:Binding(get:{transport},set:{store.stopOutput();store.project.outputTransport = $0})) {
                    ForEach(OutputTransport.allCases) { Text($0.title).tag($0) }
                }.frame(width:310)
                Text(store.outputEnabled ? "Output running" : "Output off").font(.caption)
            }
            if transport == .artNet {
                HStack {
                    Text("Destination")
                    TextField("192.168.1.100",text:$store.project.destination).textFieldStyle(.roundedBorder).frame(width:180)
                    Stepper("Universe \(store.project.universe)",value:$store.project.universe,in:1...32768)
                }
                Text("Use your node’s unicast address. Universe 1 maps to port-address 0.").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    Picker("USB cable",selection:Binding(get:{store.project.usbDevice ?? ""},set:{store.stopOutput();store.project.usbDevice = $0})) {
                        Text("Select cable…").tag("")
                        ForEach(store.usbDevices,id:\.self) { Text($0.replacingOccurrences(of:"/dev/cu.",with:"")).tag($0) }
                        if let saved = store.project.usbDevice, !saved.isEmpty, !store.usbDevices.contains(saved) { Text("Disconnected · \(saved)").tag(saved) }
                    }.frame(width:400)
                    Button("Refresh cables",action:store.refreshUSBDevices)
                }
                Text(store.usbDevices.isEmpty ? "No FTDI serial cable detected. Connect it, then refresh. Close Lightkey before starting USB output." : "One cable carries the currently selected 512-channel universe.").font(.caption)
                Text("Experimental: cable compatibility and DMX timing require hardware testing. Uses the macOS serial driver; no driver or system settings are changed.").font(.caption2).foregroundStyle(.secondary)
            }
        }.onAppear(perform:store.refreshUSBDevices)
    }
}
