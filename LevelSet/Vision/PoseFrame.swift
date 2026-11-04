import CoreGraphics
import Vision

struct PoseFrame: @unchecked Sendable {
    typealias Joint = VNHumanBodyPoseObservation.JointName

    let normalizedPoints: [Joint: CGPoint]
    let confidences: [Joint: Float]
    let imageSize: CGSize

    func pixelPoint(_ joint: Joint) -> CGPoint? {
        normalizedPoints[joint].map { CGPoint(x: $0.x * imageSize.width, y: $0.y * imageSize.height) }
    }

    func minimumConfidence(of joints: [Joint]) -> Float? {
        var lowest: Float = 1
        for joint in joints {
            guard let confidence = confidences[joint] else { return nil }
            lowest = min(lowest, confidence)
        }
        return lowest
    }
}
