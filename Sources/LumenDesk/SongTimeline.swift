import Foundation

struct SongCueEvent: Identifiable, Codable {
    var id = UUID()
    var time: Double
    var cueID: UUID
    var choreography: SongChoreography? = nil
}
struct SongMarker: Identifiable, Codable {
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
