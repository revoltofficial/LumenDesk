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
}
