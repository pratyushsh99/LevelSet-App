import CoreML
import CreateML
import Foundation
import TabularData

// Trains the push-up phase and rep models from recordings made with the in-app recorder.
// Run through Training/train.sh, which compiles this together with the app's feature code.

struct TrainedModels {
    let phase: MLBoostedTreeClassifier
    let rep: MLBoostedTreeClassifier?
}

struct Row {
    let values: [Double]
    let label: String
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: pushup-trainer <recordings-dir> <output-dir>")
    exit(2)
}
let dataDirectory = URL(fileURLWithPath: arguments[1])
let outputDirectory = URL(fileURLWithPath: arguments[2])

func loadSessions(from directory: URL) -> [LabeledSession] {
    let decoder = JSONDecoder()
    let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?
        .compactMap { $0 as? URL }
        .filter { $0.pathExtension == "json" }
        .sorted { $0.path < $1.path } ?? []
    return files.compactMap { url in
        do {
            let recording = try decoder.decode(PushUpRecording.self, from: Data(contentsOf: url))
            guard recording.version == PushUpRecording.currentVersion else {
                print("skip \(url.lastPathComponent): recording version \(recording.version)")
                return nil
            }
            return SessionLabeler.label(recording, name: url.lastPathComponent)
        } catch {
            print("skip \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}

/// Holds out whole people when there are enough of them, otherwise whole sessions, so
/// validation frames never come from a session the model trained on.
func validationSplit(_ sessions: [LabeledSession]) -> (training: [LabeledSession], validation: [LabeledSession]) {
    let participants = Set(sessions.map { $0.recording.participant.lowercased() }).sorted()
    if participants.count >= 3 {
        var heldOut = Set(participants.enumerated().filter { $0.offset % 4 == 3 }.map(\.element))
        if heldOut.isEmpty, let last = participants.last { heldOut = [last] }
        print("validating on participants: \(heldOut.sorted().joined(separator: ", "))")
        let isHeldOut = { (session: LabeledSession) in heldOut.contains(session.recording.participant.lowercased()) }
        return (sessions.filter { !isHeldOut($0) }, sessions.filter(isHeldOut))
    }

    var training: [LabeledSession] = []
    var validation: [LabeledSession] = []
    for label in PushUpRecordingLabel.allCases {
        for (index, session) in sessions.filter({ $0.recording.label == label }).enumerated() {
            if index % 4 == 3 { validation.append(session) } else { training.append(session) }
        }
    }
    print("fewer than 3 participants: validating on every 4th session of each label")
    return (training, validation)
}

func phaseRows(_ sessions: [LabeledSession]) -> [Row] {
    sessions.filter(\.isConsistent).flatMap { session in
        zip(session.features, session.phaseLabels).compactMap { features, label in
            guard let features, let label else { return nil }
            return Row(values: features.values, label: label.rawValue)
        }
    }
}

func repRows(_ sessions: [LabeledSession]) -> [Row] {
    sessions.filter(\.isConsistent).flatMap { session in
        session.repSummaries().map { Row(values: $0.values, label: session.recording.label.rawValue) }
    }
}

func trainClassifier(_ rows: [Row], names: [String]) throws -> MLBoostedTreeClassifier? {
    guard Set(rows.map(\.label)).count >= 2 else { return nil }
    var table = DataFrame()
    for (index, name) in names.enumerated() {
        table.append(column: Column(name: name, contents: rows.map { $0.values[index] }))
    }
    table.append(column: Column(name: "label", contents: rows.map(\.label)))
    let parameters = MLBoostedTreeClassifier.ModelParameters(
        validation: .none, maxDepth: 6, maxIterations: 200, rowSubsample: 0.8, columnSubsample: 0.8
    )
    return try MLBoostedTreeClassifier(trainingData: table, targetColumn: "label", featureColumns: names, parameters: parameters)
}

func train(_ sessions: [LabeledSession]) throws -> TrainedModels? {
    guard let phase = try trainClassifier(phaseRows(sessions), names: PushUpFeatures.names) else { return nil }
    return TrainedModels(phase: phase, rep: try trainClassifier(repRows(sessions), names: PushUpRepSummary.names))
}

func reportAccuracy(of model: MLModel, on rows: [Row], names: [String], title: String) {
    guard !rows.isEmpty else { return }
    var confusion: [String: [String: Int]] = [:]
    var correct = 0
    for row in rows {
        let predicted = PushUpModelClassifier.probabilities(from: model, names: names, values: row.values)?
            .max { $0.value < $1.value }?.key ?? "?"
        confusion[row.label, default: [:]][predicted, default: 0] += 1
        if predicted == row.label { correct += 1 }
    }
    print(String(format: "\n%@: %.1f%% of %d held-out examples correct", title, 100 * Double(correct) / Double(rows.count), rows.count))
    let labels = confusion.keys.sorted()
    print("  actual \\ predicted".padding(toLength: 22, withPad: " ", startingAt: 0) + labels.map { $0.padding(toLength: 12, withPad: " ", startingAt: 0) }.joined())
    for actual in labels {
        let counts = labels.map { String(confusion[actual]?[$0] ?? 0).padding(toLength: 12, withPad: " ", startingAt: 0) }
        print("  \(actual)".padding(toLength: 22, withPad: " ", startingAt: 0) + counts.joined())
    }
}

func replay(_ session: LabeledSession, through classifier: PushUpRepTracking) -> Int {
    var count = 0
    for frame in session.recording.frames {
        count = classifier.process(frame.poseFrame, at: Date(timeIntervalSinceReferenceDate: frame.t)).repCount
    }
    return count
}

/// The number that matters: how many reps each counter credits on sessions it never saw,
/// compared with what the person actually did. Uses reported counts, not derived labels.
func compareCounters(_ models: TrainedModels, on sessions: [LabeledSession]) {
    print("\nRep counts on held-out sessions (expected = good reps the person reported)")
    print("  session".padding(toLength: 34, withPad: " ", startingAt: 0) + "expected  model  heuristic")
    var modelErrors: [Int] = []
    var heuristicErrors: [Int] = []
    for session in sessions {
        let model = replay(session, through: PushUpModelClassifier(phaseModel: models.phase.model, repModel: models.rep?.model))
        let heuristic = replay(session, through: PushUpClassifier())
        modelErrors.append(abs(model - session.expectedCount))
        heuristicErrors.append(abs(heuristic - session.expectedCount))
        print("  \(session.name)".padding(toLength: 34, withPad: " ", startingAt: 0)
              + String(format: "%8d  %5d  %9d", session.expectedCount, model, heuristic))
    }
    func summary(_ errors: [Int]) -> String {
        let exact = errors.filter { $0 == 0 }.count
        let mean = Double(errors.reduce(0, +)) / Double(max(errors.count, 1))
        return String(format: "exact on %d/%d sessions, off by %.2f reps on average", exact, errors.count, mean)
    }
    print("  model:     \(summary(modelErrors))")
    print("  heuristic: \(summary(heuristicErrors))")
}

func write(_ models: TrainedModels, to directory: URL, sessionCount: Int) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    func metadata(_ description: String) -> MLModelMetadata {
        MLModelMetadata(
            author: "LevelSet Training",
            shortDescription: "\(description) Trained on \(sessionCount) recordings.",
            version: "1",
            additional: [PushUpModelClassifier.featureVersionKey: String(PushUpFeatures.version)]
        )
    }
    let phaseURL = directory.appending(path: "\(PushUpModelClassifier.phaseModelName).mlmodel")
    let repURL = directory.appending(path: "\(PushUpModelClassifier.repModelName).mlmodel")
    try models.phase.write(to: phaseURL, metadata: metadata("Push-up phase (up, down, moving, none) per pose frame."))
    print("wrote \(phaseURL.path)")
    if let rep = models.rep {
        try rep.write(to: repURL, metadata: metadata("Push-up rep verdict (good or which form fault)."))
        print("wrote \(repURL.path)")
    } else if FileManager.default.fileExists(atPath: repURL.path) {
        try FileManager.default.removeItem(at: repURL)
        print("removed stale \(repURL.path): record at least one form-fault label to train a rep model")
    }
}

let sessions = loadSessions(from: dataDirectory)
guard !sessions.isEmpty else {
    print("no recordings found in \(dataDirectory.path)")
    exit(1)
}

print("Loaded \(sessions.count) recordings")
for label in PushUpRecordingLabel.allCases {
    let group = sessions.filter { $0.recording.label == label }
    guard !group.isEmpty else { continue }
    let reps = group.filter(\.isConsistent).reduce(0) { $0 + $1.reps.count }
    print("  \(label.rawValue)".padding(toLength: 16, withPad: " ", startingAt: 0) + "\(group.count) sessions, \(reps) usable reps")
}
for session in sessions where !session.isConsistent {
    print("  excluded \(session.name): reported \(session.recording.reportedReps) reps, motion shows \(session.reps.count)")
}
if !sessions.contains(where: { $0.recording.label == .notPushup }) {
    print("  note: no 'not a push-up' recordings, so the model can't learn to ignore other movement")
}

let split = validationSplit(sessions)
if split.training.isEmpty || split.validation.isEmpty {
    print("\nnot enough recordings to hold some out for validation; skipping evaluation")
} else if let models = try train(split.training) {
    reportAccuracy(of: models.phase.model, on: phaseRows(split.validation), names: PushUpFeatures.names, title: "Phase model")
    if let rep = models.rep {
        reportAccuracy(of: rep.model, on: repRows(split.validation), names: PushUpRepSummary.names, title: "Rep model")
    }
    compareCounters(models, on: split.validation)
}

print("\nTraining final models on all recordings")
guard let models = try train(sessions) else {
    print("need push-up recordings with at least one detected rep to train the phase model")
    exit(1)
}
try write(models, to: outputDirectory, sessionCount: sessions.count)
