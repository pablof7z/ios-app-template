import SwiftUI

// MARK: - FeedbackCategory

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug = "Bug"
    case featureRequest = "Feature Request"
    case question = "Question"
    case praise = "Praise"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bug: "ant.fill"
        case .featureRequest: "lightbulb.fill"
        case .question: "questionmark.circle.fill"
        case .praise: "heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .bug: .red
        case .featureRequest: .blue
        case .question: .purple
        case .praise: .pink
        }
    }
}

// MARK: - FeedbackView

struct FeedbackView: View {
    @Bindable var workflow: FeedbackWorkflow
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: FeedbackCategory = .bug
    @State private var isSubmitting = false
    @State private var submitSuccess = false
    @State private var errorMessage: String?
    @State private var charCount = 0

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
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else if submitSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce, value: submitSuccess)
                    } else {
                        Button("Send") { submit() }
                            .disabled(workflow.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                        selectedCategory = cat
                        Haptics.selection()
                    } label: {
                        Label(cat.rawValue, systemImage: cat.icon)
                            .font(AppTheme.Typography.caption)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .glassEffect(
                        selectedCategory == cat
                            ? .regular.tint(cat.tint).interactive()
                            : .regular.interactive(),
                        in: .capsule
                    )
                    .animation(AppTheme.Animation.springFast, value: selectedCategory)
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
                    .frame(minHeight: 130)
                    .scrollContentBackground(.hidden)
                    .padding(AppTheme.Spacing.sm)
                    .onChange(of: workflow.draft) { _, new in
                        charCount = new.count
                    }

                Text("\(charCount)")
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

    private func submit() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await performSubmission()
                Haptics.success()
                withAnimation(AppTheme.Animation.spring) { submitSuccess = true }
                try? await Task.sleep(for: .milliseconds(800))
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
        // TODO: Replace with real submission — email, Nostr kind:1, GitHub issue, webhook.
        // See docs/features.md → Feedback for implementation options.
        try await Task.sleep(for: .milliseconds(600))
    }
}
