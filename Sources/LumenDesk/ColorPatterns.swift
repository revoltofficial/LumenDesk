import SwiftUI

enum ColorPattern: String, Codable, CaseIterable {
    case fade, chase, pingPong, alternating, rainbow, rainbowWave, comet, twinkle, fire, police
    var title: String {
        switch self { case .fade: return "Palette fade"; case .chase: return "Palette chase"; case .pingPong: return "Ping-pong"; case .alternating: return "Alternating pairs"; case .rainbowWave: return "Rainbow wave"; default: return rawValue.capitalized }
    }
}
enum ColorPalette: String, Codable, CaseIterable {
    case disco, techno, sunset, ocean, forest, pastel, ice, warm, police, violet
    var title: String { self == .warm ? "Warm glow" : rawValue.capitalized }
    var colors: [EffectColor] {
        switch self {
        case .disco: return EffectColor.disco
        case .techno: return EffectColor.techno
        case .sunset: return [.rgb(1,0.1,0.05),.rgb(1,0.45,0.05),.rgb(0.8,0.03,0.35)]
        case .ocean: return [.rgb(0,0.1,0.8),.rgb(0,0.65,0.8),.rgb(0.05,1,0.65)]
        case .forest: return [.rgb(0.02,0.18,0.02),.rgb(0.1,0.65,0.05),.rgb(0.55,0.85,0.03)]
        case .pastel: return [.rgb(1,0.4,0.6),.rgb(0.5,0.4,1),.rgb(0.3,0.9,0.8),.rgb(1,0.75,0.35)]
        case .ice: return [.rgb(0.02,0.25,1),.rgb(0.3,0.75,1),.rgb(0.7,0.9,1)]
        case .warm: return [.rgb(1,0.18,0.01),.rgb(1,0.6,0.1),.rgb(1,0.85,0.5)]
        case .police: return [.rgb(1,0,0),.rgb(0,0.08,1)]
        case .violet: return [.rgb(0.1,0.02,0.5),.rgb(0.5,0.03,1),.rgb(0.85,0.05,0.5)]
        }
    }
}
extension EffectColor {
    static func rgb(_ red: Double,_ green: Double,_ blue: Double) -> Self { Self(red:red,green:green,blue:blue) }
    func mixed(to other: Self, fraction: Double) -> Self {
        let t = min(1,max(0,fraction))
        return .rgb(red+(other.red-red)*t,green+(other.green-green)*t,blue+(other.blue-blue)*t)
    }
}
struct ColorPatternFrame { var color: EffectColor; var intensity: Double = 1 }
enum ColorPatternRenderer {
    static func sample(effect: Effect, cycles: Double, index: Int, count: Int) -> ColorPatternFrame {
        let palette = (effect.colors ?? ColorPalette.disco.colors).filter { $0.valid }
        guard !palette.isEmpty, cycles.isFinite, effect.validTiming else { return ColorPatternFrame(color: .rgb(0,0,0),intensity: 0) }
        let clock = (effect.colorReverse == true ? -cycles : cycles) + (effect.colorPhase ?? 0)
        let randomClock = clock.truncatingRemainder(dividingBy: 1024)
        let offset = Double(index)/Double(max(1,count)) * (effect.spread ?? 1)
        let phase = clock+offset, p = phase-floor(phase)
        func wrap(_ value: Int) -> Int { (value % palette.count + palette.count) % palette.count }
        func paletteAt(_ unit: Double, smooth: Double) -> EffectColor {
            let scaled = (unit-floor(unit))*Double(palette.count)
            let slot = Int(floor(scaled)), fraction = scaled-floor(scaled)
            let t = smooth <= 0 ? 0 : min(1,max(0,(fraction-1+smooth)/smooth))
            return palette[wrap(slot)].mixed(to: palette[wrap(slot+1)],fraction: t*t*(3-2*t))
        }
        func random(_ step: Double) -> Double { let value = sin(step*12.9898+Double(index)*78.233)*43758.5453; return value-floor(value) }
        let pattern = effect.colorPattern ?? .fade
        let smoothing = effect.colorSmoothness ?? (pattern == .chase ? 0 : 1)
        switch pattern {
        case .fade, .chase: return ColorPatternFrame(color: paletteAt(phase,smooth: smoothing))
        case .pingPong:
            let travel = (1-abs(2*p-1))*Double(max(0,palette.count-1))
            let slot = Int(floor(travel)), t = travel-floor(travel)
            return ColorPatternFrame(color: palette[slot].mixed(to: palette[min(palette.count-1,slot+1)],fraction: t*t*(3-2*t)))
        case .alternating:
            let slot = Int(floor((clock-floor(clock))*2)) + index
            return ColorPatternFrame(color: palette[wrap(slot)])
        case .rainbow: return ColorPatternFrame(color: EffectColor.hue(p))
        case .rainbowWave: return ColorPatternFrame(color: EffectColor.hue((p+0.15*sin((clock-floor(clock))*2*Double.pi))-floor(p+0.15*sin((clock-floor(clock))*2*Double.pi))).mixed(to: EffectColor.hue(p),fraction: 0.1))
        case .comet:
            let head = (1-abs(2*(clock-floor(clock))-1))*Double(max(0,count-1))
            return ColorPatternFrame(color: paletteAt(phase,smooth: 1),intensity: 0.08+0.92*max(0,1-abs(Double(index)-head)))
        case .twinkle:
            let randomPhase = randomClock+offset
            let step = floor(randomPhase*4), t = randomPhase*4-step
            let glow = pow(sin(t*Double.pi),4)*random(step)
            return ColorPatternFrame(color: palette[wrap(Int(random(step)*Double(palette.count)))].mixed(to: .rgb(1,1,1),fraction: glow*0.75),intensity: 0.25+0.75*glow)
        case .fire:
            let step = floor(randomClock*8), t = randomClock*8-step
            let noise = random(step)*(1-t)+random(step+1)*t
            return ColorPatternFrame(color: paletteAt(noise,smooth: 1),intensity: 0.5+0.5*noise)
        case .police:
            let step = Int(floor((clock-floor(clock))*8))
            return ColorPatternFrame(color: palette[wrap((step/4)+index)],intensity: step.isMultiple(of: 2) ? 1 : 0.05)
        }
    }
    static func preset(_ pattern: ColorPattern) -> Effect {
        var effect = Effect(name:pattern.title,kind:.colorPattern)
        effect.colorPattern = pattern; effect.beatTiming = true; effect.beatsPerCycle = pattern == .police ? 2 : 8
        effect.depth = 1; effect.spread = 0.75; effect.colorSmoothness = pattern == .chase ? 0 : 1
        let palette: ColorPalette = pattern == .fire ? .warm : pattern == .police ? .police : .disco
        effect.colorPalette = palette; effect.colors = palette.colors
        effect.colorIntensity = false
        return effect
    }
}
