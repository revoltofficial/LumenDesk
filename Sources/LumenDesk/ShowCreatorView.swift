import SwiftUI

struct ShowCreatorView: View {
    @EnvironmentObject var store: LightingStore
    @State private var cueID: UUID?
    @State private var confirmGeneration = false
    private var timeline: SongTimeline { store.songTimeline }
    private func time(_ value: Double) -> String { String(format:"%02d:%04.1f",Int(value)/60,value.truncatingRemainder(dividingBy:60)) }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:10) {
                HStack {
                    Text("Show Creator").font(.headline)
                    Text(timeline.audioName ?? "No audio imported").font(.caption).lineLimit(1)
                    if store.importingSong { ProgressView().controlSize(.small); Text("Reading waveform…").font(.caption) }
                    Spacer()
                    Button(timeline.audioName == nil ? "Import song…" : "Import / relink…",action:store.importSong).disabled(store.importingSong)
                    Button("Try rehearsal",action:store.trySongDemo).disabled(store.importingSong)
                }
                HStack {
                    Button(store.timelinePlaying ? "Pause" : "Play") { if store.timelinePlaying { store.pauseSong() } else { store.playSong() } }.disabled(store.songPlayer == nil)
                    Button("Stop",action:store.stop)
                    Button("Start") { store.seekSong(0) }
                    Text("\(time(store.timelinePosition)) / \(time(timeline.duration))").font(.caption).monospacedDigit()
                    Slider(value:Binding(get:{ store.timelinePosition },set:{ store.seekSong($0) }),in:0...timeline.duration).accessibilityLabel("Song position")
                    Text("Audio").font(.caption)
                    Slider(value:Binding(get:{store.songVolume},set:{value in store.songVolume = value; store.songPlayer?.volume = Float(value)}),in:0...1).frame(width:75).accessibilityLabel("Song volume")
                }
                if let analysis = store.songAnalysis {
                    HStack {
                        Text(analysis.bpm.map { "Estimated tempo: \(Int($0)) BPM · \(Int(analysis.confidence*100))% beat confidence" } ?? "Tempo uncertain — keep manual BPM").font(.caption)
                        Button("Use suggested markers & BPM") { store.applySongAnalysis(generate:false) }
                        Button("Generate show…") { confirmGeneration = true }
                    }
                }
                waveform.frame(height:105)
                HStack {
                    Picker("Cue",selection:Binding(get:{cueID ?? store.project.cues.first?.id},set:{cueID = $0})) {
                        ForEach(store.project.cues) { cue in Text(cue.name).tag(Optional(cue.id)) }
                    }.frame(maxWidth:270)
                    Button("Add cue at playhead") { if let id = cueID ?? store.project.cues.first?.id { store.addSongCue(id) } }.disabled(store.project.cues.isEmpty)
                    Menu("Add marker") { ForEach(["Intro","Verse","Break","Build","Drop","Outro"],id: \.self) { name in Button(name) { store.addSongMarker(name) } } }
                    Spacer()
                }
                eventEditor
                markerEditor
                Text("Drag cue blocks or edit their times. Scrubbing previews the lighting; moving heads blend through their limits. Audio stays local. Save Show stores the timeline and waveform; relink the audio after reopening. Analysis markers are suggestions. Generated shows use colour, dimmer and static head positions; lasers remain manual.").font(.caption2).foregroundStyle(.secondary)
            }.padding(14)
        }.clipped()
        .confirmationDialog("Replace timeline cues and markers with a generated show? Existing saved cues are kept.",isPresented:$confirmGeneration,titleVisibility:.visible) {
            Button("Generate and replace timeline") { store.applySongAnalysis(generate:true) }
            Button("Cancel",role:.cancel) {}
        }
    }
    private var waveform: some View {
        GeometryReader { geo in
            ZStack(alignment:.topLeading) {
                Canvas { context,size in
                    let peaks = timeline.waveform
                    var envelope = Path()
                    for (index,peak) in peaks.enumerated() {
                        let x = Double(index)/Double(max(1,peaks.count-1))*size.width
                        envelope.move(to:CGPoint(x:x,y:50-peak*30)); envelope.addLine(to:CGPoint(x:x,y:50+peak*30))
                    }
                    context.stroke(envelope,with:.color(.mint.opacity(0.55)),lineWidth:1)
                    for marker in timeline.markers {
                        let x = marker.time/timeline.duration*size.width
                        var line = Path(); line.move(to:CGPoint(x:x,y:0)); line.addLine(to:CGPoint(x:x,y:size.height))
                        context.stroke(line,with:.color(.orange.opacity(0.3)),lineWidth:1)
                        context.draw(Text(marker.name).font(.system(size:9)).foregroundColor(.orange),at:CGPoint(x:min(size.width-30,max(30,x)),y:9))
                    }
                    let x = store.timelinePosition/timeline.duration*size.width
                    var playhead = Path(); playhead.move(to:CGPoint(x:x,y:0)); playhead.addLine(to:CGPoint(x:x,y:size.height))
                    context.stroke(playhead,with:.color(.white),lineWidth:2)
                }
                ForEach(timeline.events) { event in
                    SongTimelineBlock(event:event,width:Double(geo.size.width),duration:timeline.duration)
                }
                if timeline.waveform.isEmpty { Text("Import audio or try rehearsal to show its waveform").font(.caption).foregroundStyle(.secondary).position(x:geo.size.width/2,y:45) }
            }.coordinateSpace(name:"songWave").background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:6))
        }.accessibilityLabel("Song waveform and cue timeline")
    }
    private var eventEditor: some View {
        LazyVStack(alignment:.leading,spacing:5) {
            Text("Cue events").font(.caption).foregroundStyle(.secondary)
            ForEach(timeline.events.sorted(by:{$0.time < $1.time})) { event in
                HStack {
                    TextField("Seconds",value:Binding(get:{ store.songTimeline.events.first(where:{$0.id == event.id})?.time ?? event.time },set:{store.moveSongCue(event.id,time:$0)}),format:.number.precision(.fractionLength(1))).frame(width:75).accessibilityLabel("Cue event time")
                    Text("s").font(.caption)
                    Text(store.project.cues.first(where:{$0.id == event.cueID})?.name ?? "Missing cue").font(.caption)
                    Button("Go") { store.selectedSongEvent = event.id; store.seekSong(event.time) }
                    Spacer()
                    Button("Remove") { store.project.songTimeline?.events.removeAll {$0.id == event.id} }
                }
            }
        }
    }
    private var markerEditor: some View {
        LazyVStack(alignment:.leading,spacing:5) {
            if !timeline.markers.isEmpty { Text("Section markers").font(.caption).foregroundStyle(.secondary) }
            ForEach(timeline.markers.sorted(by:{$0.time < $1.time})) { marker in
                HStack {
                    TextField("Seconds",value:Binding(get:{store.songTimeline.markers.first(where:{$0.id == marker.id})?.time ?? marker.time},set:{value in
                        guard value.isFinite, (0...timeline.duration).contains(value), let index = store.project.songTimeline?.markers.firstIndex(where:{$0.id == marker.id}) else { return }
                        store.project.songTimeline?.markers[index].time = value
                    }),format:.number.precision(.fractionLength(1))).frame(width:75).accessibilityLabel("Marker time")
                    TextField("Marker",text:Binding(get:{store.songTimeline.markers.first(where:{$0.id == marker.id})?.name ?? marker.name},set:{name in
                        guard !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, let index = store.project.songTimeline?.markers.firstIndex(where:{$0.id == marker.id}) else { return }
                        store.project.songTimeline?.markers[index].name = name
                    })).frame(width:140)
                    Spacer()
                    Button("Remove") { store.project.songTimeline?.markers.removeAll {$0.id == marker.id} }
                }
            }
        }
    }
}

