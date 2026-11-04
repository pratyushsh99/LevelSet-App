import CoreGraphics
import CoreVideo
import ImageIO
import Vision

final class PoseDetector: @unchecked Sendable {
    static let trackedJoints: [VNHumanBodyPoseObservation.JointName] = [
        .leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle,
        .rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle,
    ]

    private let minimumConfidence: Float = 0.6

    private let request: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        request.revision = VNDetectHumanBodyPoseRequestRevision1
        return request
    }()

    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> PoseFrame? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard
            let observation = request.results?.max(by: { $0.confidence < $1.confidence }),
            let recognized = try? observation.recognizedPoints(.all)
        else {
            return nil
        }

        var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var confidences: [VNHumanBodyPoseObservation.JointName: Float] = [:]
        for joint in Self.trackedJoints {
            guard let point = recognized[joint], point.confidence > minimumConfidence else { continue }
            points[joint] = point.location
            confidences[joint] = point.confidence
        }

        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let isQuarterTurned: Bool
        switch orientation {
        case .left, .right, .leftMirrored, .rightMirrored:
            isQuarterTurned = true
        default:
            isQuarterTurned = false
        }

        return PoseFrame(
            normalizedPoints: points,
            confidences: confidences,
            imageSize: isQuarterTurned ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        )
    }
}
