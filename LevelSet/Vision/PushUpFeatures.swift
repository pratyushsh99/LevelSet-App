import CoreGraphics
import Foundation
import Vision

/// Per-frame inputs to the push-up phase model.
///
/// The app and the trainer in `Training/` compile this same file, so the features a
/// model sees on device are exactly the ones it was trained on. Bump `version` whenever
/// a feature changes: bundled models trained on another version are ignored.
struct PushUpFeatures {
    static let version = 1

    // Joint geometry. Lengths are in torso lengths, angles are fractions of 180°.
    var elbowAngle = 0.0
    var elbowVisible = 0.0
    var backDeviation = 0.0
    var backVisible = 0.0
    /// Hip distance from the shoulder–ankle line: positive when piked, negative when sagging.
    var hipOffset = 0.0
    /// 0 when the body is horizontal, 1 when upright.
    var bodyIncline = 0.0
    var lowerJointIsAnkle = 0.0
    var shoulderAboveWrist = 0.0
    var hipAboveWrist = 0.0
    var bodySize = 0.0

    // Joint positions relative to the shoulder midpoint, mirrored so the feet are always on +x.
    var elbowX = 0.0, elbowY = 0.0
    var wristX = 0.0, wristY = 0.0
    var hipX = 0.0, hipY = 0.0
    var kneeX = 0.0, kneeY = 0.0
    var ankleX = 0.0, ankleY = 0.0

    // Share of each joint pair that Vision found, 0, 0.5 or 1.
    var shouldersSeen = 0.0
    var elbowsSeen = 0.0
    var wristsSeen = 0.0
    var hipsSeen = 0.0
    var kneesSeen = 0.0
    var anklesSeen = 0.0
    var meanConfidence = 0.0

    // Motion over the last few seconds, which adapts to each person and camera placement.
    var elbowVelocity = 0.0
    var elbowRangePosition = 0.5
    var elbowRange = 0.0
    var shoulderVelocity = 0.0
    var shoulderRangePosition = 0.5
    var shoulderRange = 0.0

    static let columns: [(name: String, value: KeyPath<PushUpFeatures, Double>)] = [
        ("elbowAngle", \.elbowAngle), ("elbowVisible", \.elbowVisible),
        ("backDeviation", \.backDeviation), ("backVisible", \.backVisible),
        ("hipOffset", \.hipOffset), ("bodyIncline", \.bodyIncline),
        ("lowerJointIsAnkle", \.lowerJointIsAnkle),
        ("shoulderAboveWrist", \.shoulderAboveWrist), ("hipAboveWrist", \.hipAboveWrist),
        ("bodySize", \.bodySize),
        ("elbowX", \.elbowX), ("elbowY", \.elbowY), ("wristX", \.wristX), ("wristY", \.wristY),
        ("hipX", \.hipX), ("hipY", \.hipY), ("kneeX", \.kneeX), ("kneeY", \.kneeY),
        ("ankleX", \.ankleX), ("ankleY", \.ankleY),
        ("shouldersSeen", \.shouldersSeen), ("elbowsSeen", \.elbowsSeen), ("wristsSeen", \.wristsSeen),
        ("hipsSeen", \.hipsSeen), ("kneesSeen", \.kneesSeen), ("anklesSeen", \.anklesSeen),
        ("meanConfidence", \.meanConfidence),
        ("elbowVelocity", \.elbowVelocity), ("elbowRangePosition", \.elbowRangePosition),
        ("elbowRange", \.elbowRange),
        ("shoulderVelocity", \.shoulderVelocity), ("shoulderRangePosition", \.shoulderRangePosition),
        ("shoulderRange", \.shoulderRange),
    ]

    static var names: [String] { columns.map(\.name) }

    var values: [Double] { Self.columns.map { self[keyPath: $0.value] } }
}

/// Turns a stream of pose frames into `PushUpFeatures`. Keeps a few seconds of history
/// for the motion features, so use one extractor per session and feed it every frame.
final class PushUpFeatureExtractor {
    private typealias Joint = VNHumanBodyPoseObservation.JointName

    private struct Sample {
        let time: TimeInterval
        let elbow: Double?
        let shoulderHeight: Double?
        let torso: CGFloat?
    }

    private struct Side {
        let shoulder: Joint
        let elbow: Joint
        let wrist: Joint
        let hip: Joint
        let knee: Joint
        let ankle: Joint
    }

    private let sides = [
        Side(shoulder: .leftShoulder, elbow: .leftElbow, wrist: .leftWrist,
             hip: .leftHip, knee: .leftKnee, ankle: .leftAnkle),
        Side(shoulder: .rightShoulder, elbow: .rightElbow, wrist: .rightWrist,
             hip: .rightHip, knee: .rightKnee, ankle: .rightAnkle),
    ]

