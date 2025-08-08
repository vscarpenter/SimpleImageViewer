//
//  WhatsNewSheet.swift
//  StillView - Simple Image Viewer
//
//  Created by Kiro on 8/7/25.
//

import SwiftUI

struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var accessibilityService = AccessibilityService.shared
    @State private var content: WhatsNewContent
    @FocusState private var isDoneButtonFocused: Bool
    
    init(content: WhatsNewContent) {
        self._content = State(initialValue: content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header with close button
            HStack {
                Text("What's New")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primary)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .focused($isDoneButtonFocused)
                .accessibilityLabel("Close What's New")
                .accessibilityHint("Closes the What's New dialog")
                .accessibilityIdentifier("whatsNewDoneButton")
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Divider(),
                alignment: .bottom
            )
            
            // Content area
            WhatsNewContentView(content: content)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 480, height: 600)
        .background(adaptiveBackgroundColor)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("What's New in version \(content.version)")
        .accessibilityHint("Shows new features and improvements in this version")
        .onAppear {
            // Set initial focus for accessibility
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isDoneButtonFocused = true
            }
        }
    }
    
    /// Adaptive background color that works well in both light and dark modes
    private var adaptiveBackgroundColor: Color {
        Color.adaptive(
            light: Color(NSColor.windowBackgroundColor),
            dark: Color(NSColor.windowBackgroundColor)
        )
    }
}

#Preview {
    WhatsNewSheet(content: WhatsNewContent.sampleContent)
}