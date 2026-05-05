import SwiftUI

// MARK: - FeedbackView

struct FeedbackView: View {
    @Bindable var workflow: FeedbackWorkflow
    @Environment(\.dismiss) private var dismiss

    @State private var store = FeedbackStore()
    @State private var composerPresented = false
    @State private var showMine = true
    @State private var identityPlaceholderPresented = false

    private var visibleThreads: [FeedbackThread] {
        // Both segments return all threads until identity / multi-user is wired up.
        store.threads
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Feedback")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        GlassEffectContainer(spacing: AppTheme.Spacing.sm) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Button {
                                    identityPlaceholderPresented = true
                                } label: {
                                    Image(systemName: "person.crop.circle")
                                }
                                .buttonStyle(.glass)
                                .buttonBorderShape(.circle)

                                Button {
                                    composerPresented = true
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .buttonStyle(.glassProminent)
                                .buttonBorderShape(.circle)
                            }
                        }
                    }
                }
        }
        .task { await store.load() }
        .sheet(isPresented: $composerPresented) {
            FeedbackComposeView(store: store, workflow: workflow)
        }
        .sheet(isPresented: $identityPlaceholderPresented) {
            identityPlaceholderSheet
        }
        .onAppear {
            if workflow.screenshot != nil || workflow.annotatedImage != nil {
                composerPresented = true
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.threads.isEmpty {
            loadingSkeleton
        } else if store.threads.isEmpty {
            emptyState
        } else {
            threadList
        }
    }

    // MARK: - Thread list

    @ViewBuilder
    private var threadList: some View {
        List {
            mineEveryoneSegmentedControl
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)

            ForEach(visibleThreads) { thread in
                NavigationLink {
                    FeedbackThreadDetailView(thread: thread, store: store)
                } label: {
                    FeedbackThreadRow(thread: thread)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await store.load() }
    }

    // MARK: - Segmented control

    @ViewBuilder
    private var mineEveryoneSegmentedControl: some View {
        Picker("Show", selection: $showMine) {
            Text("Mine").tag(true)
            Text("Everyone").tag(false)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Loading skeleton

    @ViewBuilder
    private var loadingSkeleton: some View {
        List {
            ForEach(0..<3, id: \.self) { _ in
                FeedbackThreadRow(thread: FeedbackThread.placeholder)
                    .redacted(reason: .placeholder)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No feedback yet", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Tap the pencil to share your thoughts.")
        }
    }

    // MARK: - Identity placeholder sheet

    @ViewBuilder
    private var identityPlaceholderSheet: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                Image(systemName: "person.crop.circle.badge.clock")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Identity Coming Soon")
                    .font(AppTheme.Typography.title)
                Text("Signed identity support will be added in a future update.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppTheme.Spacing.xl)
            .navigationTitle("Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { identityPlaceholderPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Placeholder helpers

private extension FeedbackThread {
    static var placeholder: FeedbackThread {
        FeedbackThread(
            category: .bug,
            content: "This is a placeholder feedback item for skeleton loading state.",
            title: "Placeholder thread title here",
            summary: "Short summary of the thread for preview purposes."
        )
    }
}
