import Foundation

/// A recording replayed through the app's feature extractor, with per-frame phase labels
/// and rep boundaries derived from the motion.
struct LabeledSession {
    struct Rep {
        let start: Int
        let end: Int
    }

    let name: String
    let recording: PushUpRecording
    let times: [Double]
    let features: [PushUpFeatures?]
    /// nil where the frame is too ambiguous to train on.
    let phaseLabels: [PushUpPhaseLabel?]
    let reps: [Rep]

    /// Push-up sessions are only trusted when the detected reps match what the person reported.
    var isConsistent: Bool {
        !recording.label.countsReps || reps.count == recording.reportedReps
    }

    /// What a perfect counter would report for this session.
    var expectedCount: Int {
        recording.label == .good ? recording.reportedReps : 0
    }

    func repSummaries() -> [PushUpRepSummary] {
        reps.map { rep in
            PushUpRepSummary(frames: features[rep.start...rep.end].compactMap { $0 },
                             duration: times[rep.end] - times[rep.start])
        }
    }
}

enum SessionLabeler {
    /// Normalised depth above this is the top of a push-up, below `downThreshold` the bottom.
    static let upThreshold = 0.7
    static let downThreshold = 0.3
    /// Frames where the body is more upright than this are not in push-up position.
    static let uprightIncline = 0.6
    static let smoothingRadius = 0.15
    static let contextAroundReps = 0.5

    static func label(_ recording: PushUpRecording, name: String) -> LabeledSession {
        let extractor = PushUpFeatureExtractor()
        let times = recording.frames.map(\.t)
        let features = recording.frames.map { extractor.features(for: $0.poseFrame, at: $0.t) }
        let upright = features.map { ($0?.backVisible ?? 0) > 0 && ($0?.bodyIncline ?? 0) > uprightIncline }

        let depth = smoothed(normalizedDepth(features, excluding: upright), times: times)
        let reps = detectReps(depth)

        var labels = [PushUpPhaseLabel?](repeating: nil, count: features.count)
        for index in features.indices where features[index] != nil {
            if recording.label == .notPushup || upright[index] {
                labels[index] = PushUpPhaseLabel.none
            }
        }
        if recording.label.countsReps, let first = reps.first, let last = reps.last {
            let from = times[first.start] - contextAroundReps
            let to = times[last.end] + contextAroundReps
            for index in features.indices where labels[index] == nil && (from...to).contains(times[index]) {
                guard let value = depth[index] else { continue }
                labels[index] = value >= upThreshold ? .up : value <= downThreshold ? .down : .moving
            }
        }

        return LabeledSession(name: name, recording: recording, times: times, features: features,
                              phaseLabels: labels, reps: reps)
    }

    /// 1 at the top of the movement, 0 at the bottom, scaled to this session's own range so
    /// camera distance and angle don't matter. Averages shoulder height and elbow angle.
    private static func normalizedDepth(_ features: [PushUpFeatures?], excluding upright: [Bool]) -> [Double?] {
        let signals: [[Double?]] = [
            features.indices.map { upright[$0] || (features[$0]?.wristsSeen ?? 0) == 0 ? nil : features[$0]?.shoulderAboveWrist },
            features.indices.map { upright[$0] || (features[$0]?.elbowVisible ?? 0) == 0 ? nil : features[$0]?.elbowAngle },
        ]
        let minimumRanges = [0.1, 0.05]

        let normalized: [[Double?]] = zip(signals, minimumRanges).map { signal, minimumRange in
            let values = signal.compactMap { $0 }.sorted()
            guard values.count >= 10 else { return signal.map { _ in nil } }
            let low = values[values.count * 5 / 100]
            let high = values[values.count * 95 / 100]
            guard high - low >= minimumRange else { return signal.map { _ in nil } }
            return signal.map { $0.map { min(1, max(0, ($0 - low) / (high - low))) } }
        }

        return features.indices.map { index in
            let available = normalized.compactMap { $0[index] }
            return available.isEmpty ? nil : available.reduce(0, +) / Double(available.count)
        }
    }

    private static func smoothed(_ values: [Double?], times: [Double]) -> [Double?] {
        values.indices.map { index in
            guard values[index] != nil else { return nil }
            var sum = 0.0
            var count = 0.0
            var other = index
            while other >= 0, times[index] - times[other] <= smoothingRadius {
                if let value = values[other] { sum += value; count += 1 }
                other -= 1
            }
            other = index + 1
            while other < values.count, times[other] - times[index] <= smoothingRadius {
                if let value = values[other] { sum += value; count += 1 }
                other += 1
            }
            return sum / count
        }
    }

    /// A rep runs from the last frame at the top, down past the bottom threshold, to the
    /// first frame back at the top.
    private static func detectReps(_ depth: [Double?]) -> [LabeledSession.Rep] {
        var reps: [LabeledSession.Rep] = []
        var lastTop: Int?
        var reachedBottom = false
        for (index, value) in depth.enumerated() {
            guard let value else { continue }
            if value >= upThreshold {
                if reachedBottom, let start = lastTop {
                    reps.append(.init(start: start, end: index))
                }
                lastTop = index
                reachedBottom = false
            } else if value <= downThreshold, lastTop != nil {
                reachedBottom = true
            }
        }
        return reps
    }
}
