import XCTest
@testable import StillView___Simple_Image_Viewer

final class PreferencesServiceTests: XCTestCase {
    private let suiteName = "AIAnalysisPreferencesTests"
    
    override func tearDown() {
        super.tearDown()
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
    
    func testEnableAIAnalysisDefaultsToFalseAndPersists() {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create user defaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        
        let service = DefaultPreferencesService(userDefaults: defaults)
        XCTAssertFalse(service.enableAIAnalysis, "AI Insights should be disabled by default")
        
        service.enableAIAnalysis = true
        XCTAssertTrue(service.enableAIAnalysis, "AI Insights preference should persist changes")
        XCTAssertTrue(defaults.bool(forKey: "enableAIAnalysis"))
    }
    
    func testEnableImageEnhancementsDefaultsToFalse() {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create user defaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let service = DefaultPreferencesService(userDefaults: defaults)
        XCTAssertFalse(service.enableImageEnhancements, "Image enhancements should be disabled by default")

        service.enableImageEnhancements = true
        XCTAssertTrue(service.enableImageEnhancements, "Image enhancement preference should persist changes")
        XCTAssertTrue(defaults.bool(forKey: "enableImageEnhancements"))
    }

    func test_recentFolderReordering_keepsEachBookmarkWithItsURL() throws {
        let service = try makePreferences()
        let folders = ["a", "b", "c"].map { URL(fileURLWithPath: "/fixture/\($0)") }
        service.recentFolders = folders
        service.folderBookmarks = [Data([1]), Data([2]), Data([3])]

        service.recentFolders = [folders[2], folders[0], folders[1]]

        XCTAssertEqual(service.folderBookmarks, [Data([3]), Data([1]), Data([2])])
    }

    func test_removeRecentFolder_removesMatchingBookmarkAtEveryPosition() throws {
        let service = try makePreferences()
        let folders = ["a", "b", "c"].map { URL(fileURLWithPath: "/fixture/\($0)") }
        let bookmarks = [Data([1]), Data([2]), Data([3])]
        for removalIndex in folders.indices {
            service.clearRecentFolders()
            service.recentFolders = folders
            service.folderBookmarks = bookmarks

            service.removeRecentFolder(folders[removalIndex])

            XCTAssertEqual(service.recentFolders, folders.enumerated().filter { $0.offset != removalIndex }.map(\.element))
            XCTAssertEqual(service.folderBookmarks, bookmarks.enumerated().filter { $0.offset != removalIndex }.map(\.element))
        }
    }

    func test_newRecentFolderWithoutBookmark_doesNotBorrowThePreviousFolderGrant() throws {
        let service = try makePreferences()
        let first = URL(fileURLWithPath: "/fixture/a")
        let second = URL(fileURLWithPath: "/fixture/b")
        service.recentFolders = [first]
        service.folderBookmarks = [Data([1])]

        service.addRecentFolder(second)

        XCTAssertEqual(service.recentFolders, [second, first])
        XCTAssertEqual(service.folderBookmarks, [Data(), Data([1])])
    }

    func test_legacyMigration_matchesBookmarkURLsRatherThanDictionaryOrder() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let fixture = try makeBookmarkFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        defaults.set(try NSKeyedArchiver.archivedData(
            withRootObject: fixture.urls, requiringSecureCoding: true), forKey: "recentFolders")
        defaults.set([fixture.bookmarks[2], fixture.bookmarks[0], fixture.bookmarks[1]], forKey: "folderBookmarks")

        let service = DefaultPreferencesService(userDefaults: defaults)

        XCTAssertEqual(service.recentFolders, fixture.urls)
        XCTAssertEqual(service.folderBookmarks, fixture.bookmarks)
    }

    func test_legacyMigration_withMissingOrInvalidBookmarks_preservesUnpairedFolders() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let fixture = try makeBookmarkFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        defaults.set(try NSKeyedArchiver.archivedData(
            withRootObject: fixture.urls, requiringSecureCoding: true), forKey: "recentFolders")
        defaults.set([Data([0]), fixture.bookmarks[2]], forKey: "folderBookmarks")

        let service = DefaultPreferencesService(userDefaults: defaults)

