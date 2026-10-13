import Foundation
import Network

/// ArtDMX per Artistic Licence Art-Net 4 specification: UDP 6454,
/// little-endian opcode and port-address, big-endian protocol and length.
/// Art-Net™ Designed by and Copyright Artistic Licence Engineering Ltd.
final class ArtNetOutput {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "LumenDesk.ArtNet")
    private var sequence: UInt8 = 0
    var onError: ((String) -> Void)?

    static func packet(frame: [UInt8], universe: Int, sequence: UInt8) -> Data {
        precondition(frame.count == 512)
        precondition((1...32768).contains(universe))
        let address = UInt16(universe - 1)
        var bytes: [UInt8] = [65,114,116,45,78,101,116,0,0,0x50,0,14,sequence,0,
                             UInt8(address & 0xff), UInt8((address >> 8) & 0x7f),2,0]
        bytes.append(contentsOf: frame)
        return Data(bytes)
    }
    func start(destination: String) {
        stop()
        sequence = 0
        let next = NWConnection(host: NWEndpoint.Host(destination), port: NWEndpoint.Port(rawValue: 6454)!, using: .udp)
        next.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state { self?.onError?(error.localizedDescription) }
        }
        connection = next
        next.start(queue: queue)
    }
    func send(frame: [UInt8], universe: Int) {
        guard let connection else { return }
        sequence = sequence == 255 ? 1 : sequence + 1
        connection.send(content: Self.packet(frame: frame, universe: universe, sequence: sequence), completion: .contentProcessed { [weak self] error in
            if let error { self?.onError?(error.localizedDescription) }
        })
    }
    /// Drain a final dark frame before closing this specific connection.
    /// A replacement connection can start immediately and is never cancelled here.
    func finish(universe: Int) {
        guard let finishing = connection else { return }
        connection = nil
        finishing.stateUpdateHandler = nil
        sequence = sequence == 255 ? 1 : sequence + 1
        let packet = Self.packet(frame: [UInt8](repeating: 0, count: 512), universe: universe, sequence: sequence)
        finishing.send(content: packet, completion: .contentProcessed { _ in finishing.cancel() })
        queue.asyncAfter(deadline: .now() + 1) { finishing.cancel() }
    }
    func stop() { connection?.cancel(); connection = nil }
    deinit { connection?.cancel() }
}
