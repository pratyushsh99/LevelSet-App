import CoreGraphics
import Foundation
import Vision

/// What the person was doing for the whole recording. One label per session keeps
/// labelling hands-free: the trainer derives per-frame phases from the motion itself.
enum PushUpRecordingLabel: String, Codable, CaseIterable, Sendable {
    case good
    case shallow
    case hipsSagging
    case hipsPiked
    case kneeling
    case notPushup

    var title: String {
        switch self {
        case .good: return "Good push-ups"
        case .shallow: return "Too shallow"
        case .hipsSagging: return "Hips sagging"
        case .hipsPiked: return "Hips piked up"
        case .kneeling: return "Knee push-ups"
        case .notPushup: return "Not a push-up"
        }
    }

    var instructions: String {
        switch self {
        case .good: return "Full range: chest near the floor, arms locked out at the top, body in a straight line."
        case .shallow: return "Plank is fine, but only bend the elbows partway. Keep the depth about the same every rep."
        case .hipsSagging: return "Full range, but let your hips drop toward the floor."
        case .hipsPiked: return "Full range, but keep your hips raised high."
        case .kneeling: return "Push-ups from your knees instead of your toes."
        case .notPushup: return "Anything else in frame: stand, walk, sit, kneel, wave your arms, hold a plank without moving, squat."
        }
    }

    var countsReps: Bool { self != .notPushup }
}

struct PushUpRecording: Codable, Sendable {
    static let currentVersion = 1

    struct Frame: Codable, Sendable {
        /// Seconds since the recording started.
        let t: Double
        let width: Double
        let height: Double
        /// Vision joint key -> [x, y, confidence], in Vision's normalized coordinates.
        let joints: [String: [Double]]
    }

    var version = PushUpRecording.currentVersion
    let id: UUID
    let label: PushUpRecordingLabel
    let participant: String
    let reportedReps: Int
    let recordedAt: Date
    let frames: [Frame]
}

extension PushUpRecording.Frame {
    init(t: Double, poseFrame: PoseFrame?) {
        self.t = t
        width = Double(poseFrame?.imageSize.width ?? 0)
        height = Double(poseFrame?.imageSize.height ?? 0)
        var joints: [String: [Double]] = [:]
        for (joint, point) in poseFrame?.normalizedPoints ?? [:] {
            let confidence = Double(poseFrame?.confidences[joint] ?? 0)
            joints[joint.rawValue.rawValue] = [Double(point.x), Double(point.y), confidence]
        }
        self.joints = joints
    }

    /// The frame as the live pipeline would have seen it, or nil when no person was detected.
    var poseFrame: PoseFrame? {
        guard !joints.isEmpty else { return nil }
        var points: [PoseFrame.Joint: CGPoint] = [:]
        var confidences: [PoseFrame.Joint: Float] = [:]
        for (key, values) in joints where values.count == 3 {
            let joint = PoseFrame.Joint(rawValue: VNRecognizedPointKey(rawValue: key))
            points[joint] = CGPoint(x: values[0], y: values[1])
            confidences[joint] = Float(values[2])
        }
        return PoseFrame(normalizedPoints: points, confidences: confidences, imageSize: CGSize(width: width, height: height))
    }
}
