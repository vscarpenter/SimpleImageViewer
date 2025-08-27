import Foundation
import Combine
import os.log

/// Comprehensive memory management service for the application
/// Provides memory monitoring, leak detection, and optimization features
@MainActor
final class MemoryManagementService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = MemoryManagementService()
    
    // MARK: - Published Properties
    
    /// Current memory usage in bytes
    @Published private(set) var currentMemoryUsage: UInt64 = 0
    
    /// Peak memory usage in bytes
    @Published private(set) var peakMemoryUsage: UInt64 = 0
    
    /// Available system memory in bytes
    @Published private(set) var availableSystemMemory: UInt64 = 0
    
    /// Memory pressure level
    @Published private(set) var memoryPressureLevel: MemoryPressureLevel = .normal
    
    /// Whether memory optimization is active
    @Published private(set) var isOptimizing: Bool = false
    
    // MARK: - Private Properties
    
    private var memoryTimer: Timer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var cancellables = Set<AnyCancellable>()
    private let memoryQueue = DispatchQueue(label: "com.vinny.memory-management", qos: .utility)
    
    // MARK: - Memory Pressure Levels
    
    enum MemoryPressureLevel: String, CaseIterable {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
        
        var threshold: Double {
            switch self {
            case .normal: return 0.7
            case .warning: return 0.85
            case .critical: return 0.95
            }
        }
        
        var color: String {
            switch self {
            case .normal: return "🟢"
            case .warning: return "🟡"
            case .critical: return "🔴"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryMonitoring()
        setupMemoryPressureHandling()
        startPeriodicMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Get current memory usage statistics
    /// - Returns: Memory usage information
    func getMemoryStats() -> MemoryStats {
        return MemoryStats(
            currentUsage: currentMemoryUsage,
            peakUsage: peakMemoryUsage,
            availableSystem: availableSystemMemory,
            pressureLevel: memoryPressureLevel,
            usagePercentage: Double(currentMemoryUsage) / Double(availableSystemMemory)
        )
    }
    
    /// Perform memory optimization
    /// - Parameter aggressive: Whether to perform aggressive cleanup
    func optimizeMemory(aggressive: Bool = false) async {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        Logger.performance("Starting memory optimization (aggressive: \(aggressive))")
        
        // Clear image caches
        await clearImageCaches(aggressive: aggressive)
        
        // Clear thumbnail caches
        await clearThumbnailCaches(aggressive: aggressive)
        
        // Clear preview caches
        await clearPreviewCaches(aggressive: aggressive)
        
        // Force garbage collection if aggressive
        if aggressive {
            await forceGarbageCollection()
        }
        
        // Update memory stats
        await updateMemoryStats()
        
        isOptimizing = false
        Logger.performance("Memory optimization completed")
    }
    
    /// Check for potential memory leaks
    /// - Returns: Array of potential leak indicators
    func detectMemoryLeaks() -> [MemoryLeakIndicator] {
        var indicators: [MemoryLeakIndicator] = []
        
        // Check for excessive memory usage
        let usagePercentage = Double(currentMemoryUsage) / Double(availableSystemMemory)
        if usagePercentage > 0.8 {
            indicators.append(.excessiveUsage(percentage: usagePercentage))
        }
        
        // Check for rapid memory growth
        if let growthRate = calculateMemoryGrowthRate(), growthRate > 0.1 {
            indicators.append(.rapidGrowth(rate: growthRate))
        }
        
        // Check for memory pressure
        if memoryPressureLevel != .normal {
            indicators.append(.memoryPressure(level: memoryPressureLevel))
        }
        
        return indicators
    }
    
    /// Register a memory-intensive operation
    /// - Parameter operation: The operation to register
    func registerMemoryOperation(_ operation: MemoryOperation) {
        Logger.performance("Memory operation registered: \(operation.description)")
        
        // Track memory usage before and after
        let beforeUsage = currentMemoryUsage
        
        // Perform the operation
        operation.execute()
        
        // Check memory impact
        let afterUsage = currentMemoryUsage
        let impact = afterUsage > beforeUsage ? afterUsage - beforeUsage : 0
        
        if impact > 10 * 1024 * 1024 { // 10MB threshold
            Logger.performance("Memory operation impact: \(ByteCountFormatter.string(fromByteCount: Int64(impact), countStyle: .memory))")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryMonitoring() {
        // Initial memory stats
        updateMemoryStats()
        
        // Set up memory pressure source
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: memoryQueue)
        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }
        memoryPressureSource?.resume()
    }
    
    private func setupMemoryPressureHandling() {
        // Memory pressure is handled by DispatchSource.makeMemoryPressureSource in init()
        // This method is kept for potential future use with other memory-related notifications
    }
    
    private func startPeriodicMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryStats()
                self?.checkMemoryHealth()
            }
        }
    }
    
    private func updateMemoryStats() {
        let processInfo = ProcessInfo.processInfo
        
        // Get actual memory usage for this process
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            currentMemoryUsage = UInt64(info.resident_size)
        } else {
            // Fallback to a reasonable estimate
            currentMemoryUsage = UInt64(100 * 1024 * 1024) // 100MB fallback
        }
        
        // Get total system memory
        availableSystemMemory = processInfo.physicalMemory
        
        // Update peak usage
        if currentMemoryUsage > peakMemoryUsage {
            peakMemoryUsage = currentMemoryUsage
        }
        
        // Update memory pressure level
        let usagePercentage = Double(currentMemoryUsage) / Double(availableSystemMemory)
        memoryPressureLevel = MemoryPressureLevel.allCases.first { usagePercentage <= $0.threshold } ?? .critical
        
        Logger.performance("Memory stats updated: \(ByteCountFormatter.string(fromByteCount: Int64(currentMemoryUsage), countStyle: .memory)) / \(ByteCountFormatter.string(fromByteCount: Int64(availableSystemMemory), countStyle: .memory)) (\(Int(usagePercentage * 100))%)")
    }
    
    private func handleMemoryPressure() {
        Logger.performance("Memory pressure detected: \(memoryPressureLevel.rawValue)")
        
        // Perform automatic memory optimization
        Task {
            await optimizeMemory(aggressive: memoryPressureLevel == .critical)
        }
        
        // Notify other services
        NotificationCenter.default.post(name: .memoryPressureDetected, object: memoryPressureLevel)
    }
    
    private func checkMemoryHealth() {
        let leaks = detectMemoryLeaks()
        if !leaks.isEmpty {
            Logger.warning("Memory health issues detected: \(leaks.count) indicators")
            
            for leak in leaks {
                Logger.warning("Memory issue: \(leak.description)")
            }
            
            // Auto-optimize if critical
            if memoryPressureLevel == .critical {
                Task {
                    await optimizeMemory(aggressive: true)
                }
            }
        }
    }
    
    private func clearImageCaches(aggressive: Bool) async {
        // Note: ImageCache and ImageMemoryManager instances should be injected
        // For now, we'll post notifications to clear caches
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
        
        if aggressive {
            // Post additional notification for aggressive clearing
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        }
    }
    
    private func clearThumbnailCaches(aggressive: Bool) async {
        // Note: EnhancedThumbnailGenerator instances should be injected
        // For now, we'll post notifications to clear caches
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
        
        if aggressive {
            // Post additional notification for aggressive clearing
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        }
    }
    
    private func clearPreviewCaches(aggressive: Bool) async {
        // Note: PreviewGeneratorService instances should be injected
        // For now, we'll post notifications to clear caches
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
        
        if aggressive {
            // Post additional notification for aggressive clearing
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
        }
    }
    
    private func forceGarbageCollection() async {
        // Force garbage collection (if available)
        #if DEBUG
        Logger.performance("Forcing garbage collection")
        #endif
        
        // Clear autorelease pools
        autoreleasepool {
            // Force cleanup of temporary objects
        }
    }
    
    private func calculateMemoryGrowthRate() -> Double? {
        // Calculate memory growth rate over time
        // This would need historical data to be meaningful
        return nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        memoryTimer?.invalidate()
        memoryPressureSource?.cancel()
    }
}

