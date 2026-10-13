import Foundation
import XCTest
@testable import CallJournalCore

final class ArchiveRepositoryTests: XCTestCase {
    private var directory: URL!
    private var repository: ArchiveRepository!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CallJournalTests-\(UUID().uuidString)", isDirectory: true)
        repository = ArchiveRepository(directory: directory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        repository = nil
        directory = nil
    }

    private func archive(_ name: String) -> PhoneArchive {
        PhoneArchive(contacts: [JournalContact(name: name, phoneNumber: "10086")])
    }

    private func createDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func testFirstLaunchReturnsEmptyArchiveWithoutWritingFiles() {
        let loaded = repository.load()
        XCTAssertEqual(loaded.archive, PhoneArchive())
        XCTAssertNil(loaded.notice)
        XCTAssertFalse(loaded.requiresRecovery)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testSavingAndReloadingPersistsRecordAndMaintainsPreviousVersion() throws {
        let first = archive("第一次")
        let second = archive("第二次")
        try repository.save(first)
        XCTAssertEqual(repository.load().archive, first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.backupURL.path))
        try repository.save(second)
        let loaded = repository.load()
        XCTAssertEqual(loaded.archive, second)
        XCTAssertFalse(loaded.requiresRecovery)
        XCTAssertNil(loaded.notice)
        XCTAssertEqual(try JournalCodec.decode(repository.readLimited(repository.backupURL)), first)
    }

    func testInvalidArchiveNeverReplacesPrimaryOrBackup() throws {
        try repository.save(archive("第一次"))
        try repository.save(archive("第二次"))
        let primaryBefore = try Data(contentsOf: repository.fileURL)
        let backupBefore = try Data(contentsOf: repository.backupURL)
        var invalid = PhoneArchive()
        invalid.calls = [CallRecord(phoneNumber: "not a number")]
        XCTAssertThrowsError(try repository.save(invalid))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), primaryBefore)
        XCTAssertEqual(try Data(contentsOf: repository.backupURL), backupBefore)
    }

    func testCorruptPrimaryLoadsHealthyBackupAndRequiresExplicitRecovery() throws {
        let previous = archive("可恢复联系人")
        try repository.save(previous)
        try repository.save(archive("较新联系人"))
        let corrupt = Data("broken-primary".utf8)
        try corrupt.write(to: repository.fileURL)
        let loaded = repository.load()
        XCTAssertEqual(loaded.archive, previous)
        XCTAssertTrue(loaded.requiresRecovery)
        XCTAssertNotNil(loaded.notice)
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), corrupt)
        XCTAssertThrowsError(try repository.save(archive("禁止覆盖")))
        XCTAssertEqual(try JournalCodec.decode(repository.readLimited(repository.backupURL)), previous)
    }

    func testMissingPrimaryWithBackupAlsoRequiresExplicitRecovery() throws {
        try createDirectory()
        let previous = archive("只有副本")
        try JournalCodec.encode(previous).write(to: repository.backupURL)
        let loaded = repository.load()
        XCTAssertEqual(loaded.archive, previous)
        XCTAssertTrue(loaded.requiresRecovery)
        XCTAssertNotNil(loaded.notice)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))
    }

    func testUnrecoverableFilesAreKeptAndEditingMustBePaused() throws {
        try createDirectory()
        let primary = Data("broken-primary".utf8)
        let backup = Data("broken-backup".utf8)
        try primary.write(to: repository.fileURL)
        try backup.write(to: repository.backupURL)
        let loaded = repository.load()
        XCTAssertEqual(loaded.archive, PhoneArchive())
        XCTAssertTrue(loaded.requiresRecovery)
        XCTAssertNotNil(loaded.notice)
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), primary)
        XCTAssertEqual(try Data(contentsOf: repository.backupURL), backup)
    }

    func testRecoveryRetainsOriginalFilesAndWritesTwoHealthyCopies() throws {
        try createDirectory()
        let primary = Data("original-primary".utf8)
        let backup = Data("original-backup".utf8)
        try primary.write(to: repository.fileURL)
        try backup.write(to: repository.backupURL)
        let replacement = archive("恢复后的联系人")
        try repository.recover(with: replacement)
        let originals = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("recovered-") }
        XCTAssertEqual(originals.count, 2)
        let originalContents = try originals.map { try Data(contentsOf: $0) }
        XCTAssertTrue(originalContents.contains(primary))
        XCTAssertTrue(originalContents.contains(backup))
        XCTAssertEqual(repository.load().archive, replacement)
        XCTAssertFalse(repository.load().requiresRecovery)
        XCTAssertEqual(try JournalCodec.decode(repository.readLimited(repository.backupURL)), replacement)
    }

    func testInvalidRecoveryLeavesOriginalFilesUntouched() throws {
        try createDirectory()
        let primary = Data("original-primary".utf8)
        try primary.write(to: repository.fileURL)
        let invalid = PhoneArchive(schemaVersion: 999)
        XCTAssertThrowsError(try repository.recover(with: invalid))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), primary)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.map(\.lastPathComponent), [repository.fileURL.lastPathComponent])
    }

    func testBackupWriteFailureLeavesPrimaryIntact() throws {
        let first = archive("完整主数据")
        try repository.save(first)
        try FileManager.default.createDirectory(at: repository.backupURL, withIntermediateDirectories: true)
        XCTAssertThrowsError(try repository.save(archive("无法保存的新数据")))
        XCTAssertEqual(repository.load().archive, first)
        XCTAssertFalse(repository.load().requiresRecovery)
    }

    func testReadLimitedRejectsOversizedFilesAndDirectories() throws {
        try createDirectory()
        let oversized = directory.appendingPathComponent("oversized.json")
        try Data(repeating: 0, count: JournalCodec.maximumBytes + 1).write(to: oversized)
        XCTAssertThrowsError(try repository.readLimited(oversized))
        XCTAssertThrowsError(try repository.readLimited(directory))
    }

    func testReadLimitedAcceptsExactlyTheByteLimitWithoutTruncation() throws {
        try createDirectory()
        let file = directory.appendingPathComponent("exact-limit.json")
        let original = Data(repeating: 65, count: JournalCodec.maximumBytes)
        try original.write(to: file)
        XCTAssertEqual(try repository.readLimited(file), original)
    }
}
