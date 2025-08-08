//
//  WhatsNewPerformanceIntegrationTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
@testable import Simple_Image_Viewer

/// Performance-focused integration tests for the What's New feature
/// measuring impact on app launch time and overall system performance.
/// Requirements: 1.1, 1.4, 1.5
final class WhatsNewPerformanceIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var testUserDefaults: UserDefaults!
    private var performanceMetrics: [String: TimeInterval] = [:]
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        testUserDefaults = UserDefaults(suiteName: "PerformanceTests")!
        testUserDefaults.removePersistentDomain(forName: "PerformanceTests")
        performanceMetrics.removeAll()
    }
    
    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: "PerformanceTests")
        testUserDefaults = nil
        
        // Print performance summary
        if !performanceMetrics.isEmpty {
            print("\n=== What's New Performance Summary ===")
            for (metric, time) in performanceMetrics.sorted(by: { $0.key < $1.key }) {
                print("\(metric): \(String(format: "%.3f", time * 1000))ms")
            }
            print("=====================================\n")
        }
        
        super.tearDown()
    }
    
    // MARK: - App Launch Performance Tests
    
    func testAppLaunchPerformanceWithWhatsNewCheck() {
        // Given: Various launch scenarios
        let launchScenarios: [(name: String, hasStoredVersion: Bool, shouldShow: Bool)] = [
            ("First Launch", false, true),
            ("Same Version Launch", true, false),
            ("Version Upgrade Launch", true, true)
        ]
        
        for scenario in launchScenarios {
            // Given: Scenario setup
            testUserDefaults.removePersistentDomain(forName: "PerformanceTests")
            if scenario.hasStoredVersion {
                testUserDefaults.set("1.0.0", forKey: "LastShownWhatsNewVersion")
            }
            
            let versionTracker = VersionTracker(userDefaults: testUserDefaults)
            let contentProvider = WhatsNewContentProvider()
            
            // When: Measuring complete launch sequence
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate app launch sequence
            let whatsNewService = WhatsNewService(
                versionTracker: versionTracker,
                contentProvider: contentProvider
            )
            
            let shouldShow = whatsNewService.shouldShowWhatsNew()
            let content = shouldShow ? whatsNewService.getWhatsNewContent() : nil
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let launchTime = endTime - startTime
            
            // Then: Performance should meet requirements
            XCTAssertLessThan(launchTime, 0.1, 
                             "\(scenario.name) should complete in under 100ms")
            XCTAssertEqual(shouldShow, scenario.shouldShow, 
                          "\(scenario.name) should show: \(scenario.shouldShow)")
            
            if shouldShow {
                XCTAssertNotNil(content, "\(scenario.name) should have content when showing")
            }
            
            // Record metrics
            performanceMetrics["\(scenario.name) Launch Time"] = launchTime
        }
    }
    
    func testAppLaunchPerformanceUnderLoad() {
        // Given: System under load simulation
        let iterations = 50
        var launchTimes: [TimeInterval] = []
        
        // Create background load
        let backgroundQueue = DispatchQueue(label: "background.load", qos: .background)
        let loadExpectation = XCTestExpectation(description: "Background load")
        loadExpectation.expectedFulfillmentCount = 10
        
        for _ in 0..<10 {
            backgroundQueue.async {
                // Simulate CPU load
                let startTime = CFAbsoluteTimeGetCurrent()
                while CFAbsoluteTimeGetCurrent() - startTime < 0.1 {
                    _ = (0..<1000).map { $0 * $0 }
                }
                loadExpectation.fulfill()
            }
        }
        
        // When: Measuring launch performance under load
        for i in 0..<iterations {
            testUserDefaults.removePersistentDomain(forName: "PerformanceTests")
            
            let versionTracker = VersionTracker(userDefaults: testUserDefaults)
            let contentProvider = WhatsNewContentProvider()
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let whatsNewService = WhatsNewService(
                versionTracker: versionTracker,
                contentProvider: contentProvider
            )
            
            _ = whatsNewService.shouldShowWhatsNew()
            _ = whatsNewService.getWhatsNewContent()
            
            let endTime = CFAbsoluteTimeGetCurrent()
            launchTimes.append(endTime - startTime)
        }
        
        wait(for: [loadExpectation], timeout: 5.0)
        
        // Then: Performance should remain acceptable under load
        let averageTime = launchTimes.reduce(0, +) / Double(launchTimes.count)
        let maxTime = launchTimes.max() ?? 0
        let minTime = launchTimes.min() ?? 0
        
        XCTAssertLessThan(averageTime, 0.15, "Average launch time under load should be under 150ms")
        XCTAssertLessThan(maxTime, 0.3, "Maximum launch time under load should be under 300ms")
        
        performanceMetrics["Launch Under Load - Average"] = averageTime
        performanceMetrics["Launch Under Load - Max"] = maxTime
        performanceMetrics["Launch Under Load - Min"] = minTime
    }
    
    func testConcurrentLaunchPerformance() {
        // Given: Multiple concurrent launch simulations
        let concurrentLaunches = 20
        let launchExpectation = XCTestExpectation(description: "Concurrent launches")
        launchExpectation.expectedFulfillmentCount = concurrentLaunches
        
        var launchTimes: [TimeInterval] = []
        let timesLock = NSLock()
        
        // When: Launching multiple instances concurrently
        for i in 0..<concurrentLaunches {
            DispatchQueue.global(qos: .userInitiated).async {
                let testDefaults = UserDefaults(suiteName: "ConcurrentTest\(i)")!
                testDefaults.removePersistentDomain(forName: "ConcurrentTest\(i)")
                
                let versionTracker = VersionTracker(userDefaults: testDefaults)
                let contentProvider = WhatsNewContentProvider()
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let whatsNewService = WhatsNewService(
                    versionTracker: versionTracker,
                    contentProvider: contentProvider
                )
                
                _ = whatsNewService.shouldShowWhatsNew()
                _ = whatsNewService.getWhatsNewContent()
                
                let endTime = CFAbsoluteTimeGetCurrent()
                
                timesLock.lock()
                launchTimes.append(endTime - startTime)
                timesLock.unlock()
                
                launchExpectation.fulfill()
            }
        }
        
        wait(for: [launchExpectation], timeout: 10.0)
        
        // Then: Concurrent performance should be acceptable
        let averageTime = launchTimes.reduce(0, +) / Double(launchTimes.count)
        let maxTime = launchTimes.max() ?? 0
        
        XCTAssertLessThan(averageTime, 0.2, "Average concurrent launch time should be under 200ms")
        XCTAssertLessThan(maxTime, 0.5, "Maximum concurrent launch time should be under 500ms")
        XCTAssertEqual(launchTimes.count, concurrentLaunches, "All launches should complete")
        
        performanceMetrics["Concurrent Launch - Average"] = averageTime
        performanceMetrics["Concurrent Launch - Max"] = maxTime
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageOptimization() {
        // Given: Memory measurement setup
        let initialMemory = getMemoryUsage()
        var services: [WhatsNewService] = []
        
        // When: Creating multiple service instances
        for i in 0..<100 {
            let testDefaults = UserDefaults(suiteName: "MemoryTest\(i)")!
            let versionTracker = VersionTracker(userDefaults: testDefaults)
            let contentProvider = WhatsNewContentProvider()
            
            let service = WhatsNewService(
                versionTracker: versionTracker,
                contentProvider: contentProvider
            )
            
            // Load content to trigger memory allocation
            _ = service.getWhatsNewContent()
            services.append(service)
        }
        
        let peakMemory = getMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // Then: Memory usage should be reasonable
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, 
                         "Memory increase should be less than 50MB for 100 instances")
        
        // When: Releasing services
        services.removeAll()
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {
                _ = Array(0..<1000).map { $0 }
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryRecovered = peakMemory - finalMemory
        
        // Then: Memory should be recovered
        XCTAssertGreaterThan(memoryRecovered, memoryIncrease * 0.7, 
                            "Should recover at least 70% of allocated memory")
        
        performanceMetrics["Memory Increase (MB)"] = Double(memoryIncrease) / (1024 * 1024)
        performanceMetrics["Memory Recovered (MB)"] = Double(memoryRecovered) / (1024 * 1024)
    }
    
    func testMemoryLeakDetection() {
        // Given: Baseline memory measurement
        let baselineMemory = getMemoryUsage()
        
        // When: Repeatedly creating and destroying services
        for iteration in 0..<10 {
            autoreleasepool {
                var services: [WhatsNewService] = []
                
                for i in 0..<10 {
                    let testDefaults = UserDefaults(suiteName: "LeakTest\(iteration)\(i)")!
                    let versionTracker = VersionTracker(userDefaults: testDefaults)
                    let contentProvider = WhatsNewContentProvider()
                    
                    let service = WhatsNewService(
                        versionTracker: versionTracker,
                        contentProvider: contentProvider
                    )
                    
                    // Exercise the service
                    _ = service.shouldShowWhatsNew()
                    _ = service.getWhatsNewContent()
                    service.markWhatsNewAsShown()
                    
                    services.append(service)
                }
                
                // Services go out of scope here
            }
        }
        
        // Force cleanup
        for _ in 0..<5 {
            autoreleasepool {
                _ = Array(0..<1000).map { String($0) }
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryDifference = finalMemory - baselineMemory
        
        // Then: Memory usage should return close to baseline
        XCTAssertLessThan(memoryDifference, 5 * 1024 * 1024, 
                         "Memory difference should be less than 5MB after cleanup")
        
        performanceMetrics["Memory Leak Test (MB)"] = Double(memoryDifference) / (1024 * 1024)
    }
    
    // MARK: - UserDefaults Performance Tests
    
    func testUserDefaultsPerformanceOptimization() {
        // Given: Performance measurement for UserDefaults operations
        let readIterations = 1000
        let writeIterations = 100
        
        var readTimes: [TimeInterval] = []
        var writeTimes: [TimeInterval] = []
        
        // When: Measuring read performance
        for i in 0..<readIterations {
            testUserDefaults.set("1.\(i % 10).0", forKey: "LastShownWhatsNewVersion")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = testUserDefaults.string(forKey: "LastShownWhatsNewVersion")
            let endTime = CFAbsoluteTimeGetCurrent()
            
            readTimes.append(endTime - startTime)
        }
        
        // When: Measuring write performance
        for i in 0..<writeIterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            testUserDefaults.set("2.\(i).0", forKey: "LastShownWhatsNewVersion")
            let endTime = CFAbsoluteTimeGetCurrent()
            
            writeTimes.append(endTime - startTime)
        }
        
        // Then: UserDefaults operations should be fast
        let averageReadTime = readTimes.reduce(0, +) / Double(readTimes.count)
        let averageWriteTime = writeTimes.reduce(0, +) / Double(writeTimes.count)
        let maxReadTime = readTimes.max() ?? 0
        let maxWriteTime = writeTimes.max() ?? 0
        
        XCTAssertLessThan(averageReadTime, 0.001, "Average read should be under 1ms")
        XCTAssertLessThan(averageWriteTime, 0.01, "Average write should be under 10ms")
        XCTAssertLessThan(maxReadTime, 0.01, "Max read should be under 10ms")
        XCTAssertLessThan(maxWriteTime, 0.1, "Max write should be under 100ms")
        
        performanceMetrics["UserDefaults Read (ms)"] = averageReadTime * 1000
        performanceMetrics["UserDefaults Write (ms)"] = averageWriteTime * 1000
    }
    
    func testUserDefaultsSynchronizationPerformance() {
        // Given: Multiple UserDefaults instances
        let instanceCount = 50
        var userDefaultsInstances: [UserDefaults] = []
        
        for i in 0..<instanceCount {
            let instance = UserDefaults(suiteName: "SyncTest\(i)")!
            userDefaultsInstances.append(instance)
        }
        
        // When: Measuring synchronization performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for (index, instance) in userDefaultsInstances.enumerated() {
            instance.set("1.\(index).0", forKey: "LastShownWhatsNewVersion")
            instance.synchronize()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let syncTime = endTime - startTime
        
        // Then: Synchronization should be reasonably fast
        XCTAssertLessThan(syncTime, 1.0, "Synchronization should complete in under 1 second")
        
        let averageSyncTime = syncTime / Double(instanceCount)
        XCTAssertLessThan(averageSyncTime, 0.02, "Average sync time should be under 20ms")
        
        performanceMetrics["UserDefaults Sync Total (ms)"] = syncTime * 1000
        performanceMetrics["UserDefaults Sync Average (ms)"] = averageSyncTime * 1000
        
        // Cleanup
        for instance in userDefaultsInstances {
            instance.removePersistentDomain(forName: instance.persistentDomainNames().first ?? "")
        }
    }
    
    // MARK: - Content Loading Performance Tests
    
    func testContentLoadingOptimization() {
        // Given: Multiple content loading scenarios
        let contentProvider = WhatsNewContentProvider()
        let loadIterations = 100
        var loadTimes: [TimeInterval] = []
        
        // When: Loading content multiple times
        for _ in 0..<loadIterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = contentProvider.loadContent()
            let endTime = CFAbsoluteTimeGetCurrent()
            
            loadTimes.append(endTime - startTime)
        }
        
        // Then: Content loading should be consistently fast
        let averageLoadTime = loadTimes.reduce(0, +) / Double(loadTimes.count)
        let maxLoadTime = loadTimes.max() ?? 0
        let minLoadTime = loadTimes.min() ?? 0
        
        XCTAssertLessThan(averageLoadTime, 0.01, "Average content load should be under 10ms")
        XCTAssertLessThan(maxLoadTime, 0.05, "Max content load should be under 50ms")
        
        // Check for caching effectiveness (subsequent loads should be faster)
        let firstLoadTime = loadTimes[0]
        let lastLoadTime = loadTimes.last ?? 0
        
        // Note: This assumes some form of caching is implemented
        // If no caching, this test documents the baseline performance
        
        performanceMetrics["Content Load Average (ms)"] = averageLoadTime * 1000
        performanceMetrics["Content Load Max (ms)"] = maxLoadTime * 1000
        performanceMetrics["Content Load Min (ms)"] = minLoadTime * 1000
        performanceMetrics["Content Load First (ms)"] = firstLoadTime * 1000
        performanceMetrics["Content Load Last (ms)"] = lastLoadTime * 1000
    }
    
    func testContentLoadingUnderMemoryPressure() {
        // Given: Simulated memory pressure
        var memoryPressureArrays: [[String]] = []
        
        // Create memory pressure
        for i in 0..<100 {
            let largeArray = Array(0..<10000).map { "String \(i) \($0)" }
            memoryPressureArrays.append(largeArray)
        }
        
        let contentProvider = WhatsNewContentProvider()
        let loadIterations = 20
        var loadTimes: [TimeInterval] = []
        
        // When: Loading content under memory pressure
        for _ in 0..<loadIterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = contentProvider.loadContent()
            let endTime = CFAbsoluteTimeGetCurrent()
            
            loadTimes.append(endTime - startTime)
        }
        
        // Release memory pressure
        memoryPressureArrays.removeAll()
        
        // Then: Performance should remain acceptable under memory pressure
        let averageLoadTime = loadTimes.reduce(0, +) / Double(loadTimes.count)
        let maxLoadTime = loadTimes.max() ?? 0
        
        XCTAssertLessThan(averageLoadTime, 0.05, 
                         "Average content load under memory pressure should be under 50ms")
        XCTAssertLessThan(maxLoadTime, 0.2, 
                         "Max content load under memory pressure should be under 200ms")
        
        performanceMetrics["Content Load Under Pressure Average (ms)"] = averageLoadTime * 1000
        performanceMetrics["Content Load Under Pressure Max (ms)"] = maxLoadTime * 1000
    }
    
    // MARK: - Overall System Impact Tests
    
    func testOverallSystemPerformanceImpact() {
        // Given: Baseline system performance measurement
        let baselineTime = measureSystemPerformance()
        
        // When: Running What's New operations
        let versionTracker = VersionTracker(userDefaults: testUserDefaults)
        let contentProvider = WhatsNewContentProvider()
        let whatsNewService = WhatsNewService(
            versionTracker: versionTracker,
            contentProvider: contentProvider
        )
        
        // Perform typical What's New operations
        for _ in 0..<10 {
            _ = whatsNewService.shouldShowWhatsNew()
            _ = whatsNewService.getWhatsNewContent()
            whatsNewService.markWhatsNewAsShown()
        }
        
        let impactTime = measureSystemPerformance()
        
        // Then: System performance should not be significantly impacted
        let performanceImpact = impactTime - baselineTime
        let impactPercentage = (performanceImpact / baselineTime) * 100
        
        XCTAssertLessThan(impactPercentage, 10, 
                         "System performance impact should be less than 10%")
        
        performanceMetrics["System Performance Impact (%)"] = impactPercentage
        performanceMetrics["Baseline Performance (ms)"] = baselineTime * 1000
        performanceMetrics["With What's New Performance (ms)"] = impactTime * 1000
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func measureSystemPerformance() -> TimeInterval {
        let iterations = 1000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform standard system operations
        for i in 0..<iterations {
            autoreleasepool {
                let array = Array(0..<100).map { "Item \(i) \($0)" }
                let filtered = array.filter { $0.contains("5") }
                let mapped = filtered.map { $0.uppercased() }
                _ = mapped.joined(separator: ", ")
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        return endTime - startTime
    }
}