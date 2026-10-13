import Foundation

enum PresetKind: String, Codable, CaseIterable, Identifiable {
    case intensity, color, effects, look
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
// Missing channels pass through to the underlying scene or layer.
struct PresetValues: Codable, Equatable {
    var dimmer: Double?
    var red: Double?
    var green: Double?
    var blue: Double?
    var white: Double?
    var channels: [Double] { [dimmer, red, green, blue, white].compactMap { $0 } }
    func applying(to state: FixtureState, fraction: Double = 1) -> FixtureState {
        var result = state
        let t = min(1, max(0, fraction))
        func mix(_ current: Double, _ value: Double?) -> Double { value.map { current + ($0 - current) * t } ?? current }
        result.dimmer = mix(state.dimmer, dimmer)
        result.red = mix(state.red, red); result.green = mix(state.green, green)
        result.blue = mix(state.blue, blue); result.white = mix(state.white, white)
        return result
    }
    mutating func merge(_ other: Self) {
        if let value = other.dimmer { dimmer = value }
        if let value = other.red { red = value }; if let value = other.green { green = value }
        if let value = other.blue { blue = value }; if let value = other.white { white = value }
    }
}
struct LookPreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var kind: PresetKind
    var values: [UUID: PresetValues]
    // nil preserves effects; an empty array explicitly disables them for these fixtures.
    var effects: [Effect]?
}
struct LayerCue: Identifiable, Codable {
    var id = UUID()
    var name: String
    var presetIDs: [UUID]
    var priority: Int = 50
    var fadeSeconds: Double = 1
}
struct ActiveLayer: Identifiable {
    var id: UUID
    var name: String
    var priority: Int
    var started: TimeInterval
    var fadeSeconds: Double
    var values: [UUID: PresetValues]
    var effects: [UUID: [Effect]]
}
struct LayerMixer {
    var layers: [ActiveLayer] = []
    func state(for id: UUID, base: FixtureState, now: TimeInterval) -> FixtureState {
        // Stable activation order breaks ties; latest activation wins.
        let ordered = layers.enumerated().sorted {
            $0.element.priority == $1.element.priority ? $0.offset < $1.offset : $0.element.priority < $1.element.priority
        }
        return ordered.reduce(base) { state, entry in
            let layer = entry.element
            let fraction = layer.fadeSeconds == 0 ? 1 : (now - layer.started) / layer.fadeSeconds
            return layer.values[id]?.applying(to: state, fraction: fraction) ?? state
        }
    }
    func effects(for id: UUID, base: [Effect]) -> [Effect] {
        let ordered = layers.enumerated().sorted {
            $0.element.priority == $1.element.priority ? $0.offset < $1.offset : $0.element.priority < $1.element.priority
        }
        return ordered.reduce(base) { $1.element.effects[id] ?? $0 }
    }
}
