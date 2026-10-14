import SwiftUI

struct MovementControls: View {
    @EnvironmentObject var store: LightingStore
    var beam = false
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            if let fixture = store.selectedFixtures.first(where: { $0.resolvedProfile.movingHead }) {
                let state = store.state(for: fixture.id)
                let profile = fixture.resolvedProfile
                if beam {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Beam & gobo").font(.headline)
                        Text("\(profile.name)").font(.caption).foregroundStyle(.secondary)
                        if profile.supports(.zoom) {
                            Text("Beam angle \(profile.minimumBeamDegrees + state.zoom * (profile.maximumBeamDegrees - profile.minimumBeamDegrees), specifier: "%.1f")°").font(.caption)
                            Slider(value: Binding(get: { store.selectionValue(\.zoom) }, set: { store.setSelectionValue(\.zoom, value: $0) }), in: 0...1).accessibilityLabel("Selection Zoom")
                        }
                        if !profile.gobos.isEmpty {
                            Picker("Gobo · \(fixture.name)", selection: Binding(get: { profile.goboIndex(store.state(for: fixture.id)) }, set: { store.setGobo(id: fixture.id, index: $0) })) {
                                ForEach(profile.gobos.indices, id: \.self) { index in Text(profile.gobos[index].name).tag(index) }
                            }.help("Gobo applies to this fixture; different profiles can use different wheels.")
                        }
                    }.frame(width: 300)
                    Text("Gobo shapes are schematic. Zoom uses the profile’s beam-angle limits. Capture a Beam preset to reuse these settings.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: 240)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pan / Tilt").font(.headline)
                        Text("Drag to position the selected heads").font(.caption).foregroundStyle(.secondary)
                        positionPad.frame(width: 210, height: 125)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        axis("Pan", key: \.pan, range: profile.panDegrees)
                        axis("Tilt", key: \.tilt, range: profile.tiltDegrees)
                        motionSettings
                        HStack {
                            Button("Center") { store.setSelectionPosition(pan: 0.5, tilt: 0.5) }
                            Button("Aim forward") { store.setSelectionPosition(pan: 0.5, tilt: 0.65) }
                        }.font(.caption)
                        Text("Hanging mount · \(fixture.height, specifier: "%.1f") m\nAbsolute travel: fades do not wrap at 360°. The floor beam disappears when it points above the horizon.").font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: 275)
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select a moving head to control its movement.").foregroundStyle(.secondary)
                    Button("Add moving-head demo", action: store.addMovementDemo)
                }
                Spacer()
            }
        }.padding(18)
    }
    private var motionSettings: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Smooth movement · all heads").font(.caption)
            HStack {
                Text("Speed °/s").font(.caption2)
                TextField("Speed", value: Binding(get: { (store.project.motion ?? MotionSettings()).speed }, set: { value in
                    guard value.isFinite, (1...720).contains(value) else { return }
                    var settings = store.project.motion ?? MotionSettings(); settings.speed = value; store.project.motion = settings
                }), format: .number).frame(width: 65).accessibilityLabel("Movement speed limit")
                Text("Accel °/s²").font(.caption2)
                TextField("Acceleration", value: Binding(get: { (store.project.motion ?? MotionSettings()).acceleration }, set: { value in
                    guard value.isFinite, (1...3600).contains(value) else { return }
                    var settings = store.project.motion ?? MotionSettings(); settings.acceleration = value; store.project.motion = settings
                }), format: .number).frame(width: 65).accessibilityLabel("Movement acceleration limit")
            }
            Text("Limits apply to preview and output. Fast effects may take longer to reach their targets.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func axis(_ name: String, key: WritableKeyPath<FixtureState, Double>, range: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                Spacer()
                Text(store.selectionIsMixed(key) ? "Mixed" : "\((store.selectionValue(key) - 0.5) * range, specifier: "%.1f")°")
            }.font(.caption).monospacedDigit()
            Slider(value: Binding(get: { store.selectionValue(key) }, set: { store.setSelectionValue(key, value: $0) }), in: 0...1).accessibilityLabel("Selection \(name)")
        }
    }
    private var positionPad: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)).overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.15)))
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 2, y: 0)); path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2)); path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }.stroke(.white.opacity(0.12))
                Circle().fill(.mint).frame(width: 12, height: 12)
                    .position(x: CGFloat(store.selectionValue(\.pan)) * geo.size.width, y: CGFloat(1.0 - store.selectionValue(\.tilt)) * geo.size.height)
            }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in
                store.setSelectionPosition(pan: Double(value.location.x / geo.size.width), tilt: 1.0 - Double(value.location.y / geo.size.height))
            })
            .accessibilityLabel("Pan Tilt position pad")
        }
    }
}
