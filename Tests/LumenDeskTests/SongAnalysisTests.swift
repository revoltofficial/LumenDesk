import XCTest
@testable import LumenDesk

final class SongAnalysisTests: XCTestCase {
    func testSilenceAndInvalidInputDoNotInventTempo() {
        XCTAssertNil(SongAnalyzer.analyze(energy:Array(repeating:0,count:1500),duration:30).bpm)
        XCTAssertNil(SongAnalyzer.analyze(energy:[.nan],duration:30).bpm)
    }
    func testRepeatedPulsesSuggest120BPM() {
        let energy = (0..<1500).map { i in i%25 < 2 ? 1.0 : 0.02 }
        let result = SongAnalyzer.analyze(energy:energy,duration:30)
        XCTAssertEqual(result.bpm ?? 0,120,accuracy:3)
        XCTAssertGreaterThan(result.confidence,0.8)
    }
    func testEnergyChangesSuggestBreakAndDrop() {
        let energy = (0..<1500).map { i in i < 500 ? 0.5 : (i < 1000 ? 0.1 : 0.9) }
        let result = SongAnalyzer.analyze(energy:energy,duration:30)
        XCTAssertTrue(result.markers.contains { $0.name == "Break?" && abs($0.time-10)<1 })
        XCTAssertTrue(result.markers.contains { $0.name == "Drop?" && abs($0.time-20)<1 })
        XCTAssertTrue(result.markers.allSatisfy { $0.time < 30 })
    }
    @MainActor func testGenerationKeepsSavedCuesAndExcludesLaser() throws {
        let store = LightingStore(startTimer:false)
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        store.project = try JSONDecoder().decode(ShowProject.self,from:Data(contentsOf:root.appendingPathComponent("Examples/AYRA-NGEAR-rig.lumendesk.json")))
        let saved = Set(store.project.cues.map(\.id))
        let laser = store.project.fixtures[4].id
        store.songAnalysis = SongAnalysis(bpm:120,confidence:0.9,markers:[SongMarker(time:0,name:"Intro"),SongMarker(time:20,name:"Drop?")])
        store.applySongAnalysis(generate:true)
        XCTAssertEqual(store.songTimeline.events.count,2)
        XCTAssertTrue(saved.isSubset(of:Set(store.project.cues.map(\.id))))
        for event in store.songTimeline.events {
            let cue = try XCTUnwrap(store.project.cues.first { $0.id == event.cueID })
            XCTAssertEqual(cue.levels.count,4); XCTAssertNil(cue.levels[laser])
        }
        XCTAssertFalse(store.outputEnabled); XCTAssertFalse(store.timelinePlaying)
        try store.project.validate()
    }
}
