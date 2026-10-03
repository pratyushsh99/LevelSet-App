import SwiftUI
import Vision

@MainActor
final class SkeletonModel: ObservableObject {
    @Published var frame: PoseFrame?
}

struct SkeletonOverlayView: View {
    @ObservedObject var model: SkeletonModel
    var isMirrored = true

    private static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        let frame = model.frame
        let mirrored = isMirrored
        return Canvas { context, size in
            guard let frame, frame.imageSize.width > 0, frame.imageSize.height > 0 else { return }

            func place(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                frame.normalizedPoints[joint].map {
                    Self.viewPoint(for: $0, imageSize: frame.imageSize, in: size, mirrored: mirrored)
                }
            }

            var bonesPath = Path()
            for (start, end) in Self.bones {
                guard let a = place(start), let b = place(end) else { continue }
                bonesPath.move(to: a)
                bonesPath.addLine(to: b)
            }
            context.stroke(
                bonesPath,
                with: .color(Theme.accent400.opacity(0.9)),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )

            for joint in frame.normalizedPoints.keys {
                guard let point = place(joint) else { continue }
                let dot = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: dot), with: .color(Theme.accent200))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func viewPoint(for normalized: CGPoint, imageSize: CGSize, in viewSize: CGSize, mirrored: Bool) -> CGPoint {
        let x = mirrored ? 1 - normalized.x : normalized.x
        let y = 1 - normalized.y
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let drawnWidth = imageSize.width * scale
        let drawnHeight = imageSize.height * scale
        let originX = (viewSize.width - drawnWidth) / 2
        let originY = (viewSize.height - drawnHeight) / 2
        return CGPoint(x: originX + x * drawnWidth, y: originY + y * drawnHeight)
    }
}
