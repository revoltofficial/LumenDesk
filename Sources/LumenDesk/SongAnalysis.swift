import Foundation

struct SongAnalysis: Sendable {
    var bpm: Double?
    var confidence: Double
    var markers: [SongMarker]
    var beatOffset: Double = 0
}
enum SongAnalyzer {
    // Positive energy changes supply an onset envelope. Tempo is a suggestion,
    // not a claim of genre recognition or a perfectly resolved half/double time.
    static func analyze(energy: [Double], duration: Double) -> SongAnalysis {
        guard duration.isFinite, duration > 2, energy.count > 100,
              energy.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            return SongAnalysis(bpm:nil,confidence:0,markers:[])
        }
        let rate = Double(energy.count)/duration
        let onsets = energy.indices.map { i in max(0,energy[i] - energy[max(0,i-1)]) }
        let power = onsets.reduce(0) { $0+$1*$1 }
        var best = 0.0, tempo = 120.0
        if power > 0.000001 {
            for candidate in 70...180 {
                let lag = max(1,Int((rate*60/Double(candidate)).rounded()))
                guard lag < onsets.count else { continue }
                var score = 0.0, a = 0.0, b = 0.0
                for i in lag..<onsets.count {
                    score += onsets[i]*onsets[i-lag]
                    a += onsets[i]*onsets[i]; b += onsets[i-lag]*onsets[i-lag]
                }
                score /= max(0.000001,sqrt(a*b))
                if score > best { best = score; tempo = rate*60/Double(lag) }
            }
        }
        let bpm: Double? = best >= 0.25 ? tempo : nil
        var beatOffset = 0.0
        if let bpm {
            let period = max(1,Int((rate*60/bpm).rounded()))
            var phases = [Double](repeating:0,count:period)
            for i in onsets.indices { phases[i%period] += onsets[i] }
            if let peak = phases.indices.max(by:{phases[$0] < phases[$1]}) { beatOffset = Double(peak)/rate }
        }
        let phrase = bpm.map { 32*60/$0 } ?? 8
        let window = max(1,Int(rate*2))
        var sections: [(Double,Double)] = []
        for start in stride(from:0,to:energy.count,by:window) {
            let end = min(energy.count,start+window)
            let mean = energy[start..<end].reduce(0,+)/Double(end-start)
            sections.append((Double(start)/rate,mean))
        }
        let maximum = max(0.000001,sections.map { $0.1 }.max() ?? 0)
        var markers = [SongMarker(time:0,name:"Intro")]
        var previous = sections.first?.1 ?? 0
        var lastTime = 0.0
        for section in sections.dropFirst() {
            let rise = section.1 > max(previous*1.2,maximum*0.6)
            let fall = section.1 < previous*0.85 && section.1 < maximum*0.8
            if (rise || fall), section.0-lastTime >= 2, markers.count < 128 {
                // Keep strong energy changes near their measured location;
                // phrase boundaries fill quiet gaps without inventing drops.
                markers.append(SongMarker(time:section.0,name:rise ? "Drop?" : "Break?"))
                lastTime = section.0
            } else if section.0-lastTime >= phrase && markers.count < 128 {
                markers.append(SongMarker(time:section.0,name:"Phrase")); lastTime = section.0
            }
            previous = section.1
        }
        return SongAnalysis(bpm:bpm,confidence:min(1,max(0,best)),markers:markers,beatOffset:beatOffset)
    }
}
