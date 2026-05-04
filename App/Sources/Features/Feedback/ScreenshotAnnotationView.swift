import SwiftUI

// MARK: - Stroke model

private struct Stroke: Equatable {
    var points: [CGPoint]
    var color: Color
    var width: CGFloat
}

// MARK: - ScreenshotAnnotationView

struct ScreenshotAnnotationView: View {
    @Bindable var workflow: FeedbackWorkflow
    @Environment(\.dismiss) private var dismiss

    @State private var strokes: [Stroke] = []
    @State private var currentStroke: Stroke?
    @State private var strokeColor: Color = .red
    @State private var strokeWidth: CGFloat = 3.0

    private let palette: [Color] = [.red, .orange, .blue, .yellow, .white]

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let screenshot = workflow.screenshot {
                        Image(uiImage: screenshot)
                            .resizable()
                            .scaledToFit()
                    }

                    Canvas { context, _ in
                        for stroke in strokes {
                            drawStroke(stroke, in: &context)
                        }
                        if let current = currentStroke {
                            drawStroke(current, in: &context)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if currentStroke == nil {
                                    currentStroke = Stroke(
                                        points: [value.location],
                                        color: strokeColor,
                                        width: strokeWidth
                                    )
                                } else {
                                    currentStroke?.points.append(value.location)
                                }
                            }
                            .onEnded { _ in
                                if let stroke = currentStroke, stroke.points.count > 1 {
                                    strokes.append(stroke)
                                    Haptics.light()
                                }
                                currentStroke = nil
                            }
                    )
                }
            }
            .navigationTitle("Annotate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        workflow.phase = .composing
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveAnnotation() }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                drawingToolbar
            }
        }
    }

    // MARK: - Drawing toolbar

    @ViewBuilder
    private var drawingToolbar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                // Color palette
                ForEach(palette, id: \.self) { color in
                    Button {
                        strokeColor = color
                        Haptics.selection()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 26, height: 26)
                            if strokeColor == color {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                                    .frame(width: 26, height: 26)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(strokeColor == color ? 1.18 : 1.0)
                    .animation(AppTheme.Animation.springFast, value: strokeColor == color)
                }

                Rectangle()
                    .fill(.separator)
                    .frame(width: 1, height: 24)

                // Width slider
                HStack(spacing: 6) {
                    Image(systemName: "pencil.tip")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $strokeWidth, in: 1.5...8.0)
                        .frame(width: 72)
                        .tint(strokeColor)
                }

                Rectangle()
                    .fill(.separator)
                    .frame(width: 1, height: 24)

                // Undo
                Button {
                    guard !strokes.isEmpty else { return }
                    strokes.removeLast()
                    Haptics.selection()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.callout)
                }
                .buttonStyle(.glass)
                .disabled(strokes.isEmpty)

                // Clear
                Button {
                    strokes = []
                    currentStroke = nil
                    Haptics.medium()
                } label: {
                    Image(systemName: "trash")
                        .font(.callout)
                }
                .buttonStyle(.glass)
                .disabled(strokes.isEmpty && currentStroke == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Drawing

    private func drawStroke(_ stroke: Stroke, in context: inout GraphicsContext) {
        guard stroke.points.count > 1 else { return }
        var path = Path()
        path.move(to: stroke.points[0])
        for point in stroke.points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(
            path,
            with: .color(stroke.color),
            style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Save

    private func saveAnnotation() {
        guard let screenshot = workflow.screenshot else {
            workflow.phase = .composing
            dismiss()
            return
        }

        let renderer = UIGraphicsImageRenderer(size: screenshot.size)
        let annotated = renderer.image { ctx in
            screenshot.draw(at: .zero)
            let scale = screenshot.size.width / UIScreen.main.bounds.width
            ctx.cgContext.scaleBy(x: scale, y: scale)

            for stroke in strokes {
                guard stroke.points.count > 1 else { continue }
                let uiColor = UIColor(stroke.color)
                ctx.cgContext.setStrokeColor(uiColor.cgColor)
                ctx.cgContext.setLineWidth(stroke.width)
                ctx.cgContext.setLineCap(.round)
                ctx.cgContext.setLineJoin(.round)
                ctx.cgContext.move(to: stroke.points[0])
                for point in stroke.points.dropFirst() {
                    ctx.cgContext.addLine(to: point)
                }
                ctx.cgContext.strokePath()
            }
        }

        workflow.annotatedImage = annotated
        workflow.phase = .composing
        dismiss()
    }
}
