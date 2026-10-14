import Foundation

struct MotionSettings: Codable {
    var enabled = true
    var speed: Double = 90
    var acceleration: Double = 180
    var valid: Bool { speed.isFinite && acceleration.isFinite && (1...720).contains(speed) && (1...3600).contains(acceleration) }
}

struct MotionAxis {
    var position: Double
    var velocity: Double = 0
    mutating func advance(target: Double, seconds: Double, range: Double, settings: MotionSettings) {
        guard seconds.isFinite, seconds > 0, target.isFinite, range.isFinite, range > 0, settings.valid else { return }
        let target = min(range, max(0, target))
        // Small integration steps keep the damped controller stable. A stalled UI
        // never catches up by jumping through seconds of missed motor travel.
        let duration = min(0.25, seconds)
        let steps = max(1, Int(ceil(duration * 120)))
        let dt = duration / Double(steps)
        for _ in 0..<steps {
            let force = 36 * (target - position) - 12 * velocity
            let acceleration = min(settings.acceleration, max(-settings.acceleration, force))
            let nextVelocity = min(settings.speed, max(-settings.speed, velocity + acceleration * dt))
            position += (velocity + nextVelocity) * 0.5 * dt
            velocity = nextVelocity
            // Physical travel limits take priority over a soft deceleration.
            if position <= 0 { position = 0; velocity = max(0, velocity) }
            if position >= range { position = range; velocity = min(0, velocity) }
        }
    }
}
struct MotionPose {
    var pan: MotionAxis
    var tilt: MotionAxis
    var panRange: Double
    var tiltRange: Double
    init(state: FixtureState, profile: FixtureProfile) {
        panRange = profile.panDegrees; tiltRange = profile.tiltDegrees
        pan = MotionAxis(position: min(1, max(0, state.pan)) * panRange)
        tilt = MotionAxis(position: min(1, max(0, state.tilt)) * tiltRange)
    }
    mutating func advance(target: FixtureState, seconds: Double, settings: MotionSettings) {
        pan.advance(target: target.pan * panRange, seconds: seconds, range: panRange, settings: settings)
        tilt.advance(target: target.tilt * tiltRange, seconds: seconds, range: tiltRange, settings: settings)
    }
    func applying(to state: FixtureState) -> FixtureState {
        var value = state; value.pan = pan.position / panRange; value.tilt = tilt.position / tiltRange; return value
    }
    mutating func park() { pan.velocity = 0; tilt.velocity = 0 }
}
