import SwiftUI

@main
struct CallJournalApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                .preferredColorScheme(store.archive.preferences.appearance.colorScheme)
        }
    }
}

private enum PhoneTab: Hashable { case favorites, recents, contacts, keypad, voicemail, search }

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTab: PhoneTab = .recents
    @State private var showNotice = false

    var body: some View {
        TabView(selection: $selectedTab) {
            if store.archive.preferences.layout == .classic {
                Tab("个人收藏", systemImage: "star.fill", value: PhoneTab.favorites) {
                    NavigationStack { FavoritesView() }
                }
            }
            Tab(store.archive.preferences.layout == .classic ? "最近通话" : "通话",
                systemImage: store.archive.preferences.layout == .classic ? "clock.fill" : "phone.fill",
                value: PhoneTab.recents) {
                NavigationStack { RecentsView() }
            }
            Tab("通讯录", systemImage: "person.crop.circle.fill", value: PhoneTab.contacts) {
                NavigationStack { ContactsView() }
            }
            Tab("拨号键盘", systemImage: "circle.grid.3x3.fill", value: PhoneTab.keypad) {
                NavigationStack { KeypadView() }
            }
            if store.archive.preferences.layout == .classic {
                Tab("语音留言", systemImage: "recordingtape", value: PhoneTab.voicemail) {
                    NavigationStack { VoicemailView() }
                }
            }
            if store.archive.preferences.layout == .unified {
                Tab(value: PhoneTab.search, role: .search) {
                    NavigationStack { RecentsView(isSearch: true) }
                }
            }
        }
        .tint(.blue)
        .onChange(of: store.archive.preferences.layout) { _, _ in selectedTab = .recents }
        .fullScreenCover(item: $store.activeCall) { session in
            LocalCallView(session: session).interactiveDismissDisabled()
        }
        .onAppear { showNotice = store.notice != nil }
        .alert("本地资料库", isPresented: $showNotice) {
            Button("好", role: .cancel) {}
        } message: { Text(store.notice ?? "") }
    }
}

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