    private let historyWindow: TimeInterval = 3
    private let velocityLag: TimeInterval = 0.2
    private let armDisagreementLimit: CGFloat = 25

    private var history: [Sample] = []
    private var facing: CGFloat = 1

    func reset() {
        history.removeAll()
        facing = 1
    }

    /// Returns nil when too little of the body is visible to describe the pose.
    func features(for frame: PoseFrame?, at time: TimeInterval) -> PushUpFeatures? {
        history.removeAll { time - $0.time > historyWindow }
        guard let frame, let shoulder = midpoint(frame, sides.map(\.shoulder)) else { return nil }

        let hip = midpoint(frame, sides.map(\.hip))
        let wrist = midpoint(frame, sides.map(\.wrist))
        let currentTorso = hip.map { distance(shoulder, $0) }
        let recentTorso = (history.compactMap(\.torso) + [currentTorso].compactMap { $0 }).max()
        let torso: CGFloat? = recentTorso ?? wrist.map { distance(shoulder, $0) }
        guard let torso, torso > 1 else { return nil }

        var features = PushUpFeatures()
        features.bodySize = Double(torso / max(frame.imageSize.height, 1))

        let elbow = elbowAngle(in: frame)
        if let elbow {
            features.elbowAngle = Double(elbow / 180)
            features.elbowVisible = 1
        }

        if let line = bodyLine(in: frame) {
            features.backVisible = 1
            features.backDeviation = Double((180 - PoseGeometry.angleBetween(line.shoulder, line.hip, line.lower)) / 180)
            features.lowerJointIsAnkle = line.lowerIsAnkle ? 1 : 0
            let dx = line.lower.x - line.shoulder.x
            let dy = line.lower.y - line.shoulder.y
            let length = max(hypot(dx, dy), 1)
            var normal = CGPoint(x: -dy / length, y: dx / length)
            if normal.y < 0 { normal = CGPoint(x: -normal.x, y: -normal.y) }
            let offset = (line.hip.x - line.shoulder.x) * normal.x + (line.hip.y - line.shoulder.y) * normal.y
            features.hipOffset = Double(offset / length)
            features.bodyIncline = Double(atan2(abs(dy), abs(dx)) / (.pi / 2))
        }

        let feet = midpoint(frame, sides.map(\.ankle)) ?? midpoint(frame, sides.map(\.knee)) ?? hip
        if let feet, abs(feet.x - shoulder.x) > torso * 0.3 {
            facing = feet.x >= shoulder.x ? 1 : -1
        }

        func place(_ point: CGPoint?, _ x: WritableKeyPath<PushUpFeatures, Double>, _ y: WritableKeyPath<PushUpFeatures, Double>) {
            guard let point else { return }
            features[keyPath: x] = Double((point.x - shoulder.x) * facing / torso)
            features[keyPath: y] = Double((point.y - shoulder.y) / torso)
        }
        place(midpoint(frame, sides.map(\.elbow)), \.elbowX, \.elbowY)
        place(wrist, \.wristX, \.wristY)
        place(hip, \.hipX, \.hipY)
        place(midpoint(frame, sides.map(\.knee)), \.kneeX, \.kneeY)
        place(midpoint(frame, sides.map(\.ankle)), \.ankleX, \.ankleY)

        let shoulderHeight = wrist.map { Double((shoulder.y - $0.y) / torso) }
        if let wrist {
            features.shoulderAboveWrist = shoulderHeight ?? 0
            if let hip { features.hipAboveWrist = Double((hip.y - wrist.y) / torso) }
        }

        func seen(_ joints: [Joint]) -> Double {
            Double(joints.filter { frame.normalizedPoints[$0] != nil }.count) / Double(joints.count)
        }
        features.shouldersSeen = seen(sides.map(\.shoulder))
        features.elbowsSeen = seen(sides.map(\.elbow))
        features.wristsSeen = seen(sides.map(\.wrist))
        features.hipsSeen = seen(sides.map(\.hip))
        features.kneesSeen = seen(sides.map(\.knee))
        features.anklesSeen = seen(sides.map(\.ankle))
        let confidences = frame.confidences.values
        features.meanConfidence = confidences.isEmpty ? 0 : Double(confidences.reduce(0, +)) / Double(confidences.count)

        let elbowValue = elbow.map { Double($0 / 180) }
        let sample = Sample(time: time, elbow: elbowValue, shoulderHeight: shoulderHeight, torso: currentTorso)
        history.append(sample)

        (features.elbowVelocity, features.elbowRangePosition, features.elbowRange) = motion(of: \.elbow, now: sample)
        (features.shoulderVelocity, features.shoulderRangePosition, features.shoulderRange) = motion(of: \.shoulderHeight, now: sample)
        return features
    }

