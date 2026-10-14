import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

extension LightingStore {
    var songTimeline: SongTimeline { project.songTimeline ?? SongTimeline() }
    func prepareTimelineControl() {
        cancelSequence(); releaseAllLayers(); stopListening(); fadeStart = nil
        timelineControlsLighting = true
    }
    func exitTimeline() {
        songPlayer?.pause(); timelinePlaying = false; timelineControlsLighting = false; timelineFreezeMotion = false
    }
    func resetSong() {
        exitTimeline(); songAnalysis = nil; songPlayer = nil; timelinePosition = 0; songURL = nil
        songImportID = UUID(); songImportTask?.cancel(); songImportTask = nil; importingSong = false
    }
    func importSong() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadSong(url)
    }
    func loadSong(_ url: URL, rehearsal: Bool = false) {
        exitTimeline(); songImportTask?.cancel()
        let token = UUID(); songImportID = token; importingSong = true
        let task = Task.detached(priority:.userInitiated) { try SongAudioReader.read(url) }
        songImportTask = task
        Task { @MainActor [weak self] in
            do {
                let audio = try await task.value
                guard let self, self.songImportID == token else { return }
                let player = try AVAudioPlayer(contentsOf:url)
                var timeline = self.songTimeline
                timeline.audioName = rehearsal ? "Rehearsal · 120 BPM" : audio.name
                timeline.duration = player.duration; timeline.waveform = audio.waveform
                if rehearsal && timeline.events.isEmpty {
                    timeline.events = self.project.cues.prefix(3).enumerated().map { SongCueEvent(time:Double($0.offset)*10,cueID:$0.element.id) }
                    timeline.markers = [SongMarker(time:0,name:"Intro"),SongMarker(time:10,name:"Break"),SongMarker(time:20,name:"Drop")]
                }
                try timeline.validate(cueIDs:Set(self.project.cues.map(\.id)))
                self.songAnalysis = audio.analysis
                self.project.songTimeline = timeline; self.songPlayer = player; self.songURL = url
                player.volume = Float(self.songVolume); player.prepareToPlay()
                self.timelinePosition = 0; self.timelineFreezeMotion = false; self.importingSong = false
                if rehearsal { self.setManualBPM(120) }
            } catch {
                guard let self, self.songImportID == token else { return }
                self.importingSong = false; self.errorMessage = error.localizedDescription
            }
        }
    }
    func trySongDemo() {
        do { loadSong(try SongAudioReader.demo(),rehearsal:true) } catch { errorMessage = error.localizedDescription }
    }
    func playSong() {
        do { try project.validate() } catch { errorMessage = error.localizedDescription; return }
        guard let player = songPlayer else { errorMessage = "Import or relink the audio file to play this timeline."; return }
        if timelinePosition >= songTimeline.duration { timelinePosition = 0 }
        prepareTimelineControl(); player.currentTime = timelinePosition; player.volume = Float(songVolume)
        timelineFreezeMotion = false; timelinePlaying = player.play()
        if !timelinePlaying { errorMessage = "Audio playback could not start." }
        updateSongTimeline()
    }
    func pauseSong() {
        songPlayer?.pause()
        if let player = songPlayer { timelinePosition = min(songTimeline.duration,max(0,player.currentTime)) }
        timelinePlaying = false; timelineFreezeMotion = true; updateSongTimeline()
        for id in motionPoses.keys { motionPoses[id]?.park() }
    }
    func seekSong(_ time: Double) {
        do { try project.validate() } catch { errorMessage = error.localizedDescription; return }
        guard time.isFinite else { return }
        prepareTimelineControl(); timelinePosition = min(songTimeline.duration,max(0,time)); songPlayer?.currentTime = timelinePosition
        timelineFreezeMotion = false; updateSongTimeline()
    }
    func updateSongTimeline() {
        guard timelineControlsLighting else { return }
        if timelinePlaying, let player = songPlayer {
            if player.isPlaying { timelinePosition = min(songTimeline.duration,max(0,player.currentTime)) }
            else {
                if timelinePosition >= songTimeline.duration-0.25 { timelinePosition = songTimeline.duration }
                timelinePlaying = false; timelineFreezeMotion = true
            }
        }
        let fixtures = project.fixtures.filter { !$0.resolvedProfile.isLaser }
        let values = SongTimelineRenderer.levels(timeline:songTimeline,cues:project.cues,fixtureIDs:fixtures.map(\.id),position:timelinePosition)
        for (id,value) in values { fixtureStates[id] = value }
        activeCueID = songTimeline.events.filter { $0.time <= timelinePosition }.max(by: { $0.time < $1.time })?.cueID
        tempoClock.seek(beats:timelinePosition*bpm/60); phase = timelinePosition
    }
    func addSongCue(_ cueID: UUID) {
        guard project.cues.contains(where: { $0.id == cueID }) else { return }
        var timeline = songTimeline, time = timelinePosition
        while timeline.events.contains(where: { abs($0.time-time) < 0.001 }) { time += 0.1 }
        guard time <= timeline.duration, timeline.events.count < 1000 else { errorMessage = "No free cue position remains here."; return }
        let event = SongCueEvent(time:time,cueID:cueID); timeline.events.append(event)
        project.songTimeline = timeline; selectedSongEvent = event.id
    }
    func moveSongCue(_ id: UUID, time: Double) {
        var timeline = songTimeline
        guard time.isFinite, let index = timeline.events.firstIndex(where: { $0.id == id }) else { return }
        let time = min(timeline.duration,max(0,time))
        guard !timeline.events.contains(where: { $0.id != id && abs($0.time-time) < 0.001 }) else { return }
        timeline.events[index].time = time; project.songTimeline = timeline
    }
    func addSongMarker(_ name: String) {
        var timeline = songTimeline
        guard timeline.markers.count < 256 else { return }
        timeline.markers.append(SongMarker(time:timelinePosition,name:name)); project.songTimeline = timeline
    }
}

 extension LightingStore {
    func applySongAnalysis(generate: Bool) {
        guard let analysis = songAnalysis else { return }
        exitTimeline()
        var timeline = songTimeline
        timeline.markers = analysis.markers
        if let tempo = analysis.bpm { setManualBPM(tempo) }
        if generate {
            let fixtures = project.fixtures.filter { !$0.resolvedProfile.isLaser }
            guard !fixtures.isEmpty else { errorMessage = "Patch a non-laser fixture before generating a show."; return }
            var events: [SongCueEvent] = []
            var cues: [Cue] = []
            for (index,marker) in analysis.markers.enumerated() {
                let quiet = marker.name == "Break?" || marker.name == "Intro"
                let strong = marker.name == "Drop?"
                let palette: [(Double,Double,Double)] = quiet ? [(0.15,0.05,0.7),(0.05,0.2,0.8)] : [(0.8,0.05,0.5),(0.05,0.7,1),(0.7,0.2,0.05)]
                var levels: [UUID:FixtureState] = [:]
                for (offset,fixture) in fixtures.enumerated() {
                    let color = palette[(index+offset)%palette.count]
                    var state = fixtureStates[fixture.id] ?? FixtureState()
                    state.dimmer = quiet ? 0.3 : (strong ? 1 : 0.7)
                    state.red = color.0; state.green = color.1; state.blue = color.2; state.white = 0
                    state.pan = quiet ? 0.5 : (offset%2 == 0 ? 0.35 : 0.65)
                    state.tilt = quiet ? 0.55 : 0.7
                    levels[fixture.id] = state
                }
                let cue = Cue(name:"Song · \(marker.name) \(index+1)",fadeSeconds:quiet ? 2 : 0.5,levels:levels)
                cues.append(cue); events.append(SongCueEvent(time:marker.time,cueID:cue.id,choreography:SongChoreography(style:quiet ? .gentle : (strong ? .energetic : .flow),strength:0.7,beatsPerCycle:quiet ? 16 : (strong ? 4 : 8))))
            }
            var proposed = project
            proposed.cues.append(contentsOf:cues); timeline.events = events; proposed.songTimeline = timeline
            do { try proposed.validate(); project = proposed } catch { errorMessage = error.localizedDescription; return }
        } else { project.songTimeline = timeline }
        timelinePosition = 0; songPlayer?.currentTime = 0
    }
}
