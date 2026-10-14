import XCTest
@testable import LumenDesk
final class MovementLibraryTests: XCTestCase {
    func testEveryBuiltInIsBoundedAndContinuousAtLoopBoundary() {
        for pattern in MovementPattern.allCases {
            let effect = MotionPath.preset(pattern)
            XCTAssertTrue(effect.validTiming)
            for step in -100...200 {
                let point = MotionPath.sample(effect: effect,phase: Double(step)/100)
                XCTAssertTrue(point.valid,"\(pattern): \(point)")
            }
            let a = MotionPath.sample(effect: effect,phase: 0.999999), b = MotionPath.sample(effect: effect,phase: 1.000001)
            XCTAssertEqual(a.x,b.x,accuracy: 0.0001,"\(pattern)")
            XCTAssertEqual(a.y,b.y,accuracy: 0.0001,"\(pattern)")
        }
    }
    func testDirectionPhaseAndPairCoordination() {
        var effect = MotionPath.preset(.circle); effect.arrangement = .together
        let together = MotionPath.coordinated(effect: effect,cycles: 0.125,index: 0,count: 4)
        XCTAssertEqual(together,MotionPath.coordinated(effect: effect,cycles: 0.125,index: 3,count: 4))
        effect.arrangement = .mirrored
        let other = MotionPath.coordinated(effect: effect,cycles: 0.125,index: 1,count: 4)
        XCTAssertEqual(together.x,-other.x); XCTAssertEqual(together.y,other.y)
        effect.arrangement = .alternating
        let alternate = MotionPath.coordinated(effect: effect,cycles: 0.125,index: 1,count: 4)
        XCTAssertEqual(alternate.x,-together.x,accuracy: 0.000001)
        effect.reverse = true; effect.motionPhase = 0.25
        let reversed = MotionPath.sample(effect: effect,phase: 0.125)
        effect.reverse = false; effect.motionPhase = 0
        XCTAssertEqual(reversed,MotionPath.sample(effect: effect,phase: 0.125))
    }
    @MainActor func testSeparateSizesAndHeadOnlySpread() {
        let store = LightingStore(startTimer: false,clock: { 0 })
        store.project = ShowProject(); store.addFixture(profile: .rgb); store.addFixture(profile: .head); store.addFixture(profile: .head)
        var effect = MotionPath.preset(.circle); effect.enabled = true; effect.arrangement = .mirrored; effect.panSize = 1; effect.tiltSize = 0
        store.project.effects = [effect]; store.tempoClock.advance(seconds: 2,bpm: 120)
        let left = store.targetState(for: store.project.fixtures[1].id), right = store.targetState(for: store.project.fixtures[2].id)
        XCTAssertEqual(left.pan+right.pan,1,accuracy: 0.000001)
        XCTAssertEqual(left.tilt,0.5); XCTAssertEqual(right.tilt,0.5)
        XCTAssertEqual(store.targetState(for: store.project.fixtures[0].id).pan,0.5)
        store.project.effects[0].panSize = 0
        XCTAssertEqual(store.targetState(for: store.project.fixtures[1].id).pan,0.5)
    }
    @MainActor func testSaveRecallFavoritesAndShowRoundTrip() throws {
        let store = LightingStore(startTimer: false)
        var effect = MotionPath.preset(.custom); effect.reverse = true; effect.panSize = 0.4; effect.motionPhase = 0.2; effect.enabled = true
        let id = try XCTUnwrap(store.saveMovement(name:"My custom",effect:effect))
        XCTAssertFalse(store.project.movementPresets![0].effect.enabled)
        store.toggleSavedMovementFavorite(id); store.toggleMovementFavorite(.spiral)
        let decoded = try JSONDecoder().decode(ShowProject.self,from: JSONEncoder().encode(store.project))
        try decoded.validate()
        XCTAssertTrue(decoded.movementPresets![0].favorite)
        XCTAssertEqual(decoded.movementFavorites,[.spiral])
        XCTAssertEqual(decoded.movementPresets![0].effect.pathPoints,effect.pathPoints)
        XCTAssertEqual(decoded.movementPresets![0].effect.panSize,0.4)
        XCTAssertEqual(decoded.movementPresets![0].effect.motionPhase,0.2)
        let target = store.prepareMovementLibrary(), beforeCount = store.project.effects.count
        var recall = decoded.movementPresets![0].effect; recall.enabled = true
        store.movementBinding(id: target).wrappedValue = recall
        XCTAssertEqual(store.project.effects.count,beforeCount)
        XCTAssertEqual(store.project.effects.first(where: { $0.id == target })?.name,"My custom")
        store.toggleMovementFavorite(.spiral); XCTAssertEqual(store.project.movementFavorites,[])
    }
    @MainActor func testInvalidSavedPresetsAndLegacyDefaults() throws {
        let store = LightingStore(startTimer: false)
        var effect = MotionPath.preset(.circle); effect.panSize = -1
        XCTAssertNil(store.saveMovement(name:"Bad",effect:effect))
        effect.panSize = 1; effect.motionPhase = .nan; XCTAssertFalse(effect.validTiming)
        effect.motionPhase = 0; XCTAssertNil(store.saveMovement(name:" ",effect:effect))
        var show = ShowProject.demo
        show.movementPresets = [MovementPreset(name:"Bad",effect: Effect(name:"Colour",kind:.rainbow))]
        XCTAssertThrowsError(try show.validate())
        show.movementPresets = nil; show.movementFavorites = [.circle,.circle]; XCTAssertThrowsError(try show.validate())
        show.movementFavorites = nil
        let decoded = try JSONDecoder().decode(ShowProject.self,from: JSONEncoder().encode(show))
        XCTAssertNil(decoded.movementPresets); XCTAssertNil(decoded.effects[0].reverse); XCTAssertNil(decoded.effects[0].panSize)
    }
    func testLongPhraseCyclesAreAcceptedAndOtherCyclesRejected() {
        var effect = MotionPath.preset(.atmosphere)
        XCTAssertEqual(effect.cycleBeats,64); XCTAssertTrue(effect.validTiming)
        effect.beatsPerCycle = 32; XCTAssertTrue(effect.validTiming)
        effect.beatsPerCycle = 3; XCTAssertFalse(effect.validTiming)
    }
}
