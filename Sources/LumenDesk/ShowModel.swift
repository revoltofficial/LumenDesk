import Foundation

enum FixtureKind: String, Codable, CaseIterable, Identifiable {
    case dimmer, rgb, rgbw, movingHead
    var id: String { rawValue }
    var footprint: Int { self == .movingHead ? 11 : (self == .dimmer ? 1 : (self == .rgb ? 3 : 4)) }
    var title: String { self == .movingHead ? "MOVING HEAD" : rawValue.uppercased() }
}
struct Fixture: Identifiable, Codable {
    var id = UUID()
    var name: String
    var kind: FixtureKind
    var address: Int
    var x: Double = 0.5
    var y: Double = 0.5
    var profile: FixtureProfile? = nil
    var mountingHeight: Double? = nil
    var mountingRotation: Double? = nil
    var invertPan: Bool? = nil
    var invertTilt: Bool? = nil
    var rotation: Double { mountingRotation ?? 0 }
    func outputState(_ state: FixtureState) -> FixtureState {
        var result = state
        if resolvedProfile.movingHead {
            if invertPan == true { result.pan = 1 - state.pan }
            if invertTilt == true { result.tilt = 1 - state.tilt }
        }
        return result
    }
    var resolvedProfile: FixtureProfile {
        if let profile { return profile }
        switch kind { case .dimmer: return .dimmer; case .rgb: return .rgb; case .rgbw: return .rgbw; case .movingHead: return .head }
    }
    var footprint: Int { resolvedProfile.footprint }
    var height: Double { mountingHeight ?? 3 }
}
struct FixtureState: Codable, Equatable {
    var dimmer: Double = 1
    var red: Double = 1
    var green: Double = 1
    var blue: Double = 1
    var white: Double = 0
    var pan: Double = 0.5
    var tilt: Double = 0.5
    var zoom: Double = 0.35
    var gobo: Double = 0
    var channels: [Double] { [dimmer, red, green, blue, white, pan, tilt, zoom, gobo] }
    enum CodingKeys: String, CodingKey { case dimmer, red, green, blue, white, pan, tilt, zoom, gobo }
    init(dimmer: Double = 1, red: Double = 1, green: Double = 1, blue: Double = 1, white: Double = 0, pan: Double = 0.5, tilt: Double = 0.5, zoom: Double = 0.35, gobo: Double = 0) {
        self.dimmer = dimmer; self.red = red; self.green = green; self.blue = blue; self.white = white
        self.pan = pan; self.tilt = tilt; self.zoom = zoom; self.gobo = gobo
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dimmer = try c.decode(Double.self, forKey: .dimmer); red = try c.decode(Double.self, forKey: .red)
        green = try c.decode(Double.self, forKey: .green); blue = try c.decode(Double.self, forKey: .blue); white = try c.decode(Double.self, forKey: .white)
        pan = try c.decodeIfPresent(Double.self, forKey: .pan) ?? 0.5; tilt = try c.decodeIfPresent(Double.self, forKey: .tilt) ?? 0.5
        zoom = try c.decodeIfPresent(Double.self, forKey: .zoom) ?? 0.35; gobo = try c.decodeIfPresent(Double.self, forKey: .gobo) ?? 0
    }
    static let off = FixtureState(dimmer: 0)
    func blended(to other: Self, fraction: Double) -> Self {
        let t = min(1, max(0, fraction))
        func mix(_ a: Double, _ b: Double) -> Double { t >= 1 ? b : a + (b - a) * t }
        return Self(dimmer: mix(dimmer, other.dimmer), red: mix(red, other.red), green: mix(green, other.green), blue: mix(blue, other.blue), white: mix(white, other.white), pan: mix(pan, other.pan), tilt: mix(tilt, other.tilt), zoom: mix(zoom, other.zoom), gobo: t >= 1 ? other.gobo : gobo)
    }
}
struct FixtureGroup: Identifiable, Codable {
    var id = UUID()
    var name: String
    var fixtureIDs: Set<UUID>
}
struct Cue: Identifiable, Codable {
    var id = UUID()
    var name: String
    var fadeSeconds: Double = 1
    var levels: [UUID: FixtureState]
    var holdSeconds: Double? = nil
    var sequenceHold: Double { holdSeconds ?? 3 }
}
enum SequenceDirection: String, Codable, CaseIterable, Identifiable {
    case forward, reverse, pingPong
    var id: String { rawValue }
    var title: String { switch self { case .forward: return "Forward"; case .reverse: return "Reverse"; case .pingPong: return "Ping-pong" } }
}
struct SequenceSettings: Codable {
    var direction: SequenceDirection = .forward
    var repeats = false
}
enum EffectKind: String, Codable, CaseIterable, Identifiable {
    case sine, chase, rainbow, circle
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
struct Effect: Identifiable, Codable {
    var id = UUID()
    var name: String
    var kind: EffectKind
    var rate: Double = 0.5
    var depth: Double = 0.75
    var enabled: Bool = false
    var beatTiming: Bool? = nil
    var beatsPerCycle: Double? = nil
    var cycleBeats: Double { beatsPerCycle ?? 4 }
    var validTiming: Bool { cycleBeats.isFinite && [0.25, 0.5, 1, 2, 4, 8, 16].contains(cycleBeats) }
}
struct ShowProject: Codable {
    var schemaVersion: Int = 1
    var fixtures: [Fixture] = []
    var cues: [Cue] = []
    var effects: [Effect] = [Effect(name: "Intensity wave", kind: .sine), Effect(name: "Chase", kind: .chase), Effect(name: "Color wheel", kind: .rainbow), Effect(name: "Pan / Tilt orbit", kind: .circle)]
    // Display universe 1 maps to Art-Net port-address 0.
    var universe: Int = 1
    var destination: String = "127.0.0.1"
    var sequenceSettings: SequenceSettings? = nil
    var fixtureGroups: [FixtureGroup]? = nil
    var presets: [LookPreset]? = nil
    var layerCues: [LayerCue]? = nil
    var fixtureProfiles: [FixtureProfile]? = nil
    var liveBoard: LiveBoard? = nil
    var tempo: TempoSettings? = nil
    static var demo: Self {
        var project = Self()
        project.fixtures = (0..<6).map { Fixture(name: "Wash \($0 + 1)", kind: .rgb, address: $0 * 3 + 1, x: 0.12 + Double($0) * 0.15, y: 0.5) }
        let warm = Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id, FixtureState(dimmer: 0.8, red: 1, green: 0.4, blue: 0.12)) })
        let cool = Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id, FixtureState(dimmer: 0.7, red: 0.15, green: 0.4, blue: 1)) })
        project.cues = [Cue(name: "Warm opening", levels: warm), Cue(name: "Blue scene", fadeSeconds: 2, levels: cool)]
        return project
    }
    func validate() throws {
        func fail(_ message: String) throws { throw ProjectError.invalid(message) }
        guard schemaVersion == 1 else { try fail("This show uses an unsupported file version."); return }
        guard (1...32768).contains(universe) else { try fail("Universe must be between 1 and 32768."); return }
        guard !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { try fail("Enter an output destination."); return }
        guard Set(fixtures.map(\.id)).count == fixtures.count, Set(cues.map(\.id)).count == cues.count, Set(effects.map(\.id)).count == effects.count else { try fail("Duplicate identifiers in the project."); return }
        let profiles = fixtureProfiles ?? []
        guard Set(profiles.map(\.id)).count == profiles.count, Set(profiles.map(\.id)).isDisjoint(with: Set(FixtureProfile.library.map(\.id))) else { try fail("Duplicate or reserved profile identifiers."); return }
        for profile in profiles { try profile.validate() }
        try liveBoard?.validate()
        guard (tempo ?? TempoSettings()).valid else { try fail("BPM must be between 30 and 300."); return }
        var occupied = Set<Int>()
        let fixtureIDs = Set(fixtures.map(\.id))
        let groups = fixtureGroups ?? []
        guard Set(groups.map(\.id)).count == groups.count else { try fail("Duplicate fixture group identifiers."); return }
        for group in groups {
            guard !group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, group.fixtureIDs.isSubset(of: fixtureIDs) else { try fail("Invalid fixture group name or members."); return }
        }
        for fixture in fixtures {
            guard fixture.address >= 1, fixture.address <= 513 - fixture.footprint else { try fail("\(fixture.name) extends outside DMX channels 1–512."); return }
            try fixture.resolvedProfile.validate()
            guard fixture.height.isFinite, (0.1...30).contains(fixture.height) else { try fail("Mounting height must be between 0.1 and 30 metres."); return }
            guard fixture.rotation.isFinite, (-180...180).contains(fixture.rotation) else { try fail("Mounting rotation must be between -180 and 180 degrees."); return }
            guard fixture.x.isFinite, fixture.y.isFinite else { try fail("Invalid fixture position."); return }
            for channel in fixture.address..<(fixture.address + fixture.footprint) {
                guard occupied.insert(channel).inserted else { try fail("\(fixture.name) overlaps DMX channel \(channel)."); return }
            }
        }
        for cue in cues {
            guard cue.fadeSeconds.isFinite, (0...3600).contains(cue.fadeSeconds) else { try fail("Invalid cue fade time."); return }
            guard cue.sequenceHold.isFinite, (0.05...3600).contains(cue.sequenceHold) else { try fail("Cue hold time must be between 0.05 and 3600 seconds."); return }
            for state in cue.levels.values {
                guard state.channels.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { try fail("Cue levels must be between 0 and 1."); return }
            }
        }
        let presets = presets ?? []
        let layers = layerCues ?? []
        guard Set(presets.map(\.id)).count == presets.count, Set(layers.map(\.id)).count == layers.count else { try fail("Duplicate preset or layer identifiers."); return }
        for preset in presets {
            guard !preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !preset.values.isEmpty, Set(preset.values.keys).isSubset(of: fixtureIDs) else { try fail("Invalid preset name or fixtures."); return }
            for values in preset.values.values {
                guard values.channels.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { try fail("Invalid preset levels."); return }
            }
            for effect in preset.effects ?? [] {
                guard effect.validTiming, effect.rate.isFinite, (0...20).contains(effect.rate), effect.depth.isFinite, (0...1).contains(effect.depth) else { try fail("Invalid preset effect."); return }
            }
        }
        for layer in layers {
            guard !layer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !layer.presetIDs.isEmpty, Set(layer.presetIDs).count == layer.presetIDs.count, Set(layer.presetIDs).isSubset(of: Set(presets.map(\.id))), (0...100).contains(layer.priority), layer.fadeSeconds.isFinite, (0...3600).contains(layer.fadeSeconds) else { try fail("Invalid layered cue or preset references."); return }
        }
        for effect in effects {
            guard effect.validTiming, effect.rate.isFinite, (0...20).contains(effect.rate), effect.depth.isFinite, (0...1).contains(effect.depth) else { try fail("Invalid effect settings."); return }
        }
    }
}
enum ProjectError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): return message } }
}
