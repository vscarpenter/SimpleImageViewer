import Foundation
import UniformTypeIdentifiers

@main struct FolderProbe {
    static func main() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("StillViewFolderProbe-\(UUID().uuidString)", isDirectory: true)
        let outside = manager.temporaryDirectory.appendingPathComponent("StillViewOutsideProbe-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        try manager.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root); try? manager.removeItem(at: outside) }
        for folder in ["nested", ".hidden", "Sample.app/Contents/Resources"] {
            try manager.createDirectory(at: root.appendingPathComponent(folder, isDirectory: true), withIntermediateDirectories: true)
        }
        for path in ["visible.png", "nested/nested.png", ".hidden/hidden.png", "Sample.app/Contents/Resources/internal.png"] {
            try Data([0]).write(to: root.appendingPathComponent(path))
        }
        try Data([0]).write(to: outside.appendingPathComponent("outside.png"))
        try manager.createSymbolicLink(at: root.appendingPathComponent("link.png"), withDestinationURL: outside.appendingPathComponent("outside.png"))
        let service = DefaultFileSystemService()
        let shallow = try await service.scanFolder(root, recursive: false)
        let recursive = try await service.scanFolder(root, recursive: true)
        print("shallow=" + shallow.map { $0.name }.sorted().joined(separator: ","))
        print("recursive=" + recursive.map { $0.name }.sorted().joined(separator: ","))
        let repeated = try await service.scanFolder(root, recursive: true)
        let first = recursive.first { $0.name == "visible.png" }!
        let second = repeated.first { $0.name == "visible.png" }!
        print("repeat_equal=\(first == second) repeat_id_equal=\(first.id == second.id)")
        let canceledTask = Task { () throws -> (Bool, Int) in
            withUnsafeCurrentTask { $0?.cancel() }
            return (Task.isCancelled, try await service.scanFolder(root, recursive: true).count)
        }
        let canceled = try await canceledTask.value
        print("precanceled_recursive_flag=\(canceled.0) result_count=\(canceled.1)")
        let shallowCanceledTask = Task { () throws -> (Bool, Int) in
            withUnsafeCurrentTask { $0?.cancel() }
            return (Task.isCancelled, try await service.scanFolder(root, recursive: false).count)
        }
        let shallowCanceled = try await shallowCanceledTask.value
        print("precanceled_shallow_flag=\(shallowCanceled.0) result_count=\(shallowCanceled.1)")
    }
}
