import XCTest
import Combine
@testable import Simple_Image_Viewer

/// Integration tests for ErrorHandlingService with other components
class ErrorHandlingServiceIntegrationTests: XCTestCase {
    private var errorHandlingService: ErrorHandlingService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        errorHandlingService = ErrorHandlingService.shared
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing state
        errorHandlingService.clearAllNotifications()
        errorHandlingService.clearModalError()
        errorHandlingService.clearPermissionDialog()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        errorHandlingService.clearAllNotifications()
        errorHandlingService.clearModalError()
        errorHandlingService.clearPermissionDialog()
        super.tearDown()
    }
    
    // MARK: - Notification Tests
    
    func testNotificationDisplay() {
        let expectation = XCTestExpectation(description: "Notification should be added")
        
        errorHandlingService.$notifications
            .dropFirst() // Skip initial empty state
            .sink { notifications in
                XCTAssertEqual(notifications.count, 1)
                XCTAssertEqual(notifications.first?.message, "Test notification")
                XCTAssertEqual(notifications.first?.type, .warning)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        errorHandlingService.showNotification("Test notification", type: .warning)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleNotificationsLimit() {
        // Add maximum notifications
        for i in 1...4 {
            errorHandlingService.showNotification("Notification \(i)", type: .info)
        }
        
        // Should only keep the latest 3 notifications
        XCTAssertEqual(errorHandlingService.notifications.count, 3)
        XCTAssertEqual(errorHandlingService.notifications.last?.message, "Notification 4")
        XCTAssertEqual(errorHandlingService.notifications.first?.message, "Notification 2")
    }
    
    // MARK: - Modal Error Tests
    
    func testModalErrorDisplay() {
        let expectation = XCTestExpectation(description: "Modal error should be set")
        
        errorHandlingService.$modalError
            .dropFirst() // Skip initial nil state
            .sink { modalError in
                XCTAssertNotNil(modalError)
                XCTAssertEqual(modalError?.title, "Test Error")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        let testError = ImageViewerError.insufficientMemory
        errorHandlingService.showModalError(testError, title: "Test Error")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testModalErrorClear() {
        let testError = ImageViewerError.insufficientMemory
        errorHandlingService.showModalError(testError, title: "Test Error")
        
        XCTAssertNotNil(errorHandlingService.modalError)
        
        errorHandlingService.clearModalError()
        
        XCTAssertNil(errorHandlingService.modalError)
    }
    
    // MARK: - Permission Dialog Tests
    
    func testPermissionDialogDisplay() {
        let expectation = XCTestExpectation(description: "Permission dialog should be shown")
        
        errorHandlingService.$showPermissionDialog
            .dropFirst() // Skip initial false state
            .sink { showDialog in
                XCTAssertTrue(showDialog)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        let permissionRequest = PermissionRequestInfo(
            title: "Test Permission",
            message: "Test message",
            explanation: "Test explanation",
            primaryAction: PermissionAction(title: "OK", action: {})
        )
        
        errorHandlingService.showPermissionRequest(permissionRequest)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Type Handling Tests
    
    func testImageViewerErrorHandling() {
        let testCases: [(ImageViewerError, String)] = [
            (.noImagesFound, "No supported images found"),
            (.corruptedImage(URL(fileURLWithPath: "/test.jpg")), "Skipped corrupted image"),
            (.unsupportedImageFormat("BMP"), "Skipped unsupported image format"),
            (.folderNotFound(URL(fileURLWithPath: "/missing")), "Folder no longer exists")
        ]
        
        for (error, expectedMessagePart) in testCases {
            errorHandlingService.clearAllNotifications()
            
            errorHandlingService.handleImageViewerError(error)
            
            XCTAssertTrue(errorHandlingService.notifications.count > 0,
                         "Should create notification for \(error)")
            
            let notification = errorHandlingService.notifications.first!
            XCTAssertTrue(notification.message.contains(expectedMessagePart),
                         "Message should contain '\(expectedMessagePart)' but was '\(notification.message)'")
        }
    }
    
    func testImageLoaderErrorHandling() {
        let testURL = URL(fileURLWithPath: "/test.jpg")
        let testCases: [(ImageLoaderError, String)] = [
            (.fileNotFound, "Image file not found"),
            (.unsupportedFormat, "Skipped unsupported image"),
            (.corruptedImage, "Skipped corrupted image")
        ]
        
        for (error, expectedMessagePart) in testCases {
            errorHandlingService.clearAllNotifications()
            
            errorHandlingService.handleImageLoaderError(error, imageURL: testURL)
            
            XCTAssertTrue(errorHandlingService.notifications.count > 0,
                         "Should create notification for \(error)")
            
            let notification = errorHandlingService.notifications.first!
            XCTAssertTrue(notification.message.contains(expectedMessagePart),
                         "Message should contain '\(expectedMessagePart)' but was '\(notification.message)'")
        }
    }
    
    func testLoadingCancelledDoesNotShowNotification() {
        let testURL = URL(fileURLWithPath: "/test.jpg")
        
        errorHandlingService.handleImageLoaderError(.loadingCancelled, imageURL: testURL)
        
        XCTAssertEqual(errorHandlingService.notifications.count, 0,
                      "Loading cancelled should not show notification")
    }
    
    // MARK: - Permission Error Handling Tests
    
    func testFolderAccessDeniedShowsPermissionDialog() {
        let expectation = XCTestExpectation(description: "Permission dialog should be shown")
        
        errorHandlingService.$showPermissionDialog
            .dropFirst()
            .sink { showDialog in
                XCTAssertTrue(showDialog)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        errorHandlingService.handleImageViewerError(.folderAccessDenied)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(errorHandlingService.permissionRequest)
        XCTAssertEqual(errorHandlingService.permissionRequest?.title, "Folder Access Required")
    }
    
    // MARK: - Critical Error Handling Tests
    
    func testInsufficientMemoryShowsModalError() {
        let expectation = XCTestExpectation(description: "Modal error should be shown")
        
        errorHandlingService.$modalError
            .dropFirst()
            .sink { modalError in
                XCTAssertNotNil(modalError)
                XCTAssertEqual(modalError?.title, "Memory Warning")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        errorHandlingService.handleImageViewerError(.insufficientMemory)
        
        wait(for: [expectation], timeout: 1.0)
    }
}