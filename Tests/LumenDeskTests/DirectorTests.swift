import XCTest
@testable import LumenDesk
final class DirectorTests: XCTestCase {
    func testPhraseLookChangesOnlyEveryEightBars() {
        XCTAssertEqual(DirectorLook.current(beats: 31.99),.mirrored)
        XCTAssertEqual(DirectorLook.current(beats: 32),.fan)
        XCTAssertEqual(DirectorLook.current(beats: 64),.crossing)
        XCTAssertEqual(Set((0..<4).map { DirectorLook.current(beats: Double($0*32)).rawValue }).count,4)
    }
    func testRolePairMirrorsAndWashMovesLess() {
        let music = MusicSnapshot(level: 0.2,energy: 0.8,section: .drop)
        func render(_ i: Int,_ role: AutopilotRole) -> FixtureState {
            AutopilotRenderer.render(base: .off,snapshot: music,style: .techno,strength: 1,beats: 2,index: i,moving: true,fresh: true,role: role)
        }
        let left = render(0,.beam), right = render(1,.beam), wash = render(0,.wash)
        XCTAssertEqual(left.pan+right.pan,1,accuracy: 0.0001)
        XCTAssertLessThan(abs(wash.pan-0.5),abs(left.pan-0.5))
        XCTAssertLessThan(wash.dimmer,left.dimmer)
    }
    func testPhraseTransitionIsContinuousAndManualRoleUnchanged() {
        let music = MusicSnapshot(level: 0.2,energy: 0.6,section: .groove)
        func render(_ b: Double) -> FixtureState { AutopilotRenderer.render(base: .off,snapshot: music,style: .disco,strength: 1,beats: b,index: 0,moving: true,fresh: true) }
        let a = render(31.999), b = render(32.001)
        XCTAssertEqual(a.pan,b.pan,accuracy: 0.001); XCTAssertEqual(a.red,b.red,accuracy: 0.001)
        XCTAssertEqual(AutopilotRenderer.render(base: .off,snapshot: music,style: .disco,strength: 1,beats: 2,index: 0,moving: true,fresh: true,role: .manual),.off)
    }
    @MainActor func testSaveLookIncludesAutopilotWithoutBakingMasterOrBlackout() throws {
        let store = LightingStore(startTimer: false,clock: { 0 })
        store.autopilotEnabled = true; store.autopilotStrength = 1
        store.music = MusicSnapshot(level: 0.2,energy: 0.8,section: .drop); store.lastMusicTime = 0
        store.master = 0.1; store.blackout = true
        let id = store.project.fixtures[0].id
        let expected = store.renderedState(for: id,applyMaster: false)
        let cueID = store.saveAutopilotLook()
        let cue = try XCTUnwrap(store.project.cues.first(where: { $0.id == cueID }))
        XCTAssertEqual(cue.levels[id],expected); XCTAssertGreaterThan(expected.dimmer,0.5)
        XCTAssertEqual(store.renderedState(for: id).dimmer,0)
        let decoded = try JSONDecoder().decode(ShowProject.self,from: JSONEncoder().encode(store.project))
        XCTAssertEqual(decoded.cues.last?.levels[id],expected)
    }
    func testRigTemplateProfilesRolesAndPatch() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let show = try JSONDecoder().decode(ShowProject.self,from: Data(contentsOf: root.appendingPathComponent("Examples/AYRA-NGEAR-rig.lumendesk.json")))
        try show.validate()
        XCTAssertEqual(show.fixtures.map(\.address),[1,10,19,28,64])
        XCTAssertEqual(show.fixtures.map(\.autopilotRole),[.beam,.wash,.wash,.beam,.manual])
        XCTAssertEqual(show.fixtures[1].resolvedProfile.bytes(for: FixtureState())[2],134)
        XCTAssertEqual(show.fixtures[0].resolvedProfile.bytes(for: FixtureState())[1],0)
    }
    @MainActor func testManualFixtureBypassesAutopilotAndRolePersists() throws {
        let store = LightingStore(startTimer: false,clock: { 0 })
        store.project.fixtures[0].autopilotRole = .manual
        let id = store.project.fixtures[0].id
        store.autopilotEnabled = true; store.lastMusicTime = 0
        store.music = MusicSnapshot(level: 0.2,energy: 1,section: .drop)
        XCTAssertEqual(store.renderedState(for: id),store.state(for: id))
        let show = try JSONDecoder().decode(ShowProject.self,from: JSONEncoder().encode(store.project))
        XCTAssertEqual(show.fixtures[0].autopilotRole,.manual)
    }

    func testLaserModesAreDiscreteAndBlackoutSilencesAllChannels() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let profile = try JSONDecoder().decode(FixtureProfile.self,from: Data(contentsOf: root.appendingPathComponent("Examples/Laserworld-EL400RGB-MK2-9ch-profile.json")))
        try profile.validate()
        var state = FixtureState(); state.laserDMX = [200,42,0,0,255,128,128,23,5]
        XCTAssertEqual(profile.bytes(for: state),state.laserDMX)
        var off = state; off.dimmer = 0
        XCTAssertEqual(profile.bytes(for: off),[UInt8](repeating: 0,count: 9))
        XCTAssertEqual(off.blended(to: state,fraction: 0.5).laserDMX,off.laserDMX)
        let decoded = try JSONDecoder().decode(FixtureState.self,from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.laserDMX,state.laserDMX)
    }
    @MainActor func testAutopilotCannotActivateOrChangeLaserEvenWithBeamRole() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let store = LightingStore(startTimer: false,clock: { 0 })
        store.project = try JSONDecoder().decode(ShowProject.self,from: Data(contentsOf: root.appendingPathComponent("Examples/AYRA-NGEAR-rig.lumendesk.json")))
        store.project.fixtures[4].autopilotRole = .beam
        let id = store.project.fixtures[4].id
        store.fixtureStates[id] = .off
        store.autopilotEnabled = true; store.lastMusicTime = 0
        store.music = MusicSnapshot(level: 0.8,energy: 1,section: .drop)
        XCTAssertEqual(Array(store.frame[63..<72]),[UInt8](repeating: 0,count: 9))
        var manual = FixtureState(); manual.laserDMX = [150,8,0,0,200,100,128,12,0]; store.fixtureStates[id] = manual
        XCTAssertEqual(store.renderedState(for: id),manual)
        store.blackout = true
        XCTAssertEqual(Array(store.frame[63..<72]),[UInt8](repeating: 0,count: 9))
        store.blackout = false; store.stop()
        XCTAssertEqual(store.state(for: id).laserDMX?[0],0)
        XCTAssertEqual(Array(store.frame[63..<72]),[UInt8](repeating: 0,count: 9))
    }

    @MainActor func testNamedLaserBoardControlsPreserveHeadsAndAutopilot() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let store = LightingStore(startTimer: false,clock: { 0 })
        store.project = try JSONDecoder().decode(ShowProject.self,from: Data(contentsOf: root.appendingPathComponent("Examples/AYRA-NGEAR-rig.lumendesk.json")))
        try store.project.validate()
        let headID = store.project.fixtures[0].id, laserID = store.project.fixtures[4].id
        store.fixtureStates[headID] = FixtureState(dimmer: 0.7,red: 0.4)
        let before = store.state(for: headID)
        store.autopilotEnabled = true
        let controls = try XCTUnwrap(store.project.liveBoard).controls
        store.boardPress(try XCTUnwrap(controls.first(where: { $0.label == "Sound mode" })))
        XCTAssertEqual(store.state(for: laserID).laserDMX?[0],50)
        store.boardPress(try XCTUnwrap(controls.first(where: { $0.label == "Red" })))
        XCTAssertEqual(store.state(for: laserID).laserDMX?[7],12)
        store.boardPress(try XCTUnwrap(controls.first(where: { $0.label == "Double scan" })))
        XCTAssertEqual(store.state(for: laserID).laserDMX?[1],127)
        XCTAssertEqual(store.state(for: headID),before); XCTAssertTrue(store.autopilotEnabled)
        store.boardPress(try XCTUnwrap(controls.first(where: { $0.label == "Laser OFF" })))
        XCTAssertEqual(Array(store.frame[63..<72]),[UInt8](repeating: 0,count: 9))
    }
    func testMalformedLaserStateIsRejected() throws {
        var state = FixtureState(); state.laserDMX = [0,1]
        XCTAssertThrowsError(try JSONDecoder().decode(FixtureState.self,from: JSONEncoder().encode(state)))
    }

    func testComputerAudioFeaturesRejectInvalidSamplesAndProduceFiniteLevels() {
        var extractor = AudioFeatureAccumulator()
        XCTAssertNil(extractor.feed(.nan,sampleRate: 48000))
        XCTAssertNil(extractor.feed(0.1,sampleRate: 0))
        var outputs = [(Double,Double,Double)]()
        for i in 0..<4800 {
            if let result = extractor.feed(sin(Double(i)*2*Double.pi*120/48000)*0.2,sampleRate: 48000) { outputs.append(result) }
        }
        XCTAssertEqual(outputs.count,5)
        XCTAssertTrue(outputs.allSatisfy { $0.0.isFinite && $0.1.isFinite && $0.2.isFinite && $0.0 > 0.1 })
    }
    @MainActor func testStopListeningResetsEverySourceAndAutopilot() {
        let store = LightingStore(startTimer: false)
        store.musicInput = .computer; store.audioDemo = true; store.listening = true; store.autopilotEnabled = true
        store.stopListening()
        XCTAssertFalse(store.listening); XCTAssertFalse(store.audioDemo); XCTAssertFalse(store.autopilotEnabled)
        XCTAssertNil(store.systemAudio); XCTAssertNil(store.microphone)
        XCTAssertEqual(store.musicInput,.computer)
    }

    @MainActor func testDemoTempoRemains120WithoutFollowingAliasEstimates() {
        let store = LightingStore(startTimer: false,clock: { 0 })
        store.startAudioDemo()
        for i in 0..<600 { store.receiveMusic(level: i%50 == 0 ? 0.4 : 0.04,bass: 0.1,high: 0.05,at: Double(i)/50) }
        XCTAssertEqual(store.bpm,120)
        XCTAssertTrue(store.autopilotEnabled)
    }
}
