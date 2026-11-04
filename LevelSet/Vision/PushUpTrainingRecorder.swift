import AVFoundation
import Combine
import Foundation

/// Records pose keypoints (never video) for training the push-up models in `Training/`.
/// Frames come from the same camera and detector pipeline the live counter uses.
@MainActor
final class PushUpTrainingRecorder: ObservableObject {
    @Published private(set) var trackingStatus: CameraTrackingStatus = .starting
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var visibleFrameCount = 0
    @Published private(set) var savedRecordings: [URL] = []

    let skeleton = SkeletonModel()

    private let camera = CameraStreamManager()
    private let detector = PoseDetector()
    private var frames: [PushUpRecording.Frame] = []
    private var recordingStartedAt: TimeInterval?
    private var isRunning = false

    var session: AVCaptureSession { camera.session }

    static var directory: URL {
        URL.documentsDirectory.appending(path: "PushUpTraining", directoryHint: .isDirectory)
    }

    func start() {
        isRunning = true
        refreshSavedRecordings()

        let needsPrompt = AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined
        trackingStatus = needsPrompt ? .requestingPermission : .starting

        Task {
            guard await CameraStreamManager.requestAuthorization() else {
                trackingStatus = .permissionDenied
                return
            }
            guard isRunning else { return }
            trackingStatus = .starting
            camera.setFrameHandler(makeFrameHandler())
            camera.startSession { [weak self] result in
                guard let self else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self.handleStartResult(result) }
                }
            }
        }
    }

    func stop() {
        isRunning = false
        isRecording = false
        camera.setFrameHandler(nil)
        camera.stopSession()
    }

    func beginRecording() {
        frames.removeAll()
        recordingStartedAt = nil
        elapsed = 0
        visibleFrameCount = 0
        isRecording = true
    }

    /// Stops collecting frames. Call `save` to keep them or `beginRecording` to start over.
    func endRecording() {
        isRecording = false
    }

    func save(label: PushUpRecordingLabel, participant: String, reportedReps: Int) throws {
        let recording = PushUpRecording(
            id: UUID(),
            label: label,
            participant: participant.trimmingCharacters(in: .whitespacesAndNewlines),
            reportedReps: label.countsReps ? reportedReps : 0,
            recordedAt: .now,
            frames: frames
        )
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let url = Self.directory.appending(path: "\(label.rawValue)-\(recording.id.uuidString.prefix(8)).json")
        try JSONEncoder().encode(recording).write(to: url, options: .atomic)
        frames.removeAll()
        refreshSavedRecordings()
    }

    func deleteAllRecordings() {
        try? FileManager.default.removeItem(at: Self.directory)
        refreshSavedRecordings()
    }

    private func refreshSavedRecordings() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil)) ?? []
        savedRecordings = urls.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func handleStartResult(_ result: Result<Void, CameraStreamManager.SetupError>) {
        guard isRunning else { return }
        switch result {
        case .success:
            if trackingStatus != .tracking { trackingStatus = .lookingForPerson }
        case .failure(.unavailable):
            trackingStatus = .unavailable
        case .failure(.configurationFailed):
            trackingStatus = .failed("configuration")
        }
    }

    private func makeFrameHandler() -> CameraStreamManager.FrameHandler {
        let detector = detector
        return { [weak self] pixelBuffer, orientation in
            guard let self else { return }
            let frame = detector.detect(in: pixelBuffer, orientation: orientation)
            let time = ProcessInfo.processInfo.systemUptime
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.apply(frame, at: time) }
            }
        }
    }

    private func apply(_ frame: PoseFrame?, at time: TimeInterval) {
        guard isRunning else { return }

        skeleton.frame = frame
        let visible = !(frame?.normalizedPoints.isEmpty ?? true)
        let status: CameraTrackingStatus = visible ? .tracking : .lookingForPerson
        if trackingStatus != status { trackingStatus = status }

        guard isRecording else { return }
        let start = recordingStartedAt ?? time
        recordingStartedAt = start
        frames.append(PushUpRecording.Frame(t: time - start, poseFrame: frame))
        elapsed = time - start
        if visible { visibleFrameCount += 1 }
    }
}
