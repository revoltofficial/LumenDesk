import SwiftUI
struct LaserControls: View {
    @EnvironmentObject var store: LightingStore
    let fixtureID: UUID
    private let labels = ["Pattern", "X position", "Y position", "Scan speed", "Pattern speed", "Size", "Colour slot", "Colour segment"]
    private var values: [UInt8] { store.state(for: fixtureID).laserDMX ?? [UInt8](repeating: 0,count: 9) }
    private func set(_ channel: Int,_ value: Int) { store.setLaserChannel(id: fixtureID,channel: channel,value: value) }
    private func namedPicker(_ title: String,_ channel: Int,_ choices: [(String,Int)]) -> some View {
        Picker(title,selection: Binding(get: { Int(values[channel]) },set: { set(channel,$0) })) {
            ForEach(choices,id: \.1) { choice in Text(choice.0).tag(choice.1) }
            if !choices.contains(where: { $0.1 == Int(values[channel]) }) { Text("DMX \(values[channel])").tag(Int(values[channel])) }
        }
    }
    var body: some View {
        VStack(alignment: .leading,spacing: 12) {
            Text("Laserworld · manual controls").font(.headline)
            Text("Excluded from music Autopilot. Named scan patterns and colours use your confirmed values; verify them on the fixture.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Picker("Mode",selection: Binding(get: { Int(values[0]) },set: { set(0,$0) })) {
                    Text("Off").tag(0); Text("Sound").tag(50); Text("Automatic").tag(100)
                    Text("Static pattern").tag(150); Text("Dynamic pattern").tag(200)
                }.frame(width: 300)
                Button("Laser off") { set(0,0) }
                Text("Master at zero, Blackout and Stop turn the laser off.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                namedPicker("Scan pattern",1,[("Double scanning",127),("Vertical scanning",135),("Vertical double scanning",145),("Diagonal scanning",94),("Spinning scan",100),("Single scanning",116)])
                namedPicker("Colour",7,[("Rainbow",0),("White",2),("Purple",4),("Light blue",6),("Green",8),("Blue",10),("Red",12)])
            }
            HStack {
                LaserPatternPreview(frame: LaserPreviewGeometry.sample(state: store.renderedState(for: fixtureID),seconds: store.phase,beats: store.tempoClock.beats)).frame(width: 180,height: 80)
                Text("Schematic scan preview. Sound/Automatic timing is illustrative; the laser runs its own programs. Unknown pattern slots have no preview.").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())],spacing: 12) {
                ForEach(1..<9) { index in
                    VStack(alignment: .leading) {
                        Text(labels[index-1]).font(.caption)
                        Stepper(value: Binding(get: { Int(values[index]) },set: { set(index,$0) }),in: 0...255) { Text("\(values[index])").monospacedDigit() }
                    }
                }
            }
            Text("Cue capture stores these controls. Mode changes are discrete. Preview geometry is illustrative, not a calibrated laser projection.").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: 850)
    }
}
