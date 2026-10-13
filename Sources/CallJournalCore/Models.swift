import Foundation

enum CallDirection: String, Codable, CaseIterable, Identifiable {
    case incoming, outgoing, missed, cancelled

    var id: String { rawValue }
    var title: String {
        switch self {
        case .incoming: return "来电"
        case .outgoing: return "去电"
        case .missed: return "未接来电"
        case .cancelled: return "已取消"
        }
    }
    var symbol: String {
        switch self {
        case .incoming: return "phone.arrow.down.left.fill"
        case .outgoing: return "phone.arrow.up.right.fill"
        case .missed: return "phone.down.fill"
        case .cancelled: return "phone.arrow.up.right.fill"
        }
    }
    var isUnanswered: Bool { self == .missed || self == .cancelled }
}

enum PhoneLayout: String, Codable, CaseIterable, Identifiable {
    case classic, unified
    var id: String { rawValue }
    var title: String { self == .classic ? "经典" : "统一" }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        }
    }
}

struct JournalPreferences: Codable, Equatable {
    var layout: PhoneLayout = .classic
    var appearance: AppAppearance = .light
}

struct JournalContact: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var phoneNumber: String
    var label: String = "手机"
    var isFavorite: Bool = false

    var displayName: String { name.trimmed.isEmpty ? phoneNumber : name }
    var initial: String { String(displayName.prefix(1)) }

    func validated() throws -> Self {
        var result = self
        result.name = name.trimmed
        result.phoneNumber = phoneNumber.trimmed
        result.label = label.trimmed.isEmpty ? "手机" : label.trimmed
        guard !result.name.isEmpty else { throw JournalError.invalid("请输入联系人姓名。") }
        try PhoneNumber.validate(result.phoneNumber)
        guard result.name.count <= 200, result.label.count <= 40 else {
            throw JournalError.invalid("姓名最多 200 字，号码标签最多 40 字。")
        }
        return result
    }
}

struct CallRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var contactID: UUID?
    // nil uses the linked contact's current name; a non-empty value overrides this call only.
    var nameOverride: String?
    // Historical numbers stay with the call when a contact changes their number.
    var phoneNumber: String
    var label: String = "手机"
    var date: Date = Date()
    var durationSeconds: Int = 0
    var direction: CallDirection = .incoming

    func validated(normalizeUnanswered: Bool = true) throws -> Self {
        var result = self
        result.phoneNumber = phoneNumber.trimmed
        result.nameOverride = nameOverride?.trimmed
        if result.nameOverride?.isEmpty == true { result.nameOverride = nil }
        result.label = label.trimmed.isEmpty ? "手机" : label.trimmed
        try PhoneNumber.validate(result.phoneNumber)
        guard (result.nameOverride?.count ?? 0) <= 200, result.label.count <= 40 else {
            throw JournalError.invalid("姓名或号码标签过长。")
        }
        guard (0...359_999).contains(durationSeconds) else {
            throw JournalError.invalid("通话时长应在 0 秒至 99 小时 59 分 59 秒之间。")
        }
        guard date.timeIntervalSince1970.isFinite,
              (-2_208_988_800..<7_258_118_400).contains(date.timeIntervalSince1970) else {
            throw JournalError.invalid("通话日期应在 1900 年至 2199 年之间。")
        }
        // The editor and exported ISO 8601 dates have whole-second precision.
        // Normalize here so a save/reload never silently changes the record.
        result.date = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
        if direction.isUnanswered {
            if !normalizeUnanswered && durationSeconds != 0 {
                throw JournalError.invalid("未接或已取消的通话时长必须是 0 秒。")
            }
            result.durationSeconds = 0
        }
        return result
    }
}

struct PhoneArchive: Codable, Equatable {
    static let currentVersion = 1
    static let maximumContacts = 5_000
    static let maximumCalls = 50_000
    var schemaVersion: Int = currentVersion
    var contacts: [JournalContact] = []
    var calls: [CallRecord] = []
    var preferences = JournalPreferences()

    func displayName(for call: CallRecord) -> String {
        if let name = call.nameOverride?.trimmed, !name.isEmpty { return name }
        if let contact = contacts.first(where: { $0.id == call.contactID }) { return contact.displayName }
        return call.phoneNumber
    }

