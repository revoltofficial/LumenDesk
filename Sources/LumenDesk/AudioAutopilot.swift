import SwiftUI
import AVFoundation

final class MicrophoneListener {
    private let engine = AVAudioEngine()
    private var tapped = false
    private var observer: NSObjectProtocol?
    func start(receive: @escaping (Double,Double,Double,Double) -> Void, failed: @escaping () -> Void) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw NSError(domain: "LumenDesk.Audio",code: 1,userInfo: [NSLocalizedDescriptionKey:"No microphone input is available."]) }
        var low = 0.0, sum = 0.0, lowSum = 0.0, highSum = 0.0, count = 0
        let window = max(1,Int(format.sampleRate/50))
        let alpha = 1-exp(-2*Double.pi*180/format.sampleRate)
        input.installTap(onBus: 0,bufferSize: 1024,format: format) { buffer, _ in
            guard let channels = buffer.floatChannelData else { return }
            for frame in 0..<Int(buffer.frameLength) {
                var sample = 0.0
                for channel in 0..<Int(buffer.format.channelCount) { sample += Double(channels[channel][frame]) }
                sample /= Double(buffer.format.channelCount)
                low += alpha*(sample-low)
                let high = sample-low
                sum += sample*sample; lowSum += low*low; highSum += high*high; count += 1
                if count >= window {
                    receive(sqrt(sum/Double(count)),sqrt(lowSum/Double(count)),sqrt(highSum/Double(count)),ProcessInfo.processInfo.systemUptime)
                    sum = 0; lowSum = 0; highSum = 0; count = 0
                }
            }
        }
        tapped = true
        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,object: engine,queue: .main) { _ in failed() }
        engine.prepare()
        do { try engine.start() } catch { stop(); throw error }
    }
    func stop() {
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        engine.stop()
        if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil
    }
    deinit { stop() }
}
extension LightingStore {
    @discardableResult func saveAutopilotLook() -> UUID {
        let cue = Cue(name: "Autopilot · \(DirectorLook.current(beats: tempoClock.beats).title) · \(project.cues.count+1)",
                      levels: Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id,renderedState(for: $0.id,applyMaster: false)) }))
        project.cues.append(cue); selectedCueID = cue.id
        return cue.id
    }

    func startListening() {
        stopListening()
        if musicInput == .computer { startComputerAudio(); return }
        let session = UUID(); audioSession = session
        microphoneStatus = "Awaiting microphone permission"
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                guard let self, self.audioSession == session else { return }
                guard granted else { self.microphoneStatus = "Microphone permission denied — enable it in System Settings"; return }
                do {
                    let listener = MicrophoneListener()
                    self.microphone = listener
                    try listener.start(receive: { [weak self] level,bass,high,time in
                        Task { @MainActor in
                            guard let self, self.audioSession == session, self.listening else { return }
                            self.receiveMusic(level: level,bass: bass,high: high,at: time)
                        }
                    },failed: { [weak self] in
                        Task { @MainActor in
                            guard let self, self.audioSession == session else { return }
                            self.stopListening(); self.microphoneStatus = "Audio device changed — start listening again"
                        }
                    })
                    self.listening = true; self.microphoneStatus = "Listening · system microphone input"
                } catch { self.stopListening(); self.microphoneStatus = error.localizedDescription }
            }
        }
    }
    func startComputerAudio() {
        let session = UUID(); audioSession = session
        microphoneStatus = "Awaiting computer-audio permission"
        let listener = SystemAudioListener(); systemAudio = listener
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await listener.start(receive: { [weak self] level,bass,high,time in
                    Task { @MainActor in
                        guard let self, self.audioSession == session, self.listening else { return }
                        self.receiveMusic(level: level,bass: bass,high: high,at: time)
                    }
                },failed: { [weak self] in
                    Task { @MainActor in
                        guard let self, self.audioSession == session else { return }
                        self.stopListening(); self.microphoneStatus = "Computer audio stopped — start listening again"
                    }
                })
                guard self.audioSession == session else { listener.stop(); return }
                self.listening = true; self.microphoneStatus = "Listening · computer audio"
            } catch {
                guard self.audioSession == session else { listener.stop(); return }
                self.stopListening(); self.microphoneStatus = error.localizedDescription
            }
        }
    }
    func stopListening() {
        audioSession = UUID(); microphone?.stop(); microphone = nil; systemAudio?.stop(); systemAudio = nil
        listening = false; audioDemo = false; autopilotEnabled = false
        musicAnalyzer = MusicAnalyzer(); music = MusicSnapshot(); lastMusicTime = -.infinity
        lastTempoUpdate = -.infinity; microphoneStatus = "Audio input off"
    }
    func startAudioDemo() {
        stopListening(); setBPM(120); syncTempo(); audioDemo = true; microphoneStatus = "Demo audio · synthetic 120 BPM rhythm"; autopilotEnabled = true
    }
    func receiveMusic(level: Double,bass: Double,high: Double,at time: Double) {
        guard time >= lastMusicTime else { return }
        music = musicAnalyzer.process(level: level,bass: bass,high: high,time: time)
        lastMusicTime = time
        if !audioDemo, automaticTempo, music.confidence >= 0.55, music.beat { tempoClock.alignBeat() }
        if !audioDemo, automaticTempo, let detected = music.bpm, music.confidence >= 0.55, time-lastTempoUpdate >= 1 {
            // Gradual changes avoid abrupt jumps from noisy half/double-time estimates.
            project.tempo = TempoSettings(bpm: bpm*0.8+detected*0.2)
            lastTempoUpdate = time
        }
    }
}
struct AutopilotControls: View {
    @EnvironmentObject var store: LightingStore
    @State private var settings = false
    var body: some View {
        HStack(spacing: 6) {
            Button { settings.toggle() } label: { Label("Autopilot",systemImage: "waveform") }
                .popover(isPresented: $settings) { panel }
            Text(store.autopilotEnabled ? store.music.section.rawValue : (store.listening ? "Listening" : "Off")).font(.caption).foregroundStyle(store.autopilotEnabled ? .mint : .secondary)
            if store.listening || store.audioDemo { ProgressView(value: min(1,store.music.level*4)).frame(width: 50) }
        }
    }
    private var panel: some View {
        VStack(alignment: .leading,spacing: 12) {
            Text("Music Autopilot · experimental").font(.headline)
            Text("Listen locally to the DJ. No audio is saved or uploaded.").font(.caption).foregroundStyle(.secondary)
            Picker("Audio source",selection: $store.musicInput) {
                ForEach(MusicInput.allCases,id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).onChange(of: store.musicInput) { _,_ in store.stopListening() }
            if store.musicInput == .computer {
                Text("Captures sound playing on this Mac. macOS requires screen/system-audio permission; no screen images are saved.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button(store.listening || store.audioDemo ? "Stop listening" : "Listen to \(store.musicInput.title.lowercased())") { if store.listening || store.audioDemo { store.stopListening() } else { store.startListening() } }
                Button("Try demo") { store.startAudioDemo() }
            }
            Text(store.microphoneStatus).font(.caption).fixedSize(horizontal: false,vertical: true)
            Toggle("Follow detected BPM",isOn: $store.automaticTempo)
            Toggle("Autopilot lighting",isOn: $store.autopilotEnabled).disabled(!store.listening && !store.audioDemo)
            Picker("Style",selection: $store.musicStyle) { ForEach(MusicStyle.allCases,id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Text("Auto uses tonal balance; choose Disco or Techno to set the palette yourself.").font(.caption).foregroundStyle(.secondary)
            HStack { Text("Intensity"); Slider(value: $store.autopilotStrength,in: 0...1) }
            Text("\(store.music.section.rawValue) · tempo confidence \(Int(store.music.confidence*100))%")
            Text(store.audioDemo ? "Demo rhythm · 120 BPM" : (store.music.bpm.map { "Estimated \($0.formatted(.number.precision(.fractionLength(1)))) BPM" } ?? "Waiting for a steady beat…")).font(.caption)
            Text("\(DirectorLook.current(beats: store.tempoClock.beats).title) · bar \(Int(store.tempoClock.beats/4)%8+1) of 8").font(.caption)
            Text("Phrase timing follows BPM and Sync. Section detection estimates energy changes; it cannot predict an unknown track.").font(.caption).foregroundStyle(.secondary)
            Button("Save this look") { store.saveAutopilotLook() }.disabled(!store.autopilotEnabled)
            Text("Saved in the cue library. Turn Autopilot off to replay it; assign it to a board button in Edit board.").font(.caption).foregroundStyle(.secondary)
            Text("Breaks soften the look; strong returns add colour and movement. Blackout and Master always take priority. Stop exits Autopilot.").font(.caption).foregroundStyle(.secondary)
        }.padding(18).frame(width: 360)
    }
}
