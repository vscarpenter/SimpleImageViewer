#!/usr/bin/env swift

//
//  integration_test_validation.swift
//  Final Integration Testing Script
//
//  Created by Kiro on 7/30/25.
//

import Foundation

print("🧪 Final Integration Testing and Polish Validation")
print(String(repeating: "=", count: 60))

// MARK: - Test Results Structure

struct TestResult {
    let testName: String
    let passed: Bool
    let details: String
    
    var status: String {
        return passed ? "✅ PASS" : "❌ FAIL"
    }
}

var results: [TestResult] = []

// MARK: - Test 1: Build System Validation

print("\n🔨 Testing Build System...")
print(String(repeating: "-", count: 40))

let buildResult = shell("xcodebuild build -project 'StillView - Simple Image Viewer.xcodeproj' -scheme 'StillView - Simple Image Viewer' -configuration Debug -quiet")

results.append(TestResult(
    testName: "Project Build",
    passed: buildResult.exitCode == 0,
    details: buildResult.exitCode == 0 ? "Build succeeded" : "Build failed: \(buildResult.output)"
))

// MARK: - Test 2: File Structure Validation

print("\n📁 Testing File Structure...")
print(String(repeating: "-", count: 40))

let requiredFiles = [
    "StillView - Simple Image Viewer/Extensions/Color+Adaptive.swift",
    "StillView - Simple Image Viewer/App/AppDelegate.swift",
    "StillView - Simple Image Viewer/Services/WindowStateManager.swift",
    "StillView - Simple Image Viewer/Models/WindowState.swift",
    "StillView - Simple Image Viewer/Views/FolderSelectionView.swift",
    "StillView - Simple Image Viewer/Views/NavigationControlsView.swift",
    "StillView - Simple Image Viewer/Views/ImageInfoOverlayView.swift"
]

var allFilesExist = true
var missingFiles: [String] = []

for file in requiredFiles {
    if !FileManager.default.fileExists(atPath: file) {
        allFilesExist = false
        missingFiles.append(file)
    }
}

results.append(TestResult(
    testName: "Required Files Present",
    passed: allFilesExist,
    details: allFilesExist ? "All required files present" : "Missing files: \(missingFiles.joined(separator: ", "))"
))

// MARK: - Test 3: Code Quality Validation

print("\n🔍 Testing Code Quality...")
print(String(repeating: "-", count: 40))

// Check for compilation warnings
let warningCheck = shell("xcodebuild build -project 'StillView - Simple Image Viewer.xcodeproj' -scheme 'StillView - Simple Image Viewer' -configuration Debug 2>&1 | grep -i warning | wc -l")

