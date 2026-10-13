import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor final class LightingStore: ObservableObject {
    @Published var project = ShowProject.demo
    @Published var selectedFixtureID: UUID?
    @Published var selectedCueID: UUID?
    @Published var master: Double = 1
    @Published var blackout = false
    @Published var activeCueID: UUID?
    @Published var outputEnabled = false
    @Published var errorMessage: String?
    @Published var phase: Double = 0
    @Published var fixtureStates: [UUID: FixtureState] = [:]
    @Published private(set) var sequencePlayer: SequencePlayer?
    private var sequenceCues: [UUID: Cue] = [:]
    private var sequencePausedAt: TimeInterval?
    private let clock: () -> TimeInterval
    private let output = ArtNetOutput()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var fadeStart: TimeInterval?
    private var fadeDuration: Double = 0
    private var fadeFrom: [UUID: FixtureState] = [:]
    private var fadeTo: [UUID: FixtureState] = [:]
    private var connectedDestination = ""
    private var lastOutputUniverse = 1

    init(startTimer: Bool = true, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.clock = clock
        lastTick = clock()
        selectedFixtureID = project.fixtures.first?.id
        selectedCueID = project.cues.first?.id
        fixtureStates = project.cues.first?.levels ?? [:]
        output.onError = { [weak self] message in
            Task { @MainActor in
                self?.errorMessage = "Art-Net output: \(message)"
                self?.stopOutput()
            }
        }
        if startTimer {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }
    func state(for id: UUID) -> FixtureState { fixtureStates[id] ?? .off }
    func setState(id: UUID, state: FixtureState) {
        cancelSequence()
        fadeStart = nil
        activeCueID = nil
        fixtureStates[id] = state
    }
    func addFixture() {
        var used = Set<Int>()
        for fixture in project.fixtures where fixture.address >= 1 && fixture.address <= 513 - fixture.kind.footprint {
            used.formUnion(fixture.address..<(fixture.address + fixture.kind.footprint))
        }
        guard let address = (1...510).first(where: { start in (start..<(start + 3)).allSatisfy { !used.contains($0) } }) else {
            errorMessage = "There are no three adjacent free DMX channels."; return
        }
        let fixture = Fixture(name: "Wash \(project.fixtures.count + 1)", kind: .rgb, address: address)
        project.fixtures.append(fixture)
        fixtureStates[fixture.id] = .off
        selectedFixtureID = fixture.id
    }
    func removeFixture(id: UUID) {
        cancelSequence()
        project.fixtures.removeAll { $0.id == id }
        fixtureStates.removeValue(forKey: id)
        for index in project.cues.indices { project.cues[index].levels.removeValue(forKey: id) }
        if selectedFixtureID == id { selectedFixtureID = project.fixtures.first?.id }
    }
    func captureCue() {
        let cue = Cue(name: "Scene \(project.cues.count + 1)", levels: Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id, state(for: $0.id)) }))
        project.cues.append(cue)
        selectedCueID = cue.id
    }
    func activateCue(id: UUID) {
        guard let cue = project.cues.first(where: { $0.id == id }) else { return }
        cancelSequence()
        applyCue(cue)
    }
    private func applyCue(_ cue: Cue) {
        fadeFrom = Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id, state(for: $0.id)) })
        fadeTo = Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id, cue.levels[$0.id] ?? .off) })
        fadeDuration = max(0, cue.fadeSeconds.isFinite ? cue.fadeSeconds : 0)
        fadeStart = clock()
        activeCueID = cue.id
        selectedCueID = cue.id
        if fadeDuration == 0 { fixtureStates = fadeTo; fadeStart = nil }
    }
    var nextCueID: UUID? {
        guard !project.cues.isEmpty else { return nil }
        guard let id = activeCueID, let index = project.cues.firstIndex(where: { $0.id == id }) else { return project.cues.first?.id }
        return project.cues.indices.contains(index + 1) ? project.cues[index + 1].id : nil
    }
    func goNext() { if let id = nextCueID { activateCue(id: id) } }
    func updateSelectedCue() {
        guard let id = selectedCueID, let index = project.cues.firstIndex(where: { $0.id == id }) else { return }
        project.cues[index].levels = Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id, state(for: $0.id)) })
    }
    func removeCue(id: UUID) {
        if sequenceCues[id] != nil { cancelSequence() }
        if activeCueID == id { stop() }
        project.cues.removeAll { $0.id == id }
        if selectedCueID == id { selectedCueID = project.cues.first?.id }
    }
    func stop() {
        cancelSequence()
        fadeStart = nil
        activeCueID = nil
        fixtureStates = Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id, FixtureState.off) })
        for index in project.effects.indices { project.effects[index].enabled = false }
    }
    var sequenceRemaining: Double {
        guard let player = sequencePlayer else { return 0 }
        return player.pausedRemaining ?? max(0, player.deadline - clock())
    }
    func startSequence() {
        do { try project.validate() } catch { errorMessage = error.localizedDescription; return }
        cancelSequence()
        guard let player = SequencePlayer(cues: project.cues, settings: project.sequenceSettings ?? SequenceSettings(), now: clock()) else { return }
        sequenceCues = Dictionary(uniqueKeysWithValues: project.cues.map { ($0.id, $0) })
        sequencePlayer = player
        if let cue = sequenceCues[player.currentCueID] { applyCue(cue) }
    }
    func toggleSequencePause() {
        guard var player = sequencePlayer else { return }
        let now = clock()
        if player.isPaused {
            if let pausedAt = sequencePausedAt, let start = fadeStart { fadeStart = start + now - pausedAt }
            player.resume(now: now)
            sequencePausedAt = nil
        } else {
            tick()
            guard let current = sequencePlayer else { return }
            player = current
            player.pause(now: now)
            sequencePausedAt = now
        }
        sequencePlayer = player
    }
    private func cancelSequence() {
        if let pausedAt = sequencePausedAt, let start = fadeStart { fadeStart = start + clock() - pausedAt }
        sequencePlayer = nil
        sequenceCues = [:]
        sequencePausedAt = nil
    }
    func tick() {
        let now = clock()
        phase += min(0.25, max(0, now - lastTick))
        lastTick = now
        if let start = fadeStart, sequencePlayer?.isPaused != true {
            let fraction = fadeDuration <= 0 ? 1 : min(1, (now - start) / fadeDuration)
            for fixture in project.fixtures { fixtureStates[fixture.id] = (fadeFrom[fixture.id] ?? .off).blended(to: fadeTo[fixture.id] ?? .off, fraction: fraction) }
            if fraction >= 1 { fadeStart = nil }
        }
        if var player = sequencePlayer {
            let next = player.advance(now: now)
            sequencePlayer = player
            if let id = next, let cue = sequenceCues[id] { applyCue(cue) }
            if player.finished { cancelSequence() }
        }
        if outputEnabled {
            do {
                try project.validate()
                if connectedDestination != project.destination {
                    output.finish(universe: lastOutputUniverse)
                    output.start(destination: project.destination)
                    connectedDestination = project.destination
                }
                if lastOutputUniverse != project.universe {
                    output.send(frame: [UInt8](repeating: 0, count: 512), universe: lastOutputUniverse)
                    lastOutputUniverse = project.universe
                }
                output.send(frame: frame, universe: project.universe)
            } catch { errorMessage = error.localizedDescription; stopOutput() }
        }
    }
    func renderedState(for id: UUID) -> FixtureState {
        var result = state(for: id)
        let index = project.fixtures.firstIndex(where: { $0.id == id }) ?? 0
        let count = max(1, project.fixtures.count)
        for effect in project.effects where effect.enabled && effect.rate.isFinite && effect.depth.isFinite {
            let position = phase * max(0, effect.rate) + Double(index) / Double(count)
            let depth = min(1, max(0, effect.depth))
            switch effect.kind {
            case .sine: result.dimmer *= 1 - depth + depth * (sin(position * 2 * .pi) + 1) / 2
            case .chase:
                let step = Int((phase * max(0, effect.rate)).truncatingRemainder(dividingBy: Double(count)))
                result.dimmer *= index == step ? 1 : 1 - depth
            case .rainbow:
                let hue = position - floor(position)
                let color = NSColor(calibratedHue: hue, saturation: 1, brightness: 1, alpha: 1)
                result.red = result.red * (1 - depth) + Double(color.redComponent) * depth
                result.green = result.green * (1 - depth) + Double(color.greenComponent) * depth
                result.blue = result.blue * (1 - depth) + Double(color.blueComponent) * depth
            }
        }
        result.dimmer *= blackout ? 0 : (master.isFinite ? min(1,max(0,master)) : 0)
        return result
    }
    var frame: [UInt8] {
        var values = [UInt8](repeating: 0, count: 512)
        // Invalid live edits silence output instead of sending overlapping patches.
        guard (try? project.validate()) != nil else { return values }
        func byte(_ value: Double) -> UInt8 { UInt8((min(1, max(0, value.isFinite ? value : 0)) * 255).rounded()) }
        for fixture in project.fixtures {
            let state = renderedState(for: fixture.id)
            let channels: [Double]
            switch fixture.kind {
            case .dimmer: channels = [state.dimmer]
            case .rgb: channels = [state.red * state.dimmer,state.green * state.dimmer,state.blue * state.dimmer]
            case .rgbw: channels = [state.red * state.dimmer,state.green * state.dimmer,state.blue * state.dimmer,state.white * state.dimmer]
            }
            for (offset, level) in channels.enumerated() { values[fixture.address - 1 + offset] = byte(level) }
        }
        return values
    }
    func startOutput() {
        do {
            try project.validate()
            connectedDestination = project.destination
            lastOutputUniverse = project.universe
            output.start(destination: project.destination)
            outputEnabled = true
        } catch { errorMessage = error.localizedDescription }
    }
    func stopOutput() {
        // UDP delivery remains best-effort; allow the final packet to drain.
        if outputEnabled { output.finish(universe: lastOutputUniverse) }
        else { output.stop() }
        outputEnabled = false
    }
    func saveProject() {
        do {
            try project.validate()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "My Show.lumendesk.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
            try encoder.encode(project).write(to: url, options: .atomic)
        } catch { errorMessage = error.localizedDescription }
    }
    func loadProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let maximumSize = 10 * 1024 * 1024
            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard fileSize <= maximumSize else { throw ProjectError.invalid("Show files must be smaller than 10 MiB.") }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= maximumSize else { throw ProjectError.invalid("Show files must be smaller than 10 MiB.") }
            let next = try JSONDecoder().decode(ShowProject.self, from: data)
            try next.validate()
            stopOutput()
            cancelSequence()
            project = next
            fadeStart = nil
            activeCueID = nil
            fixtureStates = Dictionary(uniqueKeysWithValues: next.fixtures.map { ($0.id, FixtureState.off) })
            selectedFixtureID = next.fixtures.first?.id
            selectedCueID = next.cues.first?.id
            blackout = false
        } catch { errorMessage = error.localizedDescription }
    }
}
