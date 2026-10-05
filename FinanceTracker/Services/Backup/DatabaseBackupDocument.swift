import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    public static var ftbackup: UTType {
        UTType(exportedAs: "com.local.FinanceTracker.ftbackup", conformingTo: .data)
    }
}

/// Archive structure containing the complete database state for cross-device migration.
public struct DatabaseBackupArchive: Codable {
    public let appVersion: String
    public let exportedAt: Date
    public let storeData: Data?
    public let shmData: Data?
    public let walData: Data?
}

/// Document handling full export and import of SwiftData SQLite database files (.store, .store-shm, .store-wal).
public struct DatabaseBackupDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.ftbackup, .data] }

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
        if let data = configuration.file.regularFileContents {
            if let archive = try? PropertyListDecoder().decode(DatabaseBackupArchive.self, from: data) {
                self.storeData = archive.storeData
                self.shmData = archive.shmData
                self.walData = archive.walData
                return
            } else {
                self.storeData = data
                return
            }
        }
        
        if let wrappers = configuration.file.fileWrappers {
            storeData = wrappers["default.store"]?.regularFileContents
            shmData = wrappers["default.store-shm"]?.regularFileContents
            walData = wrappers["default.store-wal"]?.regularFileContents
        }
    }

    public init(url: URL) throws {
        // Try reading directory package first (legacy support)
        if let wrapper = try? FileWrapper(url: url, options: []), wrapper.isDirectory {
            if let wrappers = wrapper.fileWrappers {
                storeData = wrappers["default.store"]?.regularFileContents
                shmData = wrappers["default.store-shm"]?.regularFileContents
                walData = wrappers["default.store-wal"]?.regularFileContents
                return
            }
        }

        // Single file binary archive support
        let data = try Data(contentsOf: url)
        if let archive = try? PropertyListDecoder().decode(DatabaseBackupArchive.self, from: data) {
            self.storeData = archive.storeData
            self.shmData = archive.shmData
            self.walData = archive.walData
        } else {
            // Direct SQLite file fallback
            self.storeData = data
        }
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let archive = DatabaseBackupArchive(
            appVersion: "1.10.1",
            exportedAt: Date(),
            storeData: storeData,
            shmData: shmData,
            walData: walData
        )
        let data = (try? PropertyListEncoder().encode(archive)) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
    
    /// Generates a single `.ftbackup` archive in the temporary directory ready for AirDrop sharing.
    public static func createExportFile() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let storeURL = appSupport.appendingPathComponent("default.store")
        let shmURL = appSupport.appendingPathComponent("default.store-shm")
        let walURL = appSupport.appendingPathComponent("default.store-wal")
        
        let storeData = try? Data(contentsOf: storeURL)
        let shmData = try? Data(contentsOf: shmURL)
        let walData = try? Data(contentsOf: walURL)
        
        let archive = DatabaseBackupArchive(
            appVersion: "1.10.1",
            exportedAt: Date(),
            storeData: storeData,
            shmData: shmData,
            walData: walData
        )
        
        guard let encoded = try? PropertyListEncoder().encode(archive) else { return nil }
        
        let tempDir = FileManager.default.temporaryDirectory
        let exportURL = tempDir.appendingPathComponent("FinanceTracker_Backup.ftbackup")
        do {
            try encoded.write(to: exportURL, options: .atomic)
            return exportURL
        } catch {
            print("❌ Failed to write export file: \(error.localizedDescription)")
            return nil
        }
    }
    
    public static func restore(from document: DatabaseBackupDocument) throws {
        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let storeURL = appSupport.appendingPathComponent("default.store")
        let shmURL = appSupport.appendingPathComponent("default.store-shm")
        let walURL = appSupport.appendingPathComponent("default.store-wal")
        
        // Remove existing database files
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

    public static func restore(from url: URL) throws {
        let doc = try DatabaseBackupDocument(url: url)
        try restore(from: doc)
    }
}
