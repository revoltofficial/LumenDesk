import XCTest
@testable import LumenDesk
final class SongTimelineTests: XCTestCase {
    func testFadesInterruptedEventsAndBackwardSeekAreTimeBased() {
        let id = UUID()
        let red = Cue(name:"Red",fadeSeconds:2,levels:[id:FixtureState(dimmer:1,red:1,green:0,blue:0)])
        let blue = Cue(name:"Blue",fadeSeconds:2,levels:[id:FixtureState(dimmer:1,red:0,green:0,blue:1)])
        var timeline = SongTimeline(); timeline.events = [SongCueEvent(time:0,cueID:red.id),SongCueEvent(time:1,cueID:blue.id)]
        func sample(_ time:Double) -> FixtureState { SongTimelineRenderer.levels(timeline:timeline,cues:[red,blue],fixtureIDs:[id],position:time)[id]! }
        XCTAssertEqual(sample(0).dimmer,0)
        XCTAssertEqual(sample(1).dimmer,0.5,accuracy:0.000001)
        XCTAssertEqual(sample(2).dimmer,0.75,accuracy:0.000001)
        XCTAssertEqual(sample(2).red,0.5,accuracy:0.000001)
        XCTAssertEqual(sample(3).blue,1)
        let backwards = sample(0.5)
        XCTAssertEqual(backwards.dimmer,0.25,accuracy:0.000001)
        XCTAssertEqual(sample(0.5),backwards)
    }
    func testTimelinePersistenceAndValidation() throws {
        var show = ShowProject.demo
        var timeline = SongTimeline(); timeline.audioName = "Local song.wav"; timeline.duration = 30; timeline.waveform = [0,0.5,1]
        timeline.events = [SongCueEvent(time:2,cueID:show.cues[0].id)]
        timeline.markers = [SongMarker(time:10,name:"Break")]; show.songTimeline = timeline
        let copy = try JSONDecoder().decode(ShowProject.self,from:JSONEncoder().encode(show)); try copy.validate()
        XCTAssertEqual(copy.songTimeline?.audioName,"Local song.wav"); XCTAssertEqual(copy.songTimeline?.events[0].time,2)
        XCTAssertNil(try JSONDecoder().decode(ShowProject.self,from:JSONEncoder().encode(ShowProject.demo)).songTimeline)
        show.songTimeline?.events.append(SongCueEvent(time:2,cueID:show.cues[1].id)); XCTAssertThrowsError(try show.validate())
        show.songTimeline?.events = [SongCueEvent(time:31,cueID:show.cues[0].id)]; XCTAssertThrowsError(try show.validate())
        show.songTimeline?.events = [SongCueEvent(time:2,cueID:UUID())]; XCTAssertThrowsError(try show.validate())
        show.songTimeline?.events = []; show.songTimeline?.waveform = [.nan]; XCTAssertThrowsError(try show.validate())
    }
    @MainActor func testScrubbingPauseStopAndManualTakeover() {
        var now = 0.0
        let store = LightingStore(startTimer:false,clock:{now})
        var timeline = SongTimeline(); timeline.events = [SongCueEvent(time:0,cueID:store.project.cues[0].id),SongCueEvent(time:8,cueID:store.project.cues[1].id)]
        store.project.songTimeline = timeline; store.seekSong(10)
        let id = store.project.fixtures[0].id
        XCTAssertEqual(store.timelinePosition,10); XCTAssertEqual(store.tempoClock.beats,20)
        XCTAssertEqual(store.state(for:id).blue,1)
        store.pauseSong(); now = 12; store.tick()
        XCTAssertEqual(store.timelinePosition,10); XCTAssertEqual(store.tempoClock.beats,20)
        store.seekSong(0.5); XCTAssertEqual(store.state(for:id).dimmer,0.4,accuracy:0.000001)
        store.setState(id:id,state:FixtureState(dimmer:0.2))
        XCTAssertFalse(store.timelineControlsLighting)
        store.seekSong(10); store.stop(); XCTAssertFalse(store.timelineControlsLighting); XCTAssertEqual(store.timelinePosition,0)
        XCTAssertEqual(store.renderedState(for:id).dimmer,0)
    }
    @MainActor func testCueEditingDeletionAndLaserRemainManual() throws {
        let store = LightingStore(startTimer:false,clock:{0})
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        store.project = try JSONDecoder().decode(ShowProject.self,from:Data(contentsOf:root.appendingPathComponent("Examples/AYRA-NGEAR-rig.lumendesk.json")))
        let laserID = store.project.fixtures[4].id
        var laser = FixtureState(); laser.laserDMX = [200,100,0,0,128,128,128,12,0]; store.fixtureStates[laserID] = laser
        let before = Array(store.frame[63..<72])
        store.addSongCue(store.project.cues[0].id); store.addSongCue(store.project.cues[1].id)
        XCTAssertEqual(store.songTimeline.events.count,2); XCTAssertNotEqual(store.songTimeline.events[0].time,store.songTimeline.events[1].time)
        let eventID = store.songTimeline.events[0].id
        store.moveSongCue(eventID,time:5); XCTAssertEqual(store.songTimeline.events[0].time,5)
        store.seekSong(8); XCTAssertEqual(Array(store.frame[63..<72]),before)
        store.addSongMarker("Drop"); XCTAssertEqual(store.songTimeline.markers[0].time,8)
        let cueID = store.project.cues[0].id; store.removeCue(id:cueID)
        XCTAssertTrue(store.songTimeline.events.allSatisfy {$0.cueID != cueID}); try store.project.validate()
        store.stop(); XCTAssertEqual(Array(store.frame[63..<72]),[UInt8](repeating:0,count:9))
    }
    func testRehearsalAudioCanBeDecodedWithBoundedWaveform() throws {
        let url = try SongAudioReader.demo(duration:0.2)
        defer { try? FileManager.default.removeItem(at:url) }
        let audio = try SongAudioReader.read(url)
        XCTAssertEqual(audio.duration,0.2,accuracy:0.001)
        XCTAssertLessThanOrEqual(audio.waveform.count,1200)
        XCTAssertTrue(audio.waveform.allSatisfy {$0.isFinite && (0...1).contains($0)})
        XCTAssertGreaterThan(audio.waveform.max() ?? 0,0.9)
    }
    @MainActor func testSongResetInvalidatesImportAndDoesNotEnableOutput() {
        let store = LightingStore(startTimer:false)
        let previous = store.songImportID
        store.importingSong = true; store.timelinePlaying = true; store.timelineControlsLighting = true
        store.resetSong()
        XCTAssertNotEqual(previous,store.songImportID); XCTAssertFalse(store.timelinePlaying); XCTAssertFalse(store.importingSong)
        XCTAssertNil(store.songPlayer); XCTAssertFalse(store.outputEnabled)
        store.playSong(); XCTAssertNotNil(store.errorMessage); XCTAssertFalse(store.outputEnabled)
    }
}
