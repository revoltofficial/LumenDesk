import XCTest
@testable import LumenDesk

final class SongPerformanceTests: XCTestCase {
    func testCompiledTimelineMatchesFadeHistoryAcrossSeeks() {
        let id = UUID()
        let cues = [Cue(name:"A",fadeSeconds:4,levels:[id:FixtureState(dimmer:0.8,red:1,green:0,blue:0)]),Cue(name:"B",fadeSeconds:3,levels:[id:FixtureState(dimmer:0.6,red:0,green:0,blue:1)])]
        var timeline = SongTimeline(); timeline.events = (0..<100).map { SongCueEvent(time:Double($0)*2,cueID:cues[$0%2].id) }; timeline.duration = 250
        let prepared = PreparedSongTimeline(timeline:timeline,cues:cues,fixtureIDs:[id])
        for time in [0.0,1,2,3,7.5,150,199,201,0.5] {
            XCTAssertEqual(prepared.levels(at:time),SongTimelineRenderer.levels(timeline:timeline,cues:cues,fixtureIDs:[id],position:time))
        }
        XCTAssertNil(prepared.index(at:-1)); XCTAssertNil(prepared.index(at:.nan))
    }
    @MainActor func testPlaybackBatchesNotificationsAndInvalidatesAfterEdits() {
        let store = LightingStore(startTimer:false,clock:{1})
        var timeline = SongTimeline(); timeline.events = [SongCueEvent(time:0,cueID:store.project.cues[0].id)]
        store.project.songTimeline = timeline; store.seekSong(2)
        var notifications = 0
        let token = store.objectWillChange.sink { notifications += 1 }
        store.tick()
        XCTAssertEqual(notifications,1)
        let before = store.preparedSong.levels(at:3)
        store.project.cues[0].levels[store.project.fixtures[0].id]?.dimmer = 0.12
        let after = store.preparedSong.levels(at:3)
        XCTAssertNotEqual(before,after)
        withExtendedLifetime(token) {}
    }
    func testCompiledSamplingPerformance() {
        let id = UUID(); let cue = Cue(name:"A",levels:[id:FixtureState()])
        var timeline = SongTimeline(); timeline.duration = 2000; timeline.events = (0..<1000).map { SongCueEvent(time:Double($0),cueID:cue.id) }
        let compiled = PreparedSongTimeline(timeline:timeline,cues:[cue],fixtureIDs:[id])
        measure { for i in 0..<1000 { _ = compiled.levels(at:Double(i)+0.5) } }
    }
}
