import SwiftUI

/// Provider logo that loads the models.dev icon URL when available,
/// falling back to a deterministic letter-tile.
struct ProviderLogoView: View {
    let providerID: String
    let providerName: String
    var iconURL: URL? = nil
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let url = iconURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.12)
                    default:
                        letterTile
                    }
                }
            } else {
                letterTile
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var letterTile: some View {
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
    }

    private var tileColor: Color {
        let hue = abs(providerID.hashValue) % 360
        return Color(hue: Double(hue) / 360.0, saturation: 0.6, brightness: 0.75)
    }

    private var monogram: String {
        let pieces = providerName
            .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "." })
            .prefix(2)
        let text = pieces.compactMap(\.first).map(String.init).joined()
        return text.isEmpty ? String(providerID.prefix(2)).uppercased() : text.uppercased()
    }
}
