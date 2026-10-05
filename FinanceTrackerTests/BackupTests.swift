import XCTest
import UniformTypeIdentifiers
@testable import FinanceTracker

final class BackupTests: XCTestCase {

    func testBackupExportAndArchiveEncoding() throws {
        var doc = DatabaseBackupDocument()
        doc.storeData = "mock-store-data".data(using: .utf8)
        doc.shmData = "mock-shm-data".data(using: .utf8)
        doc.walData = "mock-wal-data".data(using: .utf8)

        // Write to temporary file
        let archive = DatabaseBackupArchive(
            appVersion: "1.10.1",
            exportedAt: Date(),
            storeData: doc.storeData,
            shmData: doc.shmData,
            walData: doc.walData
        )
        let data = try PropertyListEncoder().encode(archive)
        XCTAssertFalse(data.isEmpty)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_backup.ftbackup")
        try data.write(to: tempURL)

        // Read back from URL
        let loadedDoc = try DatabaseBackupDocument(url: tempURL)
        XCTAssertEqual(loadedDoc.storeData, doc.storeData)
        XCTAssertEqual(loadedDoc.shmData, doc.shmData)
        XCTAssertEqual(loadedDoc.walData, doc.walData)

        try? FileManager.default.removeItem(at: tempURL)
    }

    func testCreateExportFileReturnsValidURL() {
        let exportURL = DatabaseBackupDocument.createExportFile()
        XCTAssertNotNil(exportURL)
        if let exportURL {
            XCTAssertTrue(exportURL.lastPathComponent.hasSuffix(".ftbackup"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        }
    }

    func testCreateExportFileOverwritesExistingDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let exportURL = tempDir.appendingPathComponent("FinanceTracker_Backup.ftbackup")
        
        // Simulate a legacy folder package left behind
        try? FileManager.default.removeItem(at: exportURL)
        try FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)

        // createExportFile should safely remove the legacy folder and write the new file
        let resultURL = DatabaseBackupDocument.createExportFile()
        XCTAssertNotNil(resultURL)
        XCTAssertEqual(resultURL?.path, exportURL.path)
        
        var isDirAfter: ObjCBool = true
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path, isDirectory: &isDirAfter))
        XCTAssertFalse(isDirAfter.boolValue) // Must be a regular file now, not a directory!
    }
}
