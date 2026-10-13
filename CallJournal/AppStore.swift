import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var archive: PhoneArchive
    @Published private(set) var requiresRecovery: Bool
    @Published var notice: String?
    @Published var activeCall: LocalCallSession?
    private let repository: ArchiveRepository

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        repository = ArchiveRepository(directory: base.appendingPathComponent("CallJournal", isDirectory: true))
        let loaded = repository.load()
        archive = loaded.archive
        notice = loaded.notice
        requiresRecovery = loaded.requiresRecovery
    }

    private func change(_ operation: (inout PhoneArchive) throws -> Void) throws {
        guard !requiresRecovery else { throw JournalError.storage("请先在设置中恢复资料库或导入备份。") }
        var candidate = archive
        try operation(&candidate)
        candidate = try candidate.validated()
        try repository.save(candidate)
        archive = candidate
    }

    func save(_ call: CallRecord) throws { try change { try $0.upsert(call) } }
    func save(_ contact: JournalContact) throws { try change { try $0.upsert(contact) } }
    func deleteCalls(_ ids: Set<UUID>) throws { try change { $0.calls.removeAll { ids.contains($0.id) } } }
    func deleteContact(_ id: UUID) throws { try change { $0.deleteContact(id) } }
    func setPreferences(_ preferences: JournalPreferences) throws { try change { $0.preferences = preferences } }
    func clearCalls() throws { try change { $0.calls.removeAll() } }

    func toggleFavorite(_ contact: JournalContact) throws {
        var updated = contact
        updated.isFavorite.toggle()
        try save(updated)
    }

    func exportData() throws -> Data { try JournalCodec.encode(archive) }

    func prepareImport(from url: URL) throws -> PhoneArchive {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return try JournalCodec.decode(repository.readLimited(url))
    }

    func restore(_ candidate: PhoneArchive) throws {
        let valid = try candidate.validated()
        if requiresRecovery { try repository.recover(with: valid) }
        else { try repository.save(valid) }
        archive = valid
        requiresRecovery = false
        notice = nil
    }

    func confirmRecovery() throws { try restore(archive) }

    func startCall(number: String, name: String? = nil, contactID: UUID? = nil, label: String? = nil) throws {
        guard activeCall == nil else { return }
        let numberLabel = label ?? archive.contacts.first(where: { $0.id == contactID })?.label ?? "手机"
        let call = try CallRecord(contactID: contactID, nameOverride: name, phoneNumber: number, label: numberLabel,
                                  date: Date(), direction: .cancelled).validated()
        try save(call)
        let session = LocalCallSession(call: call, displayName: archive.displayName(for: call))
        activeCall = session
        session.scheduleConnection(for: call.id)
    }

    func addLine(number: String, contactID: UUID? = nil) throws {
        guard let session = activeCall, session.lines.count < 2, session.endedAt == nil else {
            throw JournalError.invalid("当前最多可以添加两路通话。")
        }
        let numberLabel = archive.contacts.first(where: { $0.id == contactID })?.label ?? "手机"
        let call = try CallRecord(contactID: contactID, phoneNumber: number, label: numberLabel,
                                  date: Date(), direction: .cancelled).validated()
        try save(call)
        session.addLine(call: call, displayName: archive.displayName(for: call))
    }

    func finishCall() throws {
        guard let session = activeCall else { return }
        if session.endedAt == nil { session.endedAt = Date() }
        try change { archive in
            for line in session.lines {
                var call = line.record
                call.direction = line.connectedAt == nil ? .cancelled : .outgoing
                call.durationSeconds = line.duration(at: session.endedAt ?? Date())
                try archive.upsert(call)
            }
        }
        session.cancelConnections()
        activeCall = nil
    }
}

struct LocalCallLine: Identifiable {
    let record: CallRecord
    let displayName: String
    var connectedAt: Date?
    var isHeld = false
    var id: UUID { record.id }
    func duration(at date: Date) -> Int {
        guard let start = connectedAt else { return 0 }
        return min(359_999, max(0, Int(date.timeIntervalSince(start))))
    }
}

// An in-app interaction model. It never uses CallKit, tel:, a microphone, or a network.
@MainActor
final class LocalCallSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var lines: [LocalCallLine]
    @Published var activeIndex = 0
    @Published var isMuted = false
    @Published var isSpeakerOn = false
    @Published var isMerged = false
    @Published var endedAt: Date?
    private var connectionTasks: [UUID: Task<Void, Never>] = [:]

    init(call: CallRecord, displayName: String) {
        lines = [LocalCallLine(record: call, displayName: displayName)]
    }

    var current: LocalCallLine { lines[activeIndex] }

    func scheduleConnection(for id: UUID) {
        connectionTasks[id] = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
            guard !Task.isCancelled, let self, self.endedAt == nil,
                  let index = self.lines.firstIndex(where: { $0.id == id }) else { return }
            self.lines[index].connectedAt = Date()
        }
    }

    func addLine(call: CallRecord, displayName: String) {
        lines[activeIndex].isHeld = true
        lines.append(LocalCallLine(record: call, displayName: displayName))
        activeIndex = lines.count - 1
        isMerged = false
        scheduleConnection(for: call.id)
    }

    func swapLines() {
        guard lines.count == 2 else { return }
        lines[activeIndex].isHeld = true
        activeIndex = 1 - activeIndex
        lines[activeIndex].isHeld = false
        isMerged = false
    }

    func mergeLines() {
        isMerged.toggle()
        for index in lines.indices { lines[index].isHeld = !isMerged && index != activeIndex }
    }

    func toggleHold() { lines[activeIndex].isHeld.toggle() }
    func cancelConnections() {
        connectionTasks.values.forEach { $0.cancel() }
        connectionTasks.removeAll()
    }
}