private struct SongTimelineBlock: View {
    @EnvironmentObject var store: LightingStore
    let event: SongCueEvent
    let width: Double
    let duration: Double
    @State private var dragOrigin: Double?
    private var name: String { store.project.cues.first(where: { $0.id == event.cueID })?.name ?? "Missing cue" }
    private var selected: Bool { store.selectedSongEvent == event.id }
    private var x: CGFloat { CGFloat(min(width-45,max(45,event.time/duration*width))) }
    private var background: Color { selected ? Color.mint : Color.blue.opacity(0.7) }
    private var foreground: Color { selected ? Color.black : Color.white }
    var body: some View {
        Text(name).font(.system(size:9)).lineLimit(1).padding(4).frame(width:90)
            .background(background,in:RoundedRectangle(cornerRadius:4))
            .foregroundStyle(foreground).position(x:x,y:91)
            .onTapGesture { store.selectedSongEvent = event.id; store.seekSong(event.time) }
            .gesture(drag)
            .accessibilityLabel("Timeline cue \(name) at \(event.time.formatted()) seconds")
    }
    private var drag: some Gesture {
        DragGesture(coordinateSpace:.named("songWave"))
            .onChanged { value in
                guard width > 0 else { return }
                if dragOrigin == nil { dragOrigin = event.time }
                store.selectedSongEvent = event.id
                store.moveSongCue(event.id,time:(dragOrigin ?? event.time)+Double(value.translation.width)/width*duration)
            }.onEnded { _ in dragOrigin = nil }
    }
}
