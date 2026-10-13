import SwiftUI
import UIKit

struct CallDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let recordID: UUID
    @State private var editingCall: CallRecord?
    @State private var newContact: JournalContact?
    @State private var showDelete = false
    @State private var error: ErrorMessage?
    private var call: CallRecord? { store.archive.calls.first { $0.id == recordID } }

    var body: some View {
        Group {
            if let call {
                let name = store.archive.displayName(for: call)
                List {
                    Section {
                        VStack(spacing: 14) {
                            ContactAvatar(name: name, size: 92)
                            Text(name).font(.system(size: 30, weight: .regular)).multilineTextAlignment(.center)
                            HStack(spacing: 9) {
                                DetailAction(title: "呼叫", symbol: "phone.fill") { start(call) }
                                DetailAction(title: "复制", symbol: "doc.on.doc") { UIPasteboard.general.string = call.phoneNumber }
                                DetailAction(title: "编辑", symbol: "pencil") { editingCall = call }
                            }
                        }.frame(maxWidth: .infinity).padding(.vertical, 10)
                    }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                    Section(PhoneFormat.date(call.date)) {
                        HStack(alignment: .top, spacing: 20) {
                            Text(PhoneFormat.time(call.date)).monospacedDigit()
                            VStack(alignment: .leading, spacing: 6) {
                                Label(call.direction.title, systemImage: call.direction.symbol)
                                    .foregroundStyle(call.direction == .missed ? Color.red : Color.primary)
                                if !call.direction.isUnanswered {
                                    Text(PhoneFormat.duration(call.durationSeconds)).foregroundStyle(.secondary)
                                }
                            }
                        }.padding(.vertical, 5)
                    }.textCase(nil)

                    Section {
                        Button { start(call) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(call.label).font(.subheadline).foregroundStyle(.primary)
                                Text(call.phoneNumber).foregroundStyle(.blue).textSelection(.enabled)
                            }.padding(.vertical, 3)
                        }
                    }
                    Section {
                        if let contactID = call.contactID {
                            NavigationLink("查看联系人") { ContactDetailView(contactID: contactID) }
                        } else {
                            Button("创建新联系人") {
                                newContact = JournalContact(name: call.nameOverride ?? "", phoneNumber: call.phoneNumber, label: call.label)
                            }
                        }
                        Button("添加通话记录") {
                            var next = call
                            next.id = UUID()
                            next.date = Date()
                            next.direction = .outgoing
                            next.durationSeconds = 0
                            editingCall = next
                        }
                    }
                    Section {
                        Button("删除通话", role: .destructive) { showDelete = true }
                    }
                }.listStyle(.insetGrouped)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("编辑") { editingCall = call } } }
            } else {
                ContentUnavailableView("通话已删除", systemImage: "phone.down")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingCall) { CallEditorView(call: $0) }
        .sheet(item: $newContact) { contact in
            ContactEditorView(contact: contact) { saved in
                guard var updated = call else { return }
                updated.contactID = saved.id
                updated.nameOverride = nil
                do { try store.save(updated) } catch { self.error = ErrorMessage(error) }
            }
        }
        .confirmationDialog("删除这条通话记录？", isPresented: $showDelete, titleVisibility: .visible) {
            Button("删除通话", role: .destructive) {
                do { try store.deleteCalls([recordID]); dismiss() } catch { self.error = ErrorMessage(error) }
            }
            Button("取消", role: .cancel) {}
        }
        .journalError($error)
    }

    private func start(_ call: CallRecord) {
        do { try store.startCall(number: call.phoneNumber, name: call.nameOverride, contactID: call.contactID, label: call.label) }
        catch { self.error = ErrorMessage(error) }
    }
}
