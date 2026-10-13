import SwiftUI
import UIKit

struct RecentsView: View {
    @EnvironmentObject private var store: AppStore
    var isSearch = false
    @State private var query = ""
    @State private var missedOnly = false
    @State private var detailID: UUID?
    @State private var callToEdit: CallRecord?
    @State private var showSettings = false
    @State private var showClearConfirmation = false
    @State private var error: ErrorMessage?

    private var isUnified: Bool { store.archive.preferences.layout == .unified }
    private var calls: [CallRecord] { store.archive.matchingCalls(query: query, missedOnly: missedOnly) }

    var body: some View {
        List {
            if !isSearch {
                Picker("通话类型", selection: $missedOnly) {
                    Text("所有通话").tag(false)
                    Text("未接来电").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
            }

            if isUnified && !isSearch && query.isEmpty && !missedOnly {
                let favorites = Array(store.archive.sortedContacts.filter(\.isFavorite).prefix(8))
                if !favorites.isEmpty {
                    Section("个人收藏") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 22) {
                                ForEach(favorites) { contact in
                                    Button {
                                        do { try store.startCall(number: contact.phoneNumber, contactID: contact.id) }
                                        catch { self.error = ErrorMessage(error) }
                                    } label: {
                                        VStack(spacing: 7) {
                                            ContactAvatar(name: contact.displayName, size: 56)
                                            Text(contact.displayName).font(.caption).lineLimit(1).frame(width: 64)
                                        }
                                        .foregroundStyle(.primary)
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.vertical, 5)
                        }
                    }.textCase(nil)
                }
            }

            if calls.isEmpty {
                ContentUnavailableView {
                    Label(query.isEmpty ? (missedOnly ? "无未接来电" : "无最近通话") : "无搜索结果",
                          systemImage: query.isEmpty ? "phone" : "magnifyingglass")
                } description: {
                    if !query.isEmpty { Text("请尝试其他姓名或电话号码。") }
                } actions: {
                    if query.isEmpty && !missedOnly {
                        Button("添加通话") { callToEdit = CallRecord(phoneNumber: "", durationSeconds: 60) }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                Section(isUnified && !isSearch ? "最近通话" : "") {
                    ForEach(calls) { call in
                        callRow(call)
                            .contextMenu {
                                Button("编辑通话", systemImage: "pencil") { callToEdit = call }
                                Button("复制号码", systemImage: "doc.on.doc") { UIPasteboard.general.string = call.phoneNumber }
                                Button("复制为新记录", systemImage: "plus.square.on.square") {
                                    var copy = call
                                    copy.id = UUID()
                                    callToEdit = copy
                                }
                                Button("删除", systemImage: "trash", role: .destructive) { delete([call.id]) }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("删除", systemImage: "trash", role: .destructive) { delete([call.id]) }
                                Button("编辑", systemImage: "pencil") { callToEdit = call }.tint(.blue)
                            }
                    }
                    .onDelete { indices in delete(Set(indices.map { calls[$0].id })) }
                }.textCase(nil)
            }
        }
        .listStyle(.plain)
        .navigationTitle(isSearch ? "搜索" : (isUnified ? "通话" : "最近通话"))
        .searchable(text: $query, prompt: "姓名或电话号码")
        .toolbar {
            if !isSearch {
                ToolbarItem(placement: .topBarLeading) { EditButton().disabled(calls.isEmpty) }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("添加通话", systemImage: "plus") {
                        callToEdit = CallRecord(phoneNumber: "", durationSeconds: 60)
                    }
                    Menu {
                        Picker("布局", selection: Binding(get: { store.archive.preferences.layout }, set: setLayout)) {
                            ForEach(PhoneLayout.allCases) { Text($0.title).tag($0) }
                        }
                        Divider()
                        Button("所有通话", systemImage: "phone") { missedOnly = false }
                        Button("未接来电", systemImage: "phone.badge.xmark") { missedOnly = true }
                        Divider()
                        Button("设置与备份", systemImage: "gearshape") { showSettings = true }
                        Button("清空最近通话", systemImage: "trash", role: .destructive) { showClearConfirmation = true }
                            .disabled(store.archive.calls.isEmpty)
                    } label: { Image(systemName: "line.3.horizontal.decrease") }
                    .accessibilityLabel("过滤和设置")
                }
            }
        }
        .navigationDestination(item: $detailID) { CallDetailView(recordID: $0) }
        .sheet(item: $callToEdit) { CallEditorView(call: $0) }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
        .confirmationDialog("清空所有最近通话？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("清空所有通话", role: .destructive) {
                do { try store.clearCalls() } catch { self.error = ErrorMessage(error) }
            }
            Button("取消", role: .cancel) {}
        } message: { Text("联系人会保留。此操作无法撤销。") }
        .journalError($error)
    }

    private func callRow(_ call: CallRecord) -> some View {
        HStack(spacing: 12) {
            Button {
                if isUnified { detailID = call.id }
                else {
                    do { try store.startCall(number: call.phoneNumber, name: call.nameOverride, contactID: call.contactID, label: call.label) }
                    catch { self.error = ErrorMessage(error) }
                }
            } label: {
                HStack(spacing: 12) {
                    if isUnified { ContactAvatar(name: store.archive.displayName(for: call)) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.archive.displayName(for: call))
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(call.direction == .missed ? Color.red : Color.primary)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            if call.direction == .outgoing || call.direction == .cancelled {
                                Image(systemName: "phone.arrow.up.right.fill").font(.system(size: 11))
                            } else if isUnified {
                                Image(systemName: call.direction.symbol).font(.system(size: 11))
                            }
                            Text(call.label)
                            if call.direction == .cancelled { Text("· 已取消") }
                        }.font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 5)
                    Text(PhoneFormat.recent(call.date)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: isUnified ? 57 : 47, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(store.archive.displayName(for: call))，\(call.direction.title)，\(PhoneFormat.date(call.date))，\(PhoneFormat.time(call.date))")

            Button {
                if isUnified {
                    do { try store.startCall(number: call.phoneNumber, name: call.nameOverride, contactID: call.contactID, label: call.label) }
                    catch { self.error = ErrorMessage(error) }
                } else { detailID = call.id }
            } label: {
                Image(systemName: isUnified ? "phone.fill" : "info.circle")
                    .font(.system(size: 21)).frame(width: 40, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isUnified ? "呼叫" : "通话详情")
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 8))
    }

    private func delete(_ ids: Set<UUID>) {
        do { try store.deleteCalls(ids) } catch { self.error = ErrorMessage(error) }
    }
    private func setLayout(_ layout: PhoneLayout) {
        var preferences = store.archive.preferences
        preferences.layout = layout
        do { try store.setPreferences(preferences) } catch { self.error = ErrorMessage(error) }
    }
}
