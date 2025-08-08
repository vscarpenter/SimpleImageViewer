//
//  WhatsNewContentView.swift
//  StillView - Simple Image Viewer
//
//  Created by Kiro on 8/7/25.
//

import SwiftUI

struct WhatsNewContentView: View {
    let content: WhatsNewContent
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                // Header section with version and date (compact version)
                compactHeaderSection
                
                // Content sections
                contentSections
            }
            .padding(.bottom, AppSpacing.xl) // Extra bottom padding for better scrolling
        }
        .background(adaptiveBackgroundColor)
        .accessibilityLabel("What's New in version \(content.version)")
        .accessibilityHint("Scroll to view all new features and improvements")
        .accessibilityIdentifier("whatsNewContent")
        .scrollContentBackground(.hidden) // Hide default scroll view background
    }
    
    /// Header section with version and release date
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Version \(content.version)")
                .font(.appTitle2)
                .fontWeight(.semibold)
                .foregroundColor(adaptiveTextColor)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Version \(content.version)")
            
            if let releaseDate = content.releaseDate {
                Text(releaseDate, style: .date)
                    .font(.appSubheadline)
                    .foregroundColor(adaptiveSecondaryTextColor)
                    .accessibilityLabel("Released on \(releaseDate, style: .date)")
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.xl)
        .accessibilityElement(children: .combine)
    }
    
    /// Compact header section for use within the sheet (no title overlap)
    private var compactHeaderSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Version \(content.version)")
                    .font(.appHeadline)
                    .fontWeight(.medium)
                    .foregroundColor(adaptiveTextColor)
                
                Spacer()
                
                if let releaseDate = content.releaseDate {
                    Text(releaseDate, style: .date)
                        .font(.appCaption)
                        .foregroundColor(adaptiveSecondaryTextColor)
                        .accessibilityLabel("Released on \(releaseDate, style: .date)")
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Version \(content.version)")
    }
    
    /// Content sections with proper spacing and accessibility
    private var contentSections: some View {
        LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
            ForEach(Array(content.sections.enumerated()), id: \.element.title) { index, section in
                WhatsNewSectionView(section: section)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(section.title) section, \(index + 1) of \(content.sections.count)")
                
                // Add separator between sections (except for the last one)
                if index < content.sections.count - 1 {
                    Divider()
                        .foregroundColor(adaptiveBorderColor)
                        .padding(.horizontal, AppSpacing.xl)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }
    
    /// Adaptive background color that works well in both light and dark modes
    private var adaptiveBackgroundColor: Color {
        accessibilityService.adaptiveColor(
            normal: Color.appBackground,
            highContrast: colorScheme == .dark ? Color.black : Color.white
        )
    }
    
    /// Adaptive text color with proper contrast
    private var adaptiveTextColor: Color {
        accessibilityService.adaptiveColor(
            normal: Color.appText,
            highContrast: colorScheme == .dark ? Color.white : Color.black
        )
    }
    
    /// Adaptive secondary text color with proper contrast
    private var adaptiveSecondaryTextColor: Color {
        accessibilityService.adaptiveColor(
            normal: Color.appSecondaryText,
            highContrast: colorScheme == .dark ? Color(white: 0.8) : Color(white: 0.3)
        )
    }
    
    /// Adaptive border color for separators
    private var adaptiveBorderColor: Color {
        accessibilityService.adaptiveColor(
            normal: Color.appBorder,
            highContrast: colorScheme == .dark ? Color(white: 0.3) : Color(white: 0.7)
        )
    }
}

#Preview {
    WhatsNewContentView(content: WhatsNewContent.sampleContent)
        .frame(width: 480, height: 600)
}