import XCTest
@testable import LumenDesk

final class MovingHeadTests: XCTestCase {
    func test16BitCoarseFineAndNoDimmerMultiplicationOfPosition() throws {
        let profile = FixtureProfile.head
        try profile.validate()
        let bytes = profile.bytes(for: FixtureState(dimmer: 0.5, red: 1, green: 0.25, blue: 0, pan: 0.5, tilt: 1, zoom: 0, gobo: 2.0 / 3.0))
        XCTAssertEqual(bytes, [128, 0, 255, 255, 128, 255, 64, 0, 0, 64, 255])
        let dark = profile.bytes(for: FixtureState(dimmer: 0, pan: 0.5, tilt: 1))
        XCTAssertEqual(Array(dark.prefix(4)), [128, 0, 255, 255])
        XCTAssertEqual(dark[4], 0)
    }
    func testCustomChannelOffsetsRangesAndValidation() throws {
        var profile = FixtureProfile.head
        profile.id = "test.custom"; profile.channels[0].offset = 2; profile.channels[0].fineOffset = 1
        profile.channels[0].minimum = 65535; profile.channels[0].maximum = 0
        try profile.validate()
        let bytes = profile.bytes(for: FixtureState(pan: 1))
        XCTAssertEqual(Array(bytes.prefix(2)), [0,0])
        profile.channels[0].fineOffset = 3
        XCTAssertThrowsError(try profile.validate())
        profile = .head; profile.channels[0].maximum = 65536
        XCTAssertThrowsError(try profile.validate())
        profile = .rgb; profile.colorUsesDimmer = false
        XCTAssertThrowsError(try profile.validate())
        profile = .head; profile.gobos = []
        XCTAssertThrowsError(try profile.validate())
    }
    func testNeutralAndQuarterTurnFloorGeometry() {
        let neutral = HeadPose(state: FixtureState(), profile: .head)
        XCTAssertEqual(neutral.direction.z, -1, accuracy: 0.000001)
        XCTAssertEqual(neutral.floorPoint(height: 3)!.x, 0, accuracy: 0.000001)
        XCTAssertEqual(neutral.floorPoint(height: 3)!.y, 0, accuracy: 0.000001)
        let forward = HeadPose(state: FixtureState(tilt: 0.5 + 45.0 / 270), profile: .head)
        XCTAssertEqual(forward.floorPoint(height: 3)!.x, 0, accuracy: 0.000001)
        XCTAssertEqual(forward.floorPoint(height: 3)!.y, 3, accuracy: 0.000001)
        let right = HeadPose(state: FixtureState(pan: 0.5 + 90.0 / 540, tilt: 0.5 + 45.0 / 270), profile: .head)
        XCTAssertEqual(right.floorPoint(height: 3)!.x, 3, accuracy: 0.000001)
        XCTAssertEqual(right.floorPoint(height: 3)!.y, 0, accuracy: 0.000001)
    }
    func testAboveHorizonAndZoomFootprint() {
        let up = HeadPose(state: FixtureState(tilt: 1), profile: .head)
        XCTAssertNil(up.floorPoint(height: 3)); XCTAssertTrue(up.footprint(height: 3).isEmpty)
        let narrow = HeadPose(state: FixtureState(zoom: 0), profile: .head).footprint(height: 3)
        let wide = HeadPose(state: FixtureState(zoom: 1), profile: .head).footprint(height: 3)
        XCTAssertEqual(narrow.count, 40); XCTAssertEqual(wide.count, 40)
        XCTAssertEqual(narrow[0].x, 3 * tan(4 * .pi / 180), accuracy: 0.000001)
        XCTAssertEqual(wide[0].x, 3 * tan(20 * .pi / 180), accuracy: 0.000001)
        for point in wide { XCTAssertTrue(point.x.isFinite && point.y.isFinite) }
    }
    func testAbsolutePanFadeDoesNotWrapAndGoboDoesNotScroll() {
        let start = FixtureState(pan: 0, tilt: 0.25, zoom: 0, gobo: 0)
        let target = FixtureState(pan: 1, tilt: 0.75, zoom: 1, gobo: 1)
        var previous = -271.0
        for step in 0...60 {
            let value = start.blended(to: target, fraction: Double(step) / 60)
            let pose = HeadPose(state: value, profile: .head)
            XCTAssertGreaterThan(pose.pan, previous); previous = pose.pan
            XCTAssertEqual(value.gobo, step == 60 ? 1 : 0)
        }
        XCTAssertEqual(previous, 270)
        XCTAssertEqual(start.blended(to: target, fraction: 0.5).pan, 0.5)
    }
    func testLegacyStateDefaultsAndProfileRoundTrip() throws {
        let old = Data("{\"dimmer\":0.8,\"red\":1,\"green\":0.4,\"blue\":0.12,\"white\":0}".utf8)
        let state = try JSONDecoder().decode(FixtureState.self, from: old)
        XCTAssertEqual(state.pan, 0.5); XCTAssertEqual(state.tilt, 0.5)
        let decoded = try JSONDecoder().decode(FixtureProfile.self, from: JSONEncoder().encode(FixtureProfile.head))
        try decoded.validate(); XCTAssertEqual(decoded.footprint, 11)
        XCTAssertEqual(decoded.channels[0].fineOffset, 2)
        XCTAssertEqual(decoded.gobos[2].name, "Star")
    }
    @MainActor func testCuePreviewAndOutputShareFadeValuesAndBlackoutPreservesPosition() throws {
        var now = 0.0
        let store = LightingStore(startTimer: false, clock: { now })
        store.project = ShowProject(); store.addFixture(profile: .head)
        let fixture = store.project.fixtures[0]
        store.setState(id: fixture.id, state: FixtureState(dimmer: 1, pan: 0, tilt: 0.5))
        let cue = Cue(name: "Sweep", fadeSeconds: 4, levels: [fixture.id: FixtureState(dimmer: 1, pan: 1, tilt: 0.75)])
        store.project.cues = [cue]; store.activateCue(id: cue.id)
        now = 2; store.tick()
        let state = store.renderedState(for: fixture.id), pose = HeadPose(state: store.renderedState(for: fixture.id), profile: fixture.resolvedProfile)
        XCTAssertEqual(state.pan, 0.5); XCTAssertEqual(pose.pan, 0)
        XCTAssertEqual(pose.tilt, 33.75)
        XCTAssertEqual(Array(store.frame.prefix(4)), [128,0,159,255])
        store.blackout = true
        XCTAssertEqual(Array(store.frame.prefix(4)), [128,0,159,255])
        XCTAssertEqual(store.frame[4], 0)
        XCTAssertEqual(store.renderedState(for: fixture.id).pan, state.pan)
        try store.project.validate()
    }
    @MainActor func testMovingProfileBoundsAndLibraryPatching() throws {
        let store = LightingStore(startTimer: false)
        store.project = ShowProject(); store.addFixture(profile: .head); store.addFixture(profile: .head)
        XCTAssertEqual(store.project.fixtures.map(\.address), [1,12])
        XCTAssertEqual(store.project.fixtures.map(\.footprint), [11,11])
        try store.project.validate()
        store.project.fixtures[1].address = 503
        XCTAssertThrowsError(try store.project.validate())
        store.project.fixtures[1].address = 502
        XCTAssertNoThrow(try store.project.validate())
    }
    @MainActor func testMotionPresetsAndOrbitIsolation() throws {
        let store = LightingStore(startTimer: false)
        store.project = ShowProject(); store.addFixture(profile: .rgb); store.addFixture(profile: .head)
        let head = store.project.fixtures[1].id, wash = store.project.fixtures[0].id
        store.selectedFixtureIDs = [head, wash]
        store.setSelectionPosition(pan: 0.7, tilt: 0.65)
        XCTAssertEqual(store.state(for: wash).pan, 0.5)
        store.capturePreset(name: "Aim", kind: .position)
        XCTAssertEqual(Set(store.project.presets![0].values.keys), [head])
        store.setSelectionPosition(pan: 0.5, tilt: 0.5)
        store.saveLayer(name: "Aim", presetIDs: [store.project.presets![0].id], priority: 50, fadeSeconds: 0)
        store.activateLayer(id: store.project.layerCues![0].id)
        XCTAssertEqual(store.state(for: head).pan, 0.7)
        store.releaseAllLayers()
        XCTAssertEqual(store.state(for: head).pan, 0.5)
        store.project.effects = [Effect(name: "Orbit", kind: .circle, enabled: true)]
        store.phase = 0
        XCTAssertNotEqual(store.renderedState(for: head).tilt, 0.5)
        XCTAssertEqual(store.renderedState(for: wash).tilt, 0.5)
        try store.project.validate()
    }
}
