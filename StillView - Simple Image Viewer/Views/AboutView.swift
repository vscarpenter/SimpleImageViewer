//
//  AboutView.swift
//  StillView - Simple Image Viewer
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
            }
            
            // App Name and Version
            VStack(spacing: 8) {
                Text("StillView - Image Viewer")
                    .font(.title)
                    .fontWeight(.medium)
                
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Description
            Text("A lightweight, distraction-free image viewer for macOS")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            // Author Information
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Created by Vinny Carpenter")
                            .font(.headline)
                        
                        Button(action: {
                            openURL("https://vinny.dev")
                        }) {
                            Text("vinny.dev")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "curlybraces")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Source")
                            .font(.headline)
                        
                        Button(action: {
                            openURL("https://github.com/vscarpenter/SimpleImageViewer")
                        }) {
                            Text("View on GitHub")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    
                    Spacer()
                }

                if let privacyPolicyURL = URL(string: "https://stillviewapp.com/privacy.html") {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        Link("Privacy Policy", destination: privacyPolicyURL)
                            .font(.subheadline)
                            .accessibilityHint("Opens StillView's privacy policy in your default browser")

                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            // Copyright
            Text(Bundle.main.copyrightNotice)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Close Button
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.escape)
            .controlSize(.large)
        }
        .padding(30)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    AboutView()
}
