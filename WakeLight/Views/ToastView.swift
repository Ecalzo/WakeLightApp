import SwiftUI

/// A reusable toast notification component for displaying brief feedback messages.
struct ToastView: View {
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

/// A view modifier that displays a toast overlay.
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                VStack {
                    ToastView(message: message, icon: icon)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
                .zIndex(100)
            }
        }
    }
}

extension View {
    /// Displays a toast notification overlay.
    func toast(isPresented: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill") -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon))
    }
}

#Preview {
    VStack {
        ToastView(message: "Light On", icon: "sun.max.fill")
        ToastView(message: "Brightness: 15", icon: "slider.horizontal.3")
        ToastView(message: "Alarm Saved", icon: "alarm.fill")
    }
    .padding()
}
