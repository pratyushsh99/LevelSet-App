import CoreGraphics
import Vision

enum CameraTrackingStatus: Equatable {
    case requestingPermission
    case starting
    case lookingForPerson
    case tracking
    case permissionDenied
    case unavailable
    case failed(String)

    var label: String {
        switch self {
        case .requestingPermission: return "Allow camera access to begin"
        case .starting: return "Starting camera…"
        case .lookingForPerson: return "Step back until your full body is visible"
        case .tracking: return "Tracking on device"
        case .permissionDenied: return "Camera access is off in Settings"
        case .unavailable: return "Front camera unavailable"
        case .failed: return "Camera could not start"
        }
    }

    var isReady: Bool { self == .tracking }
}

enum PoseGeometry {
    struct BodySide {
        let shoulder: VNHumanBodyPoseObservation.JointName
        let elbow: VNHumanBodyPoseObservation.JointName
        let wrist: VNHumanBodyPoseObservation.JointName
        let hip: VNHumanBodyPoseObservation.JointName
        let knee: VNHumanBodyPoseObservation.JointName
        let ankle: VNHumanBodyPoseObservation.JointName
    }

    static func bestVisibleSide(
        in points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> BodySide {
        let left = BodySide(shoulder: .leftShoulder, elbow: .leftElbow, wrist: .leftWrist,
                            hip: .leftHip, knee: .leftKnee, ankle: .leftAnkle)
        let right = BodySide(shoulder: .rightShoulder, elbow: .rightElbow, wrist: .rightWrist,
                             hip: .rightHip, knee: .rightKnee, ankle: .rightAnkle)
        func score(_ side: BodySide) -> Float {
            [side.shoulder, side.elbow, side.wrist, side.hip, side.knee, side.ankle]
                .compactMap { points[$0]?.confidence }
                .reduce(0, +)
        }
        return score(left) >= score(right) ? left : right
    }

    static func angleBetween(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        guard a != b, c != b else { return 180 }
        let first = atan2(a.y - b.y, a.x - b.x)
        let second = atan2(c.y - b.y, c.x - b.x)
        let degrees = abs(first - second) * 180 / .pi
        return degrees > 180 ? 360 - degrees : degrees
    }

    static func isPlankAligned(shoulder: CGPoint, hip: CGPoint, ankle: CGPoint) -> Bool {
        let ys = [shoulder.y, hip.y, ankle.y]
        let verticalSpread = (ys.max() ?? 0) - (ys.min() ?? 0)
        let horizontalSpread = abs(shoulder.x - ankle.x)
        return horizontalSpread > 0.25 && verticalSpread < 0.16
    }
}
