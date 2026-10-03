import AVFoundation
import Vision

@MainActor
final class HoldPoseCounter: NSObject, ObservableObject {
    enum PoseKind {
        case plank
        case wallSit
    }

    @Published var heldSeconds = 0
    @Published var isInPosition = false
    @Published var formQuality: FormQuality = .notVisible
    @Published var trackingStatus: CameraTrackingStatus = .starting

    enum FormQuality: String {
        case good = "hold steady"
        case adjust = "adjust position"
        case notVisible = "step back"
    }

    let session = AVCaptureSession()
    private let videoQueue = DispatchQueue(label: "com.pratyushsharma.levelset.holdposecounter")
    private let kind: PoseKind
    private var targetSeconds = 60
    private var onComplete: (() -> Void)?
    private var accumulated: Double = 0
    private var lastInPositionTimestamp: Date?

    init(kind: PoseKind) {
        self.kind = kind
    }

    func start(targetSeconds: Int, onComplete: @escaping () -> Void) {
        heldSeconds = 0
        accumulated = 0
        lastInPositionTimestamp = nil
        self.targetSeconds = targetSeconds
        self.onComplete = onComplete
        startCamera()
    }

    func stop() {
        videoQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    private func startCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureAndRun()
        case .notDetermined:
            trackingStatus = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted { self.configureAndRun() }
                    else { self.trackingStatus = .permissionDenied }
                }
            }
        case .denied, .restricted: trackingStatus = .permissionDenied
        @unknown default: trackingStatus = .unavailable
        }
    }

    private func configureAndRun() {
        trackingStatus = .starting
        if session.inputs.isEmpty, !configureSession() { return }
        videoQueue.async { [weak self] in self?.session.startRunning() }
    }

    @discardableResult
    private func configureSession() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            session.commitConfiguration()
            trackingStatus = .unavailable
            return false
        }
        guard session.canAddInput(input) else { session.commitConfiguration(); trackingStatus = .failed("input"); return false }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); trackingStatus = .failed("output"); return false }
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        session.commitConfiguration()
        trackingStatus = .lookingForPerson
        return true
    }

    private func handle(observation: VNHumanBodyPoseObservation, at timestamp: Date) {
        guard let joints = try? observation.recognizedPoints(.all) else {
            formQuality = .notVisible
            trackingStatus = .lookingForPerson
            isInPosition = false
            return
        }
        let side = PoseGeometry.bestVisibleSide(in: joints)
        guard
            let shoulder = joints[side.shoulder],
            let hip = joints[side.hip],
            let knee = joints[side.knee],
            let ankle = joints[side.ankle],
            shoulder.confidence > 0.3, hip.confidence > 0.3,
            knee.confidence > 0.3, ankle.confidence > 0.3
        else {
            Task { @MainActor in
                self.formQuality = .notVisible
                self.isInPosition = false
                self.lastInPositionTimestamp = nil
            }
            return
        }

        let inPosition: Bool
        switch kind {
        case .plank:
            inPosition = PoseGeometry.isPlankAligned(
                shoulder: shoulder.location,
                hip: hip.location,
                ankle: ankle.location
            )
        case .wallSit:
            let torsoUpright = abs(shoulder.location.x - hip.location.x) < 0.12
                && shoulder.location.y > hip.location.y
            let kneeAngle = PoseGeometry.angleBetween(hip.location, knee.location, ankle.location)
            inPosition = torsoUpright && kneeAngle > 60 && kneeAngle < 120
        }

        Task { @MainActor in
            self.trackingStatus = .tracking
            self.isInPosition = inPosition
            self.formQuality = inPosition ? .good : .adjust

            guard inPosition else {
                self.lastInPositionTimestamp = nil
                return
            }

            if let last = self.lastInPositionTimestamp {
                self.accumulated += timestamp.timeIntervalSince(last)
            }
            self.lastInPositionTimestamp = timestamp

            let newHeld = min(self.targetSeconds, Int(self.accumulated))
            guard newHeld != self.heldSeconds else { return }
            self.heldSeconds = newHeld
            if self.heldSeconds >= self.targetSeconds {
                self.stop()
                self.onComplete?()
            }
        }
    }

}

extension HoldPoseCounter: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let timestamp = Date()
        do {
            try handler.perform([request])
            if let observation = request.results?.first {
                Task { @MainActor in self.handle(observation: observation, at: timestamp) }
            } else {
                Task { @MainActor in
                    self.trackingStatus = .lookingForPerson
                    self.formQuality = .notVisible
                    self.isInPosition = false
                }
            }
        } catch {
            Task { @MainActor in self.trackingStatus = .failed(error.localizedDescription) }
        }
    }
}
