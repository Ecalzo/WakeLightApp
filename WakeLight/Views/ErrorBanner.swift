import SwiftUI

/// An actionable error banner with title, description, and optional retry action.
struct ErrorBanner: View {
    let title: String
    let description: String
    let retryAction: (() -> Void)?

    init(title: String, description: String, retryAction: (() -> Void)? = nil) {
        self.title = title
        self.description = description
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.error)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(AppColors.errorContainer.opacity(0.3))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(title). \(description)")
    }
}

/// Helper to parse error types and provide user-friendly messages.
struct ErrorHelper {
    /// Parses an error string and returns a user-friendly title and description.
    static func parseError(_ error: String?) -> (title: String, description: String, isRetryable: Bool) {
        guard let error = error else {
            return ("Unknown Error", "An unexpected error occurred.", true)
        }

        let lowercased = error.lowercased()

        if lowercased.contains("connection") || lowercased.contains("network") || lowercased.contains("no route") {
            return (
                "Connection Failed",
                "Unable to reach your wake-up light. Check that it's powered on and connected to the same network.",
                true
            )
        }

        if lowercased.contains("timeout") || lowercased.contains("timed out") {
            return (
                "Request Timeout",
                "The device took too long to respond. It may be busy or temporarily unavailable.",
                true
            )
        }

        if lowercased.contains("not found") || lowercased.contains("404") {
            return (
                "Device Not Found",
                "Could not find a wake-up light at the specified address. Verify the IP address is correct.",
                true
            )
        }

        if lowercased.contains("permission") || lowercased.contains("denied") {
            return (
                "Permission Denied",
                "Network access was denied. Check that the app has permission to access local network.",
                false
            )
        }

        return (
            "Something Went Wrong",
            error,
            true
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        ErrorBanner(
            title: "Connection Failed",
            description: "Unable to reach your wake-up light. Check that it's powered on and connected to the same network.",
            retryAction: { print("Retry tapped") }
        )

        ErrorBanner(
            title: "Request Timeout",
            description: "The device took too long to respond."
        )
    }
    .padding()
}
