import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject var store: LightingStore
    @State private var page = "Design"
    private let accent = Color(red: 0.43, green: 0.86, blue: 0.78)
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LUMEN DESK").font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Your stage. Your show.").font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 12)
                ForEach(["Patch", "Design", "Live"], id: \.self) { item in
                    Button { page = item } label: {
                        Label(item, systemImage: item == "Patch" ? "cable.connector" : item == "Design" ? "square.grid.3x3" : "play.rectangle")
                            .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .background(page == item ? accent.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(page == item ? accent : .secondary)
                    }.buttonStyle(.plain)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    Text("SHOW FILE").font(.caption2).foregroundStyle(.secondary)
                    Button("Open show…", action: store.loadProject)
                    Button("Save show…", action: store.saveProject)
                }.buttonStyle(.plain)
                Divider()
                Label(store.outputEnabled ? "Output running" : "Output stopped", systemImage: "circle.fill")
                    .font(.caption).foregroundStyle(store.outputEnabled ? accent : .secondary)
            }.padding(20).frame(width: 190).background(Color(white: 0.075))
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(page).font(.system(size: 28, weight: .semibold))
                        Text(page == "Patch" ? "Add fixtures and assign their DMX addresses." : page == "Design" ? "Shape your look, then capture it as a cue." : "Bring your cues and effects to the stage.")
                            .foregroundStyle(.secondary).font(.subheadline)
                    }
                    Spacer()
                    Text("\(store.project.fixtures.count) fixtures · Universe \(store.project.universe)").font(.caption).foregroundStyle(.secondary)
                }.padding(26)
                Divider()
                if page == "Patch" { patch.padding(24) }
                else if page == "Design" { design.padding(24) }
                else { live.padding(24) }
                Spacer(minLength: 0)
                if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.orange).padding(.horizontal, 20).padding(.bottom, 8) }
                transport
            }.background(Color(white: 0.105))
        }
    }
    private var patch: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Fixture patch").font(.headline)
                Spacer()
                Button(action: store.addFixture) { Label("Add fixture", systemImage: "plus") }
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($store.project.fixtures) { $fixture in
                        HStack(spacing: 14) {
                            Image(systemName: "lightbulb.led.fill").foregroundStyle(accent).frame(width: 24)
                            TextField("Fixture name", text: $fixture.name).textFieldStyle(.roundedBorder)
                            Picker("Type", selection: $fixture.kind) {
                                Text("Dimmer").tag(FixtureKind.dimmer)
                                Text("RGB").tag(FixtureKind.rgb)
                                Text("RGBW").tag(FixtureKind.rgbw)
                            }.labelsHidden().frame(width: 100)
                            Stepper(value: $fixture.address, in: 1...max(1, 513 - fixture.kind.footprint)) {
                                Text("DMX \(fixture.address)").monospacedDigit().frame(width: 75)
                            }.frame(width: 130)
                            Button { store.removeFixture(id: fixture.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }.padding(12).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            Divider()
            HStack {
                Text("Art-Net destination").foregroundStyle(.secondary)
                TextField("192.168.1.100", text: $store.project.destination).textFieldStyle(.roundedBorder).frame(width: 170)
                Stepper("Universe \(store.project.universe)", value: $store.project.universe, in: 1...32768).frame(width: 190)
                Spacer()
            }
            Text("Choose your Art-Net node’s unicast address. Universe 1 sends to Art-Net port-address 0. Fixture channels must not overlap.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var design: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Stage plan").font(.headline); Spacer(); Button("Add fixture", action: store.addFixture) }
                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.07))
                        VStack { Text("UPSTAGE").font(.caption2).tracking(4).foregroundStyle(.secondary); Spacer(); Text("AUDIENCE").font(.caption2).tracking(4).foregroundStyle(.secondary) }.padding(18)
                        ForEach(store.project.fixtures) { fixture in
                            let state = store.renderedState(for: fixture.id)
                            VStack(spacing: 6) {
                                Image(systemName: "lightbulb.led.fill").font(.system(size: 27)).foregroundStyle(Color(red: state.red, green: state.green, blue: state.blue)).opacity(0.25 + state.dimmer * 0.75)
                                Text(fixture.name).font(.caption).lineLimit(1)
                            }.padding(10).background(store.selectedFixtureID == fixture.id ? accent.opacity(0.16) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.selectedFixtureID == fixture.id ? accent : .clear))
                                .position(x: max(50, min(geo.size.width - 50, fixture.x * geo.size.width)), y: max(55, min(geo.size.height - 55, fixture.y * geo.size.height)))
                                .onTapGesture { store.selectedFixtureID = fixture.id }
                                .gesture(DragGesture(coordinateSpace: .named("stage")).onChanged { value in
                                    store.selectedFixtureID = fixture.id
                                    if let i = store.project.fixtures.firstIndex(where: { $0.id == fixture.id }) {
                                        store.project.fixtures[i].x = min(0.95, max(0.05, value.location.x / geo.size.width))
                                        store.project.fixtures[i].y = min(0.9, max(0.1, value.location.y / geo.size.height))
                                    }
                                })
                        }
                    }
                    .coordinateSpace(name: "stage")
                }.frame(minHeight: 330)
                Text("Select a fixture to adjust its look. Drag fixtures to arrange the stage.").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 18) {
                Text("Fixture controls").font(.headline)
                if let id = store.selectedFixtureID, let fixture = store.project.fixtures.first(where: { $0.id == id }) {
                    Text(fixture.name).font(.title3)
                    channel("Intensity", id: id, key: \.dimmer)
                    if fixture.kind != .dimmer {
                        channel("Red", id: id, key: \.red)
                        channel("Green", id: id, key: \.green)
                        channel("Blue", id: id, key: \.blue)
                    }
                    if fixture.kind == .rgbw { channel("White", id: id, key: \.white) }
                } else { Text("Select a fixture on the stage.").foregroundStyle(.secondary) }
                Divider()
                Button(action: store.captureCue) { Label("Capture cue", systemImage: "plus.square") }.buttonStyle(.borderedProminent).tint(accent)
                Text("Captures the current fixture levels as a reusable look.").font(.caption).foregroundStyle(.secondary)
            }.padding(18).frame(width: 240).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
        }
    }
    private func channel(_ title: String, id: UUID, key: WritableKeyPath<FixtureState, Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(Int(store.state(for: id)[keyPath: key] * 100))%").monospacedDigit().foregroundStyle(.secondary) }.font(.caption)
            Slider(value: Binding(get: { store.state(for: id)[keyPath: key] }, set: { value in
                var state = store.state(for: id); state[keyPath: key] = value; store.setState(id: id, state: state)
            }), in: 0...1).tint(accent)
        }
    }
    private var live: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text("Cue launcher").font(.headline); Spacer(); Button("Capture cue", action: store.captureCue) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))], spacing: 12) {
                    ForEach($store.project.cues) { $cue in
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Cue name", text: $cue.name).font(.headline).textFieldStyle(.plain)
                            HStack { Text("Fade").font(.caption).foregroundStyle(.secondary); TextField("Seconds", value: $cue.fadeSeconds, format: .number).frame(width: 50); Text("sec").font(.caption) }
                            Button { store.activateCue(id: cue.id) } label: { Label(store.activeCueID == cue.id ? "Playing" : "Go", systemImage: "play.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(store.activeCueID == cue.id ? accent : .gray)
                        }.padding(16).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if store.project.cues.isEmpty { Text("Build a look in Design and capture your first cue.").foregroundStyle(.secondary) }
                Divider()
                Text("Effects").font(.headline)
                ForEach($store.project.effects) { $effect in
                    HStack(spacing: 16) {
                        Toggle(effect.name, isOn: $effect.enabled).frame(width: 180)
                        Picker("Pattern", selection: $effect.kind) { Text("Sine").tag(EffectKind.sine); Text("Chase").tag(EffectKind.chase); Text("Rainbow").tag(EffectKind.rainbow) }.frame(width: 140)
                        VStack { Text("Rate \(effect.rate, specifier: "%.1f") Hz").font(.caption); Slider(value: $effect.rate, in: 0.05...4) }
                        VStack { Text("Depth \(Int(effect.depth * 100))%").font(.caption); Slider(value: $effect.depth, in: 0...1) }
                    }.padding(14).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
    private var transport: some View {
        HStack(spacing: 18) {
            Button(action: store.stop) { Label("Stop", systemImage: "stop.fill") }
            Toggle("Blackout", isOn: $store.blackout).toggleStyle(.button).tint(.red)
            Divider().frame(height: 24)
            Text("Master").font(.caption)
            Slider(value: $store.master, in: 0...1).tint(accent).frame(maxWidth: 220)
            Text("\(Int(store.master * 100))%").monospacedDigit().font(.caption).frame(width: 35)
            Spacer()
            Button { store.outputEnabled ? store.stopOutput() : store.startOutput() } label: {
                Label(store.outputEnabled ? "Stop output" : "Start output", systemImage: "network")
            }.buttonStyle(.borderedProminent).tint(store.outputEnabled ? .orange : accent)
        }.padding(18).background(Color(white: 0.065))
    }
}
