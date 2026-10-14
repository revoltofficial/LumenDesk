import XCTest
@testable import LumenDesk

final class MotionControllerTests: XCTestCase {
    func testAbsoluteTravelIsBoundedBySpeedAndAccelerationAndSettles() {
        let settings = MotionSettings(speed: 90, acceleration: 180)
        var axis = MotionAxis(position: 0)
        let dt = 1.0 / 120
        for _ in 0..<1800 {
            let before = axis
            axis.advance(target: 540, seconds: dt, range: 540, settings: settings)
            XCTAssertLessThanOrEqual(abs(axis.velocity), 90.000001)
            // The hard travel boundary is allowed to stop an outward velocity.
            if axis.position > 0 && axis.position < 540 { XCTAssertLessThanOrEqual(abs(axis.velocity-before.velocity),180*dt+0.000001) }
            XCTAssertLessThanOrEqual(abs(axis.position-before.position),90*dt+0.000001)
            XCTAssertTrue((0...540).contains(axis.position))
        }
        XCTAssertEqual(axis.position,540,accuracy: 0.001)
        axis.advance(target: 0, seconds: dt, range: 540, settings: settings)
        XCTAssertGreaterThan(axis.position,539) // absolute return, not a wrap shortcut
    }
    func testReversalLongFramesAndInvalidInput() {
        let settings = MotionSettings(speed: 60, acceleration: 120)
        var axis = MotionAxis(position: 270)
        for _ in 0..<60 { axis.advance(target: 540,seconds: 1.0/120,range: 540,settings: settings) }
        let before = axis
        axis.advance(target: 0,seconds: 1.0/120,range: 540,settings: settings)
        XCTAssertGreaterThan(axis.velocity,0)
        XCTAssertLessThanOrEqual(abs(axis.velocity-before.velocity),1.000001)
        let last = axis.position
        axis.advance(target: 0,seconds: 30,range: 540,settings: settings)
        XCTAssertLessThanOrEqual(abs(axis.position-last),15.000001)
        let held = axis
        axis.advance(target: .nan,seconds: 0.1,range: 540,settings: settings)
        axis.advance(target: 0,seconds: .infinity,range: 540,settings: settings)
        XCTAssertEqual(axis.position,held.position); XCTAssertEqual(axis.velocity,held.velocity)
    }
    @MainActor func testEffectsSyncAndAutopilotShareContinuousPreviewAndOutput() {
        var now = 0.0
        let store = LightingStore(startTimer: false,clock: { now })
        store.project = ShowProject(); store.addFixture(profile: .head)
        let fixture = store.project.fixtures[0], id = fixture.id
        store.fixtureStates[id] = FixtureState(dimmer: 1,pan: 0.5,tilt: 0.5)
        store.tick()
        let initial = store.renderedState(for: id)
        store.project.effects = [Effect(name: "Orbit",kind: .circle,enabled: true)]
        XCTAssertEqual(store.renderedState(for: id).tilt,initial.tilt)
        now += 1.0/30; store.tick()
        let moved = store.renderedState(for: id)
        XCTAssertGreaterThan(moved.tilt,initial.tilt)
        XCTAssertLessThan((moved.tilt-initial.tilt)*270,90/30)
        XCTAssertEqual(Array(store.frame.prefix(fixture.footprint)),fixture.resolvedProfile.bytes(for: fixture.outputState(moved)))
        let pose = store.motionPoses[id]!
        for _ in 0..<10 { _ = store.renderedState(for: id); _ = store.frame }
        XCTAssertEqual(store.motionPoses[id]!.tilt.position,pose.tilt.position)
        store.syncTempo(); XCTAssertEqual(store.renderedState(for: id).tilt,moved.tilt)
        store.autopilotEnabled = true; store.lastMusicTime = now
        store.music = MusicSnapshot(level: 0.2,energy: 1,section: .drop)
        XCTAssertEqual(store.renderedState(for: id).pan,moved.pan)
        let before = store.motionPoses[id]!
        now += 1.0/30; store.tick()
        XCTAssertLessThanOrEqual(abs(store.motionPoses[id]!.pan.position-before.pan.position),90/30+0.000001)
        let parked = store.renderedState(for: id)
        store.blackout = true; XCTAssertEqual(store.renderedState(for: id).pan,parked.pan)
        store.stop(); now += 0.1; store.tick()
        XCTAssertEqual(store.renderedState(for: id).pan,parked.pan,accuracy: 0.000001)
        XCTAssertEqual(store.renderedState(for: id).tilt,parked.tilt,accuracy: 0.000001)
        XCTAssertEqual(store.renderedState(for: id).dimmer,0)
        XCTAssertEqual(store.motionPoses[id]!.pan.velocity,0)
        store.removeFixture(id: id); XCTAssertNil(store.motionPoses[id])
    }
    @MainActor func testInterruptedZeroFadeCueStartsFromCurrentPose() {
        var now = 0.0
        let store = LightingStore(startTimer: false,clock: { now })
        store.project = ShowProject(); store.addFixture(profile: .head)
        let id = store.project.fixtures[0].id
        store.tick()
        let cue = Cue(name: "Far",fadeSeconds: 0,levels: [id: FixtureState(pan: 1,tilt: 1)])
        store.project.cues = [cue]; store.activateCue(id: cue.id)
        XCTAssertEqual(store.renderedState(for: id).pan,0.5)
        for _ in 0..<30 { now += 1.0/30; store.tick() }
        let before = store.renderedState(for: id)
        store.setSelectionPosition(pan: 0,tilt: 0)
        XCTAssertEqual(store.renderedState(for: id).pan,before.pan)
        now += 1.0/30; store.tick()
        XCTAssertLessThanOrEqual(abs(store.renderedState(for: id).pan-before.pan)*540,3.000001)
    }
    func testSettingsPersistValidateAndLegacyDefaultsRemainEnabled() throws {
        var show = ShowProject.demo
        show.motion = MotionSettings(speed: 45,acceleration: 90)
        let copy = try JSONDecoder().decode(ShowProject.self,from: JSONEncoder().encode(show))
        XCTAssertEqual(copy.motion?.speed,45); XCTAssertEqual(copy.motion?.acceleration,90)
        show.motion = nil
        let legacy = try JSONDecoder().decode(ShowProject.self,from: JSONEncoder().encode(show))
        XCTAssertTrue((legacy.motion ?? MotionSettings()).enabled)
        show.motion = MotionSettings(speed: 0); XCTAssertThrowsError(try show.validate())
        show.motion = MotionSettings(acceleration: .infinity); XCTAssertThrowsError(try show.validate())
    }
}
