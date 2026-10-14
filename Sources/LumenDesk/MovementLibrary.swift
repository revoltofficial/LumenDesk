import SwiftUI

enum MotionArrangement: String, Codable, CaseIterable {
    case spread, together, mirrored, alternating
    var title: String { rawValue.capitalized }
}
struct MovementPreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var effect: Effect
    var favorite = false
    var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && effect.kind == .circle && effect.validTiming && effect.rate.isFinite && (0...20).contains(effect.rate) && effect.depth.isFinite && (0...1).contains(effect.depth) }
}
extension MotionPath {
    static func coordinated(effect: Effect, cycles: Double, index: Int, count: Int) -> MotionPoint {
        let arrangement = effect.arrangement ?? .spread
        let offset: Double
        switch arrangement {
        case .together, .mirrored: offset = 0
        case .alternating: offset = index.isMultiple(of: 2) ? 0 : 0.5
        case .spread: offset = Double(index) / Double(max(1, count)) * (effect.spread ?? 1)
        }
        var point = sample(effect: effect, phase: cycles + offset)
        if arrangement == .mirrored && !index.isMultiple(of: 2) { point.x = -point.x }
        return point
    }
    static func preset(_ pattern: MovementPattern) -> Effect {
        var effect = Effect(name: pattern.title, kind: .circle)
        effect.movement = pattern; effect.beatTiming = true; effect.beatsPerCycle = pattern == .atmosphere ? 64 : 16
        effect.depth = pattern == .atmosphere ? 0.5 : 0.65
        effect.arrangement = pattern == .fan || pattern == .cross ? .mirrored : .spread
        effect.spread = pattern == .atmosphere ? 0.25 : 0.5
        if pattern == .custom { effect.pathPoints = defaults }
        return effect
    }
}
extension LightingStore {
    func prepareMovementLibrary() -> UUID {
        if let effect = project.effects.first(where: { $0.kind == .circle }) { return effect.id }
        let effect = MotionPath.preset(.circle); project.effects.append(effect); return effect.id
    }
    func movementBinding(id: UUID) -> Binding<Effect> {
        Binding(get: { self.project.effects.first(where: { $0.id == id }) ?? MotionPath.preset(.circle) }, set: { value in
            guard let index = self.project.effects.firstIndex(where: { $0.id == id }) else { return }
            var value = value; value.id = id; self.project.effects[index] = value
        })
    }
    @discardableResult func saveMovement(name: String, effect: Effect) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var saved = effect; saved.enabled = false; saved.id = UUID(); saved.name = trimmed
        let preset = MovementPreset(name: trimmed, effect: saved)
        guard preset.valid, (project.movementPresets ?? []).count < 64 else { return nil }
        var presets = project.movementPresets ?? []; presets.append(preset); project.movementPresets = presets
        return preset.id
    }
    func toggleMovementFavorite(_ pattern: MovementPattern) {
        var favorites = project.movementFavorites ?? []
        if favorites.contains(pattern) { favorites.removeAll { $0 == pattern } } else { favorites.append(pattern) }
        project.movementFavorites = favorites
    }
    func toggleSavedMovementFavorite(_ id: UUID) {
        guard let index = project.movementPresets?.firstIndex(where: { $0.id == id }) else { return }
        project.movementPresets?[index].favorite.toggle()
    }
}
struct MovementLibraryButton: View {
    @EnvironmentObject var store: LightingStore
    @State private var effectID: UUID?
    var body: some View {
        Button("Movement library…") { effectID = store.prepareMovementLibrary() }
            .sheet(item: Binding(get: { effectID.map { MovementSheetID(id: $0) } }, set: { effectID = $0?.id })) { item in
                MovementLibraryView(effect: store.movementBinding(id: item.id))
            }
    }
}
private struct MovementSheetID: Identifiable { var id: UUID }
struct MovementParameters: View {
    @Binding var effect: Effect
    private func value(_ key: WritableKeyPath<Effect, Double?>, fallback: Double) -> Binding<Double> {
        Binding(get: { effect[keyPath: key] ?? fallback }, set: { effect[keyPath: key] = $0 })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Coordination", selection: Binding(get: { effect.arrangement ?? .spread }, set: { effect.arrangement = $0 })) {
                    ForEach(MotionArrangement.allCases, id: \.self) { Text($0.title).tag($0) }
                }.frame(width: 220)
                Toggle("Reverse", isOn: Binding(get: { effect.reverse ?? false }, set: { effect.reverse = $0 }))
                Text("Phase").font(.caption)
                Slider(value: value(\.motionPhase, fallback: 0), in: 0...1).frame(width: 95).accessibilityLabel("Movement phase")
                Text("\(Int((effect.motionPhase ?? 0)*100))%").font(.caption).monospacedDigit()
            }
            HStack {
                Text("Pan size").font(.caption)
                Slider(value: value(\.panSize, fallback: 1), in: 0...1).frame(width: 120).accessibilityLabel("Movement pan size")
                Text("Tilt size").font(.caption)
                Slider(value: value(\.tiltSize, fallback: 1), in: 0...1).frame(width: 120).accessibilityLabel("Movement tilt size")
            }
        }
    }
}
struct MovementPathPreview: View {
    var effect: Effect
    var body: some View {
        Canvas { context, size in
            func location(_ point: MotionPoint) -> CGPoint { CGPoint(x: (point.x+1)*size.width/2, y: (1-point.y)*size.height/2) }
            var axes = Path(); axes.move(to: CGPoint(x: size.width/2,y: 0)); axes.addLine(to: CGPoint(x: size.width/2,y: size.height)); axes.move(to: CGPoint(x: 0,y: size.height/2)); axes.addLine(to: CGPoint(x: size.width,y: size.height/2))
            context.stroke(axes,with: .color(.white.opacity(0.1)),lineWidth: 1)
            var path = Path()
            for step in 0...120 {
                var point = MotionPath.sample(effect: effect,phase: Double(step)/120)
                point.x *= effect.panSize ?? 1; point.y *= effect.tiltSize ?? 1
                if step == 0 { path.move(to: location(point)) } else { path.addLine(to: location(point)) }
            }
            context.stroke(path,with: .color(.mint),lineWidth: 2)
            var start = MotionPath.sample(effect: effect,phase: 0)
            start.x *= effect.panSize ?? 1; start.y *= effect.tiltSize ?? 1
            let q = location(start)
            context.fill(Path(ellipseIn: CGRect(x: q.x-3,y: q.y-3,width: 6,height: 6)),with: .color(.orange))
        }.background(Color.white.opacity(0.03),in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("\((effect.movement ?? .circle).title) path preview")
    }
}
struct MovementLibraryView: View {
    @Binding var effect: Effect
    @EnvironmentObject var store: LightingStore
    @Environment(\.dismiss) private var dismiss
    @State private var favoritesOnly = false
    @State private var name = "My movement"
    @State private var savedMessage = ""
    private var patterns: [MovementPattern] { MovementPattern.allCases.filter { !favoritesOnly || (store.project.movementFavorites ?? []).contains($0) } }
    private var saved: [MovementPreset] { (store.project.movementPresets ?? []).filter { !favoritesOnly || $0.favorite } }
    private func apply(_ source: Effect) {
        var value = source; value.id = effect.id; value.enabled = true; effect = value
        savedMessage = ""
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Movement library").font(.title2); Spacer(); Toggle("Favourites only",isOn: $favoritesOnly); Button("Done") { dismiss() } }
            Text("Choosing a movement starts this effect on moving heads. It blends through your movement limits. Other active effects and Autopilot can also affect the look.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()),count: 4),spacing: 10) {
                        ForEach(patterns,id: \.self) { pattern in builtInCard(pattern) }
                    }
                    Text("Saved movements").font(.headline)
                    if saved.isEmpty { Text(favoritesOnly ? "No saved favourites yet." : "Save the current settings below to build your collection.").font(.caption).foregroundStyle(.secondary) }
                    ForEach(saved) { preset in savedRow(preset) }
                }
            }.frame(height: 260)
            Divider()
            HStack(alignment: .top) {
                MovementPathPreview(effect: effect).frame(width: 160,height: 125)
                VStack(alignment: .leading,spacing: 8) {
                    Text(effect.name).font(.headline)
                    Toggle("Movement enabled",isOn: $effect.enabled)
                    MovementParameters(effect: $effect)
                    HStack {
                        Picker("Cycle", selection: Binding(get: { effect.cycleBeats },set: { effect.beatsPerCycle = $0; effect.beatTiming = true })) {
                            ForEach([0.25,0.5,1,2,4,8,16,32,64],id: \.self) { Text("\($0.formatted()) beats").tag($0) }
                        }.frame(width: 180)
                        Text("Depth").font(.caption); Slider(value: $effect.depth,in: 0...1).frame(width: 90)
                        Text("Spread").font(.caption); Slider(value: Binding(get: { effect.spread ?? 1 },set: { effect.spread = $0 }),in: 0...1).frame(width: 90)
                    }
                }
            }
            HStack {
                TextField("Preset name",text: $name).textFieldStyle(.roundedBorder).frame(width: 190)
                Button("Save movement") {
                    savedMessage = store.saveMovement(name: name,effect: effect) == nil ? "Enter a name; up to 64 movements can be saved." : "Saved in this show."
                }
                Text(savedMessage).font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }.padding(20).frame(width: 800)
    }
    private func builtInCard(_ pattern: MovementPattern) -> some View {
        VStack(spacing: 5) {
            Button { apply(MotionPath.preset(pattern)) } label: {
                VStack { MovementPathPreview(effect: MotionPath.preset(pattern)).frame(height: 65); Text(pattern.title).font(.caption) }
            }.buttonStyle(.plain).accessibilityLabel("Use \(pattern.title)")
            Button { store.toggleMovementFavorite(pattern) } label: { Image(systemName: (store.project.movementFavorites ?? []).contains(pattern) ? "star.fill" : "star") }
                .buttonStyle(.plain).foregroundStyle(.yellow).accessibilityLabel("Favourite \(pattern.title)")
        }.padding(6).background(Color.white.opacity(0.04),in: RoundedRectangle(cornerRadius: 8))
    }
    private func savedRow(_ preset: MovementPreset) -> some View {
        HStack {
            MovementPathPreview(effect: preset.effect).frame(width: 65,height: 40)
            Button(preset.name) { apply(preset.effect) }
            Button { store.toggleSavedMovementFavorite(preset.id) } label: { Image(systemName: preset.favorite ? "star.fill" : "star") }.accessibilityLabel("Favourite saved \(preset.name)")
            Spacer()
            Button("Remove") { store.project.movementPresets?.removeAll { $0.id == preset.id } }
        }
    }
}
