import Foundation
import XCTest
@testable import CallJournalCore

final class ModelsTests: XCTestCase {
    func testNativeAndBrowserBackupDateCompatibility() throws {
        func decode(_ date: String) throws -> PhoneArchive {
            let object: [String: Any] = [
                "schemaVersion": 1, "contacts": [],
                "preferences": ["layout": "classic", "appearance": "light"],
                "calls": [["id": "00000000-0000-4000-8000-000000000001", "phoneNumber": "13800000000",
                           "label": "手机", "date": date, "durationSeconds": 12, "direction": "incoming"]]
            ]
            return try JournalCodec.decode(JSONSerialization.data(withJSONObject: object))
        }
        let native = try decode("2026-10-12T10:31:45Z")
        XCTAssertEqual(try decode("2026-10-12T10:31:45.000Z"), native)
        XCTAssertEqual(try decode("2026-10-12T10:31:45.123Z"), native)
        XCTAssertEqual(try decode("2026-10-12T18:31:45.000+08:00"), native)
        XCTAssertThrowsError(try decode("not-a-date"))
    }

    private func identifier(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
    }

    private func call(id: Int = 1, name: String? = nil, number: String = "13800138000",
                      date: TimeInterval = 1_760_000_000, duration: Int = 65,
                      direction: CallDirection = .incoming, contactID: UUID? = nil) -> CallRecord {
        CallRecord(id: identifier(id), contactID: contactID, nameOverride: name,
                   phoneNumber: number, date: Date(timeIntervalSince1970: date),
                   durationSeconds: duration, direction: direction)
    }

    func testContactValidationTrimsFieldsAndSuppliesDefaultLabel() throws {
        let contact = try JournalContact(name: "  王先生\n", phoneNumber: " +86 138-0013-8000 ", label: " ").validated()
        XCTAssertEqual(contact.name, "王先生")
        XCTAssertEqual(contact.phoneNumber, "+86 138-0013-8000")
        XCTAssertEqual(contact.label, "手机")
        XCTAssertThrowsError(try JournalContact(name: "\n ", phoneNumber: "10086").validated())
        XCTAssertThrowsError(try JournalContact(name: String(repeating: "王", count: 201), phoneNumber: "10086").validated())
    }

    func testPhoneNumberValidationAndUnicodeNormalization() throws {
        for valid in ["10086", "+86 (138) 0013-8000", "*123#", "１３８００１３８０００"] {
            XCTAssertNoThrow(try PhoneNumber.validate(valid), valid)
        }
        XCTAssertEqual(PhoneNumber.normalized("+86 (１３８)-0013 8000"), "8613800138000")
        for invalid in ["", "*#", "138+00", "++86138", "138abc", "138\n00", String(repeating: "1", count: 65)] {
            XCTAssertThrowsError(try PhoneNumber.validate(invalid), invalid)
        }
    }

    func testCallNormalizationAndWholeSecondPrecision() throws {
        var original = call(name: "  张女士  ", number: " 10010 ", date: 1_760_000_000.75)
        original.label = " "
        let valid = try original.validated()
        XCTAssertEqual(valid.nameOverride, "张女士")
        XCTAssertEqual(valid.phoneNumber, "10010")
        XCTAssertEqual(valid.label, "手机")
        XCTAssertEqual(valid.date.timeIntervalSince1970, 1_760_000_000)
        original.nameOverride = "  "
        XCTAssertNil(try original.validated().nameOverride)
        XCTAssertEqual(try call(date: -0.1).validated().date.timeIntervalSince1970, -1)
    }

    func testDurationAndUnansweredConstraints() throws {
        XCTAssertEqual(try call(duration: 359_999).validated().durationSeconds, 359_999)
        XCTAssertThrowsError(try call(duration: -1).validated())
        XCTAssertThrowsError(try call(duration: 360_000).validated())
        for direction in [CallDirection.missed, .cancelled] {
            XCTAssertEqual(try call(duration: 65, direction: direction).validated().durationSeconds, 0)
            XCTAssertThrowsError(try call(duration: 65, direction: direction).validated(normalizeUnanswered: false))
            XCTAssertNoThrow(try call(duration: 0, direction: direction).validated(normalizeUnanswered: false))
        }
    }

