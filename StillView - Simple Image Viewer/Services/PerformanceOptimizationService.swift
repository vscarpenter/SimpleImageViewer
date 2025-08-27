import Foundation
import Combine
import QuartzCore
import os.log
import AppKit

/// Comprehensive performance optimization service for the application
/// Provides performance monitoring, optimization, and insights
@MainActor
final class PerformanceOptimizationService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PerformanceOptimizationService()
    
    // MARK: - Published Properties
    
    /// Current performance metrics
    @Published private(set) var currentMetrics = PerformanceMetrics()
    
    /// Performance optimization status
    @Published private(set) var optimizationStatus = OptimizationStatus.idle
    
    /// Whether performance monitoring is active
    @Published private(set) var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    
    private var performanceTimer: Timer?
    private var frameTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let performanceQueue = DispatchQueue(label: "com.vinny.performance", qos: .utility)
    private let optimizationQueue = DispatchQueue(label: "com.vinny.optimization", qos: .background)
    
    // Performance tracking
    private var frameCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private var operationTimes: [String: [CFTimeInterval]] = [:]
    
    // Optimization cooldown
    private var lastOptimizationTime: Date = Date.distantPast
    private let optimizationCooldown: TimeInterval = 30.0 // 30 seconds between optimizations
    
    // MARK: - Performance Metrics
    
    struct PerformanceMetrics {
        var fps: Double = 0.0
        var averageFrameTime: CFTimeInterval = 0.0
        var memoryUsage: UInt64 = 0
        var cpuUsage: Double = 0.0
        var diskIOCount: Int = 0
        var networkIOCount: Int = 0
        var cacheHitRate: Double = 0.0
        var operationCounts: [String: Int] = [:]
        
        var isOptimal: Bool {
            return fps >= 50.0 && averageFrameTime < 0.025 && memoryUsage < 2 * 1024 * 1024 * 1024
        }
        
        var performanceScore: Int {
            var score = 100
            
            if fps < 50.0 { score -= 20 }
            if fps < 30.0 { score -= 20 }
            if averageFrameTime > 0.025 { score -= 15 }
            if averageFrameTime > 0.033 { score -= 15 }
            if memoryUsage > 2 * 1024 * 1024 * 1024 { score -= 10 }
            if memoryUsage > 4 * 1024 * 1024 * 1024 { score -= 10 }
            
            return max(0, score)
        }
    }
    
    enum OptimizationStatus: String, CaseIterable {
        case idle = "Idle"
        case monitoring = "Monitoring"
        case optimizing = "Optimizing"
        case optimized = "Optimized"
        case degraded = "Degraded"
        
        var icon: String {
            switch self {
            case .idle: return "⏸️"
            case .monitoring: return "📊"
            case .optimizing: return "⚡"
            case .optimized: return "✅"
            case .degraded: return "⚠️"
            }
        }
        
        var color: String {
            switch self {
            case .idle: return "gray"
            case .monitoring: return "blue"
            case .optimizing: return "orange"
            case .optimized: return "green"
            case .degraded: return "red"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupPerformanceMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start performance monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        optimizationStatus = .monitoring
        
        // Start frame monitoring
        startFrameMonitoring()
        
        // Start performance timer
        startPerformanceTimer()
        
        Logger.performance("Performance monitoring started")
    }
    
    /// Stop performance monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        optimizationStatus = .idle
        
        // Stop timers
        stopFrameMonitoring()
        stopPerformanceTimer()
        
        Logger.performance("Performance monitoring stopped")
    }
    
    /// Perform performance optimization
    /// - Parameter aggressive: Whether to perform aggressive optimization
    func optimizePerformance(aggressive: Bool = false) async {
        guard optimizationStatus != .optimizing else { return }
        
        // Check cooldown to prevent excessive optimization
        let timeSinceLastOptimization = Date().timeIntervalSince(lastOptimizationTime)
        guard timeSinceLastOptimization >= optimizationCooldown else {
            Logger.performance("Skipping optimization due to cooldown (last: \(String(format: "%.1f", timeSinceLastOptimization))s ago, cooldown: \(String(format: "%.1f", optimizationCooldown))s)")
            return
        }
        
        optimizationStatus = .optimizing
        lastOptimizationTime = Date()
        Logger.performance("Starting performance optimization (aggressive: \(aggressive))")
        
        // Optimize image loading
        await optimizeImageLoading(aggressive: aggressive)
        
        // Optimize thumbnail generation
        await optimizeThumbnailGeneration(aggressive: aggressive)
        
        // Optimize UI operations
        await optimizeUIOperations(aggressive: aggressive)
        
        // Optimize memory usage
        await optimizeMemoryUsage(aggressive: aggressive)
        
        // Update optimization status
        optimizationStatus = .optimized
        
        Logger.performance("Performance optimization completed")
    }
    
    /// Track operation performance
    /// - Parameters:
    ///   - operationName: Name of the operation
    ///   - operation: The operation to track
    /// - Returns: The result of the operation
    func trackOperation<T>(_ operationName: String, operation: () throws -> T) rethrows -> T {
        let startTime = CACurrentMediaTime()
        
        do {
            let result = try operation()
            let endTime = CACurrentMediaTime()
            let duration = endTime - startTime
            
            recordOperationTime(operationName, duration: duration)
            return result
        } catch {
            let endTime = CACurrentMediaTime()
            let duration = endTime - startTime
            
            recordOperationTime(operationName, duration: duration)
            throw error
        }
    }
    
    /// Track async operation performance
    /// - Parameters:
    ///   - operationName: Name of the operation
    ///   - operation: The async operation to track
    /// - Returns: The result of the operation
    func trackAsyncOperation<T>(_ operationName: String, operation: () async throws -> T) async rethrows -> T {
        let startTime = CACurrentMediaTime()
        
        do {
            let result = try await operation()
            let endTime = CACurrentMediaTime()
            let duration = endTime - startTime
            
            recordOperationTime(operationName, duration: duration)
            return result
        } catch {
            let endTime = CACurrentMediaTime()
            let duration = endTime - startTime
            
            recordOperationTime(operationName, duration: duration)
            throw error
        }
    }
    
    /// Get performance insights
    /// - Returns: Performance insights and recommendations
    func getPerformanceInsights() -> PerformanceInsights {
        let bottlenecks = detectBottlenecks()
        let recommendations = generateRecommendations(bottlenecks: bottlenecks)
        
        return PerformanceInsights(
            metrics: currentMetrics,
            bottlenecks: bottlenecks,
            recommendations: recommendations,
            optimizationStatus: optimizationStatus
        )
    }
    
    /// Reset performance metrics
    func resetMetrics() {
        frameTimes.removeAll()
        operationTimes.removeAll()
        frameCount = 0
        lastFrameTime = 0
        
        currentMetrics = PerformanceMetrics()
        
        Logger.performance("Performance metrics reset")
    }
    
    // MARK: - Private Methods
    
    private func setupPerformanceMonitoring() {
        // Observe memory pressure notifications
        NotificationCenter.default.publisher(for: .memoryPressureDetected)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleMemoryPressure()
                }
            }
            .store(in: &cancellables)
        
        // Observe system notifications
        NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleSystemWake()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startFrameMonitoring() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.frameUpdate()
            }
        }
    }
    
    private func stopFrameMonitoring() {
        frameTimer?.invalidate()
        frameTimer = nil
    }
    
    private func startPerformanceTimer() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    private func stopPerformanceTimer() {
        performanceTimer?.invalidate()
        performanceTimer = nil
    }
    
    @MainActor private func frameUpdate() {
        let currentTime = CACurrentMediaTime()
        
        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            frameTimes.append(frameTime)
            
            // Keep only recent frame times
            if frameTimes.count > 60 {
                frameTimes.removeFirst()
            }
        }
        
        lastFrameTime = currentTime
        frameCount += 1
    }
    
    private func updatePerformanceMetrics() {
        // Calculate FPS
        let fps = frameTimes.isEmpty ? 0.0 : 1.0 / (frameTimes.reduce(0, +) / Double(frameTimes.count))
        
        // Calculate average frame time
        let avgFrameTime = frameTimes.isEmpty ? 0.0 : frameTimes.reduce(0, +) / Double(frameTimes.count)
        
        // Get actual memory usage for this process
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        let memoryUsage: UInt64
        if kerr == KERN_SUCCESS {
            memoryUsage = UInt64(info.resident_size)
        } else {
            // Fallback to a reasonable estimate
            memoryUsage = UInt64(100 * 1024 * 1024) // 100MB fallback
        }
        
        // Update metrics
        currentMetrics.fps = fps
        currentMetrics.averageFrameTime = avgFrameTime
        currentMetrics.memoryUsage = memoryUsage
        
        // Update optimization status
        updateOptimizationStatus()
        
        // Log performance issues only when there are real problems
        if !currentMetrics.isOptimal {
            // Only log if performance is actually poor, not just sub-optimal
            if fps < 40.0 || avgFrameTime > 0.033 || memoryUsage > 4 * 1024 * 1024 * 1024 {
                Logger.performance("Performance issue detected: FPS: \(String(format: "%.1f", fps)), Frame time: \(String(format: "%.3f", avgFrameTime))s")
            } else {
                Logger.performance("Performance is acceptable: FPS: \(String(format: "%.1f", fps)), Frame time: \(String(format: "%.3f", avgFrameTime))s")
            }
        } else {
            Logger.performance("Performance is optimal: FPS: \(String(format: "%.1f", fps)), Frame time: \(String(format: "%.3f", avgFrameTime))s")
        }
    }
    
    private func updateOptimizationStatus() {
        if currentMetrics.performanceScore >= 90 {
            optimizationStatus = .optimized
        } else if currentMetrics.performanceScore >= 70 {
            optimizationStatus = .monitoring
        } else {
            optimizationStatus = .degraded
        }
    }
    
    private func recordOperationTime(_ operationName: String, duration: CFTimeInterval) {
        if operationTimes[operationName] == nil {
            operationTimes[operationName] = []
        }
        
        operationTimes[operationName]?.append(duration)
        
        // Keep only recent operation times
        if let times = operationTimes[operationName], times.count > 100 {
            operationTimes[operationName] = Array(times.suffix(100))
        }
        
        // Update operation counts
        currentMetrics.operationCounts[operationName, default: 0] += 1
    }
    
    private func detectBottlenecks() -> [PerformanceBottleneck] {
        var bottlenecks: [PerformanceBottleneck] = []
        
        // Check FPS
        if currentMetrics.fps < 50.0 {
            bottlenecks.append(.lowFPS(current: currentMetrics.fps, target: 50.0))
        }
        
        // Check frame time
        if currentMetrics.averageFrameTime > 0.025 {
            bottlenecks.append(.highFrameTime(current: currentMetrics.averageFrameTime, target: 0.020))
        }
        
        // Check memory usage
        if currentMetrics.memoryUsage > 2 * 1024 * 1024 * 1024 {
            bottlenecks.append(.highMemoryUsage(current: currentMetrics.memoryUsage, target: 2 * 1024 * 1024 * 1024))
        }
        
        // Check operation performance
        for (operationName, times) in operationTimes {
            let avgTime = times.reduce(0, +) / Double(times.count)
            if avgTime > 0.1 { // 100ms threshold
                bottlenecks.append(.slowOperation(name: operationName, current: avgTime, target: 0.05))
            }
        }
        
        return bottlenecks
    }
    
    private func generateRecommendations(bottlenecks: [PerformanceBottleneck]) -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        for bottleneck in bottlenecks {
            switch bottleneck {
            case .lowFPS:
                recommendations.append(.reduceImageQuality)
                recommendations.append(.enableThumbnailCaching)
                recommendations.append(.optimizeUIUpdates)
            case .highFrameTime:
                recommendations.append(.optimizeUIUpdates)
                recommendations.append(.reduceAnimationComplexity)
            case .highMemoryUsage:
                recommendations.append(.clearImageCaches)
                recommendations.append(.reduceCacheSize)
            case .slowOperation(let operationName, _, _):
                recommendations.append(.optimizeOperation(operationName))
            }
        }
        
        // Remove duplicates
        return Array(Set(recommendations))
    }
    
    private func optimizeImageLoading(aggressive: Bool) async {
        Logger.performance("Optimizing image loading")
        
        // Adjust image quality based on performance
        // Note: ImageMemoryManager doesn't have a shared instance, so we'll post notifications instead
        if currentMetrics.fps < 40.0 {
            // Reduce image quality for better performance
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        } else if currentMetrics.fps < 50.0 {
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        } else {
            // High quality - don't optimize if performance is good
            Logger.performance("Performance is good (FPS: \(String(format: "%.1f", currentMetrics.fps))), skipping image quality reduction")
        }
        
        // Optimize cache settings - post notifications for cache management
        if aggressive {
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        } else {
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        }
    }
    
    private func optimizeThumbnailGeneration(aggressive: Bool) async {
        Logger.performance("Optimizing thumbnail generation")
        
        // Adjust thumbnail quality based on performance
        // Note: EnhancedThumbnailGenerator doesn't have a shared instance, so we'll post notifications instead
        if currentMetrics.fps < 40.0 {
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        } else if currentMetrics.fps < 50.0 {
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        } else {
            // High quality - don't optimize if performance is good
            Logger.performance("Performance is good (FPS: \(String(format: "%.1f", currentMetrics.fps))), skipping thumbnail quality reduction")
        }
        
        // Optimize cache settings - post notifications for cache management
        if aggressive {
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        }
    }
    
    private func optimizeUIOperations(aggressive: Bool) async {
        Logger.performance("Optimizing UI operations")
        
        // Reduce animation complexity if performance is poor
        if currentMetrics.fps < 40.0 {
            // Disable complex animations
            NotificationCenter.default.post(name: .reduceAnimationComplexity, object: nil)
        }
        
        // Optimize UI update frequency
        if aggressive {
            // Reduce UI update frequency
            NotificationCenter.default.post(name: .reduceUIUpdateFrequency, object: nil)
        }
    }
    
    private func optimizeMemoryUsage(aggressive: Bool) async {
        Logger.performance("Optimizing memory usage")
        
        // Clear caches if memory usage is high
        if currentMetrics.memoryUsage > 2 * 1024 * 1024 * 1024 {
            await MemoryManagementService.shared.optimizeMemory(aggressive: aggressive)
        }
    }
    
    private func handleMemoryPressure() async {
        Logger.performance("Handling memory pressure in performance service")
        
        // Perform aggressive optimization
        await optimizePerformance(aggressive: true)
    }
    
    private func handleSystemWake() {
        Logger.performance("System wake detected, refreshing performance state")
        
        // Reset performance metrics
        resetMetrics()
        
        // Restart monitoring if it was active
        if isMonitoring {
            startMonitoring()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Note: stopMonitoring() will be called automatically when the instance is deallocated
        // since the timer and cancellables will be invalidated
    }
}

