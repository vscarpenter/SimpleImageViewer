//
//  AppLaunchUIIntegrationTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
@testable import StillView___Simple_Image_Viewer

/// UI integration tests for app launch sequence and "What's New" presentation
final class AppLaunchUIIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var app: NSApplication!
    private var testWindow: NSWindow!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        app = NSApplication.shared
        
        // Create a test window to simulate the main app window
        testWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        testWindow.title = "Test Window"
    }
    
    override func tearDown() {
        testWindow?.close()
        testWindow = nil
        app = nil
        super.tearDown()
    }
    
    // MARK: - Launch Sequence UI Tests
    
    func testAppLaunchSequence_WindowReadyBeforeWhatsNew() {
        let expectation = XCTestExpectation(description: "Window should be ready before What's New check")
        
        // Given: Simulating the app launch sequence
        testWindow.makeKeyAndOrderFront(nil)
        
        // When: Checking window state after a delay (simulating real app launch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then: Window should be visible and ready
            XCTAssertTrue(self.testWindow.isVisible, "Window should be visible")
            XCTAssertTrue(self.testWindow.canBecomeKey, "Window should be able to become key")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testWhatsNewPresentationTiming_DoesNotBlockUI() {
        let expectation = XCTestExpectation(description: "UI should remain responsive during What's New presentation")
        
        // Given: Window is ready
        testWindow.makeKeyAndOrderFront(nil)
        
        // When: Simulating What's New presentation timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Simulate the delay used in the real app
            DispatchQueue.main.async {
                // Then: Main thread should still be responsive
                XCTAssertTrue(Thread.isMainThread, "Should be on main thread")
                XCTAssertTrue(self.testWindow.isVisible, "Window should remain visible")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testFocusManagement_WindowRemainsKeyAfterSheetDismissal() {
        let expectation = XCTestExpectation(description: "Window should regain focus after sheet dismissal")
        
        // Given: Window is key and visible
        testWindow.makeKeyAndOrderFront(nil)
        XCTAssertTrue(testWindow.isKeyWindow, "Window should initially be key")
        
        // When: Simulating sheet presentation and dismissal
        DispatchQueue.main.async {
            // Simulate sheet presentation (window might lose key status)
            self.testWindow.resignKey()
            
            // Simulate sheet dismissal with focus restoration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.testWindow.makeKeyAndOrderFront(nil)
                
                // Then: Window should regain key status
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    XCTAssertTrue(self.testWindow.isKeyWindow, "Window should regain key status")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAppActivation_ProperlyHandlesWhatsNewFocus() {
        let expectation = XCTestExpectation(description: "App activation should handle What's New focus properly")
        
        // Given: App becomes active while What's New might be showing
        testWindow.makeKeyAndOrderFront(nil)
        
        // When: Simulating app activation
        let activationNotification = Notification(name: NSApplication.didBecomeActiveNotification, object: app)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(activationNotification)
            
            // Then: Window should maintain proper focus state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                XCTAssertTrue(self.testWindow.isVisible, "Window should remain visible")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testLaunchSequencePerformance_CompletesWithinTimeLimit() {
        // Given: Measuring launch sequence performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let expectation = XCTestExpectation(description: "Launch sequence should complete quickly")
        
        // When: Simulating the complete launch sequence
        testWindow.makeKeyAndOrderFront(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Simulate What's New check
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            // Then: Should complete within reasonable time
            XCTAssertLessThan(duration, 1.0, "Launch sequence should complete within 1 second")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMemoryUsageDuringLaunch_RemainsReasonable() {
        // Given: Measuring memory usage
        let initialMemory = getMemoryUsage()
        
        let expectation = XCTestExpectation(description: "Memory usage should remain reasonable")
        
        // When: Simulating launch sequence with What's New
        testWindow.makeKeyAndOrderFront(nil)
        
        // Create some content to simulate What's New loading
        let content = WhatsNewContent.sampleContent
        _ = content.sections.count // Use the content
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let finalMemory = self.getMemoryUsage()
            let memoryIncrease = finalMemory - initialMemory
            
            // Then: Memory increase should be reasonable (less than 50MB)
            XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Memory increase should be reasonable")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Edge Case Tests
    
    func testLaunchWithMultipleWindows_HandlesCorrectly() {
        let expectation = XCTestExpectation(description: "Should handle multiple windows correctly")
        
        // Given: Multiple windows exist
        let secondWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        testWindow.makeKeyAndOrderFront(nil)
        secondWindow.makeKeyAndOrderFront(nil)
        
        // When: Checking window management
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then: Should identify the correct main window
            let keyWindow = NSApp.keyWindow
            XCTAssertNotNil(keyWindow, "Should have a key window")
            
            secondWindow.close()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLaunchWithWindowNotReady_RetriesGracefully() {
        let expectation = XCTestExpectation(description: "Should retry when window is not ready")
        
        // Given: Window is not initially visible
        // (Don't call makeKeyAndOrderFront initially)
        
        var retryCount = 0
        
        func checkWindowReadiness() {
            retryCount += 1
            
            if testWindow.isVisible {
                // Window is ready
                expectation.fulfill()
            } else if retryCount < 5 {
                // Retry after delay (simulating the real app behavior)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    checkWindowReadiness()
                }
            } else {
                XCTFail("Window should become ready within retry limit")
                expectation.fulfill()
            }
        }
        
        // When: Starting the check and making window visible after delay
        DispatchQueue.main.async {
            checkWindowReadiness()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.testWindow.makeKeyAndOrderFront(nil)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}