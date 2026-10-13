import XCTest
@testable import LumenDesk

final class SequenceTests: XCTestCase {
    private func cues(_ count: Int) -> [Cue] {
        (0..<count).map { Cue(name: "Cue \($0)", fadeSeconds: 1, levels: [:], holdSeconds: 2) }
    }
    func testFadeThenHoldAndFinishRetainsLastCue() throws {
        let cues = cues(2)
        var player = try XCTUnwrap(SequencePlayer(cues: cues, settings: SequenceSettings(), now: 10))
        XCTAssertNil(player.advance(now: 12.99))
        XCTAssertEqual(player.advance(now: 13), cues[1].id)
        XCTAssertNil(player.advance(now: 16))
        XCTAssertTrue(player.finished)
        XCTAssertEqual(player.currentCueID, cues[1].id)
    }
    func testReverseAndPingPongEndpointOrder() throws {
        let cues = cues(3)
        let reverse = try XCTUnwrap(SequencePlayer(cues: cues, settings: SequenceSettings(direction: .reverse), now: 0))
        XCTAssertEqual(reverse.steps.map(\.cueID), cues.reversed().map(\.id))
        let ping = try XCTUnwrap(SequencePlayer(cues: cues, settings: SequenceSettings(direction: .pingPong), now: 0))
        XCTAssertEqual(ping.steps.map(\.cueID), [cues[0].id,cues[1].id,cues[2].id,cues[1].id,cues[0].id])
        var repeating = try XCTUnwrap(SequencePlayer(cues: cues, settings: SequenceSettings(direction: .pingPong, repeats: true), now: 0))
        XCTAssertEqual(repeating.steps.map(\.cueID), [cues[0].id,cues[1].id,cues[2].id,cues[1].id])
        for time in [3.0,6,9,12] { _ = repeating.advance(now: time) }
        XCTAssertEqual(repeating.currentCueID, cues[0].id)
        XCTAssertFalse(repeating.finished)
    }
    func testPauseAndDelayedTickPreserveFullStepDuration() throws {
        let cues = cues(2)
        var player = try XCTUnwrap(SequencePlayer(cues: cues, settings: SequenceSettings(repeats: true), now: 0))
        player.pause(now: 1)
        XCTAssertNil(player.advance(now: 100))
        player.resume(now: 100)
        XCTAssertNil(player.advance(now: 101.99))
        XCTAssertEqual(player.advance(now: 102), cues[1].id)
        XCTAssertEqual(player.advance(now: 500), cues[0].id)
        XCTAssertEqual(player.deadline, 503)
    }
    func testLegacyFilesAndSequenceSettingsRoundTrip() throws {
        var project = ShowProject.demo
        project.sequenceSettings = SequenceSettings(direction: .reverse, repeats: true)
        project.cues[0].holdSeconds = 5
        let data = try JSONEncoder().encode(project)
        let current = try JSONDecoder().decode(ShowProject.self, from: data)
        XCTAssertEqual(current.sequenceSettings?.direction, .reverse)
        XCTAssertEqual(current.cues[0].sequenceHold, 5)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "sequenceSettings")
        var oldCues = try XCTUnwrap(json["cues"] as? [[String: Any]])
        for i in oldCues.indices { oldCues[i].removeValue(forKey: "holdSeconds") }
        json["cues"] = oldCues
        let legacy = try JSONDecoder().decode(ShowProject.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.sequenceSettings)
        XCTAssertEqual(legacy.cues[0].sequenceHold, 3)
        try legacy.validate()
    }
    func testInvalidTimingAndEmptySequences() {
        XCTAssertNil(SequencePlayer(cues: [], settings: SequenceSettings(), now: 0))
        var bad = cues(1)
        bad[0].holdSeconds = .nan
        XCTAssertNil(SequencePlayer(cues: bad, settings: SequenceSettings(), now: 0))
        var project = ShowProject.demo
        project.cues[0].holdSeconds = 0
        XCTAssertThrowsError(try project.validate())
    }
    @MainActor func testStorePauseDuringFadeManualTakeoverAndStop() throws {
        var time = 0.0
        let store = LightingStore(startTimer: false, clock: { time })
        let fixtureID = store.project.fixtures[0].id
        store.setState(id: fixtureID, state: .off)
        store.startSequence()
        time = 0.5; store.tick()
        XCTAssertEqual(store.state(for: fixtureID).dimmer, 0.4, accuracy: 0.001)
        store.toggleSequencePause()
        time = 20; store.tick()
        XCTAssertEqual(store.state(for: fixtureID).dimmer, 0.4, accuracy: 0.001)
        store.toggleSequencePause()
        time = 20.5; store.tick()
        XCTAssertEqual(store.state(for: fixtureID).dimmer, 0.8, accuracy: 0.001)
        time = 23.5; store.tick()
        XCTAssertEqual(store.activeCueID, store.project.cues[1].id)
        store.activateCue(id: store.project.cues[0].id)
        XCTAssertNil(store.sequencePlayer)
        store.startSequence()
        store.stop()
        XCTAssertNil(store.sequencePlayer)
        XCTAssertTrue(store.frame.allSatisfy { $0 == 0 })
        XCTAssertFalse(store.outputEnabled)
    }
}
