import XCTest
@testable import LumenDesk
final class LaserPreviewTests: XCTestCase {
    private func laser(mode: UInt8 = 200,pattern: UInt8 = 100) -> FixtureState {
        var state = FixtureState(); state.laserDMX = [mode,pattern,0,0,100,128,255,12,0]; return state
    }
    func testOffBlackoutAndUnknownSlotsHaveNoGeometry() {
        var state = laser(mode: 0)
        XCTAssertTrue(LaserPreviewGeometry.sample(state: state,seconds: 1,beats: 1).lines.isEmpty)
        state = laser(); state.dimmer = 0
        XCTAssertTrue(LaserPreviewGeometry.sample(state: state,seconds: 1,beats: 1).lines.isEmpty)
        state = laser(pattern: 42)
        XCTAssertTrue(LaserPreviewGeometry.sample(state: state,seconds: 1,beats: 1).lines.isEmpty)
        state.laserDMX = [200]
        XCTAssertTrue(LaserPreviewGeometry.sample(state: state,seconds: 1,beats: 1).lines.isEmpty)
    }
    func testSixScansAnimateWithinBoundsAndStaticModeStaysStill() {
        for pattern in LaserPreviewGeometry.knownPatterns {
            let state = laser(pattern: UInt8(pattern))
            let a = LaserPreviewGeometry.sample(state: state,seconds: 0,beats: 0), b = LaserPreviewGeometry.sample(state: state,seconds: 1,beats: 2)
            XCTAssertEqual(a.lines.count,pattern == 127 || pattern == 145 ? 2 : 1)
            XCTAssertTrue(b.lines.flatMap { $0 }.allSatisfy { $0.valid })
            XCTAssertNotEqual(a.lines,b.lines)
            XCTAssertEqual(b.colour,12)
            let fixed = laser(mode: 150,pattern: UInt8(pattern))
            XCTAssertEqual(LaserPreviewGeometry.sample(state: fixed,seconds: 0,beats: 0).lines,LaserPreviewGeometry.sample(state: fixed,seconds: 100,beats: 200).lines)
        }
    }
    @MainActor func testSoundAutoPreviewDoesNotChangeLaserDMXAndMasterSilencesIt() throws {
        let store = LightingStore(startTimer: false,clock: { 0 })
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        store.project = try JSONDecoder().decode(ShowProject.self,from: Data(contentsOf: root.appendingPathComponent("Examples/AYRA-NGEAR-rig.lumendesk.json")))
        let id = store.project.fixtures[4].id
        store.fixtureStates[id] = laser(mode:50)
        let before = store.frame
        let a = LaserPreviewGeometry.sample(state:store.renderedState(for:id),seconds:1,beats:0), b = LaserPreviewGeometry.sample(state:store.renderedState(for:id),seconds:1,beats:0.25)
        XCTAssertNotEqual(a.intensity,b.intensity); XCTAssertEqual(store.frame,before)
        store.fixtureStates[id] = laser(mode:100)
        XCTAssertFalse(LaserPreviewGeometry.sample(state:store.renderedState(for:id),seconds:30,beats:0).lines.isEmpty)
        store.master = 0
        XCTAssertTrue(LaserPreviewGeometry.sample(state:store.renderedState(for:id),seconds:1,beats:0).lines.isEmpty)
        store.master = 1; store.blackout = true
        XCTAssertTrue(LaserPreviewGeometry.sample(state:store.renderedState(for:id),seconds:1,beats:0).lines.isEmpty)
    }
}
