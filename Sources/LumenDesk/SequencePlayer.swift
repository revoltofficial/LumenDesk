import Foundation

/// A run snapshots timing and order so edits affect the next run, not this one.
struct SequencePlayer {
    struct Step {
        let cueID: UUID
        let duration: Double
    }
    let steps: [Step]
    let repeats: Bool
    private(set) var index = 0
    private(set) var deadline: TimeInterval
    private(set) var pausedRemaining: TimeInterval?
    private(set) var finished = false
    var currentCueID: UUID { steps[index].cueID }
    var isPaused: Bool { pausedRemaining != nil }

    init?(cues: [Cue], settings: SequenceSettings, now: TimeInterval) {
        guard !cues.isEmpty, cues.allSatisfy({ $0.fadeSeconds.isFinite && (0...3600).contains($0.fadeSeconds) && $0.sequenceHold.isFinite && (0.05...3600).contains($0.sequenceHold) }) else { return nil }
        var ordered = cues
        switch settings.direction {
        case .forward: break
        case .reverse: ordered.reverse()
        case .pingPong:
            // Include the starting endpoint on return, once. Repeated cycles omit
            // it at the end to avoid holding the same endpoint twice.
            if cues.count > 1 {
                ordered += Array(cues.dropLast().reversed())
                if settings.repeats { ordered.removeLast() }
            }
        }
        steps = ordered.map { Step(cueID: $0.id, duration: $0.fadeSeconds + $0.sequenceHold) }
        repeats = settings.repeats
        deadline = now + steps[0].duration
    }
    mutating func pause(now: TimeInterval) {
        guard !finished, !isPaused else { return }
        pausedRemaining = max(0, deadline - now)
    }
    mutating func resume(now: TimeInterval) {
        guard let remaining = pausedRemaining, !finished else { return }
        deadline = now + remaining
        pausedRemaining = nil
    }
    mutating func advance(now: TimeInterval) -> UUID? {
        guard !finished, !isPaused, now >= deadline else { return nil }
        if index + 1 < steps.count { index += 1 }
        else if repeats { index = 0 }
        else { finished = true; return nil }
        // On a delayed UI tick, play the next cue fully instead of firing a burst
        // of skipped cues or shortening their fades.
        deadline = now + steps[index].duration
        return currentCueID
    }
}
