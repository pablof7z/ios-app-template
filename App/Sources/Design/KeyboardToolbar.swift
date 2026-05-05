import SwiftUI

// MARK: - View extension

extension View {
    func dismissKeyboardToolbar() -> some View {
        modifier(DismissKeyboardToolbar())
    }
}

// MARK: - ViewModifier

struct DismissKeyboardToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}
