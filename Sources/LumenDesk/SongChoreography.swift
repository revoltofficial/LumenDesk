import Foundation

enum SongDanceStyle: String, Codable, CaseIterable, Identifiable {
    case gentle, flow, energetic
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
struct SongChoreography: Codable {
    var style: SongDanceStyle = .flow
    var strength: Double = 0.7
    var beatsPerCycle: Double = 8
    var valid: Bool { strength.isFinite && (0...1).contains(strength) && beatsPerCycle.isFinite && (1...64).contains(beatsPerCycle) }
}
enum SongChoreographer {
    static func render(base: FixtureState, choreography: SongChoreography, seconds: Double,
                       bpm: Double, index: Int, count: Int, moving: Bool) -> FixtureState {
        guard choreography.valid, seconds.isFinite, seconds >= 0, bpm.isFinite, bpm > 0 else { return base }
        var result = base
        let strength = choreography.strength*min(1,seconds/1.0)
        let cycles = seconds*bpm/60/choreography.beatsPerCycle
        let offset = Double(index)/Double(max(1,count))
        let angle = (cycles+offset)*2*Double.pi
        let amount: Double
        switch choreography.style {
        case .gentle: amount = 0.25
        case .flow: amount = 0.6
        case .energetic: amount = 1
        }
        if moving {
            result.pan = min(1,max(0,base.pan+sin(angle)*0.16*amount*strength))
            result.tilt = min(1,max(0,base.tilt+sin(angle*2)*0.1*amount*strength))
        }
        if choreography.style != .gentle {
            let hue = cycles*0.25+offset
            let color = EffectColor.hue(hue-floor(hue))
            let mix = strength*(choreography.style == .energetic ? 0.8 : 0.35)
            result.red = base.red*(1-mix)+color.red*mix
            result.green = base.green*(1-mix)+color.green*mix
            result.blue = base.blue*(1-mix)+color.blue*mix
            result.white *= 1-mix
        }
        if choreography.style == .energetic {
            let beat = seconds*bpm/60
            let pulse = 0.75+0.25*(0.5+0.5*cos(beat*2*Double.pi+offset*Double.pi))
            result.dimmer *= 1-strength+strength*pulse
        }
        return result
    }
}
