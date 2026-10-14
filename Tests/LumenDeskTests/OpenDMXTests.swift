import XCTest
@testable import LumenDesk

final class OpenDMXTests: XCTestCase {
    func testDMXFrameHasZeroStartCodeAnd512UnchangedSlots() {
        let levels = (0..<512).map { UInt8($0%256) }
        let packet = OpenDMXOutput.packet(levels)
        XCTAssertEqual(packet?.count,513); XCTAssertEqual(packet?.first,0)
        XCTAssertEqual(packet.map { Array($0.dropFirst()) },levels)
        XCTAssertNil(OpenDMXOutput.packet([0]))
    }
    func testNonDevicePathRejectedWithoutOpeningIt() {
        let output = OpenDMXOutput()
        XCTAssertThrowsError(try output.start(path:"/tmp/not-a-dmx-device"))
    }
    @MainActor func testMissingCableCannotEnableOutput() {
        let store = LightingStore(startTimer:false)
        store.project.outputTransport = .openDMX; store.project.usbDevice = "/dev/cu.usbserial-not-present"
        store.startOutput(); XCTAssertFalse(store.outputEnabled); XCTAssertNotNil(store.errorMessage)
        store.stopOutput(); XCTAssertFalse(store.outputEnabled)
    }
    func testLegacyShowDefaultsToArtNet() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let show = try JSONDecoder().decode(ShowProject.self,from:Data(contentsOf:root.appendingPathComponent("Examples/AYRA-NGEAR-rig.lumendesk.json")))
        XCTAssertEqual(show.outputTransport ?? .artNet,.artNet)
        try show.validate()
    }
}