    func testSupportedDateRangeAndNonfiniteDates() throws {
        XCTAssertNoThrow(try call(date: -2_208_988_800).validated())
        XCTAssertNoThrow(try call(date: 7_258_118_399.75).validated())
        for invalid in [-2_208_988_801.0, 7_258_118_400, Double.infinity, Double.nan] {
            XCTAssertThrowsError(try call(date: invalid).validated())
        }
    }

    func testLinkedNameTracksContactWhileHistoricalNumberStaysUnchanged() throws {
        var archive = PhoneArchive()
        var contact = JournalContact(id: identifier(10), name: "原姓名", phoneNumber: "10086")
        try archive.upsert(contact)
        let linked = call(number: "10086", contactID: contact.id)
        try archive.upsert(linked)
        contact.name = "新姓名"
        contact.phoneNumber = "10010"
        try archive.upsert(contact)
        XCTAssertEqual(archive.displayName(for: archive.calls[0]), "新姓名")
        XCTAssertEqual(archive.calls[0].phoneNumber, "10086")
        XCTAssertEqual(archive.contacts.count, 1)
    }

    func testNameOverrideAffectsOnlyThatCall() throws {
        let contact = JournalContact(id: identifier(10), name: "联系人", phoneNumber: "10086")
        var archive = PhoneArchive(contacts: [contact])
        try archive.upsert(call(id: 1, name: " 本次名称 ", contactID: contact.id))
        try archive.upsert(call(id: 2, contactID: contact.id))
        XCTAssertEqual(archive.displayName(for: archive.calls[0]), "本次名称")
        XCTAssertEqual(archive.displayName(for: archive.calls[1]), "联系人")
        XCTAssertEqual(archive.contacts[0].name, "联系人")
    }

    func testDeletingContactPreservesNamesAndRemovesRelationships() throws {
        let contact = JournalContact(id: identifier(10), name: "王先生", phoneNumber: "10086")
        var archive = PhoneArchive(contacts: [contact], calls: [
            call(id: 1, contactID: contact.id),
            call(id: 2, name: "个人备注", contactID: contact.id),
            call(id: 3, number: "10010")
        ])
        archive.deleteContact(contact.id)
        XCTAssertTrue(archive.contacts.isEmpty)
        XCTAssertEqual(archive.calls[0].nameOverride, "王先生")
        XCTAssertEqual(archive.calls[1].nameOverride, "个人备注")
        XCTAssertNil(archive.calls[0].contactID)
        XCTAssertNil(archive.calls[1].contactID)
        XCTAssertNil(archive.calls[2].nameOverride)
        XCTAssertEqual(archive.displayName(for: archive.calls[2]), "10010")
        XCTAssertNoThrow(try archive.validated())
    }

    func testCallUpsertReplacesExistingRecordAndRejectsDanglingContactWithoutMutation() throws {
        var archive = PhoneArchive()
        try archive.upsert(call(id: 1))
        var update = archive.calls[0]
        update.durationSeconds = 130
        try archive.upsert(update)
        XCTAssertEqual(archive.calls.count, 1)
        XCTAssertEqual(archive.calls[0].durationSeconds, 130)
        let before = archive
        XCTAssertThrowsError(try archive.upsert(call(id: 2, contactID: identifier(999))))
        XCTAssertEqual(archive, before)
    }

    func testSearchFindsNamesAndFormattedNumbersAndFiltersMissedCalls() throws {
        let contact = JournalContact(id: identifier(10), name: "Alice", phoneNumber: "13800138000")
        let archive = PhoneArchive(contacts: [contact], calls: [
            call(id: 1, number: "+86 138-0013-8000", contactID: contact.id),
            call(id: 2, name: "张先生", number: "10010", duration: 0, direction: .missed),
            call(id: 3, name: "李女士", number: "10086", duration: 0, direction: .cancelled)
        ])
        XCTAssertEqual(archive.matchingCalls(query: " alice ", missedOnly: false).map(\.id), [identifier(1)])
        XCTAssertEqual(archive.matchingCalls(query: "138 0013", missedOnly: false).map(\.id), [identifier(1)])
        XCTAssertEqual(archive.matchingCalls(query: "张", missedOnly: false).map(\.id), [identifier(2)])
        XCTAssertEqual(archive.matchingCalls(query: "", missedOnly: true).map(\.id), [identifier(2)])
        XCTAssertTrue(archive.matchingCalls(query: "Alice 100", missedOnly: false).isEmpty)
        XCTAssertTrue(archive.matchingCalls(query: "不存在", missedOnly: false).isEmpty)
    }

