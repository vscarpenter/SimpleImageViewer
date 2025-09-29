//
//  HelpView.swift
//  StillView - Simple Image Viewer
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import SwiftUI

/// Help window view displaying application help and keyboard shortcuts
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: Int = 0
    @State private var searchText: String = ""
    
    private let helpContent = HelpContent.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main content
            HStack(spacing: 0) {
                // Sidebar
                sidebarView
                
                Divider()
                
                // Content area
                contentView
            }
        }
        .frame(width: 800, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text("StillView Help")
                    .font(.title)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search help...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(helpContent.sections.indices, id: \.self) { index in
                let section = helpContent.sections[index]
                
                Button(action: {
                    selectedSection = index
                    searchText = "" // Clear search when selecting section
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: section.icon)
                            .frame(width: 16)
                            .foregroundColor(selectedSection == index ? .white : .blue)
                        
                        Text(section.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedSection == index ? .white : .primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedSection == index ?
                        Color.blue.opacity(0.8) :
                        Color.clear
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Help section: \(section.title)")
            }
            
            Spacer()
            
            // Version info
            Divider()
                .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("StillView")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("Simple Image Viewer")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 200)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if searchText.isEmpty {
                    // Show selected section
                    let section = helpContent.sections[selectedSection]
                    sectionContentView(section: section)
                } else {
                    // Show search results
                    searchResultsView
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Section Content View
    private func sectionContentView(section: HelpSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(section.title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Help section: \(section.title)")
            
            // Section items
            ForEach(section.items.indices, id: \.self) { index in
                helpItemView(item: section.items[index])
            }
        }
    }
    
    // MARK: - Help Item View
    private func helpItemView(item: HelpContentItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.type.iconName)
                    .foregroundColor(colorForItemType(item.type))
                    .frame(width: 16)
                
                Text(item.title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                }
            }
            
            Text(item.description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). \(item.description)" + (item.shortcut.map { ". Shortcut: \($0)" } ?? ""))
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                
                Text("Search Results")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            let searchResults = getSearchResults()
            
            if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Try different keywords or browse the help sections")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(searchResults.indices, id: \.self) { index in
                    let result = searchResults[index]
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(result.section.title)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(3)
                            
                            Spacer()
                        }
                        
                        helpItemView(item: result.item)
                    }
                    .padding(.bottom, 8)
                    
                    if index < searchResults.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func colorForItemType(_ type: HelpItemType) -> Color {
        switch type {
        case .information:
            return .blue
        case .shortcut:
            return .purple
        case .tip:
            return .orange
        case .warning:
            return .red
        }
    }
    
    private func getSearchResults() -> [(section: HelpSection, item: HelpContentItem)] {
        guard !searchText.isEmpty else { return [] }
        
        let searchTerms = searchText.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var results: [(section: HelpSection, item: HelpContentItem)] = []
        
        for section in helpContent.sections {
            for item in section.items {
                let itemText = "\(item.title) \(item.description) \(item.shortcut ?? "")".lowercased()
                
                if searchTerms.allSatisfy({ term in itemText.contains(term) }) {
                    results.append((section: section, item: item))
                }
            }
        }
        
        return results
    }
}

// MARK: - Preview
#Preview {
    HelpView()
}
