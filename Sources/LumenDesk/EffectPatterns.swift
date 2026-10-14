import SwiftUI
import AppKit

enum Waveform: String, Codable, CaseIterable { case sine, triangle, square, rampUp, rampDown
    var title: String { switch self { case .rampUp: return "Ramp up"; case .rampDown: return "Ramp down"; default: return rawValue.capitalized } }
    func value(at phase: Double) -> Double {
        let x = phase - floor(phase)
        switch self { case .sine: return (sin(x * 2 * .pi) + 1) / 2; case .triangle: return 1 - abs(2 * x - 1); case .square: return x < 0.5 ? 1 : 0; case .rampUp: return x; case .rampDown: return 1 - x }
    }
}
enum MovementPattern: String, Codable, CaseIterable { case circle, figureEight, sweep, verticalSweep, fan, wave, spiral, zigzag, cross, wander, atmosphere, custom
    var title: String { switch self { case .figureEight: return "Figure eight"; case .verticalSweep: return "Vertical sweep"; case .wander: return "Smooth wander"; case .atmosphere: return "Slow atmosphere"; default: return rawValue.capitalized } }
}
struct MotionPoint: Codable, Equatable { var x: Double; var y: Double
    var valid: Bool { x.isFinite && y.isFinite && (-1...1).contains(x) && (-1...1).contains(y) }
}
enum MotionPath {
    static let defaults = [MotionPoint(x: -0.8, y: 0), MotionPoint(x: 0, y: 0.8), MotionPoint(x: 0.8, y: 0), MotionPoint(x: 0, y: -0.8)]
    static func sample(effect: Effect, phase: Double) -> MotionPoint {
        let adjusted = (effect.reverse == true ? -phase : phase) + (effect.motionPhase ?? 0)
        let p = adjusted - floor(adjusted), angle = p * 2 * Double.pi
        switch effect.movement ?? .circle {
        case .circle: return MotionPoint(x: sin(angle), y: cos(angle))
        case .figureEight: return MotionPoint(x: sin(angle), y: sin(angle * 2))
        case .sweep: return MotionPoint(x: 2 * Waveform.triangle.value(at: p) - 1, y: 0)
        case .verticalSweep: return MotionPoint(x: 0, y: sin(angle))
        case .fan: return MotionPoint(x: 0.65 + 0.35 * sin(angle), y: 0.4 * cos(angle))
        case .wave: return MotionPoint(x: sin(angle), y: 0.35 * sin(3 * angle))
        case .spiral:
            let radius = 0.55 + 0.45 * cos(angle)
            return MotionPoint(x: radius * sin(3 * angle), y: radius * cos(3 * angle))
        case .zigzag: return MotionPoint(x: 2 * Waveform.triangle.value(at: p) - 1, y: 0.65 * sin(3 * angle))
        case .cross: return MotionPoint(x: sin(angle), y: sin(angle))
        case .wander: return MotionPoint(x: (sin(angle) + 0.5 * sin(3 * angle + 0.7)) / 1.5, y: (cos(2 * angle + 0.4) + 0.5 * sin(5 * angle)) / 1.5)
        case .atmosphere: return MotionPoint(x: 0.5 * sin(angle), y: 0.25 * sin(2 * angle))
        case .custom:
            let points = effect.pathPoints ?? defaults
            guard points.count >= 2 else { return MotionPoint(x: 0, y: 0) }
            let closed = effect.pathClosed ?? true
            // Open paths return along the same path, avoiding a jump at the cycle boundary.
            let travel = closed ? p : Waveform.triangle.value(at: p)
            let segments = closed ? points.count : points.count - 1
            let scaled = travel * Double(segments)
            let i = min(segments - 1, Int(scaled)), t = scaled - Double(i)
            let a = points[i], b = points[(i + 1) % points.count]
            return MotionPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }
}
struct EffectColor: Codable { var red: Double; var green: Double; var blue: Double
    var valid: Bool { [red,green,blue].allSatisfy { $0.isFinite && (0...1).contains($0) } }
    var color: Color { Color(red: red, green: green, blue: blue) }
    static func hue(_ hue: Double) -> Self { let c = NSColor(calibratedHue: hue, saturation: 1, brightness: 1, alpha: 1); return Self(red: Double(c.redComponent), green: Double(c.greenComponent), blue: Double(c.blueComponent)) }
    static let disco = [hue(0.92), hue(0.12), hue(0.48), hue(0.72)]
    static let techno = [Self(red: 0.1, green: 0.03, blue: 0.45), Self(red: 0.35, green: 0, blue: 0.06), Self(red: 0.02, green: 0.15, blue: 0.35)]
}
struct EffectEditor: View {
    @Binding var effect: Effect
    @State private var editingPath = false
    @State private var browsingMovements = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(effect.name, isOn: $effect.enabled).frame(width: 155, alignment: .leading)
                Picker("Timing", selection: Binding(get: { effect.beatTiming ?? false }, set: { effect.beatTiming = $0 })) { Text("Seconds").tag(false); Text("Beats").tag(true) }.pickerStyle(.segmented).frame(width: 150)
                if effect.beatTiming == true {
                    Picker("Cycle", selection: Binding(get: { effect.cycleBeats }, set: { effect.beatsPerCycle = $0 })) { ForEach([0.25,0.5,1,2,4,8,16,32,64], id: \.self) { Text("\($0.formatted()) beats").tag($0) } }.frame(width: 155)
                } else {
                    Text("\(1 / max(0.05,effect.rate), specifier: "%.2f") s / \(effect.kind == .chase ? "step" : "cycle")").font(.caption)
                    Slider(value: $effect.rate, in: 0.05...4).frame(width: 90)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Text("Depth").font(.caption); Slider(value: $effect.depth, in: 0...1).frame(width: 110)
                Text("Spread").font(.caption); Slider(value: Binding(get: { effect.spread ?? 1 }, set: { effect.spread = $0 }), in: 0...1).frame(width: 110)
                if effect.kind == .sine || effect.kind == .scanner {
                    Picker("Shape", selection: Binding(get: { effect.waveform ?? (effect.kind == .scanner ? .triangle : .sine) }, set: { effect.waveform = $0 })) { ForEach(Waveform.allCases, id: \.self) { Text($0.title).tag($0) } }.frame(width: 160)
                }
                if effect.kind == .circle {
                    Picker("Path", selection: Binding(get: { effect.movement ?? .circle }, set: { effect.movement = $0 })) { ForEach(MovementPattern.allCases, id: \.self) { Text($0.title).tag($0) } }.frame(width: 175)
                    Button("Library…") { browsingMovements = true }
                    Button("Edit path…") { editingPath = true }
                }
                if effect.kind == .colorChase {
                    Menu("Palette") { Button("Disco") { effect.colors = EffectColor.disco }; Button("Techno") { effect.colors = EffectColor.techno } }
                    ForEach(Array((effect.colors ?? EffectColor.disco).enumerated()), id: \.offset) { _, c in Circle().fill(c.color).frame(width: 14,height: 14) }
                }
                Spacer(minLength: 0)
            }
            if effect.kind == .circle { MovementParameters(effect: $effect) }
        }.padding(10).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
            .sheet(isPresented: $editingPath) { MovementPathEditor(effect: $effect) }
            .sheet(isPresented: $browsingMovements) { MovementLibraryView(effect: $effect) }
    }
}
struct MovementPathEditor: View {
    @Binding var effect: Effect
    @Environment(\.dismiss) var dismiss
    @State private var selected = 0
    private var points: [MotionPoint] { effect.pathPoints ?? MotionPath.defaults }
    private func coordinate(_ key: WritableKeyPath<MotionPoint, Double>) -> Binding<Double> {
        Binding(get: { points[min(selected,points.count-1)][keyPath: key] },set: { value in
            guard value.isFinite else { return }; var copy = points; copy[min(selected,copy.count-1)][keyPath: key] = min(1,max(-1,value)); effect.pathPoints = copy; effect.movement = .custom
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Movement path").font(.title2); Spacer(); Button("Done") { dismiss() } }
            Text("Drag points to shape relative pan and tilt. Depth controls the size; the fixture's current position is the center.").foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack {
                    Color.white.opacity(0.04)
                    Canvas { ctx, size in
                        var grid = Path(); grid.move(to: CGPoint(x: size.width/2,y: 0)); grid.addLine(to: CGPoint(x: size.width/2,y: size.height)); grid.move(to: CGPoint(x: 0,y: size.height/2)); grid.addLine(to: CGPoint(x: size.width,y: size.height/2)); ctx.stroke(grid,with: .color(.gray),lineWidth: 1)
                        var path = Path()
                        for (i,p) in points.enumerated() { let q = CGPoint(x: (p.x+1)*size.width/2,y: (1-p.y)*size.height/2); if i == 0 { path.move(to:q) } else { path.addLine(to:q) } }
                        if effect.pathClosed ?? true { path.closeSubpath() }
                        ctx.stroke(path,with: .color(.mint),lineWidth: 2)
                    }
                    ForEach(points.indices, id: \.self) { i in
                        Text("\(i+1)").font(.caption).frame(width: 26,height: 26).background(i == selected ? Color.orange : Color.mint,in: Circle()).foregroundStyle(.black)
                            .position(x: (points[i].x+1)*geo.size.width/2,y: (1-points[i].y)*geo.size.height/2)
                            .onTapGesture { selected = i }
                            .gesture(DragGesture(coordinateSpace: .named("path")).onChanged { value in
                                selected = i; var copy = points; copy[i] = MotionPoint(x: min(1,max(-1,Double(value.location.x/geo.size.width)*2-1)),y: min(1,max(-1,1-Double(value.location.y/geo.size.height)*2)))
                                effect.pathPoints = copy; effect.movement = .custom
                            })
                    }
                }.coordinateSpace(name: "path")
            }.frame(width: 480,height: 300).clipped()
            HStack {
                Button("Add point") { var copy = points; copy.insert(MotionPoint(x: 0,y: 0),at: min(selected+1,copy.count)); effect.pathPoints = copy; effect.movement = .custom }.disabled(points.count >= 32)
                Button("Remove selected") { var copy = points; copy.remove(at: min(selected,copy.count-1)); effect.pathPoints = copy; selected = max(0,selected-1); effect.movement = .custom }.disabled(points.count <= 2)
                Toggle("Closed loop",isOn: Binding(get: { effect.pathClosed ?? true },set: { effect.pathClosed = $0 }))
                Button("Reset") { effect.pathPoints = MotionPath.defaults; effect.movement = .custom }
            }
            HStack {
                Text("Selected point \(selected + 1)")
                TextField("Pan offset", value: coordinate(\.x), format: .number.precision(.fractionLength(2))).frame(width: 100)
                TextField("Tilt offset", value: coordinate(\.y), format: .number.precision(.fractionLength(2))).frame(width: 100)
            }
            Text("Pan ↔ · Tilt ↕ · Open paths travel back and forth").font(.caption).foregroundStyle(.secondary)
        }.padding(22).onAppear { effect.movement = .custom; if effect.pathPoints == nil { effect.pathPoints = MotionPath.defaults } }
    }
}