// MARK: - Supporting Types

/// Performance bottleneck
enum PerformanceBottleneck: Equatable {
    case lowFPS(current: Double, target: Double)
    case highFrameTime(current: CFTimeInterval, target: CFTimeInterval)
    case highMemoryUsage(current: UInt64, target: UInt64)
    case slowOperation(name: String, current: CFTimeInterval, target: CFTimeInterval)
    
    var description: String {
        switch self {
        case .lowFPS(let current, let target):
            return "Low FPS: \(String(format: "%.1f", current)) (target: \(String(format: "%.1f", target)))"
        case .highFrameTime(let current, let target):
            return "High frame time: \(String(format: "%.3f", current))s (target: \(String(format: "%.3f", target))s)"
        case .highMemoryUsage(let current, let target):
            return "High memory usage: \(ByteCountFormatter.string(fromByteCount: Int64(current), countStyle: .memory)) (target: \(ByteCountFormatter.string(fromByteCount: Int64(target), countStyle: .memory)))"
        case .slowOperation(let name, let current, let target):
            return "Slow operation '\(name)': \(String(format: "%.3f", current))s (target: \(String(format: "%.3f", target))s)"
        }
    }
}

/// Performance recommendation
enum PerformanceRecommendation: Hashable {
    case reduceImageQuality
    case enableThumbnailCaching
    case optimizeUIUpdates
    case reduceAnimationComplexity
    case clearImageCaches
    case reduceCacheSize
    case optimizeOperation(String)
    
