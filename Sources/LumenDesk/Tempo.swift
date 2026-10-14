import SwiftUI
struct TempoSettings: Codable {
    var bpm: Double = 120
    var valid: Bool { bpm.isFinite && (30...300).contains(bpm) }
}
struct TempoClock {
    private(set) var beats: Double = 0
    private var taps: [TimeInterval] = []
    mutating func advance(seconds: Double, bpm: Double) {
        guard seconds.isFinite, seconds >= 0, bpm.isFinite, (30...300).contains(bpm) else { return }
        beats += seconds * bpm / 60
    }
    mutating func alignBeat() {
        let correction = beats.rounded()-beats
        if abs(correction) < 0.25 { beats += correction*0.4 }
    }
    mutating func sync() { beats = 0 }
    mutating func seek(beats value: Double) { if value.isFinite && value >= 0 { beats = value } }
    mutating func resetTaps() { taps = [] }
    mutating func tap(at now: TimeInterval) -> Double? {
        guard now.isFinite else { return nil }
        if let last = taps.last {
            let interval = now - last
            if interval < 0.2 && interval >= 0 { return nil }
            if interval > 2.5 || interval < 0 { taps = [] }
        }
        taps.append(now); taps = Array(taps.suffix(8))
        guard taps.count >= 2, let first = taps.first, let last = taps.last else { return nil }
        let bpm = 60 * Double(taps.count - 1) / (last - first)
        return min(300, max(30, bpm))
    }
}
extension LightingStore {
    var bpm: Double { (project.tempo ?? TempoSettings()).bpm }
    func setBPM(_ value: Double) {
        guard value.isFinite, (30...300).contains(value) else { return }
        tick(); project.tempo = TempoSettings(bpm: value); tempoClock.resetTaps()
    }
    func setManualBPM(_ value: Double) {
        guard value.isFinite, (30...300).contains(value) else { return }
        automaticTempo = false
        setBPM(value)
    }
    func stepBPM(_ step: Double) {
        guard step.isFinite else { return }
        setManualBPM(min(300, max(30, bpm + step)))
    }
    func syncTempo() {
        tempoClock.sync(); phase = 0; resetTempoTick()
    }
    func tapTempo() {
        automaticTempo = false
        let now = tempoNow()
        if let value = tempoClock.tap(at: now) { project.tempo = TempoSettings(bpm: value) }
        syncTempo()
    }
}
struct TempoControls: View {
    @EnvironmentObject var store: LightingStore
    var body: some View {
        HStack(spacing: 6) {
            Text("BPM").font(.caption)
            Button { store.stepBPM(-1) } label: { Image(systemName: "minus") }
                .accessibilityLabel("Decrease BPM").help("Decrease by 1 BPM and use manual tempo").disabled(store.bpm <= 30)
            TextField("BPM", value: Binding(get: { store.bpm }, set: { store.setManualBPM($0) }), format: .number.precision(.fractionLength(0...1))).textFieldStyle(.roundedBorder).frame(width: 65)
                .accessibilityLabel("Manual BPM").help("Type an exact BPM (30–300). This switches off automatic tempo following.")
            Button { store.stepBPM(1) } label: { Image(systemName: "plus") }
                .accessibilityLabel("Increase BPM").help("Increase by 1 BPM and use manual tempo").disabled(store.bpm >= 300)
            Button("Tap", action: store.tapTempo)
            Button("Sync", action: store.syncTempo).help("Restart the shared beat and all effect phases together")
            HStack(spacing: 5) {
                ForEach(0..<4) { beat in Circle().fill(Int(store.tempoClock.beats.truncatingRemainder(dividingBy: 4)) == beat ? Color.mint : Color.white.opacity(0.15)).frame(width: 9, height: 9) }
            }.accessibilityLabel("Beat \(Int(store.tempoClock.beats.truncatingRemainder(dividingBy: 4)) + 1) of 4")
        }.font(.caption)
    }
}
