import SwiftUI

private struct CallEditDraft: Equatable {
    var contactID: UUID?
    var name: String
    var number: String
    var label: String
    var date: Date
    var second: Int
    var direction: CallDirection
    var hours: String
    var minutes: String
    var seconds: String

    init(_ call: CallRecord) {
        contactID = call.contactID
        name = call.nameOverride ?? ""
        number = call.phoneNumber
        label = call.label
        date = call.date
        second = Calendar.current.component(.second, from: call.date)
        direction = call.direction
        hours = String(call.durationSeconds / 3600)
        minutes = String(call.durationSeconds % 3600 / 60)
        seconds = String(call.durationSeconds % 60)
    }
}

struct CallEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    private let original: CallRecord
    @State private var draft: CallEditDraft
    @State private var baseline: CallEditDraft
    @State private var loaded = false
    @State private var showContactPicker = false
    @State private var showDiscard = false
    @State private var error: ErrorMessage?
    @FocusState private var focusedField: String?

    init(call: CallRecord) {
        original = call
        let draft = CallEditDraft(call)
        _draft = State(initialValue: draft)
        _baseline = State(initialValue: draft)
    }

    private var isDirty: Bool { draft != baseline }
    private var isExisting: Bool { store.archive.calls.contains { $0.id == original.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section("联系人") {
                    TextField("姓名（可留空）", text: $draft.name).textContentType(.name).focused($focusedField, equals: "name")
                    TextField("电话号码", text: $draft.number).keyboardType(.phonePad).textContentType(.telephoneNumber)
                        .focused($focusedField, equals: "number")
                    TextField("号码标签", text: $draft.label).focused($focusedField, equals: "label")
                    Button("从通讯录选择") { focusedField = nil; showContactPicker = true }
                    if draft.contactID != nil {
                        Button("取消联系人关联", role: .destructive) { draft.contactID = nil }
                    }
                }
                Section("通话时间") {
                    DatePicker("日期", selection: $draft.date, displayedComponents: .date)
                    DatePicker("时间", selection: $draft.date, displayedComponents: .hourAndMinute)
                    Stepper(value: $draft.second, in: 0...59) {
                        LabeledContent("秒", value: String(format: "%02d", draft.second))
                    }
                }
                Section("通话状态") {
                    Picker("类型", selection: $draft.direction) {
                        ForEach(CallDirection.allCases) { direction in
                            Label(direction.title, systemImage: direction.symbol).tag(direction)
                        }
                    }
                }
                Section {
                    HStack(spacing: 14) {
                        durationField("小时", text: $draft.hours, field: "hours")
                        durationField("分钟", text: $draft.minutes, field: "minutes")
                        durationField("秒", text: $draft.seconds, field: "seconds")
                    }.disabled(draft.direction.isUnanswered)
                } header: { Text("通话时长") } footer: {
                    if draft.direction.isUnanswered { Text("未接来电和已取消的通话时长为 0 秒。") }
                }
            }
            .navigationTitle(isExisting ? "编辑通话" : "添加通话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { if isDirty { showDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) { Button("完成", action: save).fontWeight(.semibold) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
            .onAppear {
                guard !loaded else { return }
                if original.nameOverride == nil,
                   let contact = store.archive.contacts.first(where: { $0.id == original.contactID }) {
                    draft.name = contact.name
                }
                baseline = draft
                loaded = true
            }
            .onChange(of: draft.direction) { _, direction in
                if direction.isUnanswered { draft.hours = "0"; draft.minutes = "0"; draft.seconds = "0" }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView(title: "选择联系人") { contact in
                    draft.contactID = contact.id
                    draft.name = contact.name
                    draft.number = contact.phoneNumber
                    draft.label = contact.label
                }
            }
            .confirmationDialog("放弃更改？", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("放弃更改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
            .journalError($error)
        }
        .interactiveDismissDisabled(isDirty)
    }

    private func durationField(_ title: String, text: Binding<String>, field: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("0", text: text).keyboardType(.numberPad).monospacedDigit()
                .focused($focusedField, equals: field)
                .padding(10).background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
        }.frame(maxWidth: .infinity)
    }

    private func save() {
        do {
            var call = original
            call.contactID = draft.contactID
            let linked = store.archive.contacts.first { $0.id == draft.contactID }
            call.nameOverride = draft.name.trimmed == linked?.name ? nil : draft.name.trimmed
            call.phoneNumber = draft.number
            call.label = draft.label
            var components = Calendar.current.dateComponents([.era, .year, .month, .day, .hour, .minute], from: draft.date)
            components.second = draft.second
            guard let date = Calendar.current.date(from: components) else { throw JournalError.invalid("日期或时间无效。") }
            call.date = date
            call.direction = draft.direction
            if call.direction.isUnanswered { call.durationSeconds = 0 }
            else {
                guard let hours = Int(draft.hours), (0...99).contains(hours),
                      let minutes = Int(draft.minutes), (0...59).contains(minutes),
                      let seconds = Int(draft.seconds), (0...59).contains(seconds) else {
                    throw JournalError.invalid("小时请填写 0–99，分钟和秒请填写 0–59。")
                }
                call.durationSeconds = hours * 3600 + minutes * 60 + seconds
            }
            try store.save(call)
            dismiss()
        } catch { self.error = ErrorMessage(error) }
    }
}