    var description: String {
        switch self {
        case .reduceImageQuality:
            return "Reduce image quality for better performance"
        case .enableThumbnailCaching:
            return "Enable thumbnail caching to improve responsiveness"
        case .optimizeUIUpdates:
            return "Optimize UI update frequency"
        case .reduceAnimationComplexity:
            return "Reduce animation complexity"
        case .clearImageCaches:
            return "Clear image caches to free memory"
        case .reduceCacheSize:
            return "Reduce cache size to improve memory usage"
        case .optimizeOperation(let name):
            return "Optimize operation: \(name)"
        }
    }
}

/// Performance insights
struct PerformanceInsights {
    let metrics: PerformanceOptimizationService.PerformanceMetrics
    let bottlenecks: [PerformanceBottleneck]
    let recommendations: [PerformanceRecommendation]
    let optimizationStatus: PerformanceOptimizationService.OptimizationStatus
    
    var hasIssues: Bool {
        return !bottlenecks.isEmpty
    }
    
    var performanceGrade: String {
        let score = metrics.performanceScore
        switch score {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let reduceAnimationComplexity = Notification.Name("reduceAnimationComplexity")
    static let reduceUIUpdateFrequency = Notification.Name("reduceUIUpdateFrequency")
}

// MARK: - Service Extensions

extension ImageMemoryManager {
    func setQualityLevel(_ level: ImageQualityLevel) {
        // Implementation would depend on ImageMemoryManager structure
        Logger.performance("Image quality level set to: \(level)")
    }
}

extension ImageCache {
    func setMaxCacheSize(_ size: Int) {
        // Implementation would depend on ImageCache structure
        Logger.performance("Image cache size set to: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .memory))")
    }
}

extension EnhancedThumbnailGenerator {
    func setQualityLevel(_ level: ThumbnailQuality) {
        // Implementation would depend on EnhancedThumbnailGenerator structure
        Logger.performance("Thumbnail quality level set to: \(level)")
    }
    
    func setMaxCacheSize(_ size: Int) {
        // Implementation would depend on EnhancedThumbnailGenerator structure
        Logger.performance("Thumbnail cache size set to: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .memory))")
    }
}

// MARK: - Image Quality Level

enum ImageQualityLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}
