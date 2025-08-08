//
//  WhatsNewSectionView.swift
//  StillView - Simple Image Viewer
//
//  Created by Kiro on 8/7/25.
//

import SwiftUI

struct WhatsNewSectionView: View {
    let section: WhatsNewSection
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Section header
            sectionHeader
            
            // Section items
            sectionItems
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(section.title) section with \(section.items.count) items")
    }
    
    /// Section header with icon and title
    private var sectionHeader: some View {
        HStack(spacing: AppSpacing.md) {
            sectionIcon
                .foregroundColor(adaptiveSectionColor)
                .font(.appTitle3)
                .accessibilityHidden(true) // Icon is decorative
            
            Text(section.title)
                .font(.appHeadline)
                .fontWeight(.semibold)
                .foregroundColor(adaptiveTextColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("\(section.title) section")
        .accessibilityHint("Contains \(section.items.count) \(section.items.count == 1 ? "item" : "items")")
    }
    
    /// Section items with proper spacing and accessibility
    private var sectionItems: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(Array(section.items.enumerated()), id: \.element.title) { index, item in
                WhatsNewItemView(item: item, itemIndex: index + 1, totalItems: section.items.count)
            }
        }
    }
    
    @ViewBuilder
    private var sectionIcon: some View {
        switch section.type {
        case .newFeatures:
            Image(systemName: "sparkles")
        case .improvements:
            Image(systemName: "arrow.up.circle")
        case .bugFixes:
            Image(systemName: "wrench.and.screwdriver")
        }
    }
    
    /// Adaptive section color that works in both light and dark modes
    private var adaptiveSectionColor: Color {
        let baseColor: Color
        switch section.type {
        case .newFeatures:
            baseColor = .blue
        case .improvements:
            baseColor = .green
        case .bugFixes:
            baseColor = .orange
        }
        
        return accessibilityService.adaptiveColor(
            normal: baseColor,
            highContrast: baseColor.highContrast
        )
    }
    
    /// Adaptive text color with proper contrast
    private var adaptiveTextColor: Color {
        accessibilityService.adaptiveColor(
            normal: Color.appText,
            highContrast: colorScheme == .dark ? Color.white : Color.black
        )
    }
}

struct WhatsNewItemView: View {
    let item: WhatsNewItem
    let itemIndex: Int
    let totalItems: Int
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Bullet point with better accessibility
            bulletPoint
            
            // Item content
            itemContent
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Item \(itemIndex) of \(totalItems)")
        .accessibilityIdentifier("whatsNewItem_\(itemIndex)")
    }
    
    /// Bullet point with adaptive styling
    private var bulletPoint: some View {
        Circle()
            .fill(adaptiveBulletColor)
            .frame(width: bulletSize, height: bulletSize)
            .padding(.top, AppSpacing.md)
            .accessibilityHidden(true) // Bullet is decorative
    }
    
    /// Item content with title and description
    private var itemContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(item.title)
                .font(item.isHighlighted ? .appHeadline : .appBody)
                .fontWeight(item.isHighlighted ? .medium : .regular)
                .foregroundColor(adaptiveTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(item.isHighlighted ? .isStaticText : [])
            
            if let description = item.description {
                Text(description)
                    .font(.appCallout)
                    .foregroundColor(adaptiveSecondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil) // Allow unlimited lines for long descriptions
            }
        }
    }
    
    /// Adaptive bullet color
    private var adaptiveBulletColor: Color {
        accessibilityService.adaptiveColor(
            normal: Color.appSecondaryText,
            highContrast: colorScheme == .dark ? Color.white : Color.black
        )
    }
    
    /// Adaptive text color with proper contrast
    private var adaptiveTextColor: Color {
        accessibilityService.adaptiveColor(
            normal: Color.appText,
            highContrast: colorScheme == .dark ? Color.white : Color.black
        )
    }
    
    /// Adaptive secondary text color
    private var adaptiveSecondaryTextColor: Color {
        accessibilityService.adaptiveColor(
            normal: Color.appSecondaryText,
            highContrast: colorScheme == .dark ? Color(white: 0.8) : Color(white: 0.3)
        )
    }
    
    /// Bullet size that adapts to accessibility settings
    private var bulletSize: CGFloat {
        accessibilityService.isHighContrastEnabled ? 6 : 4
    }
    
    /// Accessibility description for the item
    private var accessibilityDescription: String {
        var description = item.title
        
        if item.isHighlighted {
            description = "Highlighted: " + description
        }
        
        if let itemDescription = item.description {
            description += ". " + itemDescription
        }
        
        return description
    }
}

#Preview {
    VStack(spacing: 20) {
        WhatsNewSectionView(section: WhatsNewSection.sampleNewFeatures)
        WhatsNewSectionView(section: WhatsNewSection.sampleImprovements)
        WhatsNewSectionView(section: WhatsNewSection.sampleBugFixes)
    }
    .padding()
}