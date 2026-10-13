import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreGraphics
import AudioToolbox

enum MusicInput: String, CaseIterable { case microphone, computer
    var title: String { self == .microphone ? "Microphone" : "Computer audio" }
}
struct AudioFeatureAccumulator {
    private var low = 0.0, sum = 0.0, lowSum = 0.0, highSum = 0.0
    private var count = 0
    mutating func feed(_ sample: Double,sampleRate: Double) -> (Double,Double,Double)? {
        guard sample.isFinite, sampleRate.isFinite, sampleRate > 0 else { return nil }
        let alpha = 1-exp(-2*Double.pi*180/sampleRate)
        low += alpha*(sample-low)
        let high = sample-low
        sum += sample*sample; lowSum += low*low; highSum += high*high; count += 1
        guard count >= max(1,Int(sampleRate/50)) else { return nil }
        let result = (sqrt(sum/Double(count)),sqrt(lowSum/Double(count)),sqrt(highSum/Double(count)))
        sum = 0; lowSum = 0; highSum = 0; count = 0
        return result
    }
}
final class SystemAudioListener: NSObject, SCStreamOutput, SCStreamDelegate {
    private var capture: SCStream?
    private let queue = DispatchQueue(label: "LumenDesk.systemAudio")
    private var features = AudioFeatureAccumulator()
    private var receive: ((Double,Double,Double,Double) -> Void)?
    private var failed: (() -> Void)?
    func start(receive: @escaping (Double,Double,Double,Double) -> Void,failed: @escaping () -> Void) async throws {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw NSError(domain: "LumenDesk.Audio",code: 2,userInfo: [NSLocalizedDescriptionKey:"Allow LumenDesk in System Settings → Privacy & Security → Screen & System Audio Recording, then reopen the app if macOS asks."])
        }
        self.receive = receive; self.failed = failed
        let content = try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw NSError(domain: "LumenDesk.Audio",code: 3,userInfo: [NSLocalizedDescriptionKey:"No display is available for computer-audio capture."]) }
        let filter = SCContentFilter(display: display,excludingApplications: [],exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true; config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000; config.channelCount = 2
        config.width = 2; config.height = 2; config.minimumFrameInterval = CMTime(value: 1,timescale: 1)
        // Register only audio output. No screen samples or recording files are retained.
        let stream = SCStream(filter: filter,configuration: config,delegate: self)
        try stream.addStreamOutput(self,type: .audio,sampleHandlerQueue: queue)
        capture = stream
        do { try await stream.startCapture() } catch { capture = nil; throw error }
    }
    func stop() {
        let stream = capture; capture = nil
        Task { try? await stream?.stopCapture() }
    }
    func stream(_ stream: SCStream,didStopWithError error: Error) { failed?() }
    func stream(_ stream: SCStream,didOutputSampleBuffer sampleBuffer: CMSampleBuffer,of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid,
              let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              asbd.mFormatID == kAudioFormatLinearPCM, asbd.mBitsPerChannel == 32,
              asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 else { return }
        let channels = Int(asbd.mChannelsPerFrame)
        guard channels > 0, channels <= 32 else { return }
        let size = MemoryLayout<AudioBufferList>.size+(channels-1)*MemoryLayout<AudioBuffer>.size
        let storage = UnsafeMutableRawPointer.allocate(byteCount: size,alignment: 16)
        defer { storage.deallocate() }
        let list = storage.bindMemory(to: AudioBufferList.self,capacity: 1)
        var retained: CMBlockBuffer?
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,bufferListSizeNeededOut: nil,
              bufferListOut: list,bufferListSize: size,blockBufferAllocator: kCFAllocatorDefault,
              blockBufferMemoryAllocator: kCFAllocatorDefault,flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),blockBufferOut: &retained) == noErr else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        for frame in 0..<CMSampleBufferGetNumSamples(sampleBuffer) {
            var mono = 0.0, count = 0
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let samples = data.assumingMemoryBound(to: Float.self), n = Int(buffer.mNumberChannels)
                for channel in 0..<n where (frame*n+channel)*MemoryLayout<Float>.size < Int(buffer.mDataByteSize) {
                    mono += Double(samples[frame*n+channel]); count += 1
                }
            }
            if count > 0, let feature = features.feed(mono/Double(count),sampleRate: asbd.mSampleRate) {
                receive?(feature.0,feature.1,feature.2,ProcessInfo.processInfo.systemUptime)
            }
        }
        withExtendedLifetime(retained) {}
    }
}
