import SwiftUI

/// A single row in the model browser list.
/// Shows provider logo, model name + ID + capability badges, and compact pricing.
struct OpenRouterModelRow: View {
    var model: OpenRouterModelOption
    var isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProviderLogoView(providerID: model.providerID, providerName: model.providerName, iconURL: model.providerIconURL)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(model.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .imageScale(.small)
                    }
                }

                Text(model.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(badges.prefix(4), id: \.self) { badge in
                            ModelBadge(kind: badge)
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(model.compactPricing)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
                Text("per 1M")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(tokenLimit(model.contextLength))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 86, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private var badges: [ModelBadgeKind] {
        var result: [ModelBadgeKind] = []
        if !model.isCompatible { result.append(.noJSON) }
        if model.supportsTools { result.append(.tools) }
        if model.supportsReasoning { result.append(.reasoning) }
        if model.inputModalities.contains("image") { result.append(.vision) }
        if model.openWeights { result.append(.openWeights) }
        if model.isFree { result.append(.free) }
        return result
    }
}

// MARK: - Preview

#Preview {
    List {
        OpenRouterModelRow(
            model: OpenRouterModelOption(
                openRouter: ORModel(
                    id: "openai/gpt-4o",
                    name: "GPT-4o",
                    created: 1_700_000_000,
                    description: nil,
                    contextLength: 128_000,
                    architecture: ORArchitecture(
                        inputModalities: ["text", "image"],
                        outputModalities: ["text"],
                        tokenizer: "cl100k"
                    ),
                    pricing: ORPricing(
                        prompt: "0.0000025",
                        completion: "0.00001",
                        request: nil,
                        image: nil,
                        webSearch: nil,
                        inputCacheRead: nil,
                        inputCacheWrite: nil
                    ),
                    topProvider: ORTopProvider(
                        contextLength: 128_000,
                        maxCompletionTokens: 4096,
                        isModerated: true
                    ),
                    supportedParameters: ["tools", "response_format"],
                    knowledgeCutoff: "2024-04"
                ),
                modelsDev: nil
            ),
            isSelected: true
        )
    }
    .listStyle(.insetGrouped)
}
