import SwiftUI
import UniformTypeIdentifiers

struct JournalDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw JournalError.invalid("无法读取备份文件。") }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var document: JournalDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingImport: PhoneArchive?
    @State private var showImportConfirmation = false
    @State private var showRecoveryConfirmation = false
    @State private var showClearConfirmation = false
    @State private var error: ErrorMessage?
    @State private var exportName = "电话簿备份"

    var body: some View {
        Form {
            if store.requiresRecovery {
                Section("资料库恢复") {
                    Text(store.notice ?? "请先恢复本地资料库。").foregroundStyle(.secondary)
                    Button("确认使用当前资料库恢复") { showRecoveryConfirmation = true }
                    Button("从备份恢复") { showImporter = true }
                }
            }
            Section("显示") {
                Picker("电话布局", selection: preference(\.layout)) {
                    ForEach(PhoneLayout.allCases) { Text($0.title).tag($0) }
                }
                Picker("外观", selection: preference(\.appearance)) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
            }.disabled(store.requiresRecovery)
            Section {
                Button("导出备份", systemImage: "square.and.arrow.up") {
                    do {
                        document = JournalDocument(data: try store.exportData())
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
                        exportName = "电话簿备份-\(formatter.string(from: Date()))"
                        showExporter = true
                    } catch { self.error = ErrorMessage(error) }
                }
                Button("导入备份", systemImage: "square.and.arrow.down") { showImporter = true }
            } header: { Text("备份") } footer: {
                Text("备份包含联系人和通话记录。导入会替换当前资料库；卸载 App 前请先导出到“文件”。")
            }
            Section("资料库") {
                LabeledContent("联系人", value: "\(store.archive.contacts.count)")
                LabeledContent("通话记录", value: "\(store.archive.calls.count)")
                Button("清空通话记录", role: .destructive) { showClearConfirmation = true }
                    .disabled(store.archive.calls.isEmpty || store.requiresRecovery)
            }
            Section {
                Text("联系人和通话记录仅保存在本机。拨号与通话操作在 App 内运行。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        .fileExporter(isPresented: $showExporter, document: document, contentType: .json, defaultFilename: exportName) { result in
            if case .failure(let error) = result { self.error = ErrorMessage(error) }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            do {
                pendingImport = try store.prepareImport(from: result.get())
                showImportConfirmation = true
            } catch { self.error = ErrorMessage(error) }
        }
        .confirmationDialog("替换当前资料库？", isPresented: $showImportConfirmation, titleVisibility: .visible) {
            Button("导入并替换", role: .destructive) {
                do { if let candidate = pendingImport { try store.restore(candidate) }; pendingImport = nil }
                catch { self.error = ErrorMessage(error) }
            }
            Button("取消", role: .cancel) { pendingImport = nil }
        } message: {
            Text("备份包含 \(pendingImport?.contacts.count ?? 0) 个联系人和 \(pendingImport?.calls.count ?? 0) 条通话。当前内容会被替换。")
        }
        .confirmationDialog("恢复本地资料库？", isPresented: $showRecoveryConfirmation, titleVisibility: .visible) {
            Button("确认恢复") {
                do { try store.confirmRecovery() } catch { self.error = ErrorMessage(error) }
            }
            Button("取消", role: .cancel) {}
        } message: { Text("将以当前显示的数据重建资料库，无法读取的原文件会保留。建议先导出备份。") }
        .confirmationDialog("清空所有通话记录？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("清空通话记录", role: .destructive) {
                do { try store.clearCalls() } catch { self.error = ErrorMessage(error) }
            }
            Button("取消", role: .cancel) {}
        } message: { Text("联系人会保留。此操作无法撤销。") }
        .journalError($error)
    }

    private func preference<Value: Equatable>(_ keyPath: WritableKeyPath<JournalPreferences, Value>) -> Binding<Value> {
        Binding(get: { store.archive.preferences[keyPath: keyPath] }, set: { value in
            var preferences = store.archive.preferences
            preferences[keyPath: keyPath] = value
            do { try store.setPreferences(preferences) } catch { self.error = ErrorMessage(error) }
        })
    }
}
