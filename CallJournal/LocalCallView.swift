import SwiftUI
import UIKit

struct LocalCallView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var session: LocalCallSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var showKeypad = false
    @State private var digits = ""
    @State private var showContacts = false
    @State private var showAddCall = false
    @State private var error: ErrorMessage?
    @State private var previousIdleTimer = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 650
            VStack(spacing: 0) {
                Spacer(minLength: compact ? 8 : 35)
                VStack(spacing: 10) {
                    Text(session.isMerged ? "电话会议" : session.current.displayName)
                        .font(.system(size: compact ? 28 : 34, weight: .regular))
                        .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.6)
                    if session.isMerged {
                        Text(session.lines.map(\.displayName).joined(separator: "、")).font(.subheadline).foregroundStyle(.white.opacity(0.72))
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text(status(at: timeline.date)).font(.system(size: 19)).monospacedDigit().foregroundStyle(.white.opacity(0.8))
                    }
                    if session.lines.count == 2 && !session.isMerged {
                        Text("\(session.lines[1 - session.activeIndex].displayName) · 保持")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                    }
                }.frame(height: compact ? 110 : 145).padding(.horizontal, 20)
                Spacer(minLength: 12)

                if showKeypad {
                    VStack(spacing: 15) {
                        Text(digits.isEmpty ? " " : digits).font(.system(size: 24)).lineLimit(1).minimumScaleFactor(0.5)
                        PhoneDigitGrid(diameter: compact ? 64 : 76, verticalSpacing: compact ? 10 : 15, dark: true) {
                            if digits.count < 64 { digits += $0 }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }.frame(width: min(314, geometry.size.width - 36))
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: compact ? 22 : 30) {
                        callControl("静音", symbol: "mic.slash.fill", selected: session.isMuted) { session.isMuted.toggle() }
                        callControl("键盘", symbol: "circle.grid.3x3.fill", selected: false) { showKeypad = true }
                        callControl("扬声器", symbol: "speaker.wave.3.fill", selected: session.isSpeakerOn) { session.isSpeakerOn.toggle() }
                        if session.lines.count == 1 {
                            callControl("添加通话", symbol: "plus", selected: false) { showAddCall = true }
                        } else {
                            callControl("合并通话", symbol: "arrow.triangle.merge", selected: session.isMerged) { session.mergeLines() }
                        }
                        callControl(session.lines.count == 2 ? "切换" : "保持",
                                    symbol: session.lines.count == 2 ? "arrow.triangle.2.circlepath" : "pause.fill",
                                    selected: session.lines.count == 1 && session.current.isHeld) {
                            if session.lines.count == 2 { session.swapLines() } else { session.toggleHold() }
                        }
                        callControl("通讯录", symbol: "person.crop.circle.fill", selected: false) { showContacts = true }
                    }.frame(width: min(332, geometry.size.width - 28))
                }
                Spacer(minLength: compact ? 15 : 36)
                Button {
                    do { try store.finishCall() } catch { self.error = ErrorMessage(error) }
                } label: {
                    Image(systemName: "phone.down.fill").font(.system(size: 32)).foregroundStyle(.white)
                        .frame(width: 76, height: 76).background(.red, in: Circle())
                }.buttonStyle(.plain).accessibilityLabel("挂断")
                if showKeypad {
                    Button("隐藏") { showKeypad = false }.foregroundStyle(.white).padding(.top, 17)
                }
                Spacer(minLength: 22)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [Color(red: 0.22, green: 0.25, blue: 0.29), Color(red: 0.08, green: 0.11, blue: 0.15)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showContacts) {
            NavigationStack { InCallContactsView(session: session) }
        }
        .sheet(isPresented: $showAddCall) {
            AddCallSheet { number, contactID in
                do { try store.addLine(number: number, contactID: contactID) }
                catch { self.error = ErrorMessage(error) }
            }
        }
        .onAppear {
            previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = previousIdleTimer }
        .onChange(of: scenePhase) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .active ? true : previousIdleTimer
        }
        .journalError($error)
    }

    private func status(at date: Date) -> String {
        if session.endedAt != nil { return "通话已结束" }
        if session.current.isHeld && !session.isMerged { return "通话保持" }
        if session.current.connectedAt == nil { return "正在呼叫…" }
        return PhoneFormat.timer(session.current.duration(at: date))
    }

    private func callControl(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 28))
                    .foregroundStyle(selected ? Color.black : Color.white)
                    .frame(width: 73, height: 73)
                    .background(selected ? Color.white : Color.white.opacity(0.14), in: Circle())
                Text(title).font(.system(size: 14)).foregroundStyle(.white)
            }
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct InCallContactsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: LocalCallSession
    @State private var query = ""
    @State private var error: ErrorMessage?

    var body: some View {
        List {
            let contacts = store.archive.sortedContacts.filter {
                query.isEmpty || $0.displayName.localizedStandardContains(query) || $0.phoneNumber.localizedStandardContains(query)
            }
            if contacts.isEmpty { ContentUnavailableView("无联系人", systemImage: "person.crop.circle") }
            ForEach(contacts) { contact in
                NavigationLink {
                    Form {
                        Section {
                            Text(contact.displayName).font(.title2)
                            LabeledContent(contact.label, value: contact.phoneNumber)
                            Button("复制号码") { UIPasteboard.general.string = contact.phoneNumber }
                        }
                        Section {
                            Button("添加到通话") {
                                do { try store.addLine(number: contact.phoneNumber, contactID: contact.id); dismiss() }
                                catch { self.error = ErrorMessage(error) }
                            }.disabled(session.lines.count >= 2 || session.endedAt != nil)
                        }
                    }.navigationTitle(contact.displayName).navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack(spacing: 12) {
                        ContactAvatar(name: contact.displayName, size: 38)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(contact.displayName)
                            Text(contact.phoneNumber).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("通讯录").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "姓名或号码")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
        .journalError($error)
    }
}

private struct AddCallSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String, UUID?) -> Void
    @State private var number = ""
    @State private var error: ErrorMessage?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("电话号码", text: $number).keyboardType(.phonePad)
                    Button("呼叫") {
                        do { try PhoneNumber.validate(number); onSelect(number, nil); dismiss() }
                        catch { self.error = ErrorMessage(error) }
                    }
                }
                Section("通讯录") {
                    ForEach(store.archive.sortedContacts) { contact in
                        Button {
                            onSelect(contact.phoneNumber, contact.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.displayName).foregroundStyle(.primary)
                                Text(contact.phoneNumber).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加通话").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .journalError($error)
        }
    }
}
