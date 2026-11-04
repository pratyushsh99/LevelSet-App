import CoreML
import Foundation

protocol PushUpRepTracking: AnyObject, Sendable {
    func process(_ frame: PoseFrame?, at time: Date) -> PushUpReading
}

extension PushUpClassifier: PushUpRepTracking {}

/// Labels the phase model predicts for each frame.
enum PushUpPhaseLabel: String, CaseIterable, Sendable {
    case up
    case down
    case moving
    case none
}

/// Counts push-ups with the models trained by `Training/train.sh`: a phase model says
/// where each frame sits in the movement, and a rep model judges every completed
/// up → down → up cycle. Rep verdicts use `PushUpRecordingLabel` raw values.
final class PushUpModelClassifier: PushUpRepTracking, @unchecked Sendable {
    static let phaseModelName = "PushUpPhaseModel"
    static let repModelName = "PushUpRepModel"
    static let featureVersionKey = "featureVersion"

    private enum CyclePhase {
        case awaitingTop
        case top
        case descending
        case bottom
        case ascending
    }

    private static let bundledModels: (phase: MLModel, rep: MLModel?)? = {
        guard let phase = loadBundledModel(named: phaseModelName) else { return nil }
        return (phase, loadBundledModel(named: repModelName))
    }()

    /// A classifier backed by the models in the app bundle, or nil if none were trained yet.
    static func bundled() -> PushUpModelClassifier? {
        bundledModels.map { PushUpModelClassifier(phaseModel: $0.phase, repModel: $0.rep) }
    }

    private static func loadBundledModel(named name: String) -> MLModel? {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
            let model = try? MLModel(contentsOf: url)
        else { return nil }
        let metadata = model.modelDescription.metadata[.creatorDefinedKey] as? [String: String]
        guard metadata?[featureVersionKey] == String(PushUpFeatures.version) else { return nil }
        return model
    }

    private let confidentProbability = 0.6
    private let smoothingFactor = 0.5
    private let minimumRepInterval: TimeInterval = 0.5
    private let maximumMissedFrames = 10

    private let phaseModel: MLModel
    private let repModel: MLModel?
    private let extractor = PushUpFeatureExtractor()

    private var smoothedProbabilities: [String: Double] = [:]
    private var phase: CyclePhase = .awaitingTop
    private var repFrames: [PushUpFeatures] = []
    private var repStartedAt: TimeInterval = 0
    private var lastState: PushUpState?
    private var missedFrames = 0
    private var lastRepAt: TimeInterval?
    private var repCount = 0
    private var feedback: PushUpFeedback = .notVisible

    init(phaseModel: MLModel, repModel: MLModel?) {
        self.phaseModel = phaseModel
        self.repModel = repModel
    }

    func process(_ frame: PoseFrame?, at time: Date = .now) -> PushUpReading {
        let now = time.timeIntervalSinceReferenceDate
        guard
            let features = extractor.features(for: frame, at: now),
            let probabilities = Self.probabilities(from: phaseModel, names: PushUpFeatures.names, values: features.values)
        else {
            return handleMissingFrame()
        }
        missedFrames = 0

        for (label, probability) in probabilities {
            smoothedProbabilities[label] = smoothedProbabilities[label].map {
                smoothingFactor * probability + (1 - smoothingFactor) * $0
            } ?? probability
        }
        func probability(_ label: PushUpPhaseLabel) -> Double { smoothedProbabilities[label.rawValue] ?? 0 }

        let mostLikely = smoothedProbabilities.max { $0.value < $1.value }?.key
        if mostLikely == PushUpPhaseLabel.none.rawValue {
            phase = .awaitingTop
            repFrames.removeAll()
            lastState = nil
            feedback = .outOfPosition
            return PushUpReading(state: nil, repCount: repCount, feedback: feedback)
        }

        let state: PushUpState
        if probability(.up) >= confidentProbability {
            state = .up
        } else if probability(.down) >= confidentProbability {
            state = .down
        } else {
            state = .transition
        }

        if phase == .top && state == .up {
            repFrames = [features]
            repStartedAt = now
        } else if phase != .awaitingTop {
            repFrames.append(features)
        }

        advanceCycle(to: state, features: features, at: now)
        lastState = state
        return PushUpReading(state: state, repCount: repCount, feedback: feedback)
    }

    private func advanceCycle(to state: PushUpState, features: PushUpFeatures, at time: TimeInterval) {
        switch (phase, state) {
        case (.awaitingTop, .up):
            phase = .top
            repFrames = [features]
            repStartedAt = time
            feedback = .good
        case (.awaitingTop, _):
            feedback = .outOfPosition
        case (.top, .transition):
            phase = .descending
        case (.top, .down), (.descending, .down):
            phase = .bottom
        case (.descending, .up):
            phase = .top
            repFrames = [features]
            repStartedAt = time
            feedback = .tooShallow
        case (.bottom, .transition):
            phase = .ascending
        case (.bottom, .up), (.ascending, .up):
            completeRep(endingWith: features, at: time)
        case (.ascending, .down):
            phase = .bottom
        default:
            break
        }
    }

    private func completeRep(endingWith features: PushUpFeatures, at time: TimeInterval) {
        let summary = PushUpRepSummary(frames: repFrames, duration: time - repStartedAt)
        phase = .top
        repFrames = [features]
        repStartedAt = time

        if let lastRepAt, time - lastRepAt < minimumRepInterval {
            feedback = .tooFast
            return
        }

        switch verdict(for: summary) {
        case .good:
            lastRepAt = time
            repCount += 1
            feedback = .good
        case .shallow:
            feedback = .tooShallow
        case .hipsSagging, .hipsPiked:
            feedback = .backNotStraight
        case .kneeling, .notPushup:
            feedback = .outOfPosition
        }
    }

    /// Without a rep model every full cycle counts, as long as the phase model saw it.
    private func verdict(for summary: PushUpRepSummary) -> PushUpRecordingLabel {
        guard
            let repModel,
            let probabilities = Self.probabilities(from: repModel, names: PushUpRepSummary.names, values: summary.values),
            let best = probabilities.max(by: { $0.value < $1.value })?.key
        else { return .good }
        return PushUpRecordingLabel(rawValue: best) ?? .good
    }

    private func handleMissingFrame() -> PushUpReading {
        missedFrames += 1
        if missedFrames > maximumMissedFrames {
            extractor.reset()
            smoothedProbabilities.removeAll()
            phase = .awaitingTop
            repFrames.removeAll()
            lastState = nil
            feedback = .notVisible
        }
        return PushUpReading(state: lastState, repCount: repCount, feedback: feedback)
    }

    static func probabilities(from model: MLModel, names: [String], values: [Double]) -> [String: Double]? {
        let inputs = Dictionary(uniqueKeysWithValues: zip(names, values.map { MLFeatureValue(double: $0) }))
        guard
            let provider = try? MLDictionaryFeatureProvider(dictionary: inputs),
            let output = try? model.prediction(from: provider),
            let key = model.modelDescription.predictedProbabilitiesName,
            let dictionary = output.featureValue(for: key)?.dictionaryValue
        else { return nil }
        var probabilities: [String: Double] = [:]
        for (label, value) in dictionary {
            if let label = label as? String { probabilities[label] = value.doubleValue }
        }
        return probabilities
    }
}
