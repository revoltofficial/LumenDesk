import AVFoundation
import Foundation

struct SongAudioData: Sendable {
    var name: String
    var duration: Double
    var waveform: [Double]
}
enum SongAudioReader {
    static func read(_ url: URL) throws -> SongAudioData {
        let file = try AVAudioFile(forReading:url,commonFormat:.pcmFormatFloat32,interleaved:false)
        let rate = file.processingFormat.sampleRate, length = file.length
        guard rate > 0, length > 0, Double(length)/rate <= 7200 else { throw ProjectError.invalid("Choose audio shorter than two hours.") }
        let bins = min(1200,max(1,Int(length)))
        var peaks = [Double](repeating:0,count:bins)
        guard let buffer = AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:65536) else { throw ProjectError.invalid("Unable to decode this audio file.") }
        var offset: AVAudioFramePosition = 0
        while offset < length {
            try Task.checkCancellation()
            try file.read(into:buffer,frameCount:AVAudioFrameCount(min(65536,length-offset)))
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            // Representative envelope; decoding is bounded to one chunk in memory.
            for frame in stride(from:0,to:Int(buffer.frameLength),by:16) {
                let bin = min(bins-1,Int(Double(offset+AVAudioFramePosition(frame))/Double(length)*Double(bins)))
                for channel in 0..<Int(buffer.format.channelCount) {
                    let value = abs(Double(channels[channel][frame]))
                    if value.isFinite { peaks[bin] = max(peaks[bin],value) }
                }
            }
            offset += AVAudioFramePosition(buffer.frameLength)
        }
        let maximum = max(0.000001,peaks.max() ?? 1)
        return SongAudioData(name:url.lastPathComponent,duration:Double(length)/rate,waveform:peaks.map { min(1,$0/maximum) })
    }
    static func demo(duration: Double = 30) throws -> URL {
        let rate = 22050.0
        guard duration.isFinite, (0.05...60).contains(duration), let format = AVAudioFormat(standardFormatWithSampleRate:rate,channels:1), let buffer = AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(rate*duration)), let samples = buffer.floatChannelData?[0] else { throw ProjectError.invalid("Cannot create rehearsal audio.") }
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) {
            let t = Double(i)/rate, beat = t.truncatingRemainder(dividingBy:0.5)
            let energy = t < duration/3 ? 0.14 : (t < duration*2/3 ? 0.04 : 0.22)
            samples[i] = Float(energy*sin(t*2*Double.pi*90)*exp(-beat*25)+0.025*sin(t*2*Double.pi*330))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LumenDesk-rehearsal-\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting:url,settings:format.settings)
        try file.write(from:buffer)
        return url
    }
}
