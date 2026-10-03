import AVFoundation
import SwiftUI

struct QRScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmitCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        previewLayer?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !session.isRunning {
            Task.detached { [session] in session.startRunning() }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if session.isRunning {
            Task.detached { [session] in session.stopRunning() }
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didEmitCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }

        didEmitCode = true
        onCodeScanned?(value)
    }
}
