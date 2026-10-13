import Foundation

enum MusicStyle: String, Codable, CaseIterable { case auto, disco, techno
    var title: String { rawValue.capitalized }
}
struct AutopilotPreferences: Codable {
    var followTempo = true
    var style = MusicStyle.auto
    var strength = 0.65
    var valid: Bool { strength.isFinite && (0...1).contains(strength) }
}
enum MusicSection: String { case waiting = "Waiting", groove = "Groove", build = "Build", drop = "Drop", musicalBreak = "Break", silence = "Silence" }
struct MusicSnapshot {
    var level = 0.0
    var bass = 0.0
    var brightness = 0.0
    var energy = 0.0
    var bpm: Double? = nil
    var confidence = 0.0
    var beat = false
    var section = MusicSection.waiting
}
struct MusicAnalyzer {
    private var envelopes: [(time: Double, onset: Double)] = []
    private var lastTime: Double? = nil
    private var previous = 0.0
    private var lastOnset = -Double.infinity
    private var tonalBrightness = 0.0
    private var average = 0.0
    private var fast = 0.0
    private var quietSince: Double? = nil
    private var dropUntil = 0.0
    private var lastEstimate = -Double.infinity
    private var estimate: Double? = nil
    private var confidence = 0.0
    mutating func process(level: Double, bass: Double, high: Double, time: Double) -> MusicSnapshot {
        guard [level,bass,high,time].allSatisfy(\.isFinite) else { return MusicSnapshot() }
        let dt = max(0.005,min(0.2,time - (lastTime ?? (time - 0.02)))); lastTime = time
        let rms = max(0,min(1,level))
        fast += (rms-fast) * min(1,dt*5)
        average += (rms-average) * min(1,dt*0.2)
        let onset = max(0,rms-previous); previous = rms
        let beat = onset > max(0.004,average*0.4) && time-lastOnset > 0.25
        if beat { lastOnset = time }
        tonalBrightness += (min(1,max(0,high/max(0.001,rms)))-tonalBrightness)*min(1,dt*0.5)
        // Resample amplitude onsets to 50 Hz so device buffer size cannot bias BPM.
        if let last = envelopes.last, time - last.time < 0.019 {
            envelopes[envelopes.count-1].onset = max(last.onset,onset)
        } else { envelopes.append((time,onset)) }
        envelopes.removeAll { time - $0.time > 12 }
        if time - lastEstimate >= 1 {
            lastEstimate = time
            let result = tempoEstimate()
            estimate = result.bpm; confidence = result.confidence
        }
        let quiet = rms < 0.003 || (average > 0.015 && fast < average*0.55)
        if quiet { if quietSince == nil { quietSince = time } }
        else if let start = quietSince {
            if time-start > 1.5 && fast > max(0.025,average*1.25) { dropUntil = time + 4 }
            // Keep tracking until the energy has actually returned.
            if fast > average*(time-start > 1.5 ? 1.25 : 0.75) { quietSince = nil }
        }
        let section: MusicSection
        if fast < 0.003 { section = .silence }
        else if time < dropUntil { section = .drop }
        else if quietSince != nil { section = .musicalBreak }
        else if average > 0.015 && fast > average*1.5 { section = .build }
        else { section = .groove }
        let energy = min(1,max(0,fast / max(0.025,average*2)))
        return MusicSnapshot(level: rms,bass: min(1,max(0,bass / max(0.001,rms))),brightness: tonalBrightness,energy: energy,bpm: estimate,confidence: confidence,beat: beat,section: section)
    }
    private func tempoEstimate() -> (bpm: Double?, confidence: Double) {
        guard let first = envelopes.first, let last = envelopes.last, last.time-first.time >= 5 else { return (nil,0) }
        let length = min(600,Int((last.time-first.time)*50)+1)
        guard length > 100 else { return (nil,0) }
        var values = [Double](repeating: 0,count: length)
        for e in envelopes { let i = min(length-1,max(0,Int((e.time-first.time)*50))); values[i] = max(values[i],e.onset) }
        var bestScore = 0.0, bestLag = 0
        for lag in 17...50 {
            var cross = 0.0, a = 0.0, b = 0.0
            for i in lag..<length { cross += values[i]*values[i-lag]; a += values[i]*values[i]; b += values[i-lag]*values[i-lag] }
            let correlation = cross / max(0.0000001,sqrt(a*b))
            let candidate = 3000 / Double(lag)
            let prior = estimate ?? 120
            let preference = 1 - min(0.08,abs(log(candidate/prior))*0.08)
            let score = correlation * preference
            if score > bestScore { bestScore = score; bestLag = lag }
        }
        guard bestLag > 0, bestScore > 0.3 else { return (nil,bestScore) }
        return (3000/Double(bestLag),min(1,bestScore))
    }
}
enum AutopilotRole: String, Codable, CaseIterable {
    case beam, wash, manual
    var title: String { switch self { case .beam: return "Beam accents"; case .wash: return "Wash atmosphere"; case .manual: return "Manual only" } }
}
enum DirectorLook: Int, CaseIterable {
    case mirrored, fan, crossing, alternating
    var title: String { switch self { case .mirrored: return "Mirrored sweep"; case .fan: return "Outward fan"; case .crossing: return "Crossed beams"; case .alternating: return "Alternating accents" } }
    static func current(beats: Double) -> Self { allCases[Int(floor(max(0,beats)/32)).quotientAndRemainder(dividingBy: allCases.count).remainder] }
    static func point(_ look: Self,beats: Double,index: Int,quiet: Bool,drop: Bool,role: AutopilotRole) -> MotionPoint {
        let side = index % 2 == 0 ? -1.0 : 1.0
        let duration = role == .wash ? 32.0 : (quiet ? 32 : (drop ? 8 : 16))
        let angle = beats / duration * 2 * Double.pi
        switch look {
        case .mirrored: return MotionPoint(x: side*sin(angle),y: cos(angle)*0.65)
        case .fan: return MotionPoint(x: side*(0.6+0.4*sin(angle)),y: cos(angle)*0.4)
        case .crossing: return MotionPoint(x: -side*(0.6+0.4*sin(angle)),y: sin(angle)*0.5)
        case .alternating: return MotionPoint(x: side*cos(angle),y: sin(angle+Double(index%2)*Double.pi)*0.65)
        }
    }
}
enum AutopilotRenderer {
    static func render(base: FixtureState,snapshot: MusicSnapshot,style: MusicStyle,strength: Double,beats: Double,index: Int,moving: Bool,fresh: Bool,role: AutopilotRole = .beam) -> FixtureState {
        var result = base
        guard role != .manual else { return result }
        guard fresh, snapshot.section != .silence, snapshot.section != .waiting else { result.dimmer = 0; return result }
        let amount = min(1,max(0,strength))
        // Tonal heuristic only; the operator can explicitly choose the musical style.
        let resolved: MusicStyle = style == .auto ? (snapshot.brightness > 0.5 ? .disco : .techno) : style
        let palette = resolved == .disco ? EffectColor.disco : EffectColor.techno
        let safeBeats = max(0,beats)
        let phrase = Int(floor(safeBeats/32)), progress = safeBeats.truncatingRemainder(dividingBy: 32)
        let blend = phrase == 0 ? 1 : min(1,progress/4)
        let look = DirectorLook.current(beats: safeBeats)
        let previous = DirectorLook.current(beats: max(0,safeBeats-32))
        func color(_ phrase: Int) -> EffectColor { palette[(max(0,phrase)+(role == .beam ? index+1 : 0))%palette.count] }
        let c = color(phrase), old = color(phrase-1)
        result.red = base.red*(1-amount)+(old.red+(c.red-old.red)*blend)*amount
        result.green = base.green*(1-amount)+(old.green+(c.green-old.green)*blend)*amount
        result.blue = base.blue*(1-amount)+(old.blue+(c.blue-old.blue)*blend)*amount
        result.white *= 1-amount
        let quiet = snapshot.section == .musicalBreak, drop = snapshot.section == .drop
        let phase = safeBeats-floor(safeBeats)
        let pulse = role == .wash ? 0.95+0.05*max(0,1-phase*3) : 0.65+0.35*max(0,1-phase*3)
        let alternating = look == .alternating && role == .beam ? (Int(floor(safeBeats/2))%2 == index%2 ? 1.0 : 0.35) : 1.0
        let intensity = quiet ? (role == .wash ? 0.28 : 0.16) : (drop ? (role == .wash ? 0.72 : 0.95) : 0.4+snapshot.energy*0.3)
        result.dimmer = base.dimmer*(1-amount)+intensity*pulse*alternating*amount
        if moving {
            let a = DirectorLook.point(previous,beats: safeBeats,index: index,quiet: quiet,drop: drop,role: role)
            let b = DirectorLook.point(look,beats: safeBeats,index: index,quiet: quiet,drop: drop,role: role)
            let travel = amount*(role == .wash ? 0.035 : (quiet ? 0.025 : (drop ? 0.15 : 0.075)))
            result.pan = min(1,max(0,base.pan+(a.x+(b.x-a.x)*blend)*travel))
            result.tilt = min(1,max(0,base.tilt+(a.y+(b.y-a.y)*blend)*travel))
        }
        return result
    }
}