    func testSortingIsNewestFirstWithDeterministicEqualDateAndNameOrder() {
        let archive = PhoneArchive(contacts: [
            JournalContact(id: identifier(5), name: "Alice", phoneNumber: "10086"),
            JournalContact(id: identifier(4), name: "alice", phoneNumber: "10010"),
            JournalContact(id: identifier(3), name: "Bob", phoneNumber: "10000")
        ], calls: [call(id: 2, date: 100), call(id: 1, date: 100), call(id: 3, date: 200)])
        XCTAssertEqual(archive.sortedCalls.map(\.id), [identifier(3), identifier(1), identifier(2)])
        XCTAssertEqual(archive.sortedContacts.map(\.id), [identifier(4), identifier(5), identifier(3)])
    }

    func testArchiveValidationRejectsUnsupportedVersionDuplicatesAndOrphans() {
        let contact = JournalContact(id: identifier(10), name: "王先生", phoneNumber: "10086")
        XCTAssertThrowsError(try PhoneArchive(schemaVersion: 2).validated())
        XCTAssertThrowsError(try PhoneArchive(contacts: [contact, contact]).validated())
        XCTAssertThrowsError(try PhoneArchive(calls: [call(id: 1), call(id: 1)]).validated())
        XCTAssertThrowsError(try PhoneArchive(calls: [call(contactID: contact.id)]).validated())
        XCTAssertThrowsError(try PhoneArchive(calls: [call(duration: 10, direction: .missed)]).validated())
    }

    func testRecordCountLimitsRejectInsertionButAllowReplacingExistingRecords() throws {
        var archive = PhoneArchive(contacts: (1...PhoneArchive.maximumContacts).map {
            JournalContact(id: identifier($0), name: "联系人\($0)", phoneNumber: "10086")
        })
        XCTAssertThrowsError(try archive.upsert(JournalContact(id: identifier(6_000), name: "额外联系人", phoneNumber: "10086")))
        var edited = archive.contacts[0]
        edited.name = "修改后的姓名"
        XCTAssertNoThrow(try archive.upsert(edited))
        XCTAssertEqual(archive.contacts.count, PhoneArchive.maximumContacts)

        archive.calls = (1...PhoneArchive.maximumCalls).map { call(id: $0) }
        XCTAssertThrowsError(try archive.upsert(call(id: 60_000)))
        var editedCall = archive.calls[0]
        editedCall.durationSeconds = 1
        XCTAssertNoThrow(try archive.upsert(editedCall))
        XCTAssertEqual(archive.calls.count, PhoneArchive.maximumCalls)
        archive.calls.append(call(id: 60_000))
        XCTAssertThrowsError(try archive.validated())
    }

    func testCodecRoundTripPreservesNormalizedFieldsPreferencesAndSecondPrecision() throws {
        let contact = JournalContact(id: identifier(10), name: "  王先生  ", phoneNumber: "10086", isFavorite: true)
        let archive = PhoneArchive(contacts: [contact], calls: [call(date: 1_760_000_000.75, contactID: contact.id)],
                                   preferences: JournalPreferences(layout: .unified, appearance: .dark))
        let expected = try archive.validated()
        let encoded = try JournalCodec.encode(archive)
        XCTAssertEqual(try JournalCodec.decode(encoded), expected)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, PhoneArchive.currentVersion)
    }

    func testCodecRejectsMalformedTruncatedAndOversizedData() throws {
        for invalid in [Data(), Data("not-json".utf8), Data("{\"schemaVersion\":1}".utf8)] {
            XCTAssertThrowsError(try JournalCodec.decode(invalid))
        }
        XCTAssertThrowsError(try JournalCodec.decode(Data(repeating: 32, count: JournalCodec.maximumBytes + 1)))
        var archive = PhoneArchive()
        archive.schemaVersion = 2
        XCTAssertThrowsError(try JournalCodec.encode(archive))
    }
}
