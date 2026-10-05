import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    public static var ftbackup: UTType {
        UTType(exportedAs: "com.local.FinanceTracker.ftbackup", conformingTo: .package)
    }
}

public struct DatabaseBackupDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.ftbackup] }

    public var storeData: Data?
    public var shmData: Data?
    public var walData: Data?

    public init() {
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            storeData = try? Data(contentsOf: appSupport.appendingPathComponent("default.store"))
            shmData = try? Data(contentsOf: appSupport.appendingPathComponent("default.store-shm"))
            walData = try? Data(contentsOf: appSupport.appendingPathComponent("default.store-wal"))
        }
    }

    public init(configuration: ReadConfiguration) throws {
        let wrapper = configuration.file
        if let wrappers = wrapper.fileWrappers {
            storeData = wrappers["default.store"]?.regularFileContents
            shmData = wrappers["default.store-shm"]?.regularFileContents
            walData = wrappers["default.store-wal"]?.regularFileContents
        }
    }

    public init(url: URL) throws {
        let wrapper = try FileWrapper(url: url, options: [])
        if let wrappers = wrapper.fileWrappers {
            storeData = wrappers["default.store"]?.regularFileContents
            shmData = wrappers["default.store-shm"]?.regularFileContents
            walData = wrappers["default.store-wal"]?.regularFileContents
        }
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var wrappers: [String: FileWrapper] = [:]
        if let storeData {
            wrappers["default.store"] = FileWrapper(regularFileWithContents: storeData)
        }
        if let shmData {
            wrappers["default.store-shm"] = FileWrapper(regularFileWithContents: shmData)
        }
        if let walData {
            wrappers["default.store-wal"] = FileWrapper(regularFileWithContents: walData)
        }
        return FileWrapper(directoryWithFileWrappers: wrappers)
    }
    
    public static func restore(from document: DatabaseBackupDocument) throws {
        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let storeURL = appSupport.appendingPathComponent("default.store")
        let shmURL = appSupport.appendingPathComponent("default.store-shm")
        let walURL = appSupport.appendingPathComponent("default.store-wal")
        
        // Remove existing
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: shmURL)
        try? FileManager.default.removeItem(at: walURL)
        
        if let storeData = document.storeData {
            try storeData.write(to: storeURL, options: .atomic)
        }
        if let shmData = document.shmData {
            try shmData.write(to: shmURL, options: .atomic)
        }
        if let walData = document.walData {
            try walData.write(to: walURL, options: .atomic)
        }
    }
}
