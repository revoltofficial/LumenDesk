import SwiftUI
import AppKit

struct ColorEffectPreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var effect: Effect
    var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && effect.kind == .colorPattern && effect.validTiming && effect.rate.isFinite && (0...20).contains(effect.rate) && effect.depth.isFinite && (0...1).contains(effect.depth) }
}
extension LightingStore {
    func prepareColorLibrary() -> UUID {
        if let effect = project.effects.first(where: { $0.kind == .colorPattern }) { return effect.id }
        let effect = ColorPatternRenderer.preset(.fade); project.effects.append(effect); return effect.id
    }
    @discardableResult func saveColorPreset(name: String,effect: Effect) -> UUID? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var saved = effect; saved.enabled = false; saved.id = UUID(); saved.name = name
        let preset = ColorEffectPreset(name:name,effect:saved)
        guard preset.valid, (project.colorPresets ?? []).count < 64 else { return nil }
        var presets = project.colorPresets ?? []; presets.append(preset); project.colorPresets = presets
        return preset.id
    }
}
private struct ColorSheetID: Identifiable { var id: UUID }
struct ColorLibraryButton: View {
    @EnvironmentObject var store: LightingStore
    @State private var effectID: UUID?
    var body: some View {
        Button("Colour library…") { effectID = store.prepareColorLibrary() }
            .sheet(item: Binding(get: { effectID.map { ColorSheetID(id:$0) } },set: { effectID = $0?.id })) { item in
                ColorLibraryView(effect: store.movementBinding(id:item.id))
            }
    }
}
struct ColorPatternStrip: View {
    @EnvironmentObject var store: LightingStore
    var effect: Effect
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<8,id: \.self) { index in
                let cycles = effect.beatTiming == true ? store.tempoClock.beats/effect.cycleBeats : store.phase*effect.rate
                let sample = ColorPatternRenderer.sample(effect:effect,cycles:cycles,index:index,count:8)
                RoundedRectangle(cornerRadius: 4).fill(sample.color.color.opacity(effect.colorIntensity == true ? sample.intensity : 1))
            }
        }.frame(height: 28).accessibilityLabel("Animated \((effect.colorPattern ?? .fade).title) colour preview")
    }
}
struct ColorLibraryView: View {
    @Binding var effect: Effect
    @EnvironmentObject var store: LightingStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = "My colour effect"
    @State private var message = ""
    private var colors: [EffectColor] { effect.colors ?? ColorPalette.disco.colors }
    private func apply(_ source: Effect) { var value = source; value.id = effect.id; value.enabled = true; effect = value; message = "" }
    private func choose(_ pattern: ColorPattern) {
        var value = ColorPatternRenderer.preset(pattern)
        if pattern != .fire && pattern != .police { value.colors = colors; value.colorPalette = effect.colorPalette }
        apply(value)
    }
    private func swatch(_ index: Int) -> Binding<Color> {
        Binding(get: { colors.indices.contains(index) ? colors[index].color : .white },set: { value in
            guard let rgb = NSColor(value).usingColorSpace(.deviceRGB), colors.indices.contains(index) else { return }
            var copy = colors; copy[index] = .rgb(Double(rgb.redComponent),Double(rgb.greenComponent),Double(rgb.blueComponent))
            effect.colors = copy; effect.colorPalette = nil
        })
    }
    private func parameter(_ key: WritableKeyPath<Effect,Double?>,fallback: Double) -> Binding<Double> {
        Binding(get: { effect[keyPath:key] ?? fallback },set: { effect[keyPath:key] = $0 })
    }
    var body: some View {
        VStack(alignment: .leading,spacing: 12) {
            HStack { Text("Colour effects library").font(.title2); Spacer(); Button("Done") { dismiss() } }
            Text("Choose a pattern to start it on RGB/RGBW fixtures. Lasers stay manual. Turn Autopilot off to see these colours without its override. Raise dimmer or activate a cue to light the fixtures.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading,spacing: 12) {
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:5),spacing:10) {
                        ForEach(ColorPattern.allCases,id: \.self) { pattern in patternCard(pattern) }
                    }
                    Text("Palettes").font(.headline)
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:5),spacing:8) {
                        ForEach(ColorPalette.allCases,id: \.self) { palette in paletteCard(palette) }
                    }
                    Text("Saved colour presets").font(.headline)
                    if (store.project.colorPresets ?? []).isEmpty { Text("Save your settings below to reuse them in this show.").font(.caption).foregroundStyle(.secondary) }
                    ForEach(store.project.colorPresets ?? []) { preset in
                        HStack {
                            Button(preset.name) { apply(preset.effect) }
                            Spacer()
                            Button("Remove") { store.project.colorPresets?.removeAll { $0.id == preset.id } }
                        }
                    }
                }
            }.frame(height: 235)
            Divider()
            HStack { Text(effect.name).font(.headline); Toggle("Effect enabled",isOn:$effect.enabled); Spacer(); Toggle("Animate intensity",isOn:Binding(get: { effect.colorIntensity ?? false },set: { effect.colorIntensity = $0 })) }
            ColorPatternStrip(effect:effect)
            settings
            HStack(spacing: 6) {
                ForEach(colors.indices,id: \.self) { index in
                    VStack(spacing: 2) {
                        ColorPicker("Colour \(index+1)",selection:swatch(index),supportsOpacity:false).labelsHidden().frame(width: 28)
                        Button { guard colors.indices.contains(index) else { return }; var copy = colors; copy.remove(at:index); effect.colors = copy; effect.colorPalette = nil } label: { Image(systemName:"minus") }
                            .buttonStyle(.plain).disabled(colors.count <= 1).accessibilityLabel("Remove colour \(index+1)")
                    }
                }
                Button { var copy = colors; copy.append(.rgb(1,1,1)); effect.colors = copy; effect.colorPalette = nil } label: { Image(systemName:"plus") }.disabled(colors.count >= 16).accessibilityLabel("Add palette colour")
                Spacer()
            }
            HStack {
                TextField("Preset name",text:$name).textFieldStyle(.roundedBorder).frame(width:190)
                Button("Save colour preset") { message = store.saveColorPreset(name:name,effect:effect) == nil ? "Enter a name; up to 64 presets can be saved." : "Saved in this show." }
                Text(message).font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }.padding(20).frame(width: 780)
    }
    private var settings: some View {
        VStack(alignment: .leading,spacing: 8) {
            HStack {
                Picker("Timing",selection:Binding(get:{ effect.beatTiming ?? false },set:{ effect.beatTiming = $0 })) { Text("Beats").tag(true); Text("Seconds").tag(false) }.pickerStyle(.segmented).frame(width:140)
                if effect.beatTiming == true {
                    Picker("Cycle",selection:Binding(get:{ effect.cycleBeats },set:{ effect.beatsPerCycle = $0 })) {
                        ForEach([0.25,0.5,1,2,4,8,16,32,64],id: \.self) { Text("\($0.formatted()) beats").tag($0) }
                    }.frame(width:150)
                } else { Slider(value:$effect.rate,in:0.05...4).frame(width:120).accessibilityLabel("Colour effect speed"); Text("\(1/max(0.05,effect.rate),specifier:"%.1f") s").font(.caption) }
                Toggle("Reverse",isOn:Binding(get:{ effect.colorReverse ?? false },set:{ effect.colorReverse = $0 }))
                Text("Phase").font(.caption); Slider(value:parameter(\.colorPhase,fallback:0),in:0...1).frame(width:95).accessibilityLabel("Colour effect phase")
            }
            HStack {
                Text("Depth").font(.caption); Slider(value:$effect.depth,in:0...1).frame(width:100).accessibilityLabel("Colour effect depth")
                Text("Spread").font(.caption); Slider(value:parameter(\.spread,fallback:0.75),in:0...1).frame(width:100).accessibilityLabel("Colour effect spread")
                Text("Fade/chase softness").font(.caption); Slider(value:parameter(\.colorSmoothness,fallback:1),in:0...1).frame(width:100).accessibilityLabel("Colour transition softness")
            }
        }
    }
    private func patternCard(_ pattern: ColorPattern) -> some View {
        var preview = ColorPatternRenderer.preset(pattern); preview.colors = colors
        return Button { choose(pattern) } label: { VStack { ColorPatternStrip(effect:preview); Text(pattern.title).font(.caption) }.padding(7) }.buttonStyle(.plain).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:8)).accessibilityLabel("Use colour \(pattern.title)")
    }
    private func paletteCard(_ palette: ColorPalette) -> some View {
        Button { effect.colors = palette.colors; effect.colorPalette = palette } label: {
            VStack(spacing:4) { HStack(spacing:2) { ForEach(palette.colors.indices,id: \.self) { index in Rectangle().fill(palette.colors[index].color) } }.frame(height:18); Text(palette.title).font(.caption) }.padding(6)
        }.buttonStyle(.plain).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:6)).accessibilityLabel("Use palette \(palette.title)")
    }
}
