//
//  FeedbackService.swift
//  StillView - Simple Image Viewer
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import Foundation
import AppKit

/// Service for handling user feedback submission via GitHub issues or email
protocol FeedbackServiceProtocol {
    /// Opens the GitHub issues page with pre-filled system information
    func openGitHubFeedbackForm()

    /// Opens the default email client with pre-filled feedback template
    func openEmailFeedbackForm()

    /// Generates the GitHub feedback URL with system information template
    func generateFeedbackURL() -> URL?

    /// Generates the email feedback URL with system information template
    func generateEmailFeedbackURL() -> URL?
}

/// Default implementation of FeedbackService
final class FeedbackService: FeedbackServiceProtocol {

    // GitHub repository information
    private let githubOwner = "vscarpenter"
    private let githubRepo = "SimpleImageViewer"

    // Email feedback information
    private let feedbackEmail = "stillview@vinny.dev"

    /// Opens the GitHub feedback form in the user's default browser
    func openGitHubFeedbackForm() {
        guard let url = generateFeedbackURL() else {
            // Fallback to simple issues page if URL generation fails
            if let fallbackURL = URL(string: "https://github.com/\(githubOwner)/\(githubRepo)/issues/new") {
                NSWorkspace.shared.open(fallbackURL)
            }
            return
        }

        NSWorkspace.shared.open(url)
    }

    /// Opens the default email client with pre-filled feedback template
    func openEmailFeedbackForm() {
        guard let url = generateEmailFeedbackURL() else {
            // Fallback to simple mailto
            if let fallbackURL = URL(string: "mailto:\(feedbackEmail)") {
                NSWorkspace.shared.open(fallbackURL)
            }
            return
        }

        NSWorkspace.shared.open(url)
    }

    /// Generates a GitHub issue URL with pre-filled system information
    func generateFeedbackURL() -> URL? {
        let baseURL = "https://github.com/\(githubOwner)/\(githubRepo)/issues/new"

        // Collect system information
        let systemInfo = collectSystemInfo()

        // Create issue template
        let title = "[Feedback] "
        let body = createIssueTemplate(systemInfo: systemInfo)

        // Build URL components
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body)
        ]

        return components?.url
    }

    // MARK: - Private Methods

    /// Collects system information for the feedback template
    private func collectSystemInfo() -> SystemInfo {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let architecture = getArchitecture()
        let aiEnabled = DefaultPreferencesService.shared.enableAIAnalysis

        return SystemInfo(
            appVersion: appVersion,
            buildNumber: buildNumber,
            osVersion: osVersion,
            architecture: architecture,
            aiEnabled: aiEnabled
        )
    }

    /// Determines the system architecture (Apple Silicon or Intel)
    private func getArchitecture() -> String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel"
        #else
        return "Unknown"
        #endif
    }

    /// Creates the issue template body with system information
    private func createIssueTemplate(systemInfo: SystemInfo) -> String {
        return """
        ## Feedback Type
        <!-- Please check one: -->
        - [ ] Bug Report
        - [ ] Feature Request
        - [ ] General Feedback

        ## Description
        <!-- Please describe your feedback in detail -->



        ## Steps to Reproduce (for bugs)
        <!-- If reporting a bug, please provide steps to reproduce: -->
        1.
        2.
        3.

        ## Expected Behavior (for bugs/features)
        <!-- What did you expect to happen? -->



        ## Actual Behavior (for bugs)
        <!-- What actually happened? -->



        ---

        ## System Information
        - **App Version:** \(systemInfo.appVersion) (Build \(systemInfo.buildNumber))
        - **macOS Version:** \(systemInfo.osVersion)
        - **Architecture:** \(systemInfo.architecture)
        - **AI Features:** \(systemInfo.aiEnabled ? "Enabled" : "Disabled")

        <!-- Thank you for your feedback! -->
        """
    }

    /// Generates an email mailto URL with pre-filled feedback template
    func generateEmailFeedbackURL() -> URL? {
        let systemInfo = collectSystemInfo()

        let subject = "StillView Feedback"
        let body = createEmailTemplate(systemInfo: systemInfo)

        var components = URLComponents(string: "mailto:\(feedbackEmail)")
        components?.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        return components?.url
    }

    /// Creates the email template body with system information
    private func createEmailTemplate(systemInfo: SystemInfo) -> String {
        return """
        Feedback Type: [Bug Report / Feature Request / General Feedback]

        Description:
        [Please describe your feedback in detail]


        Steps to Reproduce (for bugs):
        1.
        2.
        3.


        Expected Behavior (for bugs/features):
        [What did you expect to happen?]


        Actual Behavior (for bugs):
        [What actually happened?]


        ---
        System Information:
        - App Version: \(systemInfo.appVersion) (Build \(systemInfo.buildNumber))
        - macOS Version: \(systemInfo.osVersion)
        - Architecture: \(systemInfo.architecture)
        - AI Features: \(systemInfo.aiEnabled ? "Enabled" : "Disabled")

        Thank you for your feedback!
        """
    }
}

// MARK: - Supporting Types

/// Structure holding system information for feedback
private struct SystemInfo {
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let architecture: String
    let aiEnabled: Bool
}
