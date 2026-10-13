import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor final class LightingStore: ObservableObject {
    @Published var project = ShowProject.demo
    @Published var selectedFixtureIDs: Set<UUID> = []
    var selectedFixtureID: UUID? {
        get { project.fixtures.first(where: { selectedFixtureIDs.contains($0.id) })?.id }
        set { selectedFixtureIDs = newValue.map { Set([$0]) } ?? [] }
    }
    var selectedFixtures: [Fixture] { project.fixtures.filter { selectedFixtureIDs.contains($0.id) } }
    func selectFixture(id: UUID, extending: Bool = false) {
        guard project.fixtures.contains(where: { $0.id == id }) else { return }
        if extending {
            if selectedFixtureIDs.contains(id) { selectedFixtureIDs.remove(id) } else { selectedFixtureIDs.insert(id) }
        } else { selectedFixtureIDs = [id] }
    }
    func selectAllFixtures() { selectedFixtureIDs = Set(project.fixtures.map(\.id)) }
    func selectGroup(id: UUID) {
        guard let group = project.fixtureGroups?.first(where: { $0.id == id }) else { return }
        selectedFixtureIDs = group.fixtureIDs.intersection(Set(project.fixtures.map(\.id)))
    }
    func saveGroup(id: UUID?, name: String, members: Set<UUID>) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let members = members.intersection(Set(project.fixtures.map(\.id)))
        guard !name.isEmpty, !members.isEmpty else { return }
        var groups = project.fixtureGroups ?? []
        if let id, let index = groups.firstIndex(where: { $0.id == id }) {
            groups[index].name = name; groups[index].fixtureIDs = members
        } else { groups.append(FixtureGroup(name: name, fixtureIDs: members)) }
        project.fixtureGroups = groups
    }
    func removeGroup(id: UUID) { project.fixtureGroups?.removeAll { $0.id == id } }
    func fixturesSupporting(_ key: WritableKeyPath<FixtureState, Double>) -> [Fixture] {
        selectedFixtures.filter { fixture in
            let attribute: FixtureAttribute
            switch key {
            case \.dimmer: return true
            case \.red: attribute = .red
            case \.green: attribute = .green
            case \.blue: attribute = .blue
            case \.white: attribute = .white
            case \.pan: attribute = .pan
            case \.tilt: attribute = .tilt
            case \.zoom: attribute = .zoom
            default: attribute = .gobo
            }
            return fixture.resolvedProfile.supports(attribute)
        }
    }
    func selectionValue(_ key: WritableKeyPath<FixtureState, Double>) -> Double {
        let fixtures = fixturesSupporting(key)
        guard !fixtures.isEmpty else { return 0 }
        return fixtures.reduce(0) { $0 + state(for: $1.id)[keyPath: key] } / Double(fixtures.count)
    }
    func selectionIsMixed(_ key: WritableKeyPath<FixtureState, Double>) -> Bool {
        let values = fixturesSupporting(key).map { state(for: $0.id)[keyPath: key] }
        return (values.max() ?? 0) - (values.min() ?? 0) > 0.001
    }
    func setSelectionValue(_ key: WritableKeyPath<FixtureState, Double>, value: Double) {
        guard value.isFinite else { return }
        for fixture in fixturesSupporting(key) {
            var state = state(for: fixture.id)
            state[keyPath: key] = min(1, max(0, value))
            setState(id: fixture.id, state: state)
        }
    }
    func setSelectionColor(red: Double, green: Double, blue: Double) {
        guard [red,green,blue].allSatisfy({ $0.isFinite }) else { return }
        for fixture in selectedFixtures where fixture.resolvedProfile.supports(.red) {
            var state = state(for: fixture.id)
            state.red = min(1,max(0,red)); state.green = min(1,max(0,green)); state.blue = min(1,max(0,blue))
            setState(id: fixture.id, state: state)
        }
    }
    @Published private(set) var layerMixer = LayerMixer()
    @Published var selectedCueID: UUID?
    @Published var master: Double = 1
    @Published var blackout = false
    @Published var activeCueID: UUID?
    @Published var outputEnabled = false
    @Published var errorMessage: String?
    @Published var phase: Double = 0
    @Published var tempoClock = TempoClock()
    @Published var fixtureStates: [UUID: FixtureState] = [:]
    @Published private(set) var sequencePlayer: SequencePlayer?
    private var sequenceCues: [UUID: Cue] = [:]
    private var sequencePausedAt: TimeInterval?
    private let clock: () -> TimeInterval
    @Published var music = MusicSnapshot()
    @Published var listening = false
    @Published var audioDemo = false
    @Published var autopilotEnabled = false
    var automaticTempo: Bool {
        get { (project.autopilot ?? AutopilotPreferences()).followTempo }
        set { var p = project.autopilot ?? AutopilotPreferences(); p.followTempo = newValue; project.autopilot = p }
    }
    var musicStyle: MusicStyle {
        get { (project.autopilot ?? AutopilotPreferences()).style }
        set { var p = project.autopilot ?? AutopilotPreferences(); p.style = newValue; project.autopilot = p }
    }
    var autopilotStrength: Double {
        get { (project.autopilot ?? AutopilotPreferences()).strength }
        set { var p = project.autopilot ?? AutopilotPreferences(); p.strength = newValue; project.autopilot = p }
    }
    @Published var microphoneStatus = "Microphone off"
    var microphone: MicrophoneListener?
    var musicAnalyzer = MusicAnalyzer()
    var lastMusicTime: TimeInterval = -.infinity
    var lastTempoUpdate: TimeInterval = -.infinity
    var audioSession = UUID()
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
    func state(for id: UUID) -> FixtureState { layerMixer.state(for: id, base: fixtureStates[id] ?? .off, now: clock()) }
    func capturePreset(name: String, kind: PresetKind) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !selectedFixtures.isEmpty else { return }
        var values: [UUID: PresetValues] = [:]
        for fixture in selectedFixtures {
            let state = state(for: fixture.id)
            var value = PresetValues()
            if kind == .intensity || kind == .look { value.dimmer = state.dimmer }
            if (kind == .color || kind == .look) && fixture.resolvedProfile.supports(.red) {
                value.red = state.red; value.green = state.green; value.blue = state.blue
                if fixture.resolvedProfile.supports(.white) { value.white = state.white }
            }
            if kind == .position || kind == .look {
                if fixture.resolvedProfile.supports(.pan) { value.pan = state.pan }
                if fixture.resolvedProfile.supports(.tilt) { value.tilt = state.tilt }
            }
            if kind == .beam || kind == .look {
                if fixture.resolvedProfile.supports(.zoom) { value.zoom = state.zoom }
                if fixture.resolvedProfile.supports(.gobo) { value.gobo = state.gobo }
            }
            if !value.channels.isEmpty || kind == .effects { values[fixture.id] = value }
        }
        guard !values.isEmpty else { errorMessage = "The selected fixtures do not support this preset category."; return }
        let effects = kind == .effects || kind == .look ? project.effects.filter { $0.enabled } : nil
        var presets = project.presets ?? []
        presets.append(LookPreset(name: name, kind: kind, values: values, effects: effects))
        project.presets = presets
    }
    func saveLayer(name: String, presetIDs: [UUID], priority: Int, fadeSeconds: Double) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !presetIDs.isEmpty, fadeSeconds.isFinite, (0...3600).contains(fadeSeconds), (0...100).contains(priority), Set(presetIDs).isSubset(of: Set((project.presets ?? []).map(\.id))) else { return }
        var cues = project.layerCues ?? []
        cues.append(LayerCue(name: name, presetIDs: presetIDs, priority: priority, fadeSeconds: fadeSeconds))
        project.layerCues = cues
    }
    func activateLayer(id: UUID) {
        guard let cue = project.layerCues?.first(where: { $0.id == id }) else { return }
        var values: [UUID: PresetValues] = [:]
        var effects: [UUID: [Effect]] = [:]
        for presetID in cue.presetIDs {
            guard let preset = project.presets?.first(where: { $0.id == presetID }) else { return }
            for (fixtureID, value) in preset.values {
                var merged = values[fixtureID] ?? PresetValues(); merged.merge(value); values[fixtureID] = merged
                if let bundle = preset.effects { effects[fixtureID] = bundle }
            }
        }
        releaseLayer(id: id)
        layerMixer.layers.append(ActiveLayer(id: id, name: cue.name, priority: cue.priority, started: clock(), fadeSeconds: cue.fadeSeconds, values: values, effects: effects))
    }
    func releaseLayer(id: UUID) { layerMixer.layers.removeAll { $0.id == id } }
    func releaseAllLayers() { layerMixer.layers = [] }
    func removeLayer(id: UUID) { releaseLayer(id: id); project.layerCues?.removeAll { $0.id == id } }
    func removePreset(id: UUID) {
        let dependent = (project.layerCues ?? []).filter { $0.presetIDs.contains(id) }.map(\.id)
        for layerID in dependent { removeLayer(id: layerID) }
        project.presets?.removeAll { $0.id == id }
    }
    private func takeOverLayers() {
        guard !layerMixer.layers.isEmpty else { return }
        fixtureStates = Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id, state(for: $0.id)) })
        releaseAllLayers()
    }
    func setState(id: UUID, state: FixtureState) {
        takeOverLayers()
        cancelSequence()
        fadeStart = nil
        activeCueID = nil
        fixtureStates[id] = state
    }
    var profileLibrary: [FixtureProfile] { FixtureProfile.library + (project.fixtureProfiles ?? []) }
    func addFixture() { addFixture(profile: .rgb) }
    func addFixture(profile: FixtureProfile) {
        var used = Set<Int>()
        for fixture in project.fixtures where fixture.address >= 1 && fixture.address <= 513 - fixture.footprint {
            used.formUnion(fixture.address..<(fixture.address + fixture.footprint))
        }
        guard let address = (1...(513 - profile.footprint)).first(where: { start in (start..<(start + profile.footprint)).allSatisfy { !used.contains($0) } }) else { errorMessage = "No contiguous channels are available for this profile."; return }
        let kind: FixtureKind = profile.movingHead ? .movingHead : (profile.supports(.white) ? .rgbw : (profile.supports(.red) ? .rgb : .dimmer))
        let fixture = Fixture(name: "\(profile.movingHead ? "Head" : "Fixture") \(project.fixtures.count + 1)", kind: kind, address: address, x: 0.5, y: 0.3, profile: profile)
        project.fixtures.append(fixture); fixtureStates[fixture.id] = .off; selectedFixtureID = fixture.id
        if profile.movingHead && !project.effects.contains(where: { $0.kind == .circle }) {
            project.effects.append(Effect(name: "Pan / Tilt orbit", kind: .circle))
        }
    }
    func importProfile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 1024 * 1024 else { throw ProjectError.invalid("Profiles must be smaller than 1 MiB.") }
            let data = try Data(contentsOf: url)
            guard data.count <= 1024 * 1024 else { throw ProjectError.invalid("Profiles must be smaller than 1 MiB.") }
            let profile = try JSONDecoder().decode(FixtureProfile.self, from: data)
            try profile.validate()
            guard !profileLibrary.contains(where: { $0.id == profile.id }) else { throw ProjectError.invalid("That profile identifier is already in the library.") }
            var profiles = project.fixtureProfiles ?? []; profiles.append(profile); project.fixtureProfiles = profiles
        } catch { errorMessage = error.localizedDescription }
    }
    func setSelectionPosition(pan: Double, tilt: Double) {
        guard pan.isFinite, tilt.isFinite else { return }
        for fixture in selectedFixtures where fixture.resolvedProfile.movingHead {
            var value = state(for: fixture.id); value.pan = min(1, max(0, pan)); value.tilt = min(1, max(0, tilt)); setState(id: fixture.id, state: value)
        }
    }
    func setGobo(id: UUID, index: Int) {
        guard let fixture = project.fixtures.first(where: { $0.id == id }), fixture.resolvedProfile.gobos.indices.contains(index) else { return }
        var value = state(for: id); value.gobo = Double(index) / Double(max(1, fixture.resolvedProfile.gobos.count - 1)); setState(id: id, state: value)
    }
    func addMovementDemo() {
        // Adds original generic fixtures and movement cues without replacing the existing show.
        let before = Set(project.fixtures.map(\.id))
        addFixture(profile: .head); addFixture(profile: .head)
        let indices = project.fixtures.indices.filter { !before.contains(project.fixtures[$0].id) }
        guard !indices.isEmpty else { return }
        for (offset, index) in indices.enumerated() {
            project.fixtures[index].name = "Moving head \(offset + 1)"
            project.fixtures[index].x = offset == 0 ? 0.3 : 0.7; project.fixtures[index].y = 0.2
        }
        let ids = Set(indices.map { project.fixtures[$0].id }); selectedFixtureIDs = ids
        var left = fixtureStates, right = fixtureStates
        for (offset, index) in indices.enumerated() {
            let id = project.fixtures[index].id
            left[id] = FixtureState(dimmer: 0.8, red: 0.2, green: 0.7, blue: 1, pan: offset == 0 ? 0.43 : 0.57, tilt: 0.65, zoom: 0.25)
            right[id] = FixtureState(dimmer: 0.8, red: 1, green: 0.35, blue: 0.1, pan: offset == 0 ? 0.57 : 0.43, tilt: 0.7, zoom: 0.65, gobo: 2.0 / 3.0)
        }
        let cue = Cue(name: "Heads · left", fadeSeconds: 4, levels: left)
        project.cues.append(cue); project.cues.append(Cue(name: "Heads · right", fadeSeconds: 4, levels: right))
        activateCue(id: cue.id)
    }
    func removeFixture(id: UUID) {
        cancelSequence()
        releaseAllLayers()
        if var presets = project.presets {
            for index in presets.indices { presets[index].values.removeValue(forKey: id) }
            let empty = presets.filter { $0.values.isEmpty }.map(\.id)
            project.presets = presets
            for presetID in empty { removePreset(id: presetID) }
        }
        project.fixtures.removeAll { $0.id == id }
        fixtureStates.removeValue(forKey: id)
        for index in project.cues.indices { project.cues[index].levels.removeValue(forKey: id) }
        selectedFixtureIDs.remove(id)
        if var groups = project.fixtureGroups {
            for index in groups.indices { groups[index].fixtureIDs.remove(id) }
            groups.removeAll { $0.fixtureIDs.isEmpty }
            project.fixtureGroups = groups
        }
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
        fadeFrom = Dictionary(uniqueKeysWithValues: project.fixtures.map { ($0.id, fixtureStates[$0.id] ?? .off) })
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
        let parked = Dictionary(uniqueKeysWithValues: project.fixtures.map { fixture in
            var value = renderedState(for: fixture.id); value.dimmer = 0
            return (fixture.id, value)
        })
        autopilotEnabled = false
        releaseAllLayers()
        cancelSequence()
        fadeStart = nil
        activeCueID = nil
        fixtureStates = parked
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
    func tempoNow() -> TimeInterval { clock() }
    func resetTempoTick() { lastTick = clock() }
    func tick() {
        let now = clock()
        if audioDemo {
            let beat = now.truncatingRemainder(dividingBy: 0.5)
            let section = Int(now / 12) % 3
            receiveMusic(level: section == 1 ? 0.025 : (beat < 0.06 ? 0.3 : 0.1), bass: section == 1 ? 0.01 : 0.14, high: section == 2 ? 0.12 : 0.05, at: now)
        }
        tempoClock.advance(seconds: max(0, now - lastTick), bpm: bpm)
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
    func renderedState(for id: UUID, applyMaster: Bool = true) -> FixtureState {
        var result = state(for: id)
        let index = project.fixtures.firstIndex(where: { $0.id == id }) ?? 0
        let count = max(1, project.fixtures.count)
        for effect in layerMixer.effects(for: id, base: project.effects) where effect.enabled && effect.rate.isFinite && effect.depth.isFinite {
            let cycles = effect.beatTiming == true ? tempoClock.beats / max(0.25, effect.cycleBeats) : phase * max(0, effect.rate)
            let position = cycles + Double(index) / Double(count) * (effect.spread ?? 1)
            let depth = min(1, max(0, effect.depth))
            switch effect.kind {
            case .circle:
                if project.fixtures.first(where: { $0.id == id })?.resolvedProfile.movingHead == true {
                    let point = MotionPath.sample(effect: effect, phase: position)
                    result.pan = min(1, max(0, result.pan + point.x * 0.18 * depth))
                    result.tilt = min(1, max(0, result.tilt + point.y * 0.12 * depth))
                }
            case .sine: result.dimmer *= 1 - depth + depth * (effect.waveform ?? .sine).value(at: position)
            case .pulse: result.dimmer *= 1 - depth + depth * max(0, 1 - (position - floor(position)) * 5)
            case .sparkle:
                let step = floor(cycles * 8)
                let seed = sin(step * 12.9898 + Double(index) * 78.233) * 43758.5453
                let random = seed - floor(seed)
                result.dimmer *= random > 0.7 ? 1 : 1 - depth
            case .scanner:
                let target = (effect.waveform ?? .triangle).value(at: cycles) * Double(max(0, count - 1))
                result.dimmer *= 1 - depth + depth * max(0, 1 - abs(Double(index) - target))
            case .chase:
                let step = Int((cycles * (effect.beatTiming == true ? Double(count) : 1)).truncatingRemainder(dividingBy: Double(count)))
                result.dimmer *= index == step ? 1 : 1 - depth
            case .rainbow, .colorChase:
                let color: EffectColor
                if effect.kind == .colorChase {
                    let palette = effect.colors ?? EffectColor.disco
                    color = palette[Int(floor((position - floor(position)) * Double(palette.count))) % palette.count]
                } else { color = EffectColor.hue(position - floor(position)) }
                result.red = result.red * (1 - depth) + color.red * depth
                result.green = result.green * (1 - depth) + color.green * depth
                result.blue = result.blue * (1 - depth) + color.blue * depth
            }
        }
        if autopilotEnabled, let fixture = project.fixtures.first(where: { $0.id == id }), fixture.autopilotRole != .manual {
            let role = fixture.autopilotRole ?? (fixture.resolvedProfile.movingHead ? .beam : .wash)
            let peers = project.fixtures.filter { ($0.autopilotRole ?? ($0.resolvedProfile.movingHead ? .beam : .wash)) == role }
            result = AutopilotRenderer.render(base: result, snapshot: music, style: musicStyle, strength: autopilotStrength,
                beats: tempoClock.beats, index: peers.firstIndex(where: { $0.id == id }) ?? 0, moving: fixture.resolvedProfile.movingHead,
                fresh: clock() - lastMusicTime < 1, role: role)
        }
        if applyMaster { result.dimmer *= blackout ? 0 : (master.isFinite ? min(1,max(0,master)) : 0) }
        return result
    }
    var frame: [UInt8] {
        var values = [UInt8](repeating: 0, count: 512)
        // Invalid live edits silence output instead of sending overlapping patches.
        guard (try? project.validate()) != nil else { return values }
        for fixture in project.fixtures {
            let channels = fixture.resolvedProfile.bytes(for: fixture.outputState(renderedState(for: fixture.id)))
            for (offset, level) in channels.enumerated() { values[fixture.address - 1 + offset] = level }
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
            releaseAllLayers()
            stopListening()
            project = next
            syncTempo(); tempoClock.resetTaps()
            fadeStart = nil
            activeCueID = nil
            fixtureStates = Dictionary(uniqueKeysWithValues: next.fixtures.map { ($0.id, FixtureState.off) })
            selectedFixtureID = next.fixtures.first?.id
            selectedCueID = next.cues.first?.id
            blackout = false
        } catch { errorMessage = error.localizedDescription }
    }
}
