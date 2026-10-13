import SwiftUI

struct PresetWorkspace: View {
    @EnvironmentObject var store: LightingStore
    @State private var capturing = false
    @State private var composing = false
    @State private var name = ""
    @State private var kind = PresetKind.color
    @State private var chosen: Set<UUID> = []
    @State private var priority = 50
    @State private var fade = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("PRESETS").font(.caption).tracking(2)
                    Spacer()
                    Button("Capture preset…") { name = "Preset \((store.project.presets ?? []).count + 1)"; capturing = true }
                        .disabled(store.selectedFixtures.isEmpty)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.project.presets ?? []) { preset in
                            HStack {
                                Image(systemName: preset.kind == .effects ? "waveform" : "square.stack")
                                Text(preset.name).lineLimit(1)
                                Spacer()
                                Text("\(preset.kind.title) · \(preset.values.count)").font(.caption).foregroundStyle(.secondary)
                            }.contextMenu {
                                Button("Delete preset and its layered cues", role: .destructive) { store.removePreset(id: preset.id) }
                            }
                        }
                        if (store.project.presets ?? []).isEmpty {
                            Text("Select fixtures, design a look, then capture its color, intensity, or effects.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.frame(maxWidth: .infinity)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("LAYERED CUES").font(.caption).tracking(2)
                    Spacer()
                    Button("New layer…") { name = "Layer \((store.project.layerCues ?? []).count + 1)"; chosen = []; priority = 50; fade = 1; composing = true }
                        .disabled((store.project.presets ?? []).isEmpty)
                    Button("Release all", action: store.releaseAllLayers).disabled(store.layerMixer.layers.isEmpty)
                }
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.project.layerCues ?? []) { cue in
                            let active = store.layerMixer.layers.contains { $0.id == cue.id }
                            HStack {
                                Button {
                                    if active { store.releaseLayer(id: cue.id) } else { store.activateLayer(id: cue.id) }
                                } label: {
                                    HStack {
                                        Image(systemName: active ? "checkmark.circle.fill" : "play.circle")
                                        Text(cue.name).lineLimit(1)
                                        Spacer()
                                        Text(active ? "Release" : "Activate").font(.caption)
                                    }.padding(8).background(active ? Color.mint.opacity(0.18) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                                }.buttonStyle(.plain).accessibilityLabel("\(active ? "Release" : "Activate") layer \(cue.name)")
                                Text("P\(cue.priority)").font(.caption2).foregroundStyle(.secondary)
                            }.contextMenu {
                                Button("Delete layer", role: .destructive) { store.removeLayer(id: cue.id) }
                            }
                        }
                        if (store.project.layerCues ?? []).isEmpty {
                            Text("Combine presets into a layer. Higher priority wins; at equal priority, the latest activation wins. Release instantly reveals the underlying look.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.frame(maxWidth: .infinity)
        }.padding(16)
        .sheet(isPresented: $capturing) { captureSheet }
        .sheet(isPresented: $composing) { composeSheet }
    }
    private var captureSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Capture preset").font(.title2)
            TextField("Preset name", text: $name).textFieldStyle(.roundedBorder)
            Picker("Capture", selection: $kind) { ForEach(PresetKind.allCases) { kind in Text(kind.title).tag(kind) } }
            Text("Applies to \(store.selectedFixtures.count) selected fixtures. Color leaves intensity untouched. Effects captures the enabled global effects; Look captures levels and effects.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { capturing = false }.keyboardShortcut(.cancelAction)
                Button("Save preset") { store.capturePreset(name: name, kind: kind); capturing = false }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 450).preferredColorScheme(.dark)
    }
    private var composeSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New layered cue").font(.title2)
            TextField("Layer name", text: $name).textFieldStyle(.roundedBorder)
            Text("Choose presets in palette order. Later presets replace overlapping channels within this cue.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.project.presets ?? []) { preset in
                        Toggle("\(preset.name) · \(preset.kind.title)", isOn: Binding(get: { chosen.contains(preset.id) }, set: { included in
                            if included { chosen.insert(preset.id) } else { chosen.remove(preset.id) }
                        }))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Stepper("Priority \(priority)", value: $priority, in: 0...100)
            HStack {
                Text("Fade in")
                TextField("Seconds", value: $fade, format: .number).textFieldStyle(.roundedBorder).frame(width: 90)
                Text("seconds").foregroundStyle(.secondary)
            }
            Text("Effects switch immediately. Release restores the underlying scene and layers immediately. Manual level edits take over all active layers.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { composing = false }.keyboardShortcut(.cancelAction)
                Button("Save layer") {
                    store.saveLayer(name: name, presetIDs: (store.project.presets ?? []).filter { chosen.contains($0.id) }.map(\.id), priority: priority, fadeSeconds: fade)
                    composing = false
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chosen.isEmpty || !fade.isFinite || !(0...3600).contains(fade)).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 480, height: 460).preferredColorScheme(.dark)
    }
}
