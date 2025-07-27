import XCTest
import Foundation
import CoreGraphics
@testable import Simple_Image_Viewer

class PreferencesServiceTests: XCTestCase {
    var preferencesService: DefaultPreferencesService!
    var testUserDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        
        // Create a test UserDefaults suite to avoid interfering with actual app preferences
        testUserDefaults = UserDefaults(suiteName: "test.preferences.suite")!
        
        // Clear any existing test data
        testUserDefaults.removePersistentDomain(forName: "test.preferences.suite")
        
        // Initialize preferences service with test UserDefaults
        preferencesService = DefaultPreferencesService(userDefaults: testUserDefaults)
    }
    
    override func tearDown() {
        // Clean up test data
        testUserDefaults.removePersistentDomain(forName: "test.preferences.suite")
        preferencesService = nil
        testUserDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Recent Folders Tests
    
    func testRecentFoldersInitiallyEmpty() {
        // Given a fresh preferences service with clean UserDefaults
        let cleanUserDefaults = UserDefaults(suiteName: "test.clean.suite")!
        cleanUserDefaults.removePersistentDomain(forName: "test.clean.suite")
        let service = DefaultPreferencesService(userDefaults: cleanUserDefaults)
        
        // When getting recent folders
        let folders = service.recentFolders
        
        // Then it should be empty
        XCTAssertTrue(folders.isEmpty, "Recent folders should be empty initially")
    }
    
    func testAddRecentFolder() {
        // Given a folder URL
        let folderURL = URL(fileURLWithPath: "/Users/test/Documents")
        
        // When adding it to recent folders
        preferencesService.addRecentFolder(folderURL)
        
        // Then it should be in the recent folders list
        XCTAssertEqual(preferencesService.recentFolders.count, 1)
        XCTAssertEqual(preferencesService.recentFolders.first, folderURL)
    }
    
    func testAddMultipleRecentFolders() {
        // Given multiple folder URLs
        let folder1 = URL(fileURLWithPath: "/Users/test/Documents")
        let folder2 = URL(fileURLWithPath: "/Users/test/Pictures")
        let folder3 = URL(fileURLWithPath: "/Users/test/Desktop")
        
        // When adding them to recent folders
        preferencesService.addRecentFolder(folder1)
        preferencesService.addRecentFolder(folder2)
        preferencesService.addRecentFolder(folder3)
        
        // Then they should be in reverse order (most recent first)
        let recentFolders = preferencesService.recentFolders
        XCTAssertEqual(recentFolders.count, 3)
        XCTAssertEqual(recentFolders[0], folder3)
        XCTAssertEqual(recentFolders[1], folder2)
        XCTAssertEqual(recentFolders[2], folder1)
    }
    
    func testAddDuplicateRecentFolder() {
        // Given a folder URL that's already in recent folders
        let folderURL = URL(fileURLWithPath: "/Users/test/Documents")
        preferencesService.addRecentFolder(folderURL)
        
        // When adding it again
        preferencesService.addRecentFolder(folderURL)
        
        // Then it should only appear once (at the top)
        XCTAssertEqual(preferencesService.recentFolders.count, 1)
        XCTAssertEqual(preferencesService.recentFolders.first, folderURL)
    }
    
    func testRecentFoldersLimitedToTen() {
        // Given 12 folder URLs
        let folders = (1...12).map { URL(fileURLWithPath: "/Users/test/Folder\($0)") }
        
        // When adding all of them
        folders.forEach { preferencesService.addRecentFolder($0) }
        
        // Then only the last 10 should be kept
        let recentFolders = preferencesService.recentFolders
        XCTAssertEqual(recentFolders.count, 10)
        
        // And they should be in reverse order (most recent first)
        for i in 0..<10 {
            let expectedFolder = folders[11 - i] // folders[11], folders[10], ..., folders[2]
            XCTAssertEqual(recentFolders[i], expectedFolder)
        }
    }
    
    func testRemoveRecentFolder() {
        // Given multiple folders in recent list
        let folder1 = URL(fileURLWithPath: "/Users/test/Documents")
        let folder2 = URL(fileURLWithPath: "/Users/test/Pictures")
        preferencesService.addRecentFolder(folder1)
        preferencesService.addRecentFolder(folder2)
        
        // When removing one folder
        preferencesService.removeRecentFolder(folder1)
        
        // Then it should be removed from the list
        let recentFolders = preferencesService.recentFolders
        XCTAssertEqual(recentFolders.count, 1)
        XCTAssertEqual(recentFolders.first, folder2)
        XCTAssertFalse(recentFolders.contains(folder1))
    }
    
    func testClearRecentFolders() {
        // Given folders in recent list
        let folder1 = URL(fileURLWithPath: "/Users/test/Documents")
        let folder2 = URL(fileURLWithPath: "/Users/test/Pictures")
        preferencesService.addRecentFolder(folder1)
        preferencesService.addRecentFolder(folder2)
        
        // When clearing recent folders
        preferencesService.clearRecentFolders()
        
        // Then the list should be empty
        XCTAssertTrue(preferencesService.recentFolders.isEmpty)
        XCTAssertTrue(preferencesService.folderBookmarks.isEmpty)
    }
    
    // MARK: - Window Frame Tests
    
    func testWindowFrameDefaultValue() {
        // Given a fresh preferences service with clean UserDefaults
        let cleanUserDefaults = UserDefaults(suiteName: "test.clean.suite")!
        cleanUserDefaults.removePersistentDomain(forName: "test.clean.suite")
        let service = DefaultPreferencesService(userDefaults: cleanUserDefaults)
        
        // When getting window frame
        let frame = service.windowFrame
        
        // Then it should have default values
        XCTAssertEqual(frame.origin.x, 100)
        XCTAssertEqual(frame.origin.y, 100)
        XCTAssertEqual(frame.size.width, 800)
        XCTAssertEqual(frame.size.height, 600)
    }
    
    func testSetWindowFrame() {
        // Given a custom window frame
        let customFrame = CGRect(x: 200, y: 150, width: 1024, height: 768)
        
        // When setting the window frame
        preferencesService.windowFrame = customFrame
        
        // Then it should be stored and retrievable
        let storedFrame = preferencesService.windowFrame
        XCTAssertEqual(storedFrame.origin.x, 200)
        XCTAssertEqual(storedFrame.origin.y, 150)
        XCTAssertEqual(storedFrame.size.width, 1024)
        XCTAssertEqual(storedFrame.size.height, 768)
    }
    
    // MARK: - Show File Name Tests
    
    func testShowFileNameDefaultValue() {
        // Given a fresh preferences service with clean UserDefaults
        let cleanUserDefaults = UserDefaults(suiteName: "test.clean.suite")!
        cleanUserDefaults.removePersistentDomain(forName: "test.clean.suite")
        let service = DefaultPreferencesService(userDefaults: cleanUserDefaults)
        
        // When getting showFileName
        let showFileName = service.showFileName
        
        // Then it should be false by default
        XCTAssertFalse(showFileName, "showFileName should be false by default")
    }
    
    func testSetShowFileName() {
        // Given the preference is initially false
        XCTAssertFalse(preferencesService.showFileName)
        
        // When setting it to true
        preferencesService.showFileName = true
        
        // Then it should be stored and retrievable
        XCTAssertTrue(preferencesService.showFileName)
        
        // When setting it back to false
        preferencesService.showFileName = false
        
        // Then it should be updated
        XCTAssertFalse(preferencesService.showFileName)
    }
    
    // MARK: - Last Selected Folder Tests
    
    func testLastSelectedFolderInitiallyNil() {
        // Given a fresh preferences service with clean UserDefaults
        let cleanUserDefaults = UserDefaults(suiteName: "test.clean.suite")!
        cleanUserDefaults.removePersistentDomain(forName: "test.clean.suite")
        let service = DefaultPreferencesService(userDefaults: cleanUserDefaults)
        
        // When getting last selected folder
        let folder = service.lastSelectedFolder
        
        // Then it should be nil
        XCTAssertNil(folder, "Last selected folder should be nil initially")
    }
    
    func testSetLastSelectedFolder() {
        // Given a folder URL
        let folderURL = URL(fileURLWithPath: "/Users/test/Documents")
        
        // When setting it as last selected folder
        preferencesService.lastSelectedFolder = folderURL
        
        // Then it should be stored and retrievable
        XCTAssertEqual(preferencesService.lastSelectedFolder, folderURL)
    }
    
    func testClearLastSelectedFolder() {
        // Given a last selected folder is set
        let folderURL = URL(fileURLWithPath: "/Users/test/Documents")
        preferencesService.lastSelectedFolder = folderURL
        XCTAssertNotNil(preferencesService.lastSelectedFolder)
        
        // When setting it to nil
        preferencesService.lastSelectedFolder = nil
        
        // Then it should be cleared
        XCTAssertNil(preferencesService.lastSelectedFolder)
    }
    
    // MARK: - Folder Bookmarks Tests
    
    func testFolderBookmarksInitiallyEmpty() {
        // Given a fresh preferences service with clean UserDefaults
        let cleanUserDefaults = UserDefaults(suiteName: "test.clean.suite")!
        cleanUserDefaults.removePersistentDomain(forName: "test.clean.suite")
        let service = DefaultPreferencesService(userDefaults: cleanUserDefaults)
        
        // When getting folder bookmarks
        let bookmarks = service.folderBookmarks
        
        // Then it should be empty
        XCTAssertTrue(bookmarks.isEmpty, "Folder bookmarks should be empty initially")
    }
    
    func testSetFolderBookmarks() {
        // Given some bookmark data
        let bookmark1 = "bookmark1".data(using: .utf8)!
        let bookmark2 = "bookmark2".data(using: .utf8)!
        let bookmarks = [bookmark1, bookmark2]
        
        // When setting folder bookmarks
        preferencesService.folderBookmarks = bookmarks
        
        // Then they should be stored and retrievable
        let storedBookmarks = preferencesService.folderBookmarks
        XCTAssertEqual(storedBookmarks.count, 2)
        XCTAssertEqual(storedBookmarks[0], bookmark1)
        XCTAssertEqual(storedBookmarks[1], bookmark2)
    }
    
    // MARK: - Persistence Tests
    
    func testSavePreferences() {
        // Given some preferences are set
        let folderURL = URL(fileURLWithPath: "/Users/test/Documents")
        let customFrame = CGRect(x: 300, y: 200, width: 900, height: 700)
        
        preferencesService.addRecentFolder(folderURL)
        preferencesService.windowFrame = customFrame
        preferencesService.showFileName = true
        preferencesService.lastSelectedFolder = folderURL
        
        // When saving preferences
        preferencesService.savePreferences()
        
        // Then the save operation should complete without error
        // (UserDefaults.synchronize() returns Bool but we're not testing the return value here
        // as it's mainly for ensuring data is written to disk)
        XCTAssertNoThrow(preferencesService.savePreferences())
    }
    
    func testLoadPreferences() {
        // Given preferences service
        // When loading preferences
        // Then it should complete without error
        XCTAssertNoThrow(preferencesService.loadPreferences())
    }
}