import Foundation

enum SongDanceStyle: String, Codable, CaseIterable, Identifiable {
    case gentle, flow, energetic, buildup
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
enum SongShowStyle: String, Codable, CaseIterable, Identifiable {
    case disco, techno, ambient
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var palette: [(Double,Double,Double)] {
        switch self {
        case .disco: return [(1,0.05,0.5),(0.05,0.8,1),(1,0.5,0.05),(0.2,1,0.1)]
        case .techno: return [(0.25,0.02,0.65),(0.02,0.15,0.6),(0.6,0.02,0.1)]
        case .ambient: return [(0.2,0.4,0.65),(0.4,0.2,0.6),(0.2,0.6,0.5)]
        }
    }
}
struct SongChoreography: Codable {
    var style: SongDanceStyle = .flow
    var strength: Double = 0.7
    var beatsPerCycle: Double = 8
    var showStyle: SongShowStyle? = nil
    var flashes: Bool? = nil
    var valid: Bool { strength.isFinite && (0...1).contains(strength) && beatsPerCycle.isFinite && (1...64).contains(beatsPerCycle) }
}
enum SongChoreographer {
    static func render(base: FixtureState, choreography: SongChoreography, seconds: Double,
                       bpm: Double, index: Int, count: Int, moving: Bool, beatPosition: Double? = nil, sectionDuration: Double = 8) -> FixtureState {
        guard choreography.valid, seconds.isFinite, seconds >= 0, bpm.isFinite, bpm > 0 else { return base }
        var result = base
        let progress = min(1,max(0,seconds/max(0.1,sectionDuration)))
        let building = choreography.style == .buildup
        let strength = choreography.strength*min(1,seconds/1.0)*(building ? 0.25+0.75*progress : 1)
        let beats = beatPosition ?? seconds*bpm/60
        guard beats.isFinite else { return base }
        let cycles = beats/choreography.beatsPerCycle
        let offset = Double(index)/Double(max(1,count))
        let angle = (cycles+offset)*2*Double.pi
        let amount: Double
        switch choreography.style {
        case .gentle: amount = 0.25
        case .flow: amount = 0.6
        case .energetic: amount = 1
        case .buildup: amount = 0.4+0.6*progress
        }
        if moving {
            result.pan = min(1,max(0,base.pan+sin(angle)*0.16*amount*strength))
            result.tilt = min(1,max(0,base.tilt+sin(angle*2)*0.1*amount*strength))
        }
        if choreography.style != .gentle {
            let hue = cycles*0.25+offset
            let palette = (choreography.showStyle ?? .disco).palette
            let phase = (hue-floor(hue))*Double(palette.count)
            let a = palette[Int(floor(phase))%palette.count], b = palette[(Int(floor(phase))+1)%palette.count]
            let f = phase-floor(phase)
            let color = EffectColor(red:a.0+(b.0-a.0)*f,green:a.1+(b.1-a.1)*f,blue:a.2+(b.2-a.2)*f)
            let mix = strength*(choreography.style == .energetic ? 0.8 : 0.35)
            result.red = base.red*(1-mix)+color.red*mix
            result.green = base.green*(1-mix)+color.green*mix
            result.blue = base.blue*(1-mix)+color.blue*mix
            result.white *= 1-mix
        }
        if choreography.style == .energetic {
            let beat = beats
            let pulse = 0.75+0.25*(0.5+0.5*cos(beat*2*Double.pi+offset*Double.pi))
            result.dimmer *= 1-strength+strength*pulse
        }
        if building {
            result.dimmer *= 0.45+0.55*progress
            if choreography.flashes == true, progress >= 0.65 {
                // Brief pre-drop dimmer accents; frequency capped independently of BPM.
                let frequency = min(6,max(1,bpm/60*(progress > 0.85 ? 2 : 1)))
                let phase = (seconds*frequency).truncatingRemainder(dividingBy:1)
                result.dimmer *= phase < 0.3 ? 1 : 1-0.65*strength
            }
        }
        return result
    }
}
