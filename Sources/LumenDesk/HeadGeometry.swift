import Foundation

struct Vector3 {
    var x: Double; var y: Double; var z: Double
    static func + (a: Self, b: Self) -> Self { Self(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func * (a: Self, b: Double) -> Self { Self(x: a.x * b, y: a.y * b, z: a.z * b) }
}
struct FloorPoint { var x: Double; var y: Double }
struct HeadPose {
    var pan: Double
    var tilt: Double
    var beamDegrees: Double
    var direction: Vector3 {
        let p = pan * .pi / 180, t = tilt * .pi / 180
        // Hanging mount: neutral tilt aims straight down; neutral pan faces the audience (+Y).
        return Vector3(x: sin(p) * sin(t), y: cos(p) * sin(t), z: -cos(t))
    }
    init(state: FixtureState, profile: FixtureProfile) {
        pan = (state.pan - 0.5) * profile.panDegrees
        tilt = (state.tilt - 0.5) * profile.tiltDegrees
        beamDegrees = profile.minimumBeamDegrees + state.zoom * (profile.maximumBeamDegrees - profile.minimumBeamDegrees)
    }
    func floorPoint(height: Double) -> FloorPoint? {
        let d = direction
        guard d.z < -0.001 else { return nil }
        let distance = height / -d.z
        return FloorPoint(x: d.x * distance, y: d.y * distance)
    }
    func footprint(height: Double) -> [FloorPoint] {
        let p = pan * .pi / 180, t = tilt * .pi / 180
        let d = direction
        let u = Vector3(x: cos(p), y: -sin(p), z: 0)
        let v = Vector3(x: sin(p) * cos(t), y: cos(p) * cos(t), z: sin(t))
        let angle = beamDegrees * .pi / 360
        var points: [FloorPoint] = []
        for step in 0..<40 {
            let phi = Double(step) * 2 * .pi / 40
            let ray = d * cos(angle) + u * (sin(angle) * cos(phi)) + v * (sin(angle) * sin(phi))
            // A cone crossing the horizon has no bounded floor ellipse.
            guard ray.z < -0.001 else { return [] }
            let distance = height / -ray.z
            points.append(FloorPoint(x: ray.x * distance, y: ray.y * distance))
        }
        return points
    }
}
