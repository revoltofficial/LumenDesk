import Foundation

struct SongCueEvent: Identifiable, Codable {
    var id = UUID()
    var time: Double
    var cueID: UUID
    var choreography: SongChoreography? = nil
}
struct SongMarker: Identifiable, Codable, Equatable {
    var id = UUID()
    var time: Double
    var name: String
}
struct SongTimeline: Codable {
    var audioName: String? = nil
    var beatOffset: Double? = nil
    var showStyle: SongShowStyle? = nil
    var buildFlashes: Bool? = nil
    var duration: Double = 180
    var waveform: [Double] = []
    var events: [SongCueEvent] = []
    var markers: [SongMarker] = []
    func validate(cueIDs: Set<UUID>) throws {
        func fail(_ text: String) throws { throw ProjectError.invalid(text) }
        guard duration.isFinite, (0.05...7200).contains(duration), waveform.count <= 1200, waveform.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { try fail("Invalid song duration or waveform."); return }
        guard (beatOffset ?? 0).isFinite, (0...10).contains(beatOffset ?? 0) else { try fail("Invalid beat offset."); return }
        guard events.count <= 1000, Set(events.map(\.id)).count == events.count, Set(events.map(\.time)).count == events.count else { try fail("Cue events must have unique times and identifiers (up to 1000)."); return }
        guard events.allSatisfy({ $0.time.isFinite && (0...duration).contains($0.time) && cueIDs.contains($0.cueID) && ($0.choreography?.valid ?? true) }) else { try fail("Timeline cue is missing or outside the song."); return }
        guard markers.count <= 256, Set(markers.map(\.id)).count == markers.count, markers.allSatisfy({ $0.time.isFinite && (0...duration).contains($0.time) && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { try fail("Invalid song marker."); return }
    }
}
enum SongTimelineRenderer {
    static func levels(timeline: SongTimeline, cues: [Cue], fixtureIDs: [UUID], position: Double) -> [UUID: FixtureState] {
        guard position.isFinite else { return [:] }
        let lookup = Dictionary(cues.map { ($0.id,$0) },uniquingKeysWith: { a,_ in a })
        let off = Dictionary(uniqueKeysWithValues: fixtureIDs.map { ($0,FixtureState.off) })
        var from = off, target = off, start = 0.0, fade = 0.0
        func sample(_ time: Double) -> [UUID: FixtureState] {
            let fraction = fade <= 0 ? 1 : min(1,max(0,(time-start)/fade))
            return Dictionary(uniqueKeysWithValues: fixtureIDs.map { ($0,(from[$0] ?? .off).blended(to:target[$0] ?? .off,fraction:fraction)) })
        }
        for event in timeline.events.sorted(by: { $0.time < $1.time }) where event.time <= position {
            guard let cue = lookup[event.cueID] else { continue }
            from = sample(event.time); target = cue.levels; start = event.time; fade = cue.fadeSeconds
        }
        return sample(position)
    }
}

/// Fade history is compiled once after edits; playback samples one segment.
struct PreparedSongTimeline {
    struct Segment {
        var event: SongCueEvent
        var from: [UUID:FixtureState]
        var target: [UUID:FixtureState]
        var fade: Double
    }
    var segments: [Segment] = []
    var fixtureIDs: [UUID]
    var duration: Double
    init(timeline: SongTimeline,cues: [Cue],fixtureIDs: [UUID]) {
        self.fixtureIDs = fixtureIDs; duration = timeline.duration
        let lookup = Dictionary(cues.map { ($0.id,$0) },uniquingKeysWith:{a,_ in a})
        var previous = Dictionary(uniqueKeysWithValues:fixtureIDs.map { ($0,FixtureState.off) })
        for event in timeline.events.sorted(by:{$0.time < $1.time}) {
            guard let cue = lookup[event.cueID] else { continue }
            if let last = segments.last {
                previous = Self.sample(last,at:event.time,fixtureIDs:fixtureIDs)
            }
            segments.append(Segment(event:event,from:previous,target:cue.levels,fade:cue.fadeSeconds))
        }
    }
    func index(at position: Double) -> Int? {
        guard position.isFinite else { return nil }
        var low = 0, high = segments.count
        while low < high {
            let mid = (low+high)/2
            if segments[mid].event.time <= position { low = mid+1 } else { high = mid }
        }
        return low > 0 ? low-1 : nil
    }
    func levels(at position: Double) -> [UUID:FixtureState] {
        guard let index = index(at:position) else { return Dictionary(uniqueKeysWithValues:fixtureIDs.map { ($0,FixtureState.off) }) }
        return Self.sample(segments[index],at:position,fixtureIDs:fixtureIDs)
    }
    private static func sample(_ segment: Segment,at position: Double,fixtureIDs: [UUID]) -> [UUID:FixtureState] {
        let fraction = segment.fade <= 0 ? 1 : min(1,max(0,(position-segment.event.time)/segment.fade))
        return Dictionary(uniqueKeysWithValues:fixtureIDs.map { ($0,(segment.from[$0] ?? .off).blended(to:segment.target[$0] ?? .off,fraction:fraction)) })
    }
}
