import XCTest
@testable import LumenDesk
final class ColorPatternTests: XCTestCase {
    func testEveryPatternAndPaletteProducesDeterministicBoundedOutput() {
        for palette in ColorPalette.allCases {
            XCTAssertTrue(palette.colors.allSatisfy { $0.valid })
            for pattern in ColorPattern.allCases {
                var effect = ColorPatternRenderer.preset(pattern); effect.colors = palette.colors
                for step in -8...32 {
                    let cycles = Double(step)/7
                    let a = ColorPatternRenderer.sample(effect:effect,cycles:cycles,index:1,count:4)
                    let b = ColorPatternRenderer.sample(effect:effect,cycles:cycles,index:1,count:4)
                    XCTAssertTrue(a.color.valid,"\(pattern) \(palette)")
                    XCTAssertTrue((0...1).contains(a.intensity))
                    XCTAssertEqual(a.color.red,b.color.red); XCTAssertEqual(a.intensity,b.intensity)
                }
            }
        }
    }
    func testFadeLoopReverseAndPaletteChase() {
        var effect = ColorPatternRenderer.preset(.fade); effect.spread = 0
        let a = ColorPatternRenderer.sample(effect:effect,cycles:0.999999,index:0,count:4), b = ColorPatternRenderer.sample(effect:effect,cycles:1.000001,index:0,count:4)
        XCTAssertEqual(a.color.red,b.color.red,accuracy:0.00001)
        XCTAssertEqual(a.color.green,b.color.green,accuracy:0.00001)
        effect.colorReverse = true; effect.colorPhase = 0.5
        let reverse = ColorPatternRenderer.sample(effect:effect,cycles:0.2,index:0,count:1)
        effect.colorReverse = false; effect.colorPhase = 0
        let forward = ColorPatternRenderer.sample(effect:effect,cycles:0.3,index:0,count:1)
        XCTAssertEqual(reverse.color.blue,forward.color.blue,accuracy:0.000001)
        effect.colorPattern = .chase; effect.colorSmoothness = 0; effect.colors = [.rgb(1,0,0),.rgb(0,0,1)]
        XCTAssertEqual(ColorPatternRenderer.sample(effect:effect,cycles:0.1,index:0,count:1).color.red,1)
        XCTAssertEqual(ColorPatternRenderer.sample(effect:effect,cycles:0.6,index:0,count:1).color.blue,1)
    }
    @MainActor func testColourOnlyFixtureSpacingAndRGBWWhiteMix() {
        let store = LightingStore(startTimer:false,clock:{0})
        store.project = ShowProject(); store.addFixture(profile:.dimmer); store.addFixture(profile:.rgbw); store.addFixture(profile:.rgb)
        for fixture in store.project.fixtures { store.fixtureStates[fixture.id] = FixtureState(dimmer:0.7,white:1) }
        var effect = ColorPatternRenderer.preset(.alternating); effect.colors = [.rgb(1,0,0),.rgb(0,0,1)]; effect.enabled = true
        store.project.effects = [effect]
        let a = store.targetState(for:store.project.fixtures[1].id), b = store.targetState(for:store.project.fixtures[2].id)
        XCTAssertEqual(a.red,1); XCTAssertEqual(a.blue,0); XCTAssertEqual(b.red,0); XCTAssertEqual(b.blue,1)
        XCTAssertEqual(a.dimmer,0.7); XCTAssertEqual(a.white,0)
        effect.depth = 0.5; store.project.effects = [effect]
        XCTAssertEqual(store.targetState(for:store.project.fixtures[1].id).white,0.5)
        XCTAssertEqual(store.targetState(for:store.project.fixtures[0].id).white,1)
    }
    @MainActor func testIntensityIsOptionalAndMasterBlackoutKeepPriority() {
        let store = LightingStore(startTimer:false,clock:{0})
        let id = store.project.fixtures[1].id
        store.fixtureStates[id] = FixtureState(dimmer:0.8)
        var effect = ColorPatternRenderer.preset(.comet); effect.enabled = true
        store.project.effects = [effect]
        XCTAssertEqual(store.renderedState(for:id).dimmer,0.8)
        store.project.effects[0].colorIntensity = true
        XCTAssertLessThan(store.renderedState(for:id).dimmer,0.8)
        let level = store.renderedState(for:id).dimmer
        store.master = 0.5; XCTAssertEqual(store.renderedState(for:id).dimmer,level*0.5,accuracy:0.000001)
        store.blackout = true; XCTAssertEqual(store.renderedState(for:id).dimmer,0)
        store.stop(); XCTAssertTrue(store.project.effects.allSatisfy { !$0.enabled })
    }
    @MainActor func testPresetRoundTripRecallAndValidation() throws {
        let store = LightingStore(startTimer:false)
        var effect = ColorPatternRenderer.preset(.pingPong); effect.colorPhase = 0.3; effect.colorReverse = true; effect.colors = [.rgb(0.2,0.6,0.8)]
        XCTAssertNotNil(store.saveColorPreset(name:"Ocean loop",effect:effect))
        let decoded = try JSONDecoder().decode(ShowProject.self,from:JSONEncoder().encode(store.project))
        try decoded.validate(); XCTAssertEqual(decoded.colorPresets![0].effect.colorPhase,0.3)
        XCTAssertEqual(decoded.colorPresets![0].effect.colors?.count,1)
        XCTAssertFalse(decoded.colorPresets![0].effect.enabled)
        let id = store.prepareColorLibrary(); store.movementBinding(id:id).wrappedValue = decoded.colorPresets![0].effect
        XCTAssertEqual(store.project.effects.first(where:{$0.id == id})?.name,"Ocean loop")
        effect.colorSmoothness = .nan; XCTAssertNil(store.saveColorPreset(name:"Bad",effect:effect))
        var show = ShowProject.demo; show.colorPresets = [ColorEffectPreset(name:"Bad",effect:Effect(name:"Motion",kind:.circle))]
        XCTAssertThrowsError(try show.validate())
        XCTAssertNil(try JSONDecoder().decode(ShowProject.self,from:JSONEncoder().encode(ShowProject.demo)).colorPresets)
    }
    @MainActor func testLaserChannelsRemainUnchangedAndInvalidPaletteDoesNotCrash() throws {
        let store = LightingStore(startTimer:false,clock:{0})
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        store.project = try JSONDecoder().decode(ShowProject.self,from:Data(contentsOf:root.appendingPathComponent("Examples/AYRA-NGEAR-rig.lumendesk.json")))
        let id = store.project.fixtures[4].id
        var laser = FixtureState(); laser.laserDMX = [200,100,0,0,255,128,255,12,0]; store.fixtureStates[id] = laser
        let before = Array(store.frame[63..<72])
        var effect = ColorPatternRenderer.preset(.fire); effect.enabled = true; store.project.effects = [effect]
        XCTAssertEqual(Array(store.frame[63..<72]),before)
        effect.colors = []; XCTAssertEqual(ColorPatternRenderer.sample(effect:effect,cycles:0,index:0,count:1).intensity,0)
        effect.colors = [.rgb(1,0,0)]; XCTAssertEqual(ColorPatternRenderer.sample(effect:effect,cycles:.infinity,index:0,count:1).intensity,0)
    }
}