        XCTAssertEqual(service.recentFolders, fixture.urls)
        XCTAssertEqual(service.folderBookmarks, [Data(), Data(), fixture.bookmarks[2]])
    }

    func test_orderedFolderRecords_roundTripWithBookmarklessEntryInTheMiddle() throws {
        let service = try makePreferences()
        let records = [
            RecentFolderRecord(url: URL(fileURLWithPath: "/fixture/a"), bookmarkData: Data([1])),
            RecentFolderRecord(url: URL(fileURLWithPath: "/fixture/b"), bookmarkData: nil),
            RecentFolderRecord(url: URL(fileURLWithPath: "/fixture/c"), bookmarkData: Data([3]))
        ]
        service.recentFolderRecords = records

        let restored = DefaultPreferencesService(userDefaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)))

        XCTAssertEqual(restored.recentFolderRecords, records)
        XCTAssertEqual(restored.folderBookmarks, [Data([1]), Data(), Data([3])])
    }

    func test_orderedFolderRecords_deduplicatesAndLimitsWholeRecordsTogether() throws {
        let service = try makePreferences()
        let records = (0..<12).map { index in
            RecentFolderRecord(url: URL(fileURLWithPath: "/fixture/\(index)"), bookmarkData: Data([UInt8(index)]))
        }
        service.recentFolderRecords = [records[0]] + records

        XCTAssertEqual(service.recentFolderRecords, Array(records.prefix(10)))
    }

    func test_legacyMigration_damagedBookmarkAtEveryPosition_keepsOtherGrants() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let fixture = try makeBookmarkFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        for damagedIndex in fixture.urls.indices {
            defaults.removePersistentDomain(forName: suiteName)
            var damagedBookmarks = fixture.bookmarks
            damagedBookmarks[damagedIndex] = Data([0])
            defaults.set(try NSKeyedArchiver.archivedData(
                withRootObject: fixture.urls, requiringSecureCoding: true), forKey: "recentFolders")
            defaults.set(damagedBookmarks.reversed().map { $0 }, forKey: "folderBookmarks")

            let service = DefaultPreferencesService(userDefaults: defaults)

            let expected = fixture.urls.enumerated().map { index, url in
                RecentFolderRecord(url: url, bookmarkData: index == damagedIndex ? nil : fixture.bookmarks[index])
            }
            XCTAssertEqual(service.recentFolderRecords, expected)
        }
    }

    func test_removeBookmark_preservesOtherOrderedRecordsAndFolderForReauthorization() throws {
        let service = try makePreferences()
        let records = ["a", "b", "c"].enumerated().map { index, name in
            RecentFolderRecord(url: URL(fileURLWithPath: "/fixture/\(name)"), bookmarkData: Data([UInt8(index + 1)]))
        }
        service.recentFolderRecords = records
        let manager = SecurityScopedBookmarkManager(preferencesService: service)

        manager.removeBookmark(for: records[1].url)

        var expected = records
        expected[1].bookmarkData = nil
        XCTAssertEqual(service.recentFolderRecords, expected)
    }

    func test_failedLaunchBookmarkCleanup_preservesURLsAndRecordPositions() throws {
        let service = try makePreferences()
        let records = ["a", "b", "c"].enumerated().map { index, name in
            RecentFolderRecord(url: URL(fileURLWithPath: "/fixture/\(name)"), bookmarkData: Data([UInt8(index + 1)]))
        }
        service.recentFolderRecords = records
        let manager = SecurityScopedBookmarkManager(preferencesService: service)

        manager.restoreBookmarksOnLaunch()

        XCTAssertEqual(service.recentFolderRecords, records.map { RecentFolderRecord(url: $0.url, bookmarkData: nil) })
    }

    private func makePreferences() throws -> DefaultPreferencesService {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return DefaultPreferencesService(userDefaults: defaults)
    }

    private func makeBookmarkFixture() throws -> (directory: URL, urls: [URL], bookmarks: [Data]) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let urls = ["a", "b", "c"].map { directory.appendingPathComponent($0, isDirectory: true) }
        for url in urls {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        let bookmarks = try urls.map { try $0.bookmarkData(options: [.withSecurityScope]) }
        return (directory, urls, bookmarks)
    }
}
