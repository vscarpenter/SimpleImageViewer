import SwiftUI

/// Reusable component for organizing preferences into sections with enhanced visual feedback
struct PreferencesSection<Content: View>: View {
    
    // MARK: - Properties
    
    let title: String
    let content: Content
    
    @State private var isHovered = false
    @State private var isExpanded = true
    @Environment(\.preferencesViewModel) private var preferencesViewModel
    
    // MARK: - Initialization
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
                    VStack(alignment: .leading, spacing: 18) { // Increased spacing from 16 to 18
                // Section title with enhanced styling
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Section: \(title)")
                    
                    Spacer()
                    
                    // Optional collapse/expand indicator for future enhancement
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.appSecondaryText)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .opacity(0) // Hidden for now, can be enabled later
                        .animation(AnimationPresets.adaptiveTransition(), value: isExpanded)
                }
                .padding(.leading, 4)
                
                // Section content with glass effect
                if isExpanded {
                    VStack(alignment: .leading, spacing: 16) { // Consistent spacing
                        content
                    }
                    .padding(20) // Balanced padding
                .background(sectionBackground)
                .overlay(sectionBorder)
                .cornerRadius(10)
                .shadowSubtle()
                .scaleEffect(isHovered ? 1.005 : 1.0)
                .animation(AnimationPresets.adaptiveHover(), value: isHovered)
                .onHover { hovering in
                    withAnimation(AnimationPresets.adaptiveHover()) {
                        isHovered = hovering
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(title) section")
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 1.05).combined(with: .opacity)
                ))
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Computed Properties
    
    private var sectionBackground: some View {
        Group {
            if preferencesViewModel?.enableGlassEffects == true {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.appGlassSecondary)
                    )
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appSecondarySurface)
            }
        }
    }
    
    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.appBorder.opacity(0.5),
                        Color.appBorder.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

/// Container for preferences tab content with consistent layout
struct PreferencesTabContainer<Content: View>: View {
    
    // MARK: - Properties
    
    let content: Content
    
    // MARK: - Initialization
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { // Consistent spacing
                content
            }
            .padding(.horizontal, 24) // Increased horizontal padding for better text layout
            .padding(.top, 24) // Balanced top padding
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .accessibilityElement(children: .contain)
        .accessibilityScrollAction { edge in
            // Announce scroll position for VoiceOver users
            switch edge {
            case .top:
                break
            case .bottom:
                break
            default:
                break
            }
        }
    }
}

/// Labeled control component for consistent preference controls with enhanced visual feedback
struct PreferencesControl<Content: View>: View {
    
    // MARK: - Properties
    
    let label: String
    let description: String?
    let content: Content
    
    @EnvironmentObject private var focusManager: PreferencesFocusManager
    @State private var controlId = UUID().uuidString
    @State private var isHovered = false
    @State private var isInteracting = false
    
    // MARK: - Initialization
    
    init(_ label: String, description: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.description = description
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(labelColor)
                        .accessibilityLabel(label)
                        .animation(AnimationPresets.adaptiveHover(), value: isHovered)
                    
                    if let description = description {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(descriptionColor)
                            .lineLimit(3) // Allow up to 3 lines
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .accessibilityLabel("Description: \(description)")
                            .animation(AnimationPresets.adaptiveHover(), value: isHovered)
                    }
                }
                .frame(maxWidth: 240, alignment: .leading) // Set max width for text area
                
                Spacer(minLength: 8)
                
                KeyboardAccessibleControl(id: controlId) {
                    content
                        .accessibilityLabel(label)
                        .accessibilityHint(description ?? "")
                        .scaleEffect(isInteracting ? 0.98 : 1.0)
                        .animation(AnimationPresets.adaptiveSpring(.snappy), value: isInteracting)
                        .onTapGesture {
                            withAnimation(AnimationPresets.adaptiveSpring(.snappy)) {
                                isInteracting = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(AnimationPresets.adaptiveSpring(.gentle)) {
                                    isInteracting = false
                                }
                            }
                        }
                }
                .frame(minWidth: 120) // Ensure minimum width for controls
            }
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .animation(AnimationPresets.adaptiveHover(), value: isHovered)
        )
        .onHover { hovering in
            withAnimation(AnimationPresets.adaptiveHover()) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(description ?? "")
        .accessibilityFocusRing(isVisible: focusManager.focusedControl == controlId)
    }
    
    // MARK: - Computed Properties
    
    private var labelColor: Color {
        isHovered ? .appText : .appText.opacity(0.9)
    }
    
    private var descriptionColor: Color {
        isHovered ? .appSecondaryText : .appTertiaryText
    }
    
    private var backgroundColor: Color {
        isHovered ? Color.appHoverBackground.opacity(0.5) : Color.clear
    }
    
    private var accessibilityLabelText: String {
        if let description = description {
            return "\(label). \(description)"
        } else {
            return label
        }
    }
}

// MARK: - Environment Keys

/// Environment key for accessing the preferences view model
struct PreferencesViewModelKey: EnvironmentKey {
    static let defaultValue: PreferencesViewModel? = nil
}

extension EnvironmentValues {
    var preferencesViewModel: PreferencesViewModel? {
        get { self[PreferencesViewModelKey.self] }
        set { self[PreferencesViewModelKey.self] = newValue }
    }
}

// MARK: - Preview

#if DEBUG
struct PreferencesSection_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesTabContainer {
            PreferencesSection("Sample Section") {
                PreferencesControl("Sample Control", description: "This is a sample control") {
                    Toggle("", isOn: .constant(true))
                        .labelsHidden()
                }
                
                // Note: ValidatedPreferencesControl is defined in ValidationFeedbackView.swift
                Text("Validated Control Example")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 600, height: 500)
        .environmentObject(PreferencesFocusManager())
    }
}
#endif
