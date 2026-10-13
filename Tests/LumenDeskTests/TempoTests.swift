import XCTest
@testable import LumenDesk
final class TempoTests: XCTestCase {
    func testTapAverageAndGapReset() {
        var clock = TempoClock()
        XCTAssertNil(clock.tap(at: 0))
        XCTAssertEqual(clock.tap(at: 0.5)!, 120, accuracy: 0.001)
        XCTAssertNil(clock.tap(at: 0.55))
        XCTAssertEqual(clock.tap(at: 1)!, 120, accuracy: 0.001)
        XCTAssertNil(clock.tap(at: 5))
        XCTAssertEqual(clock.tap(at: 6)!, 60, accuracy: 0.001)
    }
    @MainActor func testTempoChangePreservesBeatAndSyncResets() {
        var now = 0.0
        let store = LightingStore(startTimer: false, clock: { now })
        now = 1; store.tick()
        XCTAssertEqual(store.tempoClock.beats, 2, accuracy: 0.001)
        store.setBPM(60)
        now = 2; store.tick()
        XCTAssertEqual(store.tempoClock.beats, 3, accuracy: 0.001)
        store.syncTempo()
        XCTAssertEqual(store.tempoClock.beats, 0); XCTAssertEqual(store.phase, 0)
        now = 2.5; store.tick()
        XCTAssertEqual(store.tempoClock.beats, 0.5, accuracy: 0.001)
        store.setBPM(0); XCTAssertEqual(store.bpm, 60)
    }
    @MainActor func testBeatEffectCompletesCycleAndChaseVisitsEveryFixture() {
        var now = 0.0
        let store = LightingStore(startTimer: false, clock: { now })
        let ids = store.project.fixtures.map(\.id)
        for id in ids { store.fixtureStates[id] = FixtureState() }
        var effect = Effect(name: "Beat", kind: .sine)
        effect.enabled = true; effect.depth = 1; effect.beatTiming = true; effect.beatsPerCycle = 4
        store.project.effects = [effect]
        XCTAssertEqual(store.renderedState(for: ids[0]).dimmer, 0.5, accuracy: 0.001)
        now = 0.5; store.tick()
        XCTAssertEqual(store.renderedState(for: ids[0]).dimmer, 1, accuracy: 0.001)
        now = 2; store.tick()
        XCTAssertEqual(store.renderedState(for: ids[0]).dimmer, 0.5, accuracy: 0.001)
        store.project.effects[0].kind = .chase; store.syncTempo()
        for index in ids.indices {
            now = 2 + 2 * (Double(index) + 0.1) / Double(ids.count); store.tick()
            for (i, id) in ids.enumerated() { XCTAssertEqual(store.renderedState(for: id).dimmer, i == index ? 1 : 0) }
        }
    }
    func testSavedTempoAndLegacyDefaults() throws {
        var show = ShowProject.demo
        show.tempo = TempoSettings(bpm: 96)
        show.effects[0].beatTiming = true; show.effects[0].beatsPerCycle = 2
        let data = try JSONEncoder().encode(show)
        let copy = try JSONDecoder().decode(ShowProject.self, from: data)
        XCTAssertEqual(copy.tempo?.bpm, 96); XCTAssertEqual(copy.effects[0].cycleBeats, 2)
        show.tempo = nil; show.effects[0].beatTiming = nil; show.effects[0].beatsPerCycle = nil
        let legacy = try JSONDecoder().decode(ShowProject.self, from: JSONEncoder().encode(show))
        XCTAssertNil(legacy.tempo); XCTAssertNil(legacy.effects[0].beatTiming); XCTAssertEqual(legacy.effects[0].cycleBeats, 4)
        show.tempo = TempoSettings(bpm: 301); XCTAssertThrowsError(try show.validate())
        show.tempo = nil; show.effects[0].beatsPerCycle = 3; XCTAssertThrowsError(try show.validate())
    }
    @MainActor func testBoardTempoActions() {
        var now = 10.0
        let store = LightingStore(startTimer: false, clock: { now })
        var button = BoardControl(); button.action = .tapTempo
        store.boardPress(button); now = 11; store.boardPress(button)
        XCTAssertEqual(store.bpm, 60)
        now = 12; store.tick(); XCTAssertEqual(store.tempoClock.beats, 1)
        button.action = .syncTempo; store.boardPress(button)
        XCTAssertEqual(store.tempoClock.beats, 0)
    }
}
