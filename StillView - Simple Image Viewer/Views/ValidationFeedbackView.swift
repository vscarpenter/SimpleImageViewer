import SwiftUI

/// Component for displaying validation feedback to users
struct ValidationFeedbackView: View {
    
    // MARK: - Properties
    
    let results: [ValidationResult]
    
    // MARK: - Body
    
    var body: some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    ValidationItemView(result: result)
                }
            }
            .padding(16) // Increased padding from 12 to 16
            .background(Color.appSecondaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Validation feedback")
            .accessibilityHint("Contains \(results.count) validation \(results.count == 1 ? "message" : "messages")")
        }
    }
    
    // MARK: - Computed Properties
    
    private var borderColor: Color {
        let hasErrors = results.contains { !$0.isValid }
        let hasWarnings = results.contains { $0.severity == .warning }
        
        if hasErrors {
            return .appError.opacity(0.3)
        } else if hasWarnings {
            return .appWarning.opacity(0.3)
        } else {
            return .appInfo.opacity(0.3)
        }
    }
}

/// Individual validation result item
struct ValidationItemView: View {
    
    // MARK: - Properties
    
    let result: ValidationResult
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) { // Increased spacing from 8 to 10
            // Icon
            Image(systemName: result.severity.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(result.severity.color)
                .frame(width: 16, height: 16)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                if let message = result.message {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineLimit(nil) // Remove line limit to prevent truncation
                        .fixedSize(horizontal: false, vertical: true) // Allow text to wrap naturally
                }
                
                if let suggestion = result.suggestion {
                    Text(suggestion)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(nil) // Remove line limit to prevent truncation
                        .fixedSize(horizontal: false, vertical: true) // Allow text to wrap naturally
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.severity.accessibilityPrefix): \(result.message ?? "")")
        .accessibilityHint(result.suggestion ?? "")
    }
}

/// Inline validation feedback for individual controls
struct InlineValidationView: View {
    
    // MARK: - Properties
    
    let result: ValidationResult?
    
    // MARK: - Body
    
    var body: some View {
        if let result = result, let message = result.message {
            HStack(spacing: 6) {
                Image(systemName: result.severity.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(result.severity.color)
                    .accessibilityHidden(true)
                
                Text(message)
                    .font(.system(size: 10))
                    .foregroundColor(result.severity.color)
                    .lineLimit(nil) // Remove line limit to prevent truncation
                    .fixedSize(horizontal: false, vertical: true) // Allow text to wrap naturally
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6) // Increased vertical padding from 4 to 6
            .background(result.severity.color.opacity(0.1))
            .cornerRadius(4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(result.severity.accessibilityPrefix): \(message)")
            .accessibilityHint(result.suggestion ?? "")
        }
    }
}

/// Enhanced preferences control with validation support
struct ValidatedPreferencesControl<Content: View>: View {
    
    // MARK: - Properties
    
    let label: String
    let description: String?
    let validation: ValidationResult?
    let content: Content
    
    // MARK: - Initialization
    
    init(
        _ label: String,
        description: String? = nil,
        validation: ValidationResult? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.description = description
        self.validation = validation
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PreferencesControl(label, description: description) {
                content
            }
            
            // Inline validation feedback
            InlineValidationView(result: validation)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ValidationFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ValidationFeedbackView(results: [
                .info("This is an informational message"),
                .warning("This is a warning message", suggestion: "Try this suggestion"),
                .error("This is an error message", suggestion: "Fix this issue")
            ])
            
            ValidatedPreferencesControl(
                "Sample Control",
                description: "This control has validation",
                validation: .warning("This setting may impact performance")
            ) {
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
            }
        }
        .padding()
        .frame(width: 400)
    }
}
#endif