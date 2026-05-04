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
    @State private var filter: ItemFilter = .all
    @State private var showCompleted = false
    @State private var quickAddText = ""
    @State private var isQuickAdding = false
    @FocusState private var quickAddFocused: Bool
    @Namespace private var glassNS
    @Namespace private var listNS

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

            bottomBar
        }
        .navigationTitle("Home")
        .sheet(isPresented: $showAddSheet) { AddItemSheet(isPresented: $showAddSheet) }
        .sheet(isPresented: $showAgentCompose) {
            AgentComposeSheet(isPresented: $showAgentCompose, agentSession: $agentSession)
        }
        .onChange(of: agentSession?.phase) { _, phase in
            if case .completed = phase {
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(AppTheme.Animation.spring) { agentSession = nil }
                }
            }
        }
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
                ItemRow(item: item)
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
                    ItemRow(item: item)
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
                Button("Dismiss") {
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

// MARK: - ThinkingDots

private struct ThinkingDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.primary)
                    .frame(width: 5, height: 5)
                    .opacity(active == i ? 1 : 0.25)
                    .scaleEffect(active == i ? 1.2 : 1.0)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: false)
            ) {}
            startCycle()
        }
    }

    private func startCycle() {
        Task { @MainActor in
            while true {
                for i in 0..<3 {
                    withAnimation(AppTheme.Animation.springFast) { active = i }
                    try? await Task.sleep(for: .milliseconds(380))
                }
            }
        }
    }
}

// MARK: - ItemRow

struct ItemRow: View {
    @Environment(AppStateStore.self) private var store
    let item: Item
    @State private var showNoteInput = false
    @State private var noteText = ""

    private var noteCount: Int {
        store.activeNotes.filter { $0.target == .item(id: item.id) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    Haptics.selection()
                    withAnimation(AppTheme.Animation.spring) {
                        store.setItemStatus(item.id, status: item.status == .pending ? .done : .pending)
                    }
                } label: {
                    Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.status == .done ? .green : .secondary)
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .strikethrough(item.status == .done)
                        .foregroundStyle(item.status == .done ? .secondary : .primary)
                        .animation(AppTheme.Animation.spring, value: item.status)

                    if let name = item.requestedByDisplayName {
                        Label(name, systemImage: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: AppTheme.Spacing.xs) {
                    if noteCount > 0 {
                        StatBadge.count(noteCount, color: .purple)
                    }
                    if item.source == .agent {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(item.status == .done ? 0.55 : 1.0)
            .animation(AppTheme.Animation.spring, value: item.status)
            .padding(.vertical, AppTheme.Spacing.xs)

            if showNoteInput {
                HStack(spacing: AppTheme.Spacing.sm) {
                    TextField("Add a note…", text: $noteText)
                        .font(AppTheme.Typography.caption)
                        .submitLabel(.done)
                        .onSubmit { commitNote() }

                    Button { commitNote() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .disabled(noteText.isEmpty)
                }
                .padding(.vertical, AppTheme.Spacing.xs)
                .padding(.horizontal, AppTheme.Spacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { store.deleteItem(item.id) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                store.setItemStatus(item.id, status: item.status == .done ? .pending : .done)
                Haptics.selection()
            } label: {
                Label(
                    item.status == .done ? "Reopen" : "Done",
                    systemImage: item.status == .done ? "arrow.uturn.left" : "checkmark"
                )
            }
            .tint(.green)
        }
        .contextMenu {
            Button("Add Note", systemImage: "note.text.badge.plus") {
                withAnimation(AppTheme.Animation.spring) { showNoteInput = true }
            }
            Button("Mark \(item.status == .done ? "Pending" : "Done")", systemImage: item.status == .done ? "arrow.uturn.left" : "checkmark.circle") {
                store.setItemStatus(item.id, status: item.status == .done ? .pending : .done)
                Haptics.selection()
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                store.deleteItem(item.id)
            }
        }
    }

    private func commitNote() {
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            withAnimation(AppTheme.Animation.spring) { showNoteInput = false }
            return
        }
        store.addNote(text: text, target: .item(id: item.id))
        Haptics.success()
        noteText = ""
        withAnimation(AppTheme.Animation.spring) { showNoteInput = false }
    }
}

// MARK: - AddItemSheet

private struct AddItemSheet: View {
    @Environment(AppStateStore.self) private var store
    @Binding var isPresented: Bool
    @State private var title = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What do you want to do?", text: $title, axis: .vertical)
                        .focused($focused)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func add() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        store.addItem(title: t)
        Haptics.success()
        isPresented = false
    }
}

// MARK: - AgentComposeSheet

private struct AgentComposeSheet: View {
    @Environment(AppStateStore.self) private var store
    @Binding var isPresented: Bool
    @Binding var agentSession: AgentSession?
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tell the agent what to do…", text: $input, axis: .vertical)
                        .focused($focused)
                        .lineLimit(3...8)
                }
                Section {
                    Text("The agent can create items, take notes, and remember things about you.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run") { runAgent() }
                        .fontWeight(.semibold)
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func runAgent() {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let session = AgentSession(store: store, maxTurns: store.state.settings.agentMaxTurns)
        agentSession = session
        isPresented = false
        Task { await session.run(transcript: t) }
    }
}

// MARK: - Phase helpers

private extension AgentSession.Phase {
    var isActive: Bool {
        if case .idle = self { return false }
        return true
    }

    var bannerTint: Color {
        switch self {
        case .running: .blue
        case .completed: .green
        case .failed: .orange
        case .idle: .clear
        }
    }
}

