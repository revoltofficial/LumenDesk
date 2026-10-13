import SwiftUI
import AppKit

struct WorkspaceView: View {
    @EnvironmentObject var store: LightingStore
    @State private var mode = "Design"
    @State private var showingPatch = false
    @State private var paletteSearch = ""
    @State private var liveStyle = "Buttons"
    @State private var showEffects = false
    @State private var confirmUpdate = false
    @State private var showingGroupEditor = false
    @State private var editingGroupID: UUID?
    @State private var groupName = ""
    @State private var groupMembers: Set<UUID> = []
    @State private var extendingSelection = false
    @State private var selectionModifiers: EventModifiers = []
    private let accent = Color(red: 0.43, green: 0.86, blue: 0.78)

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    stage.frame(minHeight: 250, maxHeight: .infinity)
                    modeBar
                    Divider()
                    if mode == "Design" { designControls.frame(height: 230) }
                    else { liveControls.frame(height: 230) }
                }
                Divider()
                palette.frame(width: 270)
            }
            if let error = store.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(error).font(.caption)
                    Spacer()
                    Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }.padding(10).background(Color.orange.opacity(0.08))
            }
            Divider()
            transport
        }
        .background(Color(white: 0.10))
        .onModifierKeysChanged(mask: [.command, .shift]) { _, current in selectionModifiers = current }
        .sheet(isPresented: $showingPatch) { patchSheet }
        .sheet(isPresented: $showingGroupEditor) { groupEditor }
        .confirmationDialog("Replace the selected cue with the current fixture levels?", isPresented: $confirmUpdate) {
            Button("Update cue", action: store.updateSelectedCue)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 18) {
            Label("LumenDesk", systemImage: "light.beacon.max.fill").font(.headline)
            Divider().frame(height: 24)
            Button { showingPatch = true } label: { Label("Patch & Output", systemImage: "cable.connector") }
            Button(action: store.loadProject) { Image(systemName: "folder") }.help("Open show")
            Button(action: store.saveProject) { Image(systemName: "square.and.arrow.down") }.help("Save show")
            Spacer()
            Text("\(store.project.fixtures.count) fixtures").foregroundStyle(.secondary)
            Text("Universe \(store.project.universe)").foregroundStyle(.secondary)
            Label(store.outputEnabled ? "Output on" : "Preview only", systemImage: "circle.fill")
                .foregroundStyle(store.outputEnabled ? accent : .secondary)
        }.font(.caption).buttonStyle(.borderless).padding(.horizontal, 20).frame(height: 52)
    }

    private var stage: some View {
        GeometryReader { geo in
            ZStack {
                Color(white: 0.055)
                Canvas { context, size in
                    var grid = Path()
                    for x in stride(from: 0.0, through: size.width, by: 32) { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)) }
                    for y in stride(from: 0.0, through: size.height, by: 32) { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)) }
                    context.stroke(grid, with: .color(.white.opacity(0.025)), lineWidth: 1)
                    let rect = CGRect(x: size.width * 0.1, y: size.height * 0.26, width: size.width * 0.8, height: size.height * 0.5)
                    context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(.white.opacity(0.12)), lineWidth: 1)
                }.allowsHitTesting(false)
                VStack {
                    HStack { Text("STAGE PREVIEW").tracking(2); Spacer(); Text(mode == "Design" ? "⌘ / Shift-click to select more" : "Live levels") }
                    Spacer()
                    Text("AUDIENCE").tracking(5)
                }.font(.caption2).foregroundStyle(.secondary).padding(20).allowsHitTesting(false)
                ForEach(store.project.fixtures) { fixture in
                    let state = store.renderedState(for: fixture.id)
                    let color = Color(red: state.red, green: state.green, blue: state.blue)
                    let x = max(48, min(geo.size.width - 48, fixture.x * geo.size.width))
                    let y = max(58, min(geo.size.height - 68, fixture.y * geo.size.height))
                    ZStack {
                        Ellipse().fill(color.opacity(state.dimmer * 0.13)).frame(width: 95, height: 135).blur(radius: 12).offset(y: 50)
                        VStack(spacing: 7) {
                            Image(systemName: "lightbulb.led.fill").font(.system(size: 24))
                                .foregroundStyle(color).opacity(0.2 + state.dimmer * 0.8)
                                .padding(12).background(Color(white: 0.14), in: Circle())
                                .overlay(Circle().stroke(store.selectedFixtureIDs.contains(fixture.id) ? accent : .white.opacity(0.15), lineWidth: 2))
                            Text(fixture.name).font(.caption).lineLimit(1)
                            Text("\(Int(state.dimmer * 100))%").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 96, height: 110).contentShape(Rectangle())
                    .position(x: x, y: y)
                    .onTapGesture { store.selectFixture(id: fixture.id, extending: extendingSelection || selectionModifiers.contains(.command) || selectionModifiers.contains(.shift)) }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Select \(fixture.name)")
                    .accessibilityAddTraits(.isButton)
                    .gesture(DragGesture(coordinateSpace: .named("stage")).onChanged { value in
                        guard mode == "Design", let i = store.project.fixtures.firstIndex(where: { $0.id == fixture.id }) else { return }
                        if !store.selectedFixtureIDs.contains(fixture.id) { store.selectFixture(id: fixture.id) }
                        store.project.fixtures[i].x = min(0.94, max(0.06, value.location.x / geo.size.width))
                        store.project.fixtures[i].y = min(0.82, max(0.16, value.location.y / geo.size.height))
                    })
                }
                if store.project.fixtures.isEmpty {
                    VStack(spacing: 12) {
                        Text("Start with your lighting rig").font(.title3)
                        Button("Patch fixtures…") { showingPatch = true }
                    }
                }
            }.coordinateSpace(name: "stage").clipped()
        }
    }

    private var modeBar: some View {
        HStack {
            Picker("Workspace", selection: $mode) { Text("Design").tag("Design"); Text("Live").tag("Live") }
                .pickerStyle(.segmented).frame(width: 180)
            Spacer()
            if mode == "Design" {
                Toggle("Multi-select", isOn: $extendingSelection).toggleStyle(.button)
                Button(action: store.captureCue) { Label("Capture cue", systemImage: "plus.square") }
            } else {
                Button(action: store.goNext) { Label("Go Next", systemImage: "forward.end.fill") }.disabled(store.nextCueID == nil)
            }
        }.padding(.horizontal, 18).frame(height: 46)
    }

    private var designControls: some View {
        HStack(alignment: .top, spacing: 22) {
            if let fixture = store.selectedFixtures.first {
                VStack(alignment: .leading, spacing: 14) {
                    Text(store.selectedFixtures.count == 1 ? fixture.name : "\(store.selectedFixtures.count) fixtures selected").font(.headline)
                    Text(store.selectedFixtures.count == 1 ? "\(fixture.kind.title) · DMX \(fixture.address)–\(fixture.address + fixture.kind.footprint - 1)" : "Changes apply to the selection").font(.caption).foregroundStyle(.secondary)
                    channel("Dimmer", key: \.dimmer)
                    if !store.fixturesSupporting(\.white).isEmpty { channel("White", key: \.white) }
                }.frame(width: 185)
                if !store.fixturesSupporting(\.red).isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        ColorPicker("Color", selection: Binding(get: {
                            return Color(red: store.selectionValue(\.red), green: store.selectionValue(\.green), blue: store.selectionValue(\.blue))
                        }, set: { color in
                            guard let c = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                            store.setSelectionColor(red: Double(c.redComponent), green: Double(c.greenComponent), blue: Double(c.blueComponent))
                        }), supportsOpacity: false)
                        HStack(spacing: 8) {
                            ForEach(0..<8) { index in
                                let colors: [Color] = [.white, .red, .orange, .yellow, .green, .cyan, .blue, .purple]
                                Button {
                                    guard let c = NSColor(colors[index]).usingColorSpace(.deviceRGB) else { return }
                                    store.setSelectionColor(red: Double(c.redComponent), green: Double(c.greenComponent), blue: Double(c.blueComponent))
                                } label: { Circle().fill(colors[index]).frame(width: 21, height: 21).overlay(Circle().stroke(.white.opacity(0.3))) }
                                .buttonStyle(.plain).help(["White", "Red", "Amber", "Yellow", "Green", "Cyan", "Blue", "Purple"][index])
                            }
                        }
                        channel("Red", key: \.red)
                        channel("Green", key: \.green)
                        channel("Blue", key: \.blue)
                    }.frame(maxWidth: 280)
                }
                Spacer(minLength: 0)
            } else { Text("Select a fixture in the preview to design a look.").foregroundStyle(.secondary); Spacer() }
        }.padding(18)
    }

    private func channel(_ title: String, key: WritableKeyPath<FixtureState, Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title); Spacer()
                Text(store.selectionIsMixed(key) ? "Mixed" : "\(Int(store.selectionValue(key) * 100))%")
                    .monospacedDigit().foregroundStyle(.secondary)
            }.font(.caption)
            Slider(value: Binding(get: { store.selectionValue(key) }, set: { store.setSelectionValue(key, value: $0) }), in: 0...1).tint(accent)
                .accessibilityLabel("Selection \(title)")
        }
    }

    private func editGroup(_ group: FixtureGroup? = nil) {
        editingGroupID = group?.id
        groupName = group?.name ?? "Group \((store.project.fixtureGroups ?? []).count + 1)"
        groupMembers = group?.fixtureIDs ?? store.selectedFixtureIDs
        showingGroupEditor = true
    }
    private var groupControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FIXTURE GROUPS").font(.caption2).tracking(2)
                Spacer()
                Button { editGroup() } label: { Image(systemName: "plus") }.buttonStyle(.borderless).help("Save selection as a group")
            }
            HStack {
                Button("Select all", action: store.selectAllFixtures)
                Button("Clear") { store.selectedFixtureIDs = [] }
                Spacer()
                Text("\(store.selectedFixtures.count) selected").font(.caption2).foregroundStyle(.secondary)
            }.font(.caption).buttonStyle(.borderless)
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(store.project.fixtureGroups ?? []) { group in
                        HStack {
                            Button { store.selectGroup(id: group.id) } label: {
                                HStack {
                                    Image(systemName: "lightbulb.2")
                                    Text(group.name).lineLimit(1)
                                    Spacer()
                                    Text("\(group.fixtureIDs.count)").foregroundStyle(.secondary)
                                }.padding(7).background(store.selectedFixtureIDs == group.fixtureIDs ? accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain)
                            Menu {
                                Button("Edit group…") { editGroup(group) }
                                Button("Use current selection") { store.saveGroup(id: group.id, name: group.name, members: store.selectedFixtureIDs) }
                                    .disabled(store.selectedFixtureIDs.isEmpty)
                                Button("Delete group", role: .destructive) { store.removeGroup(id: group.id) }
                            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 18)
                        }
                    }
                    if (store.project.fixtureGroups ?? []).isEmpty {
                        Text("Select fixtures, then + to save a group.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.frame(height: 110)
        }
    }
    private var groupEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingGroupID == nil ? "New fixture group" : "Edit fixture group").font(.title2)
            TextField("Group name", text: $groupName).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.project.fixtures) { fixture in
                        Toggle(fixture.name, isOn: Binding(get: { groupMembers.contains(fixture.id) }, set: { included in
                            if included { groupMembers.insert(fixture.id) } else { groupMembers.remove(fixture.id) }
                        }))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Text("\(groupMembers.count) members").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { showingGroupEditor = false }.keyboardShortcut(.cancelAction)
                Button("Save group") {
                    store.saveGroup(id: editingGroupID, name: groupName, members: groupMembers)
                    showingGroupEditor = false
                }.disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || groupMembers.isEmpty).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 420, height: 390).preferredColorScheme(.dark)
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 12) {
            groupControls
            Divider()
            HStack { Text("LOOK PALETTE").font(.caption).tracking(2); Spacer(); Button(action: store.captureCue) { Image(systemName: "plus") }.buttonStyle(.borderless).help("Capture current look") }
            TextField("Find a cue", text: $paletteSearch).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(store.project.cues.enumerated()), id: \.element.id) { index, cue in
                        if paletteSearch.isEmpty || cue.name.localizedCaseInsensitiveContains(paletteSearch) {
                            Button { store.selectedCueID = cue.id } label: {
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 4).fill(cueColor(cue)).frame(width: 24, height: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(cue.name).lineLimit(1)
                                        Text("\(index + 1) · \(cue.fadeSeconds, specifier: "%.1f") s fade").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    if store.activeCueID == cue.id { Image(systemName: "play.fill").foregroundStyle(accent) }
                                }.padding(9).background(store.selectedCueID == cue.id ? accent.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            }.buttonStyle(.plain)
                            .contextMenu {
                                Button("Activate") { store.activateCue(id: cue.id) }
                                Button("Delete cue", role: .destructive) { store.removeCue(id: cue.id) }
                            }
                        }
                    }
                }
            }
            Divider()
            if let i = store.project.cues.firstIndex(where: { $0.id == store.selectedCueID }) {
                Text("CUE INSPECTOR").font(.caption2).tracking(2).foregroundStyle(.secondary)
                TextField("Cue name", text: $store.project.cues[i].name).textFieldStyle(.roundedBorder)
                HStack {
                    Text("Fade").font(.caption)
                    TextField("Seconds", value: $store.project.cues[i].fadeSeconds, format: .number).textFieldStyle(.roundedBorder).frame(width: 70)
                    Text("seconds").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Hold").font(.caption)
                    TextField("Seconds", value: Binding(get: { store.project.cues[i].sequenceHold }, set: { store.project.cues[i].holdSeconds = $0 }), format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 70)
                    Text("seconds").font(.caption).foregroundStyle(.secondary)
                }
                Button("Activate cue") { store.activateCue(id: store.project.cues[i].id) }.frame(maxWidth: .infinity)
                Button("Update from current look…") { confirmUpdate = true }.font(.caption)
            } else { Text("Capture a look to create a cue.").font(.caption).foregroundStyle(.secondary) }
        }.padding(16).background(Color(white: 0.08))
    }

    private func cueColor(_ cue: Cue) -> Color {
        let states = cue.levels.values.filter { $0.dimmer > 0 }
        guard !states.isEmpty else { return Color(white: 0.25) }
        let count = Double(states.count)
        return Color(red: states.reduce(0) { $0 + $1.red } / count, green: states.reduce(0) { $0 + $1.green } / count, blue: states.reduce(0) { $0 + $1.blue } / count)
    }

    private var liveControls: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("Live layout", selection: $liveStyle) { Text("Buttons").tag("Buttons"); Text("Cue list").tag("Cue list") }.pickerStyle(.segmented).frame(width: 180)
                Spacer()
                Toggle("Effects", isOn: $showEffects).toggleStyle(.button)
            }
            HStack(spacing: 12) {
                Button(action: store.startSequence) { Label(store.sequencePlayer == nil ? "Run sequence" : "Restart", systemImage: "play.circle") }
                    .disabled(store.project.cues.isEmpty)
                if let player = store.sequencePlayer {
                    Button(action: store.toggleSequencePause) { Label(player.isPaused ? "Resume" : "Pause", systemImage: player.isPaused ? "play.fill" : "pause.fill") }
                    Text("\(player.isPaused ? "Paused" : "Step \(player.index + 1)/\(player.steps.count)") · \(store.sequenceRemaining, specifier: "%.1f") s")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                } else {
                    Picker("Order", selection: Binding(get: { (store.project.sequenceSettings ?? SequenceSettings()).direction }, set: { value in
                        var settings = store.project.sequenceSettings ?? SequenceSettings(); settings.direction = value; store.project.sequenceSettings = settings
                    })) { ForEach(SequenceDirection.allCases) { direction in Text(direction.title).tag(direction) } }.labelsHidden().frame(width: 125)
                    Toggle("Repeat", isOn: Binding(get: { (store.project.sequenceSettings ?? SequenceSettings()).repeats }, set: { value in
                        var settings = store.project.sequenceSettings ?? SequenceSettings(); settings.repeats = value; store.project.sequenceSettings = settings
                    }))
                }
                Spacer(minLength: 0)
            }.font(.caption).help("Each cue fades, then holds. Timing edits apply on the next run. Pause freezes cue fades; global effects continue.")
            ScrollView {
                if showEffects { effectsPanel }
                else if liveStyle == "Buttons" {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                        ForEach(store.project.cues) { cue in
                            Button { store.activateCue(id: cue.id) } label: {
                                VStack(spacing: 8) {
                                    Text(cue.name).font(.headline).lineLimit(2)
                                    Label(store.activeCueID == cue.id ? "Active" : "\(cue.fadeSeconds.formatted()) s", systemImage: store.activeCueID == cue.id ? "play.fill" : "circle")
                                        .font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, minHeight: 76)
                                    .background(cueColor(cue).opacity(store.activeCueID == cue.id ? 0.45 : 0.15), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.activeCueID == cue.id ? accent : cueColor(cue).opacity(0.4), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        ForEach(Array(store.project.cues.enumerated()), id: \.element.id) { index, cue in
                            Button { store.activateCue(id: cue.id) } label: {
                                HStack {
                                    Text(String(format: "%02d", index + 1)).monospacedDigit().foregroundStyle(.secondary).frame(width: 28)
                                    Text(cue.name)
                                    Spacer()
                                    Text("Fade \(cue.fadeSeconds, specifier: "%.1f") s · Hold \(cue.sequenceHold, specifier: "%.1f") s").font(.caption).foregroundStyle(.secondary)
                                    Image(systemName: store.activeCueID == cue.id ? "play.fill" : "play").foregroundStyle(accent)
                                }.padding(10).background(store.activeCueID == cue.id ? accent.opacity(0.15) : .white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if store.project.cues.isEmpty && !showEffects { Text("Capture a look in Design to add a cue here.").foregroundStyle(.secondary).padding() }
            }
        }.padding(16)
    }

    private var effectsPanel: some View {
        VStack(spacing: 10) {
            ForEach($store.project.effects) { $effect in
                HStack(spacing: 14) {
                    Toggle(effect.name, isOn: $effect.enabled).frame(width: 145, alignment: .leading)
                    Canvas { context, size in
                        var curve = Path()
                        for step in 0...80 {
                            let x = Double(step) / 80
                            let y: Double
                            switch effect.kind {
                            case .sine: y = 1 - effect.depth + effect.depth * (sin(x * 4 * .pi) + 1) / 2
                            case .chase: y = Int(x * 6) % 3 == 0 ? 1 : 1 - effect.depth
                            case .rainbow: y = x
                            }
                            let p = CGPoint(x: x * size.width, y: (1 - y) * (size.height - 4) + 2)
                            if step == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
                        }
                        context.stroke(curve, with: .color(accent), lineWidth: 2)
                    }.frame(width: 80, height: 30).help("Pattern preview")
                    VStack { Text("\(effect.rate, specifier: "%.2f") Hz").font(.caption); Slider(value: $effect.rate, in: 0.05...4) }
                    VStack { Text("Depth \(Int(effect.depth * 100))%").font(.caption); Slider(value: $effect.depth, in: 0...1) }
                }.padding(10).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 16) {
            Button(action: store.stop) { Label("Stop", systemImage: "stop.fill") }
            Toggle("Blackout", isOn: $store.blackout).toggleStyle(.button).tint(.red)
            Divider().frame(height: 24)
            Text("Master").font(.caption)
            Slider(value: $store.master, in: 0...1).tint(accent).frame(width: 140)
            Text("\(Int(store.master * 100))%").font(.caption).monospacedDigit().frame(width: 35)
            Spacer()
            if let id = store.nextCueID, let cue = store.project.cues.first(where: { $0.id == id }) {
                Text("Next: \(cue.name)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Button { store.outputEnabled ? store.stopOutput() : store.startOutput() } label: {
                Label(store.outputEnabled ? "Stop output" : "Start output", systemImage: "network")
            }.buttonStyle(.borderedProminent).tint(store.outputEnabled ? .orange : accent)
        }.padding(.horizontal, 18).frame(height: 60)
    }

    private var patchSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Patch & Output").font(.title2); Spacer(); Button("Done") { showingPatch = false }.keyboardShortcut(.defaultAction) }
            HStack { Text("Fixture patch").font(.headline); Spacer(); Button(action: store.addFixture) { Label("Add fixture", systemImage: "plus") } }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($store.project.fixtures) { $fixture in
                        HStack(spacing: 14) {
                            Image(systemName: "lightbulb.led.fill").foregroundStyle(accent)
                            TextField("Fixture name", text: $fixture.name).textFieldStyle(.roundedBorder)
                            Picker("Type", selection: $fixture.kind) { ForEach(FixtureKind.allCases) { kind in Text(kind.title).tag(kind) } }.labelsHidden().frame(width: 95)
                            Stepper(value: $fixture.address, in: 1...max(1, 513 - fixture.kind.footprint)) { Text("DMX \(fixture.address)").monospacedDigit().frame(width: 75) }.frame(width: 135)
                            Button { store.removeFixture(id: fixture.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }.padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            Divider()
            Text("Art-Net output").font(.headline)
            HStack {
                Text("Destination")
                TextField("192.168.1.100", text: $store.project.destination).textFieldStyle(.roundedBorder).frame(width: 180)
                Stepper("Universe \(store.project.universe)", value: $store.project.universe, in: 1...32768)
            }
            Text("Use your node’s unicast address. Universe 1 maps to port-address 0. Output stays off until you start it.").font(.caption).foregroundStyle(.secondary)
            if let issue = patchIssue { Label(issue, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
        }.padding(24).frame(width: 720, height: 480).preferredColorScheme(.dark)
    }
    private var patchIssue: String? {
        do { try store.project.validate(); return nil } catch { return error.localizedDescription }
    }
}
