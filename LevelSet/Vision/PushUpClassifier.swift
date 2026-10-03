import CoreGraphics
import Foundation
import Vision

enum PushUpState: String {
    case up
    case down
    case transition
}

enum PushUpFeedback: String {
    case good = "form: good"
    case tooShallow = "go lower"
    case backNotStraight = "keep your back straight"
    case outOfPosition = "get in plank position"
    case tooFast = "slow down"
    case notVisible = "get your full body in frame"
}

struct PushUpReading: Sendable {
    let state: PushUpState?
    let repCount: Int
    let feedback: PushUpFeedback
}

final class PushUpClassifier: @unchecked Sendable {
    private typealias Joint = VNHumanBodyPoseObservation.JointName

    private struct Side {
        let shoulder: Joint
        let elbow: Joint
        let wrist: Joint
        let hip: Joint
        let knee: Joint
        let ankle: Joint
    }

    private enum CyclePhase {
        case awaitingTop
        case top
        case descending
        case bottom
        case ascending
    }

    private let upThreshold: CGFloat = 160
    private let downThreshold: CGFloat = 90
    private let backTolerance: CGFloat = 15
    private let smoothingFactor: CGFloat = 0.3
    private let armDisagreementLimit: CGFloat = 25
    private let minimumRepInterval: TimeInterval = 0.5
    private let maximumMissedFrames = 10

    private let sides = [
        Side(shoulder: .leftShoulder, elbow: .leftElbow, wrist: .leftWrist,
             hip: .leftHip, knee: .leftKnee, ankle: .leftAnkle),
        Side(shoulder: .rightShoulder, elbow: .rightElbow, wrist: .rightWrist,
             hip: .rightHip, knee: .rightKnee, ankle: .rightAnkle),
    ]

    private var smoothedElbowAngle: CGFloat?
    private var smoothedBackDeviation: CGFloat?
    private var phase: CyclePhase = .awaitingTop
    private var reachedDepthWithBentBack = false
    private var lastState: PushUpState?
    private var missedFrames = 0
    private var lastRepAt: Date?
    private var repCount = 0
    private var feedback: PushUpFeedback = .notVisible

    func process(_ frame: PoseFrame?, at time: Date = .now) -> PushUpReading {
        guard
            let frame,
            let rawElbow = elbowAngle(in: frame),
            let rawBack = backDeviation(in: frame)
        else {
            return handleMissingFrame()
        }
        missedFrames = 0

        let elbow = smooth(rawElbow, into: &smoothedElbowAngle)
        let back = smooth(rawBack, into: &smoothedBackDeviation)
        let backIsStraight = back <= backTolerance

        let state: PushUpState
        if elbow > upThreshold {
            state = .up
        } else if elbow < downThreshold && backIsStraight {
            state = .down
        } else {
            state = .transition
        }

        if elbow < downThreshold && !backIsStraight {
            reachedDepthWithBentBack = true
            feedback = .backNotStraight
        }

        advanceCycle(to: state, at: time)
        lastState = state
        return PushUpReading(state: state, repCount: repCount, feedback: feedback)
    }

    private func advanceCycle(to state: PushUpState, at time: Date) {
        switch (phase, state) {
        case (.awaitingTop, .up):
            phase = .top
            feedback = .good
        case (.awaitingTop, _):
            feedback = .outOfPosition
        case (.top, .transition):
            phase = .descending
        case (.top, .down), (.descending, .down):
            phase = .bottom
            feedback = .good
        case (.descending, .up):
            phase = .top
            feedback = reachedDepthWithBentBack ? .backNotStraight : .tooShallow
            reachedDepthWithBentBack = false
        case (.bottom, .transition):
            phase = .ascending
        case (.bottom, .up), (.ascending, .up):
            completeRep(at: time)
        case (.ascending, .down):
            phase = .bottom
        default:
            break
        }
    }

    private func completeRep(at time: Date) {
        phase = .top
        reachedDepthWithBentBack = false
        if let lastRepAt, time.timeIntervalSince(lastRepAt) < minimumRepInterval {
            feedback = .tooFast
            return
        }
        lastRepAt = time
        repCount += 1
        feedback = .good
    }

    private func handleMissingFrame() -> PushUpReading {
        missedFrames += 1
        if missedFrames > maximumMissedFrames {
            smoothedElbowAngle = nil
            smoothedBackDeviation = nil
            phase = .awaitingTop
            reachedDepthWithBentBack = false
            lastState = nil
            feedback = .notVisible
        }
        return PushUpReading(state: lastState, repCount: repCount, feedback: feedback)
    }

    private func smooth(_ value: CGFloat, into average: inout CGFloat?) -> CGFloat {
        let next = average.map { smoothingFactor * value + (1 - smoothingFactor) * $0 } ?? value
        average = next
        return next
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

    private func backDeviation(in frame: PoseFrame) -> CGFloat? {
        let readings: [(deviation: CGFloat, confidence: Float)] = sides.compactMap { side in
            let lowerJoint = frame.pixelPoint(side.ankle) != nil ? side.ankle : side.knee
            guard
                let shoulder = frame.pixelPoint(side.shoulder),
                let hip = frame.pixelPoint(side.hip),
                let lower = frame.pixelPoint(lowerJoint),
                let confidence = frame.minimumConfidence(of: [side.shoulder, side.hip, lowerJoint])
            else { return nil }
            return (180 - PoseGeometry.angleBetween(shoulder, hip, lower), confidence)
        }
        return readings.max(by: { $0.confidence < $1.confidence })?.deviation
    }
}
