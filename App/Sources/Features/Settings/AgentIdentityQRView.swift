import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - QRCodeView

struct QRCodeView: View {
    let content: String

    var body: some View {
        if let image = generateQR(content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
    }

    private func generateQR(_ string: String) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return UIImage(ciImage: scaled)
    }
}

// MARK: - AgentIdentityQRView

struct AgentIdentityQRView: View {
    let npub: String
    let name: String

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        ZStack {
            // Dimmed blurred background — tapping anywhere dismisses
            Color.black.opacity(0.6)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 24) {
                // Dismiss button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                }
                .padding(.horizontal, 24)

                // Name + subtitle
                VStack(spacing: 6) {
                    if !name.isEmpty {
                        Text(name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    Text("Scan to add as a contact")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // QR card — tap to copy
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Color.white
                            .clipShape(RoundedRectangle(cornerRadius: 24))

                        QRCodeView(content: npub)
                            .frame(width: 260, height: 260)
                            .padding(20)

                        // Copied overlay
                        if copied {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.black.opacity(0.55))
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.white)
                                    Text("Copied")
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        }
                    }
                    .frame(width: 300, height: 300)
                }
                .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                .onTapGesture {
                    copyNpub()
                }

                // npub text
                Text(npub)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 32)

                Text("Tap QR to copy")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // Action row
                HStack(spacing: 12) {
                    Button {
                        copyNpub()
                    } label: {
                        Label("Copy npub", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.glass)

                    ShareLink(item: npub) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal, 24)
            }
        }
        .statusBarHidden(true)
        .animation(AppTheme.Animation.spring, value: copied)
    }

    private func copyNpub() {
        UIPasteboard.general.string = npub
        Haptics.success()
        withAnimation(AppTheme.Animation.spring) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            await MainActor.run {
                withAnimation(AppTheme.Animation.spring) { copied = false }
            }
        }
    }
}
