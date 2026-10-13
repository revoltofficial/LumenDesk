import XCTest
@testable import LumenDesk

final class FixtureGroupTests: XCTestCase {
    @MainActor func testSelectionToggleAndSupportedBulkEditsPreserveOtherProperties() {
        let store = LightingStore(startTimer: false)
        let dimmer = Fixture(name: "House", kind: .dimmer, address: 1)
        let rgb = Fixture(name: "Wash", kind: .rgb, address: 2)
        let rgbw = Fixture(name: "Front", kind: .rgbw, address: 5)
        let untouched = Fixture(name: "Back", kind: .rgb, address: 9)
        store.project = ShowProject()
        store.project.fixtures = [dimmer,rgb,rgbw,untouched]
        for f in store.project.fixtures { store.setState(id: f.id, state: FixtureState(dimmer: 0.4, red: 0.1, green: 0.2, blue: 0.3, white: 0.6)) }
        store.selectFixture(id: dimmer.id)
        store.selectFixture(id: rgb.id, extending: true)
        store.selectFixture(id: rgbw.id, extending: true)
        store.setSelectionColor(red: 1, green: 0, blue: 0)
        XCTAssertEqual(store.state(for: dimmer.id).red, 0.1)
        XCTAssertEqual(store.state(for: rgb.id).red, 1)
        XCTAssertEqual(store.state(for: rgbw.id).dimmer, 0.4)
        store.setSelectionValue(\.white, value: 0.8)
        XCTAssertEqual(store.state(for: rgb.id).white, 0.6)
        XCTAssertEqual(store.state(for: rgbw.id).white, 0.8)
        store.setSelectionValue(\.dimmer, value: 0.7)
        XCTAssertEqual(store.state(for: dimmer.id).dimmer, 0.7)
        XCTAssertEqual(store.state(for: untouched.id).dimmer, 0.4)
        store.selectFixture(id: rgb.id, extending: true)
        XCTAssertFalse(store.selectedFixtureIDs.contains(rgb.id))
        XCTAssertEqual(store.selectedFixtureIDs.count, 2)
        XCTAssertFalse(store.outputEnabled)
    }
    @MainActor func testGroupsSaveSelectEditAndCleanUpRemovedFixtures() throws {
        let store = LightingStore(startTimer: false)
        let ids = store.project.fixtures.map(\.id)
        store.saveGroup(id: nil, name: "  Front lights  ", members: [ids[0],ids[1]])
        let group = try XCTUnwrap(store.project.fixtureGroups?.first)
        XCTAssertEqual(group.name, "Front lights")
        store.selectGroup(id: group.id)
        XCTAssertEqual(store.selectedFixtureIDs, Set([ids[0],ids[1]]))
        store.saveGroup(id: group.id, name: "Stage left", members: [ids[0],ids[2]])
        XCTAssertEqual(store.project.fixtureGroups?.count, 1)
        store.removeFixture(id: ids[0])
        XCTAssertEqual(store.project.fixtureGroups?.first?.fixtureIDs, Set([ids[2]]))
        XCTAssertFalse(store.selectedFixtureIDs.contains(ids[0]))
        store.removeFixture(id: ids[2])
        XCTAssertEqual(store.project.fixtureGroups?.count, 0)
        try store.project.validate()
    }
    @MainActor func testMixedValuesAndManualTakeover() {
        let store = LightingStore(startTimer: false)
        let ids = store.project.fixtures.map(\.id)
        store.setState(id: ids[0], state: FixtureState(dimmer: 0.2))
        store.setState(id: ids[1], state: FixtureState(dimmer: 0.8))
        store.selectedFixtureIDs = [ids[0],ids[1]]
        XCTAssertTrue(store.selectionIsMixed(\.dimmer))
        XCTAssertEqual(store.selectionValue(\.dimmer), 0.5, accuracy: 0.001)
        store.startSequence()
        store.setSelectionValue(\.dimmer, value: 0.6)
        XCTAssertNil(store.sequencePlayer)
        XCTAssertFalse(store.selectionIsMixed(\.dimmer))
        store.selectedFixtureIDs = []
        store.setSelectionValue(\.dimmer, value: 0)
        XCTAssertEqual(store.state(for: ids[0]).dimmer, 0.6)
    }
    func testGroupRoundTripLegacyFilesAndDanglingMembers() throws {
        var project = ShowProject.demo
        project.fixtureGroups = [FixtureGroup(name: "Washes", fixtureIDs: Set(project.fixtures.map(\.id)))]
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(ShowProject.self, from: data)
        XCTAssertEqual(decoded.fixtureGroups?.first?.fixtureIDs, project.fixtureGroups?.first?.fixtureIDs)
        try decoded.validate()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "fixtureGroups")
        let legacy = try JSONDecoder().decode(ShowProject.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.fixtureGroups)
        try legacy.validate()
        project.fixtureGroups?[0].fixtureIDs.insert(UUID())
        XCTAssertThrowsError(try project.validate())
    }
}
