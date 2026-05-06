import SwiftUI

struct ElevenLabsVoiceRow: View {
    let voice: ElevenLabsVoice
    let isSelected: Bool
    let isPlaying: Bool
    let isLoadingPreview: Bool
    let canPreview: Bool
    let onTogglePreview: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            playButton

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(voice.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .imageScale(.small)
                    }
                }

                Text(voice.voiceID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !voice.pillLabels.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(voice.pillLabels.prefix(4), id: \.self) { pill in
                            ModelBadge(text: pill)
                        }
                    }
                }

                if let description = voice.descriptionLabel, !description.isEmpty {
                    Text(description.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var playButton: some View {
        Button {
            onTogglePreview()
        } label: {
            ZStack {
                Circle()
                    .fill(buttonFill)
                    .frame(width: AppTheme.Layout.iconSm, height: AppTheme.Layout.iconSm)

                if isLoadingPreview {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canPreview)
        .opacity(canPreview ? 1 : 0.4)
        .accessibilityLabel(isPlaying ? "Stop preview" : "Play preview")
    }

    private var buttonFill: Color {
        guard canPreview else { return Color.secondary.opacity(0.4) }
        return isPlaying
            ? Color.red
            : AppTheme.Brand.elevenLabsTint
    }
}
