import XCTest
@testable import LumenDesk

final class LightingEngineTests: XCTestCase {
    func testArtDMXHeaderAndUniverseBoundary() {
        let frame = [UInt8](repeating: 127, count: 512)
        let first = [UInt8](ArtNetOutput.packet(frame: frame, universe: 1, sequence: 1))
        XCTAssertEqual(first.count, 530)
        XCTAssertEqual(Array(first.prefix(18)), [65,114,116,45,78,101,116,0,0,80,0,14,1,0,0,0,2,0])
        XCTAssertEqual(Array(first.dropFirst(18)), frame)
        let last = [UInt8](ArtNetOutput.packet(frame: frame, universe: 32768, sequence: 255))
        XCTAssertEqual(last[14], 255)
        XCTAssertEqual(last[15], 127)
    }
    func testOverlappingAndOutOfBoundsPatchesAreRejected() {
        var project = ShowProject()
        project.fixtures = [Fixture(name: "RGB", kind: .rgb, address: 1), Fixture(name: "Dimmer", kind: .dimmer, address: 3)]
        XCTAssertThrowsError(try project.validate())
        project.fixtures[1].address = 4
        XCTAssertNoThrow(try project.validate())
        project.fixtures[0].address = 511
        XCTAssertThrowsError(try project.validate())
    }
    func testProjectRoundTripKeepsCueFixtureAssociations() throws {
        let project = ShowProject.demo
        let decoded = try JSONDecoder().decode(ShowProject.self, from: JSONEncoder().encode(project))
        try decoded.validate()
        XCTAssertEqual(decoded.fixtures.map(\.id), project.fixtures.map(\.id))
        XCTAssertEqual(decoded.cues.first?.levels, project.cues.first?.levels)
    }
    @MainActor func testMasterAndBlackoutAffectAllRGBChannels() {
        let store = LightingStore()
        store.project = ShowProject()
        let fixture = Fixture(name: "RGB", kind: .rgb, address: 1)
        store.project.fixtures = [fixture]
        store.setState(id: fixture.id, state: FixtureState(dimmer: 1, red: 1, green: 0.5, blue: 0))
        store.master = 0.5
        XCTAssertEqual(Array(store.frame.prefix(3)), [128,64,0])
        store.blackout = true
        XCTAssertTrue(store.frame.allSatisfy { $0 == 0 })
    }
    func testUnsupportedSchemaVersionIsRejected() throws {
        var project = ShowProject.demo
        project.schemaVersion = 2
        let decoded = try JSONDecoder().decode(ShowProject.self, from: JSONEncoder().encode(project))
        XCTAssertThrowsError(try decoded.validate())
    }
    func testFadeInterpolation() {
        let midpoint = FixtureState.off.blended(to: FixtureState(dimmer: 1), fraction: 0.5)
        XCTAssertEqual(midpoint.dimmer, 0.5)
    }
}
