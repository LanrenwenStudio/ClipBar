import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var notifiedLowQuotaKeys: Set<String> = []
    private var notifiedExhaustedKeys: Set<String> = []

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func checkAndNotify(accounts: [AccountQuota], settings: AppSettings) {
        guard settings.enableNotifications, settings.lowQuotaAlertThreshold > 0 else { return }

        let threshold = Double(settings.lowQuotaAlertThreshold)

        for row in accounts {
            let key = row.account.statusKey
            let isLocallyDisabled = settings.isAccountDisabled(statusKey: key, serverDisabled: row.account.disabled)
            guard !isLocallyDisabled else { continue }

            let minRemaining = row.snapshot.windows.compactMap(\.remainingPercent).min()

            if let remaining = minRemaining {
                if remaining <= threshold && remaining > 0 {
                    if !notifiedLowQuotaKeys.contains(key) {
                        notifiedLowQuotaKeys.insert(key)
                        sendNotification(
                            identifier: "low-\(key)",
                            title: L10n.t("额度不足提醒", "Low Quota Alert"),
                            body: L10n.t(
                                "\(row.account.provider.displayName) 账号 \(row.account.displayName) 剩余额度仅剩 \(Int(remaining.rounded()))%",
                                "\(row.account.provider.displayName) account \(row.account.displayName) has only \(Int(remaining.rounded()))% quota remaining."
                            )
                        )
                    }
                } else if remaining > threshold {
                    notifiedLowQuotaKeys.remove(key)
                }

                if remaining <= 0 {
                    if !notifiedExhaustedKeys.contains(key) {
                        notifiedExhaustedKeys.insert(key)
                        sendNotification(
                            identifier: "exhausted-\(key)",
                            title: L10n.t("额度已耗尽", "Quota Exhausted"),
                            body: L10n.t(
                                "\(row.account.provider.displayName) 账号 \(row.account.displayName) 额度已用完",
                                "\(row.account.provider.displayName) account \(row.account.displayName) quota has been exhausted."
                            )
                        )
                    }
                } else {
                    if notifiedExhaustedKeys.contains(key) {
                        notifiedExhaustedKeys.remove(key)
                        sendNotification(
                            identifier: "restored-\(key)",
                            title: L10n.t("额度已重置恢复", "Quota Restored"),
                            body: L10n.t(
                                "\(row.account.provider.displayName) 账号 \(row.account.displayName) 额度已恢复至 \(Int(remaining.rounded()))%",
                                "\(row.account.provider.displayName) account \(row.account.displayName) quota has recovered to \(Int(remaining.rounded()))%."
                            )
                        )
                    }
                }
            }
        }
    }

    private func sendNotification(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}
