import Foundation
import Darwin
import USBSerial

enum OutputTransport: String, Codable, CaseIterable, Identifiable {
    case artNet, openDMX
    var id: String { rawValue }
    var title: String { self == .artNet ? "Art-Net" : "Open DMX USB · experimental" }
}
final class OpenDMXOutput {
    private let queue = DispatchQueue(label:"LumenDesk.OpenDMX",qos:.userInitiated)
    private var timer: DispatchSourceTimer?
    private var fd: Int32 = -1
    private var frame = [UInt8](repeating:0,count:512)
    var onError: ((String)->Void)?
    static func devices() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath:"/dev")) ?? []).filter { $0.hasPrefix("cu.usbserial") }.sorted().map { "/dev/"+$0 }
    }
    static func packet(_ frame: [UInt8]) -> [UInt8]? { frame.count == 512 ? [0]+frame : nil }
    func start(path: String) throws {
        guard Self.devices().contains(path) else { throw ProjectError.invalid("Select a detected FTDI USB serial cable. Plug it in and refresh the device list.") }
        try queue.sync {
            closePort()
            fd = path.withCString { ld_dmx_open($0) }
            guard fd >= 0 else { throw ProjectError.invalid("Cannot open USB cable: \(String(cString:strerror(errno))). Close other lighting apps and check the cable driver.") }
            frame = [UInt8](repeating:0,count:512)
            let timer = DispatchSource.makeTimerSource(queue:queue)
            timer.schedule(deadline:.now(),repeating:.milliseconds(40),leeway:.milliseconds(1))
            timer.setEventHandler { [weak self] in self?.transmit() }
            self.timer = timer; timer.resume()
        }
    }
    func send(frame: [UInt8]) { guard frame.count == 512 else { return }; queue.async { self.frame = frame } }
    private func transmit() {
        guard fd >= 0, let bytes = Self.packet(frame) else { return }
        let result = bytes.withUnsafeBufferPointer { ld_dmx_write(fd,$0.baseAddress,Int32($0.count)) }
        if result != 0 { let message = String(cString:strerror(errno)); closePort(); onError?("USB output stopped: \(message)") }
    }
    private func closePort() { timer?.cancel(); timer = nil; ld_dmx_close(fd); fd = -1 }
    func stop() {
        queue.async {
            if self.fd >= 0 {
                self.frame = [UInt8](repeating:0,count:512); self.transmit()
                // 513 slots take about 23 ms at 250 kbit/s. Let the dark frame drain.
                usleep(30000)
            }
            self.closePort()
        }
    }
    deinit { timer?.cancel(); ld_dmx_close(fd) }
}
