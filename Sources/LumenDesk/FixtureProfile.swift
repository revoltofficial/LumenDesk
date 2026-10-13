import Foundation

enum FixtureAttribute: String, Codable, CaseIterable {
    case dimmer, red, green, blue, white, pan, tilt, zoom, gobo, constant, laser
}
struct ProfileChannel: Codable {
    var attribute: FixtureAttribute
    var offset: Int
    var fineOffset: Int? = nil
    var minimum: Int = 0
    var maximum: Int = 255
    var constant: Int = 0
}
struct GoboSlot: Codable {
    var name: String
    var dmx: Int
    // Original preview patterns; imported fixtures can map slots to these approximations.
    var pattern: String
}
struct FixtureProfile: Identifiable, Codable {
    var id: String
    var name: String
    var footprint: Int
    var channels: [ProfileChannel]
    var panDegrees: Double = 540
    var tiltDegrees: Double = 270
    var minimumBeamDegrees: Double = 8
    var maximumBeamDegrees: Double = 40
    var gobos: [GoboSlot] = []
    var colorUsesDimmer: Bool = false
    var isLaser: Bool { supports(.laser) }
    var movingHead: Bool { supports(.pan) && supports(.tilt) }
    func supports(_ attribute: FixtureAttribute) -> Bool { channels.contains { $0.attribute == attribute } }
    func goboIndex(_ state: FixtureState) -> Int { Int((state.gobo * Double(max(0, gobos.count - 1))).rounded()) }
    func validate() throws {
        func fail(_ message: String) throws { throw ProjectError.invalid("Profile \(name): \(message)") }
        guard !id.isEmpty, !name.isEmpty, (1...512).contains(footprint), !channels.isEmpty else { try fail("invalid identity or footprint."); return }
        guard panDegrees.isFinite, (1...1440).contains(panDegrees), tiltDegrees.isFinite, (1...720).contains(tiltDegrees), minimumBeamDegrees.isFinite, maximumBeamDegrees.isFinite, minimumBeamDegrees >= 1, maximumBeamDegrees <= 120, minimumBeamDegrees <= maximumBeamDegrees else { try fail("invalid movement or beam limits."); return }
        var occupied = Set<Int>(), attributes = Set<String>()
        for channel in channels {
            let limit = channel.fineOffset == nil ? 255 : 65535
            guard (0...limit).contains(channel.minimum), (0...limit).contains(channel.maximum), (0...255).contains(channel.constant) else { try fail("invalid channel range."); return }
            if channel.attribute != .constant && channel.attribute != .laser {
                guard attributes.insert(channel.attribute.rawValue).inserted else { try fail("duplicate attribute."); return }
            }
            if channel.attribute == .gobo && channel.fineOffset != nil { try fail("gobo slots require an 8-bit channel."); return }
            for offset in [channel.offset, channel.fineOffset].compactMap({ $0 }) {
                guard (1...footprint).contains(offset), occupied.insert(offset).inserted else { try fail("overlapping or out-of-range offsets."); return }
            }
        }
        if isLaser {
            guard footprint == 9, channels.count == 9, channels.allSatisfy({ $0.attribute == .laser && $0.fineOffset == nil }) else { try fail("laser profiles require nine direct channels."); return }
        }
        guard supports(.dimmer) || colorUsesDimmer || !channels.contains(where: { [.red, .green, .blue, .white].contains($0.attribute) }) else { try fail("color-only fixtures must use virtual dimming."); return }
        guard gobos.count <= 32, gobos.allSatisfy({ !$0.name.isEmpty && (0...255).contains($0.dmx) && ["open", "dots", "star", "bars"].contains($0.pattern) }) else { try fail("invalid gobo slots."); return }
        guard !supports(.gobo) || !gobos.isEmpty else { try fail("a gobo channel needs named slots."); return }
    }
    func bytes(for state: FixtureState) -> [UInt8] {
        var values = [UInt8](repeating: 0, count: footprint)
        func normalized(_ value: Double) -> Double { min(1, max(0, value.isFinite ? value : 0)) }
        for channel in channels {
            if channel.attribute == .laser {
                let raw = state.laserDMX ?? [UInt8](repeating: 0,count: 9)
                values[channel.offset-1] = state.dimmer > 0 && raw.count == 9 ? raw[channel.offset-1] : 0
                continue
            }
            let value: Double
            switch channel.attribute {
            case .dimmer: value = state.dimmer
            case .red: value = state.red * (colorUsesDimmer ? state.dimmer : 1)
            case .green: value = state.green * (colorUsesDimmer ? state.dimmer : 1)
            case .blue: value = state.blue * (colorUsesDimmer ? state.dimmer : 1)
            case .white: value = state.white * (colorUsesDimmer ? state.dimmer : 1)
            case .pan: value = state.pan
            case .tilt: value = state.tilt
            case .zoom: value = state.zoom
            case .gobo: value = state.gobo
            case .constant, .laser: value = 0
            }
            let encoded: Int
            if channel.attribute == .constant { encoded = channel.constant }
            else if channel.attribute == .gobo, !gobos.isEmpty { encoded = gobos[min(gobos.count - 1, max(0, goboIndex(state)))].dmx }
            else { encoded = Int((Double(channel.minimum) + normalized(value) * Double(channel.maximum - channel.minimum)).rounded()) }
            if let fine = channel.fineOffset {
                values[channel.offset - 1] = UInt8((encoded >> 8) & 255)
                values[fine - 1] = UInt8(encoded & 255)
            } else { values[channel.offset - 1] = UInt8(encoded & 255) }
        }
        return values
    }
    static let dimmer = FixtureProfile(id: "generic.dimmer", name: "Generic Dimmer · 1ch", footprint: 1, channels: [ProfileChannel(attribute: .dimmer, offset: 1)])
    static let rgb = FixtureProfile(id: "generic.rgb", name: "Generic RGB · 3ch", footprint: 3, channels: [ProfileChannel(attribute: .red, offset: 1), ProfileChannel(attribute: .green, offset: 2), ProfileChannel(attribute: .blue, offset: 3)], colorUsesDimmer: true)
    static let rgbw = FixtureProfile(id: "generic.rgbw", name: "Generic RGBW · 4ch", footprint: 4, channels: [ProfileChannel(attribute: .red, offset: 1), ProfileChannel(attribute: .green, offset: 2), ProfileChannel(attribute: .blue, offset: 3), ProfileChannel(attribute: .white, offset: 4)], colorUsesDimmer: true)
    static let head = FixtureProfile(id: "generic.head11", name: "Generic Moving Head · 11ch", footprint: 11, channels: [
        ProfileChannel(attribute: .pan, offset: 1, fineOffset: 2, maximum: 65535),
        ProfileChannel(attribute: .tilt, offset: 3, fineOffset: 4, maximum: 65535),
        ProfileChannel(attribute: .dimmer, offset: 5), ProfileChannel(attribute: .red, offset: 6),
        ProfileChannel(attribute: .green, offset: 7), ProfileChannel(attribute: .blue, offset: 8),
        ProfileChannel(attribute: .zoom, offset: 9), ProfileChannel(attribute: .gobo, offset: 10),
        ProfileChannel(attribute: .constant, offset: 11, constant: 255)
    ], gobos: [GoboSlot(name: "Open", dmx: 0, pattern: "open"), GoboSlot(name: "Dots", dmx: 32, pattern: "dots"), GoboSlot(name: "Star", dmx: 64, pattern: "star"), GoboSlot(name: "Bars", dmx: 96, pattern: "bars")])
    static let library = [dimmer, rgb, rgbw, head]
}
