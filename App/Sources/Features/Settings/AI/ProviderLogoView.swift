import SwiftUI

/// Letter-tile provider logo. Renders a circle with a deterministic gradient color
/// derived from the provider ID hash, overlaid with a 1–2 character monogram.
/// No external image loading — purely generative, always renders instantly.
struct ProviderLogoView: View {
    let providerID: String
    let providerName: String
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tileColor.opacity(0.9), tileColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(monogram)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - Derived values

    /// Deterministic hue from providerID hash (0–359 degrees).
    private var tileColor: Color {
        let hue = abs(providerID.hashValue) % 360
        return Color(hue: Double(hue) / 360.0, saturation: 0.6, brightness: 0.75)
    }

    /// First 1–2 characters of the provider name, uppercased.
    private var monogram: String {
        let pieces = providerName
            .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "." })
            .prefix(2)
        let text = pieces.compactMap(\.first).map(String.init).joined()
        return text.isEmpty ? String(providerID.prefix(2)).uppercased() : text.uppercased()
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        ProviderLogoView(providerID: "openai", providerName: "OpenAI")
        ProviderLogoView(providerID: "anthropic", providerName: "Anthropic")
        ProviderLogoView(providerID: "google", providerName: "Google", size: 52)
        ProviderLogoView(providerID: "meta-llama", providerName: "Meta Llama", size: 28)
    }
    .padding()
}
