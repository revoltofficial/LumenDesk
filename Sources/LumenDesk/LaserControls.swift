import SwiftUI
struct LaserControls: View {
    @EnvironmentObject var store: LightingStore
    let fixtureID: UUID
    private let labels = ["Pattern", "X position", "Y position", "Scan speed", "Pattern speed", "Size", "Colour slot", "Colour segment"]
    private var values: [UInt8] { store.state(for: fixtureID).laserDMX ?? [UInt8](repeating: 0,count: 9) }
    private func set(_ channel: Int,_ value: Int) {
        var state = store.state(for: fixtureID)
        var channels = state.laserDMX ?? [UInt8](repeating: 0,count: 9)
        channels[channel] = UInt8(min(255,max(0,value)))
        state.laserDMX = channels; state.dimmer = channels[0] == 0 ? 0 : 1
        store.setState(id: fixtureID,state: state)
    }
    var body: some View {
        VStack(alignment: .leading,spacing: 12) {
            Text("Laserworld · manual controls").font(.headline)
            Text("Excluded from music Autopilot. Pattern and colour slots show DMX values; verify them on the fixture.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Picker("Mode",selection: Binding(get: { Int(values[0]) },set: { set(0,$0) })) {
                    Text("Off").tag(0); Text("Sound").tag(50); Text("Automatic").tag(100)
                    Text("Static pattern").tag(150); Text("Dynamic pattern").tag(200)
                }.frame(width: 300)
                Button("Laser off") { set(0,0) }
                Text("Master at zero, Blackout and Stop turn the laser off.").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())],spacing: 12) {
                ForEach(1..<9) { index in
                    VStack(alignment: .leading) {
                        Text(labels[index-1]).font(.caption)
                        Stepper(value: Binding(get: { Int(values[index]) },set: { set(index,$0) }),in: 0...255) { Text("\(values[index])").monospacedDigit() }
                    }
                }
            }
            Text("Cue capture stores these controls. Mode changes are discrete; patterns are not simulated in the stage preview.").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: 850)
    }
}
