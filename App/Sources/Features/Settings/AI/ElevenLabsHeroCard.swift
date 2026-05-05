import SwiftUI

// MARK: - Connection state

enum ElevenLabsConnectionState {
    case notConnected
    case connectedBYOK
    case connectedManual
    case reconnectRequired

    static func derive(source: ElevenLabsCredentialSource, hasKey: Bool) -> Self {
        switch (source, hasKey) {
        case (.none, _):              return .notConnected
        case (.byok, true):           return .connectedBYOK
        case (.manual, true):         return .connectedManual
        case (.byok, false):          return .reconnectRequired
        case (.manual, false):        return .reconnectRequired
        }
    }
}

// MARK: - Hero card

struct ElevenLabsHeroCard: View {
    let connectionState: ElevenLabsConnectionState
    let keyLabel: String?
    let connectedAt: Date?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: connectionIcon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(connectionTint)
                .symbolEffect(.bounce, value: connectionState == .notConnected ? 0 : 1)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("ElevenLabs")
                    .font(AppTheme.Typography.title)
                Text(heroSubtitle)
                    .font(.callout)
                    .foregroundStyle(isConnected ? .primary : .secondary)
                if let tertiary = heroTertiary {
                    Text(tertiary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if connectionState != .notConnected {
                statusPill
            }
        }
        .padding(16)
        .frame(minHeight: 88)
        .glassSurface(cornerRadius: 16, interactive: true)
    }

    // MARK: - Status pill

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(pillTint)
                .frame(width: 6, height: 6)
            Text(pillLabel)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular.tint(pillTint), in: .capsule)
    }

    // MARK: - Derived values

    private var isConnected: Bool {
        connectionState == .connectedBYOK || connectionState == .connectedManual
    }

    private var connectionIcon: String {
        switch connectionState {
        case .notConnected:      return "waveform.circle"
        case .connectedBYOK:     return "waveform.circle.fill"
        case .connectedManual:   return "waveform.circle.fill"
        case .reconnectRequired: return "exclamationmark.triangle.fill"
        }
    }

    private var connectionTint: Color {
        switch connectionState {
        case .notConnected:      return .secondary
        case .connectedBYOK:     return Color(red: 0, green: 0.78, blue: 0.62)
        case .connectedManual:   return Color(red: 0, green: 0.78, blue: 0.62)
        case .reconnectRequired: return .orange
        }
    }

    private var heroSubtitle: String {
        switch connectionState {
        case .notConnected:      return "Not connected"
        case .connectedBYOK:     return "Connected with BYOK"
        case .connectedManual:   return "Manual key saved"
        case .reconnectRequired: return "Reconnect required"
        }
    }

    private var heroTertiary: String? {
        guard isConnected else { return nil }
        if let label = keyLabel, !label.isEmpty { return label }
        if let date = connectedAt {
            return date.formatted(.relative(presentation: .named))
        }
        return nil
    }

    private var pillTint: Color {
        connectionState == .reconnectRequired ? .orange : Color(red: 0, green: 0.78, blue: 0.62)
    }

    private var pillLabel: String {
        connectionState == .reconnectRequired ? "Action needed" : "Live"
    }
}
