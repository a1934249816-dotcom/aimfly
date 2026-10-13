import Foundation

struct ArchiveLoadResult {
    var archive: PhoneArchive
    var notice: String?
    var requiresRecovery: Bool = false
}

// No networking or third-party services. All mutations are atomic local file writes.
final class ArchiveRepository {
    let directory: URL
    var fileURL: URL { directory.appendingPathComponent("phone-journal.json") }
    var backupURL: URL { directory.appendingPathComponent("phone-journal.previous.json") }

    init(directory: URL) { self.directory = directory }

    func load() -> ArchiveLoadResult {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else {
            if manager.fileExists(atPath: backupURL.path) { return recoverBackup() }
            return ArchiveLoadResult(archive: PhoneArchive())
        }
        do {
            return ArchiveLoadResult(archive: try JournalCodec.decode(readLimited(fileURL)))
        } catch {
            return recoverBackup()
        }
    }

    private func recoverBackup() -> ArchiveLoadResult {
        do {
            let archive = try JournalCodec.decode(readLimited(backupURL))
            return ArchiveLoadResult(archive: archive,
                notice: "主数据文件无法读取，已载入上一次保存的副本。请先导出备份，再前往设置确认恢复。",
                requiresRecovery: true)
        } catch {
            return ArchiveLoadResult(archive: PhoneArchive(),
                notice: "本地数据文件无法读取，原文件已保留。为避免覆盖，编辑已暂停；可以在设置中导入备份，或确认重建空资料库。",
                requiresRecovery: true)
        }
    }

    func readLimited(_ url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw JournalError.invalid("请选择普通 JSON 备份文件。") }
        let size = values.fileSize ?? 0
        guard size <= JournalCodec.maximumBytes else { throw JournalError.invalid("文件不能超过 10 MB。") }
        // The file may grow after the size check. Read at most the limit plus
        // one byte so an oversized import cannot allocate an unbounded Data.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= JournalCodec.maximumBytes {
            let requested = min(65_536, JournalCodec.maximumBytes + 1 - data.count)
            guard let chunk = try handle.read(upToCount: requested), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard data.count <= JournalCodec.maximumBytes else { throw JournalError.invalid("文件不能超过 10 MB。") }
        return data
    }

    func save(_ archive: PhoneArchive) throws {
        let data = try JournalCodec.encode(archive)
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        if manager.fileExists(atPath: fileURL.path) {
            let previous = try readLimited(fileURL)
            // Never replace a healthy backup with a corrupt primary file.
            _ = try JournalCodec.decode(previous)
            try write(previous, to: backupURL)
        }
        try write(data, to: fileURL)
    }

    func recover(with archive: PhoneArchive) throws {
        let data = try JournalCodec.encode(archive)
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        // Keep both original files for diagnosis; never delete them as part of recovery.
        let stamp = UUID().uuidString
        for url in [fileURL, backupURL] where manager.fileExists(atPath: url.path) {
            try manager.copyItem(at: url, to: directory.appendingPathComponent("recovered-\(stamp)-\(url.lastPathComponent)"))
        }
        try write(data, to: fileURL)
        try write(data, to: backupURL)
    }

    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
