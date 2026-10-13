import XCTest
@testable import LumenDesk
final class PerformanceTests: XCTestCase {
    func testMicrophoneTempoEstimatorLocksToSteadyBeatAndRejectsSilence() {
        var analyzer = MusicAnalyzer(), snapshot = MusicSnapshot()
        for i in 0..<600 {
            let level = i % 25 == 0 ? 0.4 : 0.04
            snapshot = analyzer.process(level: level,bass: level*0.8,high: level*0.2,time: Double(i)/50)
        }
        XCTAssertEqual(snapshot.bpm ?? 0,120,accuracy: 1)
        XCTAssertGreaterThan(snapshot.confidence,0.55)
        var silence = MusicAnalyzer()
        for i in 0..<600 { snapshot = silence.process(level: 0,bass: 0,high: 0,time: Double(i)/50) }
        XCTAssertNil(snapshot.bpm); XCTAssertEqual(snapshot.section,.silence)
    }
    func testBreakAndDropRespondToEnergyReturn() {
        var analyzer = MusicAnalyzer(), snapshot = MusicSnapshot()
        for i in 0..<1000 { snapshot = analyzer.process(level: 0.15,bass: 0.1,high: 0.05,time: Double(i)/50) }
        for i in 1000..<1200 { snapshot = analyzer.process(level: 0.02,bass: 0.01,high: 0.01,time: Double(i)/50) }
        XCTAssertEqual(snapshot.section,.musicalBreak)
        for i in 1200..<1220 { snapshot = analyzer.process(level: 0.4,bass: 0.3,high: 0.1,time: Double(i)/50) }
        XCTAssertEqual(snapshot.section,.drop)
    }
    func testAutopilotDropIsBrighterThanBreakAndStylesDiffer() {
        let base = FixtureState(dimmer: 0,red: 0,green: 0,blue: 0)
        var music = MusicSnapshot(level: 0.2,energy: 0.6,section: .musicalBreak)
        let quiet = AutopilotRenderer.render(base: base,snapshot: music,style: .disco,strength: 1,beats: 0,index: 0,moving: true,fresh: true)
        music.section = .drop
        let drop = AutopilotRenderer.render(base: base,snapshot: music,style: .disco,strength: 1,beats: 0,index: 0,moving: true,fresh: true)
        let techno = AutopilotRenderer.render(base: base,snapshot: music,style: .techno,strength: 1,beats: 0,index: 0,moving: true,fresh: true)
        XCTAssertGreaterThan(drop.dimmer,quiet.dimmer); XCTAssertGreaterThan(drop.tilt,quiet.tilt)
        XCTAssertGreaterThan(drop.red,techno.red)
        XCTAssertEqual(AutopilotRenderer.render(base: base,snapshot: music,style: .disco,strength: 1,beats: 0,index: 0,moving: false,fresh: false).dimmer,0)
    }
    @MainActor func testAutopilotMasterBlackoutAndStopOverride() {
        var now = 0.0
        let store = LightingStore(startTimer: false,clock: { now })
        store.autopilotEnabled = true; store.autopilotStrength = 1
        store.music = MusicSnapshot(level: 0.2,energy: 0.8,section: .drop); store.lastMusicTime = 0
        let id = store.project.fixtures[0].id
        let full = store.renderedState(for: id).dimmer
        store.master = 0.5; XCTAssertEqual(store.renderedState(for: id).dimmer,full*0.5)
        store.blackout = true; XCTAssertEqual(store.renderedState(for: id).dimmer,0)
        store.blackout = false; store.stop(); XCTAssertFalse(store.autopilotEnabled); XCTAssertEqual(store.renderedState(for: id).dimmer,0)
        now = 2
    }
    func testCustomPathsInterpolateAndOpenPathReturnsWithoutJump() throws {
        var effect = Effect(name: "Path",kind: .circle)
        effect.movement = .custom; effect.pathPoints = [MotionPoint(x: -1,y: -1),MotionPoint(x: 1,y: 1)]; effect.pathClosed = false
        XCTAssertEqual(MotionPath.sample(effect: effect,phase: 0),MotionPoint(x: -1,y: -1))
        XCTAssertEqual(MotionPath.sample(effect: effect,phase: 0.5),MotionPoint(x: 1,y: 1))
        XCTAssertEqual(MotionPath.sample(effect: effect,phase: 1),MotionPoint(x: -1,y: -1))
        XCTAssertEqual(MotionPath.sample(effect: effect,phase: 0.25),MotionPoint(x: 0,y: 0))
        var show = ShowProject.demo; show.effects = [effect]; try show.validate()
        let decoded = try JSONDecoder().decode(ShowProject.self,from: JSONEncoder().encode(show))
        XCTAssertEqual(decoded.effects[0].pathPoints,effect.pathPoints)
        show.effects[0].pathPoints?[0].x = 2; XCTAssertThrowsError(try show.validate())
    }
    func testWaveformBoundaries() {
        XCTAssertEqual(Waveform.triangle.value(at: 0.5),1)
        XCTAssertEqual(Waveform.square.value(at: 0.5),0)
        XCTAssertEqual(Waveform.rampUp.value(at: 1.25),0.25)
        XCTAssertEqual(Waveform.rampDown.value(at: -0.25),0.25)
    }
    @MainActor func testNewEffectsRemainBoundedAndDeterministic() {
        let store = LightingStore(startTimer: false)
        for kind in [EffectKind.pulse,.scanner,.sparkle,.colorChase] {
            var effect = Effect(name: "Test",kind: kind); effect.enabled = true; effect.depth = 1; effect.beatTiming = true
            store.project.effects = [effect]
            for fixture in store.project.fixtures {
                let a = store.renderedState(for: fixture.id), b = store.renderedState(for: fixture.id)
                XCTAssertTrue(a.channels.allSatisfy { $0.isFinite && (0...1).contains($0) })
                XCTAssertEqual(a.channels,b.channels)
            }
        }
    }
}
