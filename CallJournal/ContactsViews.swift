import SwiftUI
import UIKit

struct ContactsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var newContact: JournalContact?

    private var contacts: [JournalContact] {
        store.archive.sortedContacts.filter {
            query.trimmed.isEmpty || $0.displayName.localizedStandardContains(query.trimmed)
                || $0.phoneNumber.localizedStandardContains(query.trimmed)
                || (!PhoneNumber.normalized(query).isEmpty && PhoneNumber.normalized($0.phoneNumber).contains(PhoneNumber.normalized(query)))
        }
    }

    private func initial(_ name: String) -> String {
        let latin = name.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? name
        let value = String(latin.prefix(1)).uppercased()
        return value.range(of: "^[A-Z]$", options: .regularExpression) == nil ? "#" : value
    }

    var body: some View {
        List {
            if contacts.isEmpty {
                ContentUnavailableView(query.isEmpty ? "无联系人" : "无搜索结果", systemImage: "person.crop.circle")
                    .listRowSeparator(.hidden)
            } else {
                let groups = Dictionary(grouping: contacts) { initial($0.displayName) }
                ForEach(groups.keys.sorted(), id: \.self) { key in
                    Section(key) {
                        ForEach(groups[key] ?? []) { contact in
                            NavigationLink { ContactDetailView(contactID: contact.id) } label: {
                                Text(contact.displayName).fontWeight(.semibold).padding(.vertical, 4)
                            }
                        }
                    }
                }
                Section {
                    Text("\(contacts.count) 个联系人").foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("通讯录")
        .searchable(text: $query, prompt: "搜索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("添加联系人", systemImage: "plus") { newContact = JournalContact(name: "", phoneNumber: "") }
            }
        }
        .sheet(item: $newContact) { ContactEditorView(contact: $0) }
    }
}

struct ContactDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let contactID: UUID
    @State private var editContact: JournalContact?
    @State private var newCall: CallRecord?
    @State private var showDelete = false
    @State private var error: ErrorMessage?
    private var contact: JournalContact? { store.archive.contacts.first { $0.id == contactID } }

    var body: some View {
        Group {
            if let contact {
                List {
                    Section {
                        VStack(spacing: 14) {
                            ContactAvatar(name: contact.displayName, size: 92)
                            Text(contact.displayName).font(.system(size: 30)).multilineTextAlignment(.center)
                            HStack(spacing: 9) {
                                DetailAction(title: "呼叫", symbol: "phone.fill") { call(contact) }
                                DetailAction(title: "复制", symbol: "doc.on.doc") { UIPasteboard.general.string = contact.phoneNumber }
                                DetailAction(title: contact.isFavorite ? "已收藏" : "收藏", symbol: contact.isFavorite ? "star.fill" : "star") {
                                    do { try store.toggleFavorite(contact) } catch { self.error = ErrorMessage(error) }
                                }
                            }
                        }.frame(maxWidth: .infinity).padding(.vertical, 10)
                    }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    Section {
                        Button { call(contact) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(contact.label).font(.subheadline).foregroundStyle(.primary)
                                Text(contact.phoneNumber).foregroundStyle(.blue)
                            }.padding(.vertical, 4)
                        }
                    }
                    Section {
                        Button("添加通话记录") {
                            newCall = CallRecord(contactID: contact.id, phoneNumber: contact.phoneNumber, label: contact.label, durationSeconds: 60)
                        }
                        Button(contact.isFavorite ? "从个人收藏移除" : "添加到个人收藏") {
                            do { try store.toggleFavorite(contact) } catch { self.error = ErrorMessage(error) }
                        }
                    }
                    let history = store.archive.sortedCalls.filter { $0.contactID == contact.id }
                    if !history.isEmpty {
                        Section("最近通话") {
                            ForEach(history.prefix(20)) { call in
                                NavigationLink { CallDetailView(recordID: call.id) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(call.direction.title).foregroundStyle(call.direction == .missed ? Color.red : Color.primary)
                                            Text(PhoneFormat.duration(call.durationSeconds)).font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(PhoneFormat.recent(call.date)).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }.textCase(nil)
                    }
                    Section { Button("删除联系人", role: .destructive) { showDelete = true } }
                }.listStyle(.insetGrouped)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("编辑") { editContact = contact } } }
            } else { ContentUnavailableView("联系人已删除", systemImage: "person.crop.circle.badge.xmark") }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editContact) { ContactEditorView(contact: $0) }
        .sheet(item: $newCall) { CallEditorView(call: $0) }
        .confirmationDialog("删除联系人？", isPresented: $showDelete, titleVisibility: .visible) {
            Button("删除联系人", role: .destructive) {
                do { try store.deleteContact(contactID); dismiss() } catch { self.error = ErrorMessage(error) }
            }
            Button("取消", role: .cancel) {}
        } message: { Text("已有通话记录的姓名和号码会保留。") }
        .journalError($error)
    }

    private func call(_ contact: JournalContact) {
        do { try store.startCall(number: contact.phoneNumber, contactID: contact.id) }
        catch { self.error = ErrorMessage(error) }
    }
}

