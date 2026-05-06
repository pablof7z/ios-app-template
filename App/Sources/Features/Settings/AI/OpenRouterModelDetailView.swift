import SwiftUI

/// Full-screen detail view for a single OpenRouter model.
/// Pushed via `NavigationLink(value:)` from the model selector.
struct OpenRouterModelDetailView: View {
    var model: OpenRouterModelOption
    @Binding var selectedModelID: String
    @Environment(\.dismiss) private var dismiss

    enum Layout {
        static let contentPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 18
        static let heroSpacing: CGFloat = 14
        static let heroLogoSize: CGFloat = 52
        static let heroInnerSpacing: CGFloat = 6
        static let groupSpacing: CGFloat = 10
        static let groupInnerSpacing: CGFloat = 8
        static let detailLineMinSpacing: CGFloat = 12
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                heroSection
                selectButton

                detailGroup("Pricing") {
                    DetailLine("Prompt", pricingDetail(model.promptCostPerMillion))
                    DetailLine("Completion", pricingDetail(model.completionCostPerMillion))
                    if model.cacheReadCostPerMillion != nil {
                        DetailLine("Cache read", pricingDetail(model.cacheReadCostPerMillion))
                    }
                    if model.cacheWriteCostPerMillion != nil {
                        DetailLine("Cache write", pricingDetail(model.cacheWriteCostPerMillion))
                    }
                    if let webSearchCost = model.webSearchCost {
                        DetailLine("Web search", OpenRouterModelOption.money(webSearchCost))
                    }
                    if let imageCost = model.imageCost {
                        DetailLine("Image", OpenRouterModelOption.money(imageCost))
                    }
                }

                detailGroup("Capabilities") {
                    DetailLine("Compatibility", model.isCompatible ? "JSON response format" : "May not support JSON schema")
                    DetailLine("Input", model.inputModalities.isEmpty ? "Unknown" : model.inputModalities.joined(separator: ", "))
                    DetailLine("Output", model.outputModalities.isEmpty ? "Unknown" : model.outputModalities.joined(separator: ", "))
                    DetailLine("Tools", model.supportsTools ? "Yes" : "No")
                    DetailLine("Reasoning", model.supportsReasoning ? "Yes" : "No")
                    DetailLine("Structured output", model.supportsStructuredOutputs ? "Yes" : "No")
                    DetailLine("Weights", model.openWeights ? "Open" : "Closed")
                }

                detailGroup("Limits") {
                    DetailLine("Context", tokenLimit(model.contextLength))
                    DetailLine("Output", tokenLimit(model.outputLimit))
                    if let tokenizer = model.tokenizer {
                        DetailLine("Tokenizer", tokenizer)
                    }
                    if let isModerated = model.isModerated {
                        DetailLine("Moderated", isModerated ? "Yes" : "No")
                    }
                }

                if model.releaseDate != nil || model.lastUpdated != nil || model.knowledgeCutoff != nil || model.createdAt != nil {
                    detailGroup("Dates") {
                        if let releaseDate = model.releaseDate {
                            DetailLine("Release", releaseDate)
                        }
                        if let lastUpdated = model.lastUpdated {
                            DetailLine("Updated", lastUpdated)
                        }
                        if let knowledgeCutoff = model.knowledgeCutoff {
                            DetailLine("Knowledge cutoff", knowledgeCutoff)
                        }
                        if let createdAt = model.createdAt {
                            DetailLine("Added to OpenRouter", createdAt.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }

                if let description = model.modelDescription, !description.isEmpty {
                    detailGroup("Description") {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(Layout.contentPadding)
        }
        .navigationTitle("Model")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sub-views

    private var heroSection: some View {
        HStack(alignment: .top, spacing: Layout.heroSpacing) {
            ProviderLogoView(providerID: model.providerID, providerName: model.providerName, size: Layout.heroLogoSize)

            VStack(alignment: .leading, spacing: Layout.heroInnerSpacing) {
                Text(model.name)
                    .font(.title3.weight(.semibold))
                Text(model.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(model.providerName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectButton: some View {
        let alreadySelected = selectedModelID == model.id
        return Button {
            selectedModelID = model.id
            dismiss()
        } label: {
            Label(
                alreadySelected ? "Selected" : "Use Model",
                systemImage: "checkmark.circle.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .disabled(alreadySelected)
    }

    // MARK: - Helpers

    private func detailGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.groupSpacing) {
            Text(title)
                .font(AppTheme.Typography.headline)
            VStack(alignment: .leading, spacing: Layout.groupInnerSpacing) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pricingDetail(_ value: Double?) -> String {
        guard let value else { return "Variable" }
        return "\(OpenRouterModelOption.perToken(value)) / \(OpenRouterModelOption.money(value)) per 1M"
    }
}

// MARK: - Detail line

struct DetailLine: View {
    var label: String
    var value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: OpenRouterModelDetailView.Layout.detailLineMinSpacing)
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}
