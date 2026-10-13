import XCTest
@testable import LumenDesk

final class LayerTests: XCTestCase {
    func testSparseChannelsPriorityAndRelease() {
        let fixture = UUID()
        let color = ActiveLayer(id: UUID(), name: "Red", priority: 50, started: 0, fadeSeconds: 0, values: [fixture: PresetValues(red: 1, green: 0, blue: 0)], effects: [:])
        let intensity = ActiveLayer(id: UUID(), name: "Low", priority: 50, started: 0, fadeSeconds: 0, values: [fixture: PresetValues(dimmer: 0.2)], effects: [:])
        var mixer = LayerMixer(layers: [color, intensity])
        let base = FixtureState(dimmer: 0.8, red: 0.1, green: 0.3, blue: 1)
        XCTAssertEqual(mixer.state(for: fixture, base: base, now: 1), FixtureState(dimmer: 0.2, red: 1, green: 0, blue: 0))
        var higher = intensity; higher.id = UUID(); higher.priority = 75; higher.values = [fixture: PresetValues(dimmer: 0.6)]
        mixer.layers = [higher, color, intensity]
        XCTAssertEqual(mixer.state(for: fixture, base: base, now: 1).dimmer, 0.6)
        mixer.layers.removeAll { $0.id == higher.id }
        XCTAssertEqual(mixer.state(for: fixture, base: base, now: 1).dimmer, 0.2)
        mixer.layers.removeAll { $0.id == intensity.id }
        XCTAssertEqual(mixer.state(for: fixture, base: base, now: 1).dimmer, 0.8)
        mixer.layers = []
        XCTAssertEqual(mixer.state(for: fixture, base: base, now: 1), base)
    }
    func testFadeAndFixtureIsolation() {
        let fixture = UUID(), other = UUID()
        let mixer = LayerMixer(layers: [ActiveLayer(id: UUID(), name: "Fade", priority: 50, started: 10, fadeSeconds: 2, values: [fixture: PresetValues(dimmer: 1)], effects: [:])])
        XCTAssertEqual(mixer.state(for: fixture, base: .off, now: 11).dimmer, 0.5)
        XCTAssertEqual(mixer.state(for: fixture, base: .off, now: 12).dimmer, 1)
        XCTAssertEqual(mixer.state(for: other, base: .off, now: 12), .off)
    }
    func testEffectOverrideAndRelease() {
        let id = UUID(), other = UUID()
        let base = [Effect(name: "Wave", kind: .sine, enabled: true)]
        var mixer = LayerMixer(layers: [ActiveLayer(id: UUID(), name: "No effects", priority: 50, started: 0, fadeSeconds: 0, values: [:], effects: [id: []])])
        XCTAssertTrue(mixer.effects(for: id, base: base).isEmpty)
        XCTAssertEqual(mixer.effects(for: other, base: base).count, 1)
        mixer.layers = []
        XCTAssertEqual(mixer.effects(for: id, base: base).first?.kind, .sine)
    }
    @MainActor func testPresetCompositionManualTakeoverAndStop() throws {
        let store = LightingStore(startTimer: false)
        let first = store.project.fixtures[0].id, second = store.project.fixtures[1].id
        store.selectedFixtureIDs = [first]
        store.setSelectionColor(red: 1, green: 0, blue: 0)
        store.capturePreset(name: "Red", kind: .color)
        store.setSelectionValue(\.dimmer, value: 0.2)
        store.capturePreset(name: "Low", kind: .intensity)
        store.setSelectionColor(red: 0, green: 0, blue: 1)
        store.setSelectionValue(\.dimmer, value: 0.8)
        store.saveLayer(name: "Red low", presetIDs: store.project.presets!.map(\.id), priority: 50, fadeSeconds: 0)
        let layer = store.project.layerCues![0].id
        store.activateLayer(id: layer)
        XCTAssertEqual(store.state(for: first).dimmer, 0.2)
        XCTAssertEqual(store.state(for: first).red, 1)
        XCTAssertEqual(store.state(for: second).dimmer, 0.8)
        store.releaseLayer(id: layer)
        XCTAssertEqual(store.state(for: first).blue, 1)
        XCTAssertEqual(store.state(for: first).dimmer, 0.8)
        store.activateLayer(id: layer)
        store.setSelectionValue(\.dimmer, value: 0.4)
        XCTAssertTrue(store.layerMixer.layers.isEmpty)
        XCTAssertEqual(store.state(for: first).red, 1)
        XCTAssertEqual(store.state(for: first).dimmer, 0.4)
        store.activateLayer(id: layer); store.stop()
        XCTAssertTrue(store.layerMixer.layers.isEmpty)
        XCTAssertTrue(store.frame.allSatisfy { $0 == 0 })
        try store.project.validate()
    }
    @MainActor func testSequenceContinuesBelowLayers() {
        var now = 0.0
        let store = LightingStore(startTimer: false, clock: { now })
        store.selectAllFixtures(); store.capturePreset(name: "Intensity", kind: .intensity)
        store.saveLayer(name: "Intensity", presetIDs: [store.project.presets![0].id], priority: 50, fadeSeconds: 0)
        store.startSequence(); store.activateLayer(id: store.project.layerCues![0].id)
        XCTAssertNotNil(store.sequencePlayer)
        now = 5; store.tick()
        XCTAssertEqual(store.activeCueID, store.project.cues[1].id)
        now = 7; store.tick(); store.releaseAllLayers()
        XCTAssertEqual(store.state(for: store.project.fixtures[0].id).dimmer, 0.7, accuracy: 0.001)
    }
    @MainActor func testPersistenceLegacyAndDeletion() throws {
        let store = LightingStore(startTimer: false)
        store.capturePreset(name: "Color", kind: .color)
        store.saveLayer(name: "Color", presetIDs: [store.project.presets![0].id], priority: 50, fadeSeconds: 0)
        let restored = try JSONDecoder().decode(ShowProject.self, from: JSONEncoder().encode(store.project))
        try restored.validate()
        XCTAssertEqual(restored.layerCues?.first?.presetIDs, store.project.layerCues?.first?.presetIDs)
        XCTAssertNil(try JSONDecoder().decode(ShowProject.self, from: JSONEncoder().encode(ShowProject.demo)).presets)
        store.activateLayer(id: store.project.layerCues![0].id)
        store.removeFixture(id: store.project.fixtures[0].id)
        XCTAssertTrue(store.project.presets!.isEmpty)
        XCTAssertTrue(store.project.layerCues!.isEmpty)
        XCTAssertTrue(store.layerMixer.layers.isEmpty)
        try store.project.validate()
    }
    @MainActor func testValidationRejectsDanglingReferencesAndInvalidLevels() throws {
        let store = LightingStore(startTimer: false)
        store.capturePreset(name: "Color", kind: .color)
        store.saveLayer(name: "Color", presetIDs: [store.project.presets![0].id], priority: 50, fadeSeconds: 0)
        var project = store.project
        project.layerCues![0].presetIDs = [UUID()]
        XCTAssertThrowsError(try project.validate())
        project = store.project
        let id = project.fixtures[0].id
        project.presets![0].values[id]?.red = 2
        XCTAssertThrowsError(try project.validate())
    }
}
