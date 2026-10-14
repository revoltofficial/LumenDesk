import XCTest
@testable import LumenDesk

final class SongChoreographyTests: XCTestCase {
    func testZeroStrengthAndSectionStartPreserveCue() {
        let base = FixtureState(dimmer:0.8,red:0.5,green:0.1,blue:0.7,pan:0.4,tilt:0.6)
        var dance = SongChoreography(style:.energetic,strength:0,beatsPerCycle:4)
        XCTAssertEqual(SongChoreographer.render(base:base,choreography:dance,seconds:4,bpm:120,index:0,count:4,moving:true),base)
        dance.strength = 1
        XCTAssertEqual(SongChoreographer.render(base:base,choreography:dance,seconds:0,bpm:120,index:0,count:4,moving:true),base)
    }
    func testSongTimedMotionIsDeterministicBoundedAndSpread() {
        let base = FixtureState()
        let dance = SongChoreography(style:.energetic,strength:1,beatsPerCycle:4)
        let a = SongChoreographer.render(base:base,choreography:dance,seconds:1.25,bpm:120,index:0,count:4,moving:true)
        let b = SongChoreographer.render(base:base,choreography:dance,seconds:1.25,bpm:120,index:1,count:4,moving:true)
        XCTAssertNotEqual(a.pan,b.pan)
        XCTAssertEqual(a,SongChoreographer.render(base:base,choreography:dance,seconds:1.25,bpm:120,index:0,count:4,moving:true))
        XCTAssertTrue((0...1).contains(a.pan)); XCTAssertTrue((0...1).contains(a.tilt)); XCTAssertLessThanOrEqual(a.dimmer,base.dimmer)
        let wash = SongChoreographer.render(base:base,choreography:dance,seconds:1.25,bpm:120,index:0,count:4,moving:false)
        XCTAssertEqual(wash.pan,base.pan); XCTAssertEqual(wash.tilt,base.tilt)
    }
    func testLegacyTimelineAndInvalidDanceValidation() throws {
        let cue = UUID(); var timeline = SongTimeline(); timeline.events = [SongCueEvent(time:0,cueID:cue)]
        let decoded = try JSONDecoder().decode(SongTimeline.self,from:JSONEncoder().encode(timeline))
        XCTAssertNil(decoded.events[0].choreography)
        timeline.events[0].choreography = SongChoreography(strength:.nan)
        XCTAssertThrowsError(try timeline.validate(cueIDs:[cue]))
    }
    @MainActor func testTimelineChoreographyDoesNotAnimateLaser() throws {
        let store = LightingStore(startTimer:false)
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        store.project = try JSONDecoder().decode(ShowProject.self,from:Data(contentsOf:root.appendingPathComponent("Examples/AYRA-NGEAR-rig.lumendesk.json")))
        let laserID = store.project.fixtures[4].id
        var laser = FixtureState(); laser.laserDMX = [200,100,0,0,128,128,128,12,0]; store.fixtureStates[laserID] = laser
        var timeline = SongTimeline(); timeline.events = [SongCueEvent(time:0,cueID:store.project.cues[0].id,choreography:SongChoreography(style:.energetic))]
        store.project.songTimeline = timeline; store.seekSong(4)
        XCTAssertEqual(store.targetState(for:laserID,applyMaster:false),laser)
        store.pauseSong(); let head = store.project.fixtures[0].id
        let held = store.targetState(for:head); store.tick(); XCTAssertEqual(store.targetState(for:head),held)
        store.stop(); XCTAssertEqual(store.renderedState(for:head).dimmer,0)
    }
}
