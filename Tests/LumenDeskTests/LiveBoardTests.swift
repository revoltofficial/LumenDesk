import XCTest
@testable import LumenDesk
final class LiveBoardTests: XCTestCase {
    func testHardwareDraftMappingsAvoidNgearStrobeRange() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func load(_ name: String) throws -> FixtureProfile { try JSONDecoder().decode(FixtureProfile.self, from: Data(contentsOf: root.appendingPathComponent(name))) }
        let wash = try load("NGEAR-Move-Wash-7-9ch-profile.json")
        let ayra = try load("Ayra-ERO-Micro-Beam-9ch-profile.json")
        try wash.validate(); try ayra.validate()
        XCTAssertEqual(wash.bytes(for: FixtureState(dimmer: 1, red: 1, green: 0, blue: 0, white: 1, pan: 0, tilt: 1)), [0,255,134,255,0,0,255,0,0])
        XCTAssertEqual(wash.bytes(for: FixtureState(dimmer: 0))[2], 0)
        XCTAssertEqual(ayra.bytes(for: FixtureState(dimmer: 1, pan: 0, tilt: 1)), [255,0,0,255,255,255,255,255,0])
        XCTAssertFalse(ayra.supports(.zoom)); XCTAssertFalse(wash.supports(.gobo))
        XCTAssertEqual(ayra.minimumBeamDegrees, ayra.maximumBeamDegrees)
    }

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
