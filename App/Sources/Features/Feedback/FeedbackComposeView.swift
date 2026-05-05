import SwiftUI

// MARK: - FeedbackComposeView

struct FeedbackComposeView: View {
    let store: FeedbackStore
    @Bindable var workflow: FeedbackWorkflow
    @Environment(\.dismiss) private var dismiss

    @State private var isSending = false
    @State private var errorMessage: String?

    private var canSend: Bool {
        !workflow.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    categoryPicker
                    textEditorSection
                    screenshotSection

                    if let error = errorMessage {
                        Text(error)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.red)
                            .transition(.opacity)
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .navigationTitle("New feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Send") {
                            Task { await send() }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSend)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Category picker

    @ViewBuilder
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(FeedbackCategory.allCases) { cat in
                    Button {
                        workflow.selectedCategory = cat
                        Haptics.selection()
                    } label: {
                        Label(cat.rawValue, systemImage: cat.icon)
                            .font(AppTheme.Typography.caption)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .glassEffect(
                        workflow.selectedCategory == cat
                            ? .regular.tint(cat.tint).interactive()
                            : .regular.interactive(),
                        in: .capsule
                    )
                    .animation(AppTheme.Animation.springFast, value: workflow.selectedCategory)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 2)
        }
        .padding(.horizontal, -AppTheme.Spacing.md)
    }

    // MARK: - Text editor

    @ViewBuilder
    private var textEditorSection: some View {
        ZStack(alignment: .topLeading) {
            if workflow.draft.isEmpty {
                Text("What's on your mind?")
                    .foregroundStyle(.tertiary)
                    .padding(AppTheme.Spacing.md)
            }

            VStack(alignment: .trailing, spacing: 0) {
                TextEditor(text: $workflow.draft)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .padding(AppTheme.Spacing.sm)

                Text("\(workflow.draft.count)")
                    .font(AppTheme.Typography.mono)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, AppTheme.Spacing.sm)
                    .padding(.bottom, AppTheme.Spacing.xs)
            }
        }
        .glassSurface(cornerRadius: AppTheme.Corner.md)
    }

    // MARK: - Screenshot section

    @ViewBuilder
    private var screenshotSection: some View {
        let displayImage = workflow.annotatedImage ?? workflow.screenshot

        if let image = displayImage {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Corner.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Corner.md)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    )
                    .appShadow(AppTheme.Shadow.subtle)

                GlassEffectContainer(spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Button("Re-annotate") {
                            workflow.phase = .annotating
                            dismiss()
                        }
                        .buttonStyle(.glass)

                        Spacer()

                        Button("Remove") {
                            workflow.screenshot = nil
                            workflow.annotatedImage = nil
                        }
                        .tint(.red)
                        .buttonStyle(.glass)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Button {
                    workflow.phase = .awaitingScreenshot
                    dismiss()
                } label: {
                    Label("Attach Screenshot", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.xs)
                }
                .buttonStyle(.glass)

                Text("Dismiss this sheet, then shake to capture the screen.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func cancel() {
        workflow.phase = .idle
        workflow.draft = ""
        workflow.screenshot = nil
        workflow.annotatedImage = nil
        dismiss()
    }

    private func send() async {
        Haptics.light()
        isSending = true
        errorMessage = nil

        do {
            let image = workflow.annotatedImage ?? workflow.screenshot
            try await store.publishThread(
                category: workflow.selectedCategory,
                content: workflow.draft.trimmingCharacters(in: .whitespacesAndNewlines),
                image: image
            )
            Haptics.success()
            workflow.phase = .idle
            workflow.draft = ""
            workflow.screenshot = nil
            workflow.annotatedImage = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }

        isSending = false
    }
}
