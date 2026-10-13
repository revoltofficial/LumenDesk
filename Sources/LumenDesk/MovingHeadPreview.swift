import SwiftUI

struct MovingHeadBeams: View {
    @EnvironmentObject var store: LightingStore
    var body: some View {
        Canvas { context, size in
            for fixture in store.project.fixtures where fixture.resolvedProfile.movingHead {
                let state = store.renderedState(for: fixture.id)
                guard state.dimmer > 0, fixture.height.isFinite, fixture.height > 0 else { continue }
                let pose = HeadPose(state: state, profile: fixture.resolvedProfile)
                let origin = CGPoint(x: max(48, min(size.width - 48, fixture.x * size.width)), y: max(58, min(size.height - 68, fixture.y * size.height)))
                func map(_ point: FloorPoint) -> CGPoint { CGPoint(x: origin.x + point.x * size.width / 12, y: origin.y + point.y * size.height / 8) }
                let points = pose.footprint(height: fixture.height)
                guard let first = points.first, let floor = pose.floorPoint(height: fixture.height) else { continue }
                let target = map(floor)
                var footprint = Path(); footprint.move(to: map(first))
                for point in points.dropFirst() { footprint.addLine(to: map(point)) }; footprint.closeSubpath()
                let color = Color(red: state.red, green: state.green, blue: state.blue)
                var beam = Path(); beam.move(to: origin)
                // Show the ray to the floor; the floor ellipse is derived from the same cone.
                beam.addLine(to: target)
                context.stroke(beam, with: .color(color.opacity(state.dimmer * 0.18)), lineWidth: 4)
                context.fill(footprint, with: .color(color.opacity(state.dimmer * 0.25)))
                context.stroke(footprint, with: .color(color.opacity(state.dimmer * 0.65)), lineWidth: 1)
                let gobos = fixture.resolvedProfile.gobos
                let index = min(max(0, fixture.resolvedProfile.goboIndex(state)), max(0, gobos.count - 1))
                if !gobos.isEmpty, gobos[index].pattern != "open" {
                    var clipped = context; clipped.clip(to: footprint)
                    let bounds = footprint.boundingRect
                    let pattern = gobos[index].pattern
                    if pattern == "dots" {
                        for row in -2...2 { for column in -2...2 {
                            let rect = CGRect(x: target.x + Double(column) * bounds.width / 5 - bounds.width / 18, y: target.y + Double(row) * bounds.height / 5 - bounds.height / 18, width: bounds.width / 9, height: bounds.height / 9)
                            clipped.fill(Path(ellipseIn: rect), with: .color(color.opacity(state.dimmer * 0.7)))
                        } }
                    } else if pattern == "star" {
                        var star = Path()
                        for step in 0..<10 {
                            let angle = Double(step) * .pi / 5 - .pi / 2
                            let radius = step % 2 == 0 ? 0.45 : 0.2
                            let point = CGPoint(x: target.x + cos(angle) * bounds.width * radius, y: target.y + sin(angle) * bounds.height * radius)
                            if step == 0 { star.move(to: point) } else { star.addLine(to: point) }
                        }; star.closeSubpath(); clipped.fill(star, with: .color(color.opacity(state.dimmer * 0.7)))
                    } else {
                        for stripe in -3...3 {
                            let rect = CGRect(x: target.x + Double(stripe) * bounds.width / 7, y: bounds.minY, width: bounds.width / 14, height: bounds.height)
                            clipped.fill(Path(rect), with: .color(color.opacity(state.dimmer * 0.7)))
                        }
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
struct MovingHeadGlyph: View {
    var pose: HeadPose
    var color: Color
    var intensity: Double
    var body: some View {
        Canvas { context, _ in
            func project(_ v: Vector3) -> CGPoint { CGPoint(x: 26 + v.x * 15 + v.y * 6, y: 28 + v.y * 5 - v.z * 15) }
            let yaw = pose.pan * .pi / 180
            let left = Vector3(x: -cos(yaw) * 0.65, y: sin(yaw) * 0.65, z: 0)
            let right = left * -1
            var yoke = Path()
            yoke.move(to: project(left)); yoke.addLine(to: project(left + Vector3(x: 0, y: 0, z: 1)))
            yoke.addLine(to: project(right + Vector3(x: 0, y: 0, z: 1))); yoke.addLine(to: project(right))
            context.stroke(yoke, with: .color(.gray), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            let d = pose.direction
            let back = project(d * -0.45), lens = project(d * 0.6)
            var head = Path(); head.move(to: back); head.addLine(to: lens)
            context.stroke(head, with: .color(Color(white: 0.26)), style: StrokeStyle(lineWidth: 17, lineCap: .round))
            context.stroke(head, with: .color(Color(white: 0.43)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
            let glass = CGRect(x: lens.x - 6, y: lens.y - 4, width: 12, height: 8)
            context.fill(Path(ellipseIn: glass), with: .color(color.opacity(0.15 + intensity * 0.85)))
            let base = CGRect(x: 14, y: 5, width: 24, height: 6)
            context.fill(Path(roundedRect: base, cornerRadius: 2), with: .color(.gray))
        }.frame(width: 52, height: 54).accessibilityHidden(true)
    }
}