    var sortedCalls: [CallRecord] {
        calls.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date
        }
    }

    var sortedContacts: [JournalContact] {
        contacts.sorted {
            let order = $0.displayName.compare($1.displayName,
                options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "zh_Hans_CN"))
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
    }

    func matchingCalls(query: String, missedOnly: Bool) -> [CallRecord] {
        let query = query.trimmed
        // A mixed name/number query (for example "张 138") must not turn into
        // an unrestricted number-only search merely because it contains digits.
        let digits = query.allSatisfy(PhoneNumber.isAllowedCharacter) ? PhoneNumber.normalized(query) : ""
        return sortedCalls.filter { call in
            guard !missedOnly || call.direction == .missed else { return false }
            return query.isEmpty
                || displayName(for: call).localizedStandardContains(query)
                || call.phoneNumber.localizedStandardContains(query)
                || (!digits.isEmpty && PhoneNumber.normalized(call.phoneNumber).contains(digits))
        }
    }

    mutating func upsert(_ contact: JournalContact) throws {
        let valid = try contact.validated()
        if let index = contacts.firstIndex(where: { $0.id == valid.id }) {
            contacts[index] = valid
        } else {
            guard contacts.count < Self.maximumContacts else {
                throw JournalError.invalid("最多支持 5,000 个联系人。")
            }
            contacts.append(valid)
        }
    }

    mutating func upsert(_ call: CallRecord) throws {
        let valid = try call.validated()
        if let id = valid.contactID, !contacts.contains(where: { $0.id == id }) {
            throw JournalError.invalid("找不到这条通话关联的联系人，请重新选择或取消关联。")
        }
        if let index = calls.firstIndex(where: { $0.id == valid.id }) {
            calls[index] = valid
        } else {
            guard calls.count < Self.maximumCalls else {
                throw JournalError.invalid("最多支持 50,000 条通话记录。")
            }
            calls.append(valid)
        }
    }

    mutating func deleteContact(_ id: UUID) {
        // Preserve names in history before removing the relationship.
        for index in calls.indices where calls[index].contactID == id {
            calls[index].nameOverride = displayName(for: calls[index])
            calls[index].contactID = nil
        }
        contacts.removeAll { $0.id == id }
    }

    func validated() throws -> Self {
        guard schemaVersion == Self.currentVersion else {
            throw JournalError.invalid("备份版本不受支持，请使用本版本 App 导出的备份。")
        }
        guard contacts.count <= Self.maximumContacts, calls.count <= Self.maximumCalls else {
            throw JournalError.invalid("最多支持 5,000 个联系人和 50,000 条通话记录。")
        }
        let contactIDs = Set(contacts.map(\.id))
        guard contactIDs.count == contacts.count, Set(calls.map(\.id)).count == calls.count else {
            throw JournalError.invalid("备份中有重复的记录 ID。")
        }
        var result = self
        result.contacts = try contacts.map { try $0.validated() }
        result.calls = try calls.map {
            if let id = $0.contactID, !contactIDs.contains(id) {
                throw JournalError.invalid("备份中有找不到对应联系人的通话记录。")
            }
            return try $0.validated(normalizeUnanswered: false)
        }
        return result
    }
}

enum PhoneNumber {
    private static let punctuation: Set<Character> = ["+", "*", "#", "-", "(", ")", " ", "\u{00A0}"]

    static func isAllowedCharacter(_ character: Character) -> Bool {
        punctuation.contains(character) || (character.wholeNumberValue.map { (0...9).contains($0) } ?? false)
    }

    static func normalized(_ value: String) -> String {
        value.compactMap { character -> String? in
            if let digit = character.wholeNumberValue, (0...9).contains(digit) { return String(digit) }
            if character == "*" || character == "#" { return String(character) }
            return nil
        }.joined()
    }

    static func validate(_ value: String) throws {
        guard !value.isEmpty, value.count <= 64,
              value.contains(where: { $0.wholeNumberValue != nil }) else {
            throw JournalError.invalid("请输入有效的电话号码，最多 64 个字符。")
        }
        guard value.allSatisfy(isAllowedCharacter),
              value.filter({ $0 == "+" }).count <= 1,
              !value.contains("+") || value.first == "+" else {
            throw JournalError.invalid("号码可包含数字、开头的 +、空格、括号、短横线、* 和 #。")
        }
    }
}

enum JournalError: LocalizedError, Equatable {
    case invalid(String)
    case storage(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let message), .storage(let message): return message
        }
    }
}

enum JournalCodec {
    static let maximumBytes = 10 * 1024 * 1024

    static func encode(_ archive: PhoneArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(archive.validated())
        guard data.count <= maximumBytes else { throw JournalError.invalid("备份文件不能超过 10 MB。") }
        return data
    }

    static func decode(_ data: Data) throws -> PhoneArchive {
        guard data.count <= maximumBytes else { throw JournalError.invalid("备份文件不能超过 10 MB。") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            // Browser backups use .000Z; native backups omit fractional seconds.
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date")
        }
        do {
            return try decoder.decode(PhoneArchive.self, from: data).validated()
        } catch let error as JournalError {
            throw error
        } catch {
            throw JournalError.invalid("无法读取备份：文件格式不正确或内容不完整。")
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