    private func motion(of signal: KeyPath<Sample, Double?>, now: Sample) -> (velocity: Double, position: Double, range: Double) {
        guard let current = now[keyPath: signal] else { return (0, 0.5, 0) }
        let values = history.compactMap { $0[keyPath: signal] }
        let low = values.min() ?? current
        let high = values.max() ?? current
        let range = high - low
        let position = range > 0.02 ? (current - low) / range : 0.5

        var velocity = 0.0
        if let past = history.last(where: { now.time - $0.time >= velocityLag && $0[keyPath: signal] != nil }),
           let pastValue = past[keyPath: signal] {
            velocity = (current - pastValue) / (now.time - past.time)
        }
        return (velocity, position, range)
    }

    private func midpoint(_ frame: PoseFrame, _ joints: [Joint]) -> CGPoint? {
        let points = joints.compactMap { frame.pixelPoint($0) }
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func elbowAngle(in frame: PoseFrame) -> CGFloat? {
        let readings: [(angle: CGFloat, confidence: Float)] = sides.compactMap { side in
            guard
                let shoulder = frame.pixelPoint(side.shoulder),
                let elbow = frame.pixelPoint(side.elbow),
                let wrist = frame.pixelPoint(side.wrist),
                let confidence = frame.minimumConfidence(of: [side.shoulder, side.elbow, side.wrist])
            else { return nil }
            return (PoseGeometry.angleBetween(shoulder, elbow, wrist), confidence)
        }

        guard let best = readings.max(by: { $0.confidence < $1.confidence }) else { return nil }
        guard readings.count == 2 else { return best.angle }
        if abs(readings[0].angle - readings[1].angle) <= armDisagreementLimit {
            return (readings[0].angle + readings[1].angle) / 2
        }
        return best.angle
    }

    private func bodyLine(in frame: PoseFrame) -> (shoulder: CGPoint, hip: CGPoint, lower: CGPoint, lowerIsAnkle: Bool)? {
        let readings: [(line: (CGPoint, CGPoint, CGPoint, Bool), confidence: Float)] = sides.compactMap { side in
            let lowerIsAnkle = frame.pixelPoint(side.ankle) != nil
            let lowerJoint = lowerIsAnkle ? side.ankle : side.knee
            guard
                let shoulder = frame.pixelPoint(side.shoulder),
                let hip = frame.pixelPoint(side.hip),
                let lower = frame.pixelPoint(lowerJoint),
                let confidence = frame.minimumConfidence(of: [side.shoulder, side.hip, lowerJoint])
            else { return nil }
            return ((shoulder, hip, lower, lowerIsAnkle), confidence)
        }
        guard let best = readings.max(by: { $0.confidence < $1.confidence })?.line else { return nil }
        return (best.0, best.1, best.2, best.3)
    }
}

/// Inputs to the rep model: a summary of every frame between leaving the top of a
/// push-up and returning to it.
struct PushUpRepSummary {
    static let names = [
        "duration",
        "elbowMin", "elbowMax", "elbowRange", "elbowVisibleShare",
        "shoulderHeightMin", "shoulderHeightMax", "shoulderHeightRange",
        "backDeviationMax", "backDeviationMean",
        "hipOffsetMin", "hipOffsetMax", "hipOffsetMean",
        "bodyInclineMean", "lowerJointIsAnkleShare", "kneeAboveWristMean",
    ]

    let values: [Double]

    init(frames: [PushUpFeatures], duration: TimeInterval) {
        func stats(_ value: (PushUpFeatures) -> Double?) -> (min: Double, max: Double, mean: Double) {
            let samples = frames.compactMap(value)
            guard let low = samples.min(), let high = samples.max() else { return (0, 0, 0) }
            return (low, high, samples.reduce(0, +) / Double(samples.count))
        }
        let elbow = stats { $0.elbowVisible > 0 ? $0.elbowAngle : nil }
        let shoulder = stats { $0.wristsSeen > 0 ? $0.shoulderAboveWrist : nil }
        let back = stats { $0.backVisible > 0 ? $0.backDeviation : nil }
        let hip = stats { $0.backVisible > 0 ? $0.hipOffset : nil }
        let incline = stats { $0.backVisible > 0 ? $0.bodyIncline : nil }
        let knee = stats { $0.kneesSeen > 0 && $0.wristsSeen > 0 ? $0.kneeY - $0.wristY : nil }
        let count = Double(max(frames.count, 1))

        values = [
            duration,
            elbow.min, elbow.max, elbow.max - elbow.min,
            Double(frames.filter { $0.elbowVisible > 0 }.count) / count,
            shoulder.min, shoulder.max, shoulder.max - shoulder.min,
            back.max, back.mean,
            hip.min, hip.max, hip.mean,
            incline.mean,
            frames.reduce(0) { $0 + $1.lowerJointIsAnkle } / count,
            knee.mean,
        ]
    }
}
