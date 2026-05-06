import SwiftUI

/// Full model browser presented as a sheet.
/// Wrap in a `NavigationStack` at the call site.

private enum SelectorLayout {
    /// Maximum number of providers to show in the filter menu.
    static let maxProviderCount: Int = 24
    /// Vertical spacing inside the current-section fallback VStack.
    static let currentFallbackSpacing: CGFloat = 6
    /// Vertical padding on the current-section fallback row and error row.
    static let rowVerticalPadding: CGFloat = 4
    /// Horizontal spacing between the loading spinner and label.
    static let loadingSpacing: CGFloat = 12
    /// Vertical spacing inside the error section VStack.
    static let errorSpacing: CGFloat = 10
}

struct OpenRouterModelSelectorView: View {
    @Binding var selectedModelID: String
    /// Persisted human-readable name for the selected model, updated on every selection.
    @Binding var selectedModelName: String
    /// Human-readable role label forwarded to the detail view (e.g. "Agent", "Memory Compilation").
    var role: String = "Model"
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = OpenRouterModelSelectorViewModel()
    @State private var searchText = ""
    @State private var capabilityFilter: ModelCapabilityFilter = .compatible
    @State private var sort: ModelSort = .recommended
    @State private var providerFilter: String?
    @State private var manualModelID = ""

    var body: some View {
        List {
            currentSection
            controlsSection
            loadingSection
            modelsSection
            customSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(role) Model")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search models, providers, ids")
        .refreshable { await viewModel.reload() }
        .task {
            if manualModelID.isEmpty { manualModelID = selectedModelID }
            await viewModel.loadIfNeeded()
        }
        .navigationDestination(for: OpenRouterModelOption.self) { model in
            OpenRouterModelDetailView(model: model, selectedModelID: $selectedModelID, selectedModelName: $selectedModelName, role: role)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                providerMenu
                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Refresh models")
            }
        }
    }

    // MARK: - Sections

    private var currentSection: some View {
        Section("Current") {
            if let current = viewModel.models.first(where: { $0.id == selectedModelID }) {
                NavigationLink(value: current) {
                    OpenRouterModelRow(model: current, isSelected: true)
                }
            } else {
                VStack(alignment: .leading, spacing: SelectorLayout.currentFallbackSpacing) {
                    Text(selectedModelID)
                        .font(.subheadline.monospaced())
                    Text("Custom model ID")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, SelectorLayout.rowVerticalPadding)
            }
        }
    }

    private var controlsSection: some View {
        Section {
            Picker("Filter", selection: $capabilityFilter) {
                ForEach(ModelCapabilityFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.systemImage).tag(filter)
                }
            }

            Picker("Sort", selection: $sort) {
                ForEach(ModelSort.allCases) { s in
                    Text(s.title).tag(s)
                }
            }

            if let providerFilter,
               let name = viewModel.models.first(where: { $0.providerID == providerFilter })?.providerName {
                Button {
                    self.providerFilter = nil
                } label: {
                    Label("Provider: \(name)", systemImage: "xmark.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var loadingSection: some View {
        if viewModel.isLoading && viewModel.models.isEmpty {
            Section {
                HStack(spacing: SelectorLayout.loadingSpacing) {
                    ProgressView()
                    Text("Loading models")
                        .foregroundStyle(.secondary)
                }
            }
        }

        if let error = viewModel.errorMessage {
            Section {
                VStack(alignment: .leading, spacing: SelectorLayout.errorSpacing) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)

                    Button {
                        Task { await viewModel.reload() }
                    } label: {
                        Label("Try again", systemImage: "arrow.clockwise")
                    }
                }
                .padding(.vertical, SelectorLayout.rowVerticalPadding)
            }
        }
    }

    private var modelsSection: some View {
        Section("\(visibleModels.count) Models") {
            if visibleModels.isEmpty && !viewModel.isLoading {
                Text("No models match this search")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleModels) { model in
                    NavigationLink(value: model) {
                        OpenRouterModelRow(model: model, isSelected: model.id == selectedModelID)
                    }
                }
            }
        }
    }

    private var customSection: some View {
        Section("Custom model ID") {
            TextField("provider/model", text: $manualModelID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())

            Button {
                let trimmed = manualModelID.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                selectedModelID = trimmed
                selectedModelName = ""
                dismiss()
            } label: {
                Label("Use custom ID", systemImage: "checkmark.circle")
            }
            .disabled(manualModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Provider menu

    private var providerMenu: some View {
        Menu {
            Button {
                providerFilter = nil
            } label: {
                Label("All providers", systemImage: providerFilter == nil ? "checkmark" : "building.2")
            }

            ForEach(providerSummaries) { provider in
                Button {
                    providerFilter = provider.id
                } label: {
                    if providerFilter == provider.id {
                        Label("\(provider.name) (\(provider.count))", systemImage: "checkmark")
                    } else {
                        Text("\(provider.name) (\(provider.count))")
                    }
                }
            }
        } label: {
            Image(systemName: "building.2")
        }
        .accessibilityLabel("Filter by provider")
    }

    // MARK: - Computed

    private var visibleModels: [OpenRouterModelOption] {
        var models = viewModel.models

        if let providerFilter {
            models = models.filter { $0.providerID == providerFilter }
        }
        models = models.filter { capabilityFilter.matches($0) }

        let terms = searchText.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        if !terms.isEmpty {
            models = models.filter { model in
                terms.allSatisfy { model.searchText.contains($0) }
            }
        }

        switch sort {
        case .recommended: return models
        case .newest:  return models.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .price:   return models.sorted { $0.priceSortValue < $1.priceSortValue }
        case .context: return models.sorted { ($0.contextLength ?? 0) > ($1.contextLength ?? 0) }
        case .name:    return models.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private var providerSummaries: [ProviderSummary] {
        let grouped = Dictionary(grouping: viewModel.models, by: \.providerID)
        let summaries: [ProviderSummary] = grouped.map { id, models in
            ProviderSummary(id: id, name: models.first?.providerName ?? id, count: models.count)
        }
        let sorted = summaries.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return Array(sorted.prefix(SelectorLayout.maxProviderCount))
    }
}

// MARK: - View model

@MainActor
final class OpenRouterModelSelectorViewModel: ObservableObject {
    @Published private(set) var models: [OpenRouterModelOption] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service = OpenRouterModelCatalogService()

    func loadIfNeeded() async {
        guard models.isEmpty else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            models = try await service.fetchModels()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
