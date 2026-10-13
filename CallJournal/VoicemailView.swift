import SwiftUI

struct VoicemailView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("voicemail.number") private var mailboxNumber = ""
    @State private var showNumber = false
    @State private var draftNumber = ""
    @State private var validationError = ""
    @State private var error: ErrorMessage?

    var body: some View {
        ContentUnavailableView {
            Label("无语音留言", systemImage: "recordingtape")
        } actions: {
            Button("呼叫语音信箱") {
                if mailboxNumber.isEmpty { draftNumber = ""; validationError = ""; showNumber = true }
                else { call() }
            }
        }
        .navigationTitle("语音留言")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { draftNumber = mailboxNumber; validationError = ""; showNumber = true }
            }
        }
        .sheet(isPresented: $showNumber) {
            NavigationStack {
                Form {
                    Section("语音信箱号码") {
                        TextField("电话号码", text: $draftNumber).keyboardType(.phonePad)
                    }
                    if !validationError.isEmpty { Text(validationError).foregroundStyle(.red) }
                }
                .navigationTitle("语音信箱").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { showNumber = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            do { try PhoneNumber.validate(draftNumber.trimmed); mailboxNumber = draftNumber.trimmed; showNumber = false }
                            catch { validationError = error.localizedDescription }
                        }
                    }
                }
            }
        }
        .journalError($error)
    }

    private func call() {
        do { try store.startCall(number: mailboxNumber, name: "语音信箱") }
        catch { self.error = ErrorMessage(error) }
    }
}
