import SwiftUI
import UIKit

struct ErrorMessage: Identifiable {
    let id = UUID()
    let text: String
    init(_ error: Error) { text = error.localizedDescription }
}

extension View {
    func journalError(_ error: Binding<ErrorMessage?>) -> some View {
        alert(item: error) { message in
            Alert(title: Text("未能完成"), message: Text(message.text), dismissButton: .default(Text("好")))
        }
    }
}

enum PhoneFormat {
    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_Hans_CN"))
            .year().month(.twoDigits).day(.twoDigits).weekday(.wide))
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func recent(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨天"
        } else if date < now, now.timeIntervalSince(date) < 6 * 86_400 {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateFormat = calendar.component(.year, from: date) == calendar.component(.year, from: now)
                ? "M/d" : "yyyy/M/d"
        }
        return formatter.string(from: date)
    }

    static func duration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = seconds % 3600 / 60
        let remainder = seconds % 60
        if hours > 0 { return "\(hours) 小时 \(minutes) 分 \(remainder) 秒" }
        if minutes > 0 { return "\(minutes) 分 \(remainder) 秒" }
        return "\(remainder) 秒"
    }

    static func timer(_ seconds: Int) -> String {
        seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct ContactAvatar: View {
    var name: String
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(white: 0.68), Color(white: 0.52)],
                                         startPoint: .top, endPoint: .bottom))
            Text(String(name.prefix(1))).font(.system(size: size * 0.4, weight: .medium)).foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct DetailAction: View {
    let title: String
    let symbol: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 23))
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 66)
            .foregroundStyle(.blue)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }
}
