import SwiftUI

/// A view that displays temporary notifications to the user
struct NotificationView: View {
    let message: String
    let type: NotificationType
    @Binding var isVisible: Bool
    
    enum NotificationType {
        case info
        case warning
        case error
        case success
        
        var color: Color {
            switch self {
            case .info:
                return .blue
            case .warning:
                return .orange
            case .error:
                return .red
            case .success:
                return .green
            }
        }
        
        var icon: String {
            switch self {
            case .info:
                return "info.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.circle.fill"
            case .success:
                return "checkmark.circle.fill"
            }
        }
        
        var accessibilityPrefix: String {
            switch self {
            case .info:
                return "Information"
            case .warning:
                return "Warning"
            case .error:
                return "Error"
            case .success:
                return "Success"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .accessibilityLabel(accessibilityLabel)
            
            Text(message)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            // Auto-dismiss after 4 seconds for non-error notifications
            if type != .error {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                    }
                }
            }
        }
    }
    
    private var accessibilityLabel: String {
        switch type {
        case .info:
            return "Information"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .success:
            return "Success"
        }
    }
}

/// A container view that manages multiple notifications
struct NotificationContainer: View {
    @StateObject private var notificationManager = NotificationManager()
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.notifications) { notification in
                NotificationView(
                    message: notification.message,
                    type: notification.type,
                    isVisible: .constant(true)
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .environmentObject(notificationManager)
    }
}

/// A notification item for the notification manager
struct NotificationItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: NotificationView.NotificationType
    let duration: TimeInterval
    let timestamp: Date = Date()
    
    init(message: String, type: NotificationView.NotificationType, duration: TimeInterval = 4.0) {
        self.message = message
        self.type = type
        self.duration = duration
    }
    
    static func == (lhs: NotificationItem, rhs: NotificationItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages the display of notifications
class NotificationManager: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    
    func show(_ message: String, type: NotificationView.NotificationType, duration: TimeInterval = 4.0) {
        let notification = NotificationItem(message: message, type: type, duration: duration)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications.append(notification)
        }
        
        // Auto-remove after duration (except for errors)
        if type != .error {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.remove(notification)
            }
        }
    }
    
    func remove(_ notification: NotificationItem) {
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications.removeAll { $0.id == notification.id }
        }
    }
    
    func removeAll() {
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications.removeAll()
        }
    }
    
    // Convenience methods
    func showInfo(_ message: String) {
        show(message, type: .info)
    }
    
    func showWarning(_ message: String) {
        show(message, type: .warning)
    }
    
    func showError(_ message: String) {
        show(message, type: .error, duration: 0) // Errors don't auto-dismiss
    }
    
    func showSuccess(_ message: String) {
        show(message, type: .success)
    }
}

#Preview {
    VStack {
        NotificationView(
            message: "Image skipped due to corruption",
            type: .warning,
            isVisible: .constant(true)
        )
        
        NotificationView(
            message: "Successfully loaded 25 images",
            type: .success,
            isVisible: .constant(true)
        )
        
        NotificationView(
            message: "Failed to access folder",
            type: .error,
            isVisible: .constant(true)
        )
    }
    .padding()
    .frame(width: 400)
}