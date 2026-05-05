import SwiftUI

// MARK: - Filter

private enum ItemFilter: String, CaseIterable {
    case all = "All"
    case mine = "Mine"
    case agent = "Agent"
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(AppStateStore.self) private var store
    @State private var showAddSheet = false
    @State private var showAgentCompose = false
    @State private var agentSession: AgentSession?
    @State private var sessionDismissTask: Task<Void, Never>?
    @State private var reviewBatchID: UUID?
    @State private var filter: ItemFilter = .all
    @State private var showCompleted = false
    @State private var quickAddText = ""
    @State private var isQuickAdding = false
    @State private var highlightedItemID: UUID?
    @FocusState private var quickAddFocused: Bool
    @Namespace private var glassNS

    // MARK: - Derived

    private var allActive: [Item] {
        store.activeItems.sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredActive: [Item] {
        switch filter {
        case .all: allActive
        case .mine: allActive.filter { $0.source == .manual }
        case .agent: allActive.filter { $0.source == .agent }
        }
    }

    private var completedItems: [Item] {
        store.state.items
            .filter { !$0.deleted && $0.status == .done }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                List {
                    filterPicker

                    if filteredActive.isEmpty && completedItems.isEmpty {
                        emptyStateRow
                    } else {
                        activeSection
                        if !completedItems.isEmpty {
                            completedSection
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .animation(AppTheme.Animation.spring, value: filteredActive.map(\.id))
                .animation(AppTheme.Animation.spring, value: filter)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }
                .onChange(of: store.pendingSpotlightLink) { _, link in
                    handleSpotlightLink(link, scrollProxy: proxy)
                }
                .task {
                    // Drain any link delivered before this view was on screen.
                    handleSpotlightLink(store.pendingSpotlightLink, scrollProxy: proxy)
                }
            }

            bottomBar
        }
        .navigationTitle("Home")
        .sheet(isPresented: $showAddSheet) { AddItemSheet(isPresented: $showAddSheet) }
        .sheet(isPresented: $showAgentCompose) {
            AgentComposeSheet(isPresented: $showAgentCompose, agentSession: $agentSession)
        }
        .sheet(item: Binding(
            get: { reviewBatchID.map(IdentifiedBatch.init(id:)) },
            set: { reviewBatchID = $0?.id }
        )) { wrapped in
            AgentActivitySheet(batchID: wrapped.id)
        }
        .onChange(of: agentSession?.phase) { _, phase in
            sessionDismissTask?.cancel()
            guard case .completed = phase else { return }
            // Hold the banner longer when there are changes to review so the
            // user has time to tap "Review" before it disappears.
            let delay: Duration = (agentSession?.activityCount ?? 0) > 0 ? .seconds(10) : .seconds(4)
            sessionDismissTask = Task { @MainActor in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                withAnimation(AppTheme.Animation.spring) { agentSession = nil }
            }
        }
        .onDisappear { sessionDismissTask?.cancel() }
    }

    // MARK: - Filter picker

    @ViewBuilder
    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(ItemFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }

    // MARK: - Active items section

    @ViewBuilder
    private var activeSection: some View {
        if filteredActive.isEmpty {
            Text("No \(filter.rawValue.lowercased()) items")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .padding(.vertical, AppTheme.Spacing.lg)
        } else {
            ForEach(filteredActive) { item in
                ItemRow(item: item, isHighlighted: highlightedItemID == item.id)
                    .id(item.id)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
    }

    // MARK: - Completed section

    @ViewBuilder
    private var completedSection: some View {
        Section {
            if showCompleted {
                ForEach(completedItems.prefix(20)) { item in
                    ItemRow(item: item, isHighlighted: highlightedItemID == item.id)
                        .id(item.id)
                }
                if completedItems.count > 20 {
                    Text("+ \(completedItems.count - 20) more")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        } header: {
            Button {
                withAnimation(AppTheme.Animation.spring) { showCompleted.toggle() }
                Haptics.selection()
            } label: {
                HStack {
                    Label(
                        "\(completedItems.count) Completed",
                        systemImage: showCompleted ? "chevron.down" : "chevron.right"
                    )
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyStateRow: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Nothing to do")
                    .font(AppTheme.Typography.headline)
                Text("Add something or ask the agent —\nit can create tasks for you.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.xl)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            if let session = agentSession, session.phase != .idle {
                agentBanner(session: session)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isQuickAdding {
                quickAddBar
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            GlassEffectContainer(spacing: AppTheme.Spacing.md) {
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        withAnimation(AppTheme.Animation.spring) { showAgentCompose = true }
                    } label: {
                        Label("Ask Agent", systemImage: "sparkles")
                            .font(.callout.weight(.medium))
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("agent-btn", in: glassNS)

                    Button {
                        withAnimation(AppTheme.Animation.spring) {
                            isQuickAdding = true
                            quickAddFocused = true
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffectID("add-btn", in: glassNS)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.md)
            }
        }
        .animation(AppTheme.Animation.spring, value: agentSession?.phase.isActive ?? false)
        .animation(AppTheme.Animation.spring, value: isQuickAdding)
    }

    // MARK: - Quick-add bar

    @ViewBuilder
    private var quickAddBar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            TextField("What do you want to do?", text: $quickAddText)
                .focused($quickAddFocused)
                .font(AppTheme.Typography.body)
                .submitLabel(.done)
                .onSubmit { commitQuickAdd() }

            if !quickAddText.isEmpty {
                Button { commitQuickAdd() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                withAnimation(AppTheme.Animation.spring) {
                    isQuickAdding = false
                    quickAddText = ""
                    quickAddFocused = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.Spacing.sm)
        .glassSurface(cornerRadius: AppTheme.Corner.lg)
    }

    // MARK: - Agent banner

    @ViewBuilder
    private func agentBanner(session: AgentSession) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            switch session.phase {
            case .running(let turn):
                ThinkingDots()
                Text("Working · turn \(turn + 1)")
                    .font(AppTheme.Typography.caption)
            case .completed(let exhausted):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: true)
                Text(exhausted ? "Done (turn limit)" : "Done")
                    .font(AppTheme.Typography.caption)
                Spacer()
                if session.activityCount > 0 {
                    Button {
                        sessionDismissTask?.cancel()
                        reviewBatchID = session.batchID
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Review")
                            StatBadge.count(session.activityCount, color: .green)
                        }
                    }
                    .font(AppTheme.Typography.caption)
                    .buttonStyle(.glassProminent)
                    .transition(.scale.combined(with: .opacity))
                }
                Button("Dismiss") {
                    sessionDismissTask?.cancel()
                    withAnimation(AppTheme.Animation.spring) { agentSession = nil }
                }
                .font(AppTheme.Typography.caption)
                .buttonStyle(.glass)
            case .failed(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(AppTheme.Typography.caption)
                    .lineLimit(1)
                Spacer()
                Button("Dismiss") {
                    sessionDismissTask?.cancel()
                    withAnimation(AppTheme.Animation.spring) { agentSession = nil }
                }
                .font(AppTheme.Typography.caption)
                .buttonStyle(.glass)
            case .idle:
                EmptyView()
            }
        }
        .padding(AppTheme.Spacing.sm)
        .glassSurface(cornerRadius: AppTheme.Corner.lg, tint: session.phase.bannerTint)
    }

    // MARK: - Actions

    private func handleSpotlightLink(_ link: SpotlightIndexer.DeepLink?, scrollProxy: ScrollViewProxy) {
        guard let link else { return }
        let targetID: UUID
        switch link {
        case .item(let id): targetID = id
        case .note(let id):
            // Notes target their parent item if anchored, otherwise leave it
            // for whichever screen owns notes to handle.
            if let parent = store.activeNotes.first(where: { $0.id == id })?.target,
               case .item(let parentID) = parent {
                targetID = parentID
            } else {
                store.pendingSpotlightLink = nil
                return
            }
        }
        // Make sure the item is visible under the current filter.
        if !filteredActive.contains(where: { $0.id == targetID }) {
            filter = .all
            // Item may still be in the completed section — expand it so the
            // scroll-to has something to anchor on.
            if completedItems.contains(where: { $0.id == targetID }) {
                showCompleted = true
            }
        }
        // The list may not have laid out the row yet immediately after a tab
        // switch; one runloop tick is enough.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(AppTheme.Animation.spring) {
                scrollProxy.scrollTo(targetID, anchor: .center)
                highlightedItemID = targetID
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut) { highlightedItemID = nil }
        }
        store.pendingSpotlightLink = nil
    }

    private func commitQuickAdd() {
        let text = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            withAnimation(AppTheme.Animation.spring) {
                isQuickAdding = false
                quickAddFocused = false
            }
            return
        }
        store.addItem(title: text)
        Haptics.success()
        quickAddText = ""
        withAnimation(AppTheme.Animation.spring) {
            isQuickAdding = false
            quickAddFocused = false
        }
    }
}

// MARK: - Sheet item wrapper

private struct IdentifiedBatch: Identifiable, Hashable {
    let id: UUID
}
