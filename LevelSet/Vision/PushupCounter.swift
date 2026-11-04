import AVFoundation
import Combine

@MainActor
final class PushupCounter: ObservableObject {
    @Published private(set) var repCount = 0
    @Published private(set) var formQuality: PushUpFeedback = .notVisible
    @Published private(set) var pushUpState: PushUpState?
    @Published private(set) var trackingStatus: CameraTrackingStatus = .starting

    let skeleton = SkeletonModel()

    private let camera = CameraStreamManager()
    private let detector = PoseDetector()
    private var targetReps = 12
    private var onComplete: (() -> Void)?
    private var isRunning = false

    var session: AVCaptureSession { camera.session }

    func start(targetReps: Int, onComplete: @escaping () -> Void) {
        self.targetReps = targetReps
        self.onComplete = onComplete
        repCount = 0
        pushUpState = nil
        formQuality = .notVisible
        skeleton.frame = nil
        isRunning = true

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
        camera.setFrameHandler(nil)
        camera.stopSession()
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
        let classifier: PushUpRepTracking = PushUpModelClassifier.bundled() ?? PushUpClassifier()
        return { [weak self] pixelBuffer, orientation in
            guard let self else { return }
            let frame = detector.detect(in: pixelBuffer, orientation: orientation)
            let reading = classifier.process(frame, at: .now)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.apply(reading, frame: frame) }
            }
        }
    }

    private func apply(_ reading: PushUpReading, frame: PoseFrame?) {
        guard isRunning else { return }

        skeleton.frame = frame

        let visible = !(frame?.normalizedPoints.isEmpty ?? true)
        let status: CameraTrackingStatus = visible ? .tracking : .lookingForPerson
        if trackingStatus != status { trackingStatus = status }
        if pushUpState != reading.state { pushUpState = reading.state }
        if formQuality != reading.feedback { formQuality = reading.feedback }
        if repCount != reading.repCount { repCount = reading.repCount }

        if repCount >= targetReps {
            stop()
            onComplete?()
        }
    }
}
