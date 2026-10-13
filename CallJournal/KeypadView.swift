import SwiftUI
import UIKit

struct PhoneDigit: Identifiable {
    let value: String
    let letters: String
    var id: String { value }
    static let all: [PhoneDigit] = [
        .init(value: "1", letters: ""), .init(value: "2", letters: "ABC"), .init(value: "3", letters: "DEF"),
        .init(value: "4", letters: "GHI"), .init(value: "5", letters: "JKL"), .init(value: "6", letters: "MNO"),
        .init(value: "7", letters: "PQRS"), .init(value: "8", letters: "TUV"), .init(value: "9", letters: "WXYZ"),
        .init(value: "*", letters: ""), .init(value: "0", letters: "+"), .init(value: "#", letters: "")
    ]
}

struct PhoneDigitGrid: View {
    var diameter: CGFloat = 78
    var verticalSpacing: CGFloat = 15
    var dark = false
    var onDigit: (String) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: verticalSpacing) {
            ForEach(PhoneDigit.all) { digit in
                if digit.value == "0" {
                    key(digit)
                        .highPriorityGesture(
                            LongPressGesture(minimumDuration: 0.65).exclusively(before: TapGesture())
                                .onEnded { gesture in
                                    switch gesture {
                                    case .first(let succeeded): if succeeded { onDigit("+") }
                                    case .second: onDigit("0")
                                    }
                                }
                        )
                        .accessibilityAction(named: Text("输入加号")) { onDigit("+") }
                } else { key(digit) }
            }
        }
    }

    private func key(_ digit: PhoneDigit) -> some View {
        Button { onDigit(digit.value) } label: {
                    VStack(spacing: 0) {
                        Text(digit.value).font(.system(size: diameter * 0.45, weight: .regular))
                        if !digit.letters.isEmpty {
                            Text(digit.letters).font(.system(size: 10, weight: .semibold)).tracking(2)
                        }
                    }
                    .frame(width: diameter, height: diameter)
                    .foregroundStyle(dark ? Color.white : Color.primary)
                    .background(dark ? Color.white.opacity(0.13) : Color(uiColor: .systemGray5), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(digit.value == "*" ? "星号" : (digit.value == "#" ? "井号" : digit.value))
    }
}

struct KeypadView: View {
    @EnvironmentObject private var store: AppStore
    @State private var number = ""
    @State private var newContact: JournalContact?
    @State private var newRecord: CallRecord?
    @State private var error: ErrorMessage?
    @State private var showSettings = false

    private var matchedContact: JournalContact? {
        guard !number.isEmpty else { return nil }
        return store.archive.contacts.first { PhoneNumber.normalized($0.phoneNumber) == PhoneNumber.normalized(number) }
    }

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(80, max(62, (geometry.size.height - 175) / 5.0), (geometry.size.width - 100) / 3)
            let gridWidth = min(322, geometry.size.width - 36)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    Text(number.isEmpty ? " " : number)
                        .font(.system(size: 34, weight: .regular)).lineLimit(1).minimumScaleFactor(0.4)
                        .frame(maxWidth: .infinity).textSelection(.enabled).accessibilityLabel("号码 \(number)")
                    if let contact = matchedContact {
                        Text(contact.displayName).font(.subheadline).foregroundStyle(.secondary)
                    } else if !number.isEmpty {
                        Button("添加号码") { newContact = JournalContact(name: "", phoneNumber: number) }
                            .font(.subheadline)
                    } else { Text(" ").font(.subheadline) }
                }.frame(height: 84).padding(.horizontal, 18)
                Spacer(minLength: 8)
                PhoneDigitGrid(diameter: diameter, verticalSpacing: 15) { append($0) }.frame(width: gridWidth)
                HStack {
                    Color.clear.frame(width: diameter, height: diameter)
                    Spacer()
                    Button(action: start) {
                        Image(systemName: "phone.fill").font(.system(size: 32)).foregroundStyle(.white)
                            .frame(width: diameter, height: diameter).background(.green, in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel("呼叫")
                    Spacer()
                    Button { if !number.isEmpty { number.removeLast() } } label: {
                        Image(systemName: "delete.left.fill").font(.system(size: 25)).foregroundStyle(.secondary)
                            .frame(width: diameter, height: diameter)
                    }.buttonStyle(.plain).opacity(number.isEmpty ? 0 : 1)
                        .disabled(number.isEmpty).accessibilityLabel("删除最后一位")
                        .onLongPressGesture { number = "" }
                }.frame(width: gridWidth).padding(.top, 17)
                Spacer(minLength: 12)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("粘贴号码", systemImage: "doc.on.clipboard") {
                        if let pasted = UIPasteboard.general.string { number = String(pasted.trimmed.prefix(64)) }
                    }
                    Button("添加通话记录", systemImage: "plus") {
                        newRecord = CallRecord(contactID: matchedContact?.id, phoneNumber: number, durationSeconds: 60, direction: .outgoing)
                    }
                    Button("设置与备份", systemImage: "gearshape") { showSettings = true }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("更多")
            }
        }
        .sheet(item: $newContact) { ContactEditorView(contact: $0) }
        .sheet(item: $newRecord) { CallEditorView(call: $0) }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
        .journalError($error)
    }

    private func append(_ digit: String) {
        guard number.count < 64, digit != "+" || number.isEmpty else { return }
        number += digit
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func start() {
        if number.isEmpty {
            number = store.archive.sortedCalls.first(where: { $0.direction == .outgoing || $0.direction == .cancelled })?.phoneNumber ?? ""
            return
        }
        do { try store.startCall(number: number, contactID: matchedContact?.id) }
        catch { self.error = ErrorMessage(error) }
    }
}