// MARK: - Supporting Types

/// Memory usage statistics
struct MemoryStats {
    let currentUsage: UInt64
    let peakUsage: UInt64
    let availableSystem: UInt64
    let pressureLevel: MemoryManagementService.MemoryPressureLevel
    let usagePercentage: Double
    
    var formattedCurrentUsage: String {
        return ByteCountFormatter.string(fromByteCount: Int64(currentUsage), countStyle: .memory)
    }
    
    var formattedPeakUsage: String {
        return ByteCountFormatter.string(fromByteCount: Int64(peakUsage), countStyle: .memory)
    }
    
    var formattedAvailableSystem: String {
        return ByteCountFormatter.string(fromByteCount: Int64(availableSystem), countStyle: .memory)
    }
}

/// Memory leak indicator
enum MemoryLeakIndicator {
    case excessiveUsage(percentage: Double)
    case rapidGrowth(rate: Double)
    case memoryPressure(level: MemoryManagementService.MemoryPressureLevel)
    
    var description: String {
        switch self {
        case .excessiveUsage(let percentage):
            return "Excessive memory usage: \(Int(percentage * 100))%"
        case .rapidGrowth(let rate):
            return "Rapid memory growth: \(Int(rate * 100))% per minute"
        case .memoryPressure(let level):
            return "Memory pressure: \(level.rawValue)"
        }
    }
}

/// Memory operation protocol
protocol MemoryOperation {
    var description: String { get }
    func execute()
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryPressureDetected = Notification.Name("memoryPressureDetected")
}

// MARK: - Service Extensions

extension EnhancedThumbnailGenerator {
    func clearAllCaches() {
        clearThumbnailCache()
        // Additional cache clearing if needed
    }
}

extension PreviewGeneratorService {
    func clearAllCaches() {
        // Note: This method should be implemented or the call should be removed
        // For now, we'll post a notification to clear caches
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
        // Additional cache clearing if needed
    }
}
