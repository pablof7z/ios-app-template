import AVFoundation
import SwiftUI

// MARK: - SwiftUI wrapper

struct QRCodeScannerView: UIViewRepresentable {
    let onScanned: (String) -> Void

    func makeUIView(context: Context) -> QRCaptureView {
        let view = QRCaptureView()
        view.onScanned = { [weak context] value in
            context?.coordinator.deliver(value)
        }
        view.start()
        return view
    }

    func updateUIView(_ uiView: QRCaptureView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned) }

    final class Coordinator: NSObject {
        private let onScanned: (String) -> Void
        private var delivered = false

        init(onScanned: @escaping (String) -> Void) { self.onScanned = onScanned }

        func deliver(_ value: String) {
            guard !delivered else { return }
            delivered = true
            onScanned(value)
        }
    }
}

// MARK: - UIKit capture view

final class QRCaptureView: UIView {
    var onScanned: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    func start() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        if let layer = layer as? AVCaptureVideoPreviewLayer {
            layer.session = session
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    deinit { session.stopRunning() }
}

extension QRCaptureView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        onScanned?(value)
    }
}
