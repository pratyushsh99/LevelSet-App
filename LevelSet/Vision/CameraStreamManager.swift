import AVFoundation
import ImageIO

final class CameraStreamManager: NSObject, @unchecked Sendable {
    typealias FrameHandler = @Sendable (CVPixelBuffer, CGImagePropertyOrientation) -> Void

    enum SetupError: Error {
        case unavailable
        case configurationFailed
    }

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.pratyushsharma.levelset.camera.session")
    private let processingQueue = DispatchQueue(label: "com.pratyushsharma.levelset.camera.processing", qos: .userInitiated)
    private var frameHandler: FrameHandler?
    private var isConfigured = false
    private var bufferOrientation: CGImagePropertyOrientation = .up

    static func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func setFrameHandler(_ handler: FrameHandler?) {
        processingQueue.async { [self] in
            frameHandler = handler
        }
    }

    func startSession(completion: @escaping @Sendable (Result<Void, SetupError>) -> Void) {
        sessionQueue.async { [self] in
            if !isConfigured {
                if let error = configure() {
                    completion(.failure(error))
                    return
                }
                isConfigured = true
            }
            if !session.isRunning {
                session.startRunning()
            }
            completion(.success(()))
        }
    }

    func stopSession() {
        sessionQueue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configure() -> SetupError? {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            return .unavailable
        }
        guard session.canAddInput(input) else { return .configurationFailed }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: processingQueue)
        guard session.canAddOutput(output) else { return .configurationFailed }
        session.addOutput(output)

        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
            bufferOrientation = .up
        } else {
            bufferOrientation = .right
        }
        return nil
    }
}

extension CameraStreamManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let handler = frameHandler, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        handler(pixelBuffer, bufferOrientation)
    }
}
