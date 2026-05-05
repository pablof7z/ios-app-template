import SwiftUI

// MARK: - FeedbackComposeView

struct FeedbackComposeView: View {
    let store: FeedbackStore
    @Bindable var workflow: FeedbackWorkflow
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStateStore.self) private var appStore

    @State private var isSending = false
    @State private var errorMessage: String?

    private var canSend: Bool {
        !workflow.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    identityRow
                    textEditorSection
                    screenshotSection

                    if let error = errorMessage {
                        Text(error)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.red)
                            .transition(.opacity)
                    }

                    Spacer()
                }
                .padding(AppTheme.Spacing.md)
            }
            .navigationTitle("New Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    screenshotToolbarButton
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Send") {
                            Task { await send() }
                        }
                        .fontWeight(.semibold)
                        .disabled(!canSend)
                    }
                }
            }
        }
    }

    // MARK: - Identity row

    @ViewBuilder
    private var identityRow: some View {
        let settings = appStore.state.settings
        let name = settings.nostrProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let pubkey = settings.nostrPublicKeyHex

        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: name.isEmpty ? "person.crop.circle" : "person.crop.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(name.isEmpty ? Color(.tertiaryLabel) : Color(.label))

            if name.isEmpty && pubkey == nil {
                Text("Anonymous")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    if !name.isEmpty {
                        Text(name)
                            .font(AppTheme.Typography.caption.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    if let hex = pubkey {
                        Text(String(hex.prefix(8)) + "…")
                            .font(AppTheme.Typography.mono)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text("Posting as")
                .font(AppTheme.Typography.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.Spacing.sm)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppTheme.Corner.sm, style: .continuous))
    }

    // MARK: - Toolbar screenshot button

    @ViewBuilder
    private var screenshotToolbarButton: some View {
        let hasImage = workflow.annotatedImage != nil || workflow.screenshot != nil
        Button {
            if hasImage {
                workflow.phase = .annotating
                dismiss()
            } else {
                workflow.phase = .awaitingScreenshot
                dismiss()
            }
        } label: {
            Image(systemName: hasImage ? "camera.viewfinder" : "camera")
                .symbolVariant(hasImage ? .fill : .none)
                .foregroundStyle(hasImage ? .blue : .secondary)
        }
        .accessibilityLabel(hasImage ? "Re-annotate screenshot" : "Attach screenshot")
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

            TextEditor(text: $workflow.draft)
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
                .padding(AppTheme.Spacing.sm)
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppTheme.Corner.md, style: .continuous))
    }

    // MARK: - Screenshot preview

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
                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                    )

                HStack {
                    Button("Re-annotate") {
                        workflow.phase = .annotating
                        dismiss()
                    }
                    .foregroundStyle(.blue)

                    Spacer()

                    Button("Remove") {
                        workflow.screenshot = nil
                        workflow.annotatedImage = nil
                    }
                    .foregroundStyle(.red)
                }
                .font(AppTheme.Typography.caption)
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