struct ContactEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JournalContact
    private let original: JournalContact
    var onSaved: ((JournalContact) -> Void)?
    @State private var showDiscard = false
    @State private var error: ErrorMessage?
    @FocusState private var focus: Bool

    init(contact: JournalContact, onSaved: ((JournalContact) -> Void)? = nil) {
        original = contact
        _draft = State(initialValue: contact)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { Spacer(); ContactAvatar(name: draft.name.isEmpty ? "人" : draft.name, size: 86); Spacer() }
                        .listRowBackground(Color.clear).padding(.vertical, 10)
                }
                Section {
                    TextField("姓名", text: $draft.name).textContentType(.name).focused($focus)
                    TextField("电话号码", text: $draft.phoneNumber).keyboardType(.phonePad).textContentType(.telephoneNumber).focused($focus)
                    TextField("标签", text: $draft.label).focused($focus)
                }
                Section { Toggle("个人收藏", isOn: $draft.isFavorite) }
            }
            .navigationTitle(store.archive.contacts.contains(where: { $0.id == draft.id }) ? "编辑联系人" : "新建联系人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { if draft != original { showDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        do {
                            let valid = try draft.validated()
                            try store.save(valid)
                            onSaved?(valid)
                            dismiss()
                        } catch { self.error = ErrorMessage(error) }
                    }.fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { focus = false } }
            }
            .confirmationDialog("放弃更改？", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("放弃更改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
            .journalError($error)
        }.interactiveDismissDisabled(draft != original)
    }
}

struct ContactPickerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var title: String
    var onSelect: (JournalContact) -> Void
    @State private var query = ""
    @State private var newContact: JournalContact?

    var body: some View {
        NavigationStack {
            List {
                let contacts = store.archive.sortedContacts.filter {
                    query.isEmpty || $0.displayName.localizedStandardContains(query) || $0.phoneNumber.localizedStandardContains(query)
                }
                if contacts.isEmpty { ContentUnavailableView("无联系人", systemImage: "person.crop.circle") }
                ForEach(contacts) { contact in
                    Button { onSelect(contact); dismiss() } label: {
                        HStack(spacing: 12) {
                            ContactAvatar(name: contact.displayName, size: 38)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.displayName).foregroundStyle(.primary)
                                Text(contact.phoneNumber).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "姓名或号码")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建联系人", systemImage: "plus") { newContact = JournalContact(name: "", phoneNumber: "") }
                }
            }
            .sheet(item: $newContact) { contact in
                ContactEditorView(contact: contact) { saved in
                    // The user can select the newly saved contact from the list after this sheet closes.
                    query = saved.name
                }
            }
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showPicker = false
    @State private var detailID: UUID?
    @State private var error: ErrorMessage?

    var body: some View {
        List {
            let favorites = store.archive.sortedContacts.filter(\.isFavorite)
            if favorites.isEmpty {
                ContentUnavailableView {
                    Label("无个人收藏", systemImage: "star")
                } actions: { Button("添加个人收藏") { showPicker = true } }
                .listRowSeparator(.hidden)
            }
            ForEach(favorites) { contact in
                HStack(spacing: 12) {
                    Button {
                        do { try store.startCall(number: contact.phoneNumber, contactID: contact.id) }
                        catch { self.error = ErrorMessage(error) }
                    } label: {
                        HStack(spacing: 12) {
                            ContactAvatar(name: contact.displayName)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.displayName).fontWeight(.semibold).foregroundStyle(.primary)
                                Label(contact.label, systemImage: "phone.fill").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }.frame(minHeight: 52).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Button { detailID = contact.id } label: { Image(systemName: "info.circle").font(.title3).frame(width: 40, height: 44) }
                        .buttonStyle(.borderless).accessibilityLabel("联系人详情")
                }
            }
            .onDelete { indices in
                do { for index in indices { try store.toggleFavorite(favorites[index]) } }
                catch { self.error = ErrorMessage(error) }
            }
        }
        .listStyle(.plain).navigationTitle("个人收藏")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) { Button("添加个人收藏", systemImage: "plus") { showPicker = true } }
        }
        .sheet(isPresented: $showPicker) {
            ContactPickerView(title: "添加个人收藏") { contact in
                var favorite = contact
                favorite.isFavorite = true
                do { try store.save(favorite) } catch { self.error = ErrorMessage(error) }
            }
        }
        .navigationDestination(item: $detailID) { ContactDetailView(contactID: $0) }
        .journalError($error)
    }
}