let warningCount = Int(warningCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

results.append(TestResult(
    testName: "Build Warnings",
    passed: warningCount <= 5, // Allow some acceptable warnings
    details: "Found \(warningCount) warnings (acceptable threshold: 5)"
))

// MARK: - Test 4: App Store Compliance Files

print("\n📱 Testing App Store Compliance...")
print(String(repeating: "-", count: 40))

let complianceFiles = [
    "app_store_validation_summary.md",
    "StillView - Simple Image Viewer Tests/App/AppStoreComplianceTests.swift",
    "StillView - Simple Image Viewer Tests/Views/DarkModeUITests.swift",
    "StillView - Simple Image Viewer Tests/App/WindowManagementIntegrationTests.swift"
]

var complianceFilesExist = true
var missingComplianceFiles: [String] = []

for file in complianceFiles {
    if !FileManager.default.fileExists(atPath: file) {
        complianceFilesExist = false
        missingComplianceFiles.append(file)
    }
}

results.append(TestResult(
    testName: "App Store Compliance Files",
    passed: complianceFilesExist,
    details: complianceFilesExist ? "All compliance files present" : "Missing: \(missingComplianceFiles.joined(separator: ", "))"
))

// MARK: - Test 5: Dark Mode Implementation Check

print("\n🌙 Testing Dark Mode Implementation...")
print(String(repeating: "-", count: 40))

let colorAdaptiveContent = shell("cat 'StillView - Simple Image Viewer/Extensions/Color+Adaptive.swift'")
let hasDarkModeColors = colorAdaptiveContent.output.contains("appBackground") && 
                       colorAdaptiveContent.output.contains("NSColor.controlBackgroundColor")

results.append(TestResult(
    testName: "Dark Mode Color System",
    passed: hasDarkModeColors,
    details: hasDarkModeColors ? "Adaptive color system implemented" : "Missing adaptive color system"
))

// MARK: - Test 6: Window Management Implementation Check

print("\n🪟 Testing Window Management Implementation...")
print(String(repeating: "-", count: 40))

let appDelegateContent = shell("cat 'StillView - Simple Image Viewer/App/AppDelegate.swift'")
let hasWindowManagement = appDelegateContent.output.contains("applicationShouldHandleReopen") && 
                         appDelegateContent.output.contains("showMainWindow")

results.append(TestResult(
    testName: "Window Management System",
    passed: hasWindowManagement,
    details: hasWindowManagement ? "Window management implemented" : "Missing window management"
))

// MARK: - Test 7: Performance Check

print("\n⚡ Testing Performance...")
print(String(repeating: "-", count: 40))

// Check for any obvious performance issues in the code
let performanceCheck = shell("find 'StillView - Simple Image Viewer' -name '*.swift' -exec grep -l 'DispatchQueue.main.sync' {} \\; | wc -l")
let syncCallCount = Int(performanceCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

results.append(TestResult(
    testName: "Performance Check",
    passed: syncCallCount == 0,
    details: syncCallCount == 0 ? "No blocking sync calls found" : "Found \(syncCallCount) potentially blocking sync calls"
))

// MARK: - Test 8: Memory Management Check

print("\n🧠 Testing Memory Management...")
print(String(repeating: "-", count: 40))

// Check for potential memory leaks (basic check)
let memoryCheck = shell("find 'StillView - Simple Image Viewer' -name '*.swift' -exec grep -l 'weak\\|unowned' {} \\; | wc -l")
let weakReferenceCount = Int(memoryCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

results.append(TestResult(
    testName: "Memory Management",
    passed: weakReferenceCount > 0,
    details: "Found \(weakReferenceCount) files with weak/unowned references"
))

// MARK: - Test 9: Keyboard Navigation Check

print("\n⌨️ Testing Keyboard Navigation...")
print(String(repeating: "-", count: 40))

let keyboardContent = shell("find 'StillView - Simple Image Viewer' -name '*.swift' -exec grep -l 'keyEquivalent\\|KeyboardHandler' {} \\; | wc -l")
let keyboardFileCount = Int(keyboardContent.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

results.append(TestResult(
    testName: "Keyboard Navigation",
    passed: keyboardFileCount > 0,
    details: "Found keyboard handling in \(keyboardFileCount) files"
))

// MARK: - Test 10: Final App Bundle Check

print("\n📦 Testing App Bundle...")
print(String(repeating: "-", count: 40))

let bundlePath = shell("find ~/Library/Developer/Xcode/DerivedData -name 'StillView - Simple Image Viewer.app' -type d | head -1")
let appBundleExists = !bundlePath.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

results.append(TestResult(
    testName: "App Bundle Creation",
    passed: appBundleExists,
    details: appBundleExists ? "App bundle created successfully" : "App bundle not found"
))

// MARK: - Results Summary

print("\n📊 Test Results Summary")
print(String(repeating: "=", count: 60))

let passedTests = results.filter { $0.passed }.count
let totalTests = results.count

for result in results {
    print("\(result.status) \(result.testName)")
    if !result.details.isEmpty {
        print("   \(result.details)")
    }
}

print("\n" + String(repeating: "=", count: 60))
print("📈 Overall Results: \(passedTests)/\(totalTests) tests passed")

if passedTests == totalTests {
    print("🎉 ALL TESTS PASSED - Ready for App Store submission!")
    exit(0)
} else {
    print("⚠️  Some tests failed - Review issues before submission")
    exit(1)
}

// MARK: - Helper Functions

struct ShellResult {
    let output: String
    let exitCode: Int32
}

func shell(_ command: String) -> ShellResult {
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/bash"
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    
    task.waitUntilExit()
    
    return ShellResult(output: output, exitCode: task.terminationStatus)
}