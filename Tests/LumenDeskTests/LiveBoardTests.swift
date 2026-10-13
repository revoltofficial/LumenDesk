import XCTest
@testable import LumenDesk
final class LiveBoardTests: XCTestCase {
    func testLayoutRoundTripAndBounds() throws {
        var show = ShowProject.demo
        var control = BoardControl(); control.label = "Movement"; control.action = .text; control.width = 3
        show.liveBoard = LiveBoard(controls: [control])
        try show.validate()
        let copy = try JSONDecoder().decode(ShowProject.self, from: JSONEncoder().encode(show))
        XCTAssertEqual(copy.liveBoard?.controls.first?.label, "Movement")
        show.liveBoard?.controls[0].column = 11
        XCTAssertThrowsError(try show.validate())
    }
    @MainActor func testEffectToggleAndMomentaryReleaseDoNotChangeOtherEffects() {
        let store = LightingStore()
        var control = BoardControl(); control.action = .effect; control.targetID = store.project.effects[0].id; control.behavior = .toggle
        store.boardPress(control); XCTAssertTrue(store.project.effects[0].enabled)
        store.boardPress(control); XCTAssertFalse(store.project.effects[0].enabled)
        control.behavior = .momentary
        store.boardPress(control); XCTAssertTrue(store.project.effects[0].enabled)
        store.boardRelease(control); XCTAssertFalse(store.project.effects[0].enabled)
        XCTAssertFalse(store.project.effects[1].enabled)
    }
    @MainActor func testMissingTargetIsInertAndBlackoutPreservesPosition() {
        let store = LightingStore()
        var control = BoardControl()
        XCTAssertFalse(store.boardActive(control))
        control.action = .effect; control.targetID = UUID(); store.boardPress(control)
        XCTAssertTrue(store.project.effects.allSatisfy { !$0.enabled })
        let id = store.project.fixtures[0].id
        let pan = store.renderedState(for: id).pan
        control.action = .blackout; store.boardPress(control)
        XCTAssertTrue(store.blackout); XCTAssertEqual(store.renderedState(for: id).pan, pan)
    }
    func testMomentarySceneIsRejected() {
        var control = BoardControl(); control.behavior = .momentary
        XCTAssertThrowsError(try LiveBoard(controls: [control]).validate())
    }
}
