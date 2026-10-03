import AVFoundation
import Vision

@MainActor
final class JumpingJackCounter: NSObject, ObservableObject {
    @Published var repCount = 0
    @Published var formQuality: FormQuality = .good
    @Published var trackingStatus: CameraTrackingStatus = .starting

    enum FormQuality: String {
        case good = "form: good"
        case armsOnly = "jump those legs out too"
        case tooFast = "slow down"
        case notVisible = "get your full body in frame"
    }

    let session = AVCaptureSession()
    private let videoQueue = DispatchQueue(label: "com.pratyushsharma.levelset.jumpingjackcounter")
    private var armsAndLegsOut = false
    private let minRepInterval: TimeInterval = 0.35
    private var lastRepAt: Date?

    func start(targetReps: Int, onComplete: @escaping () -> Void) {
        repCount = 0
        armsAndLegsOut = false
        lastRepAt = nil
        self.onComplete = onComplete
        self.targetReps = targetReps
        startCamera()
    }

    func stop() {
        videoQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    private var onComplete: (() -> Void)?
    private var targetReps = 20

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

    private func handle(observation: VNHumanBodyPoseObservation) {
        guard
            let leftWrist = try? observation.recognizedPoint(.leftWrist),
            let rightWrist = try? observation.recognizedPoint(.rightWrist),
            let neck = try? observation.recognizedPoint(.neck),
            let leftHip = try? observation.recognizedPoint(.leftHip),
            let rightHip = try? observation.recognizedPoint(.rightHip),
            let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
            let rightAnkle = try? observation.recognizedPoint(.rightAnkle),
            leftWrist.confidence > 0.3, rightWrist.confidence > 0.3, neck.confidence > 0.3,
            leftHip.confidence > 0.3, rightHip.confidence > 0.3,
            leftAnkle.confidence > 0.3, rightAnkle.confidence > 0.3
        else {
            Task { @MainActor in
                self.formQuality = .notVisible
                self.armsAndLegsOut = false
            }
            return
        }

        let armsUp = leftWrist.location.y > neck.location.y && rightWrist.location.y > neck.location.y
        let hipWidth = abs(leftHip.location.x - rightHip.location.x)
        let ankleSpread = abs(leftAnkle.location.x - rightAnkle.location.x)
        let legsOut = ankleSpread > hipWidth * 1.6
        let legsIn = ankleSpread < hipWidth * 1.2

        Task { @MainActor in
            self.trackingStatus = .tracking
            if armsUp && legsOut {
                self.armsAndLegsOut = true
                self.formQuality = .good
            } else if armsUp && !legsOut {
                self.formQuality = .armsOnly
            } else if !armsUp && legsIn && self.armsAndLegsOut {
                self.armsAndLegsOut = false
                self.countRepIfAllowed()
            }
        }
    }

    private func countRepIfAllowed() {
        let now = Date()
        if let last = lastRepAt, now.timeIntervalSince(last) < minRepInterval {
            formQuality = .tooFast
            return
        }
        lastRepAt = now
        formQuality = .good
        repCount += 1
        if repCount >= targetReps {
            stop()
            onComplete?()
        }
    }
}

extension JumpingJackCounter: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            if let observation = request.results?.first {
                Task { @MainActor in self.handle(observation: observation) }
            } else {
                Task { @MainActor in
                    self.trackingStatus = .lookingForPerson
                    self.formQuality = .notVisible
                }
            }
        } catch {
            Task { @MainActor in self.trackingStatus = .failed(error.localizedDescription) }
        }
    }
}
