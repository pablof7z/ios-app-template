import SwiftUI

struct FeedbackView: View {
    @Bindable var workflow: FeedbackWorkflow
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Text input on a Liquid Glass surface
                    ZStack(alignment: .topLeading) {
                        if workflow.draft.isEmpty {
                            Text("What's on your mind?")
                                .foregroundStyle(.tertiary)
                                .padding(AppTheme.Spacing.md)
                        }
                        TextEditor(text: $workflow.draft)
                            .frame(minHeight: 140)
                            .scrollContentBackground(.hidden)
                            .padding(AppTheme.Spacing.sm)
                    }
                    .glassSurface(cornerRadius: AppTheme.Corner.md)

                    screenshotSection

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Send") { submit() }
                            .disabled(workflow.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cancel() {
        workflow.phase = .idle
        workflow.draft = ""
        workflow.screenshot = nil
        workflow.annotatedImage = nil
        dismiss()
    }

    private func submit() {
        // TODO: Implement your feedback submission here.
        // Options: email via MFMailComposeViewController, Nostr kind:1 event,
        // GitHub issue via API, custom webhook, etc.
        // See docs/features.md → Feedback for implementation options.
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await performSubmission()
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
            isSubmitting = false
        }
    }

    private func performSubmission() async throws {
        // Placeholder — replace with real submission logic
        try await Task.sleep(for: .milliseconds(500))
    }
}
