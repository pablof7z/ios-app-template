import SwiftUI

/// Full-screen canvas for annotating a screenshot with red freehand strokes.
/// Opened automatically when a screenshot is captured after a shake.
struct ScreenshotAnnotationView: View {
    @Bindable var workflow: FeedbackWorkflow
    @Environment(\.dismiss) private var dismiss

    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

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
                        for stroke in strokes { drawStroke(stroke, in: &context) }
                        drawStroke(currentStroke, in: &context)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in currentStroke.append(value.location) }
                            .onEnded { _ in
                                guard !currentStroke.isEmpty else { return }
                                strokes.append(currentStroke)
                                currentStroke = []
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        strokes = []
                        currentStroke = []
                    }
                    .disabled(strokes.isEmpty && currentStroke.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveAnnotation() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func drawStroke(_ points: [CGPoint], in context: inout GraphicsContext) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        context.stroke(
            path,
            with: .color(.red),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

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
            ctx.cgContext.setStrokeColor(UIColor.red.cgColor)
            ctx.cgContext.setLineWidth(3)
            ctx.cgContext.setLineCap(.round)
            for stroke in strokes {
                guard !stroke.isEmpty else { continue }
                ctx.cgContext.move(to: stroke[0])
                for point in stroke.dropFirst() { ctx.cgContext.addLine(to: point) }
                ctx.cgContext.strokePath()
            }
        }

        workflow.annotatedImage = annotated
        workflow.phase = .composing
        dismiss()
    }
}
