import AppKit
import UserNotifications

/// Notifiche locali, senza suono. Il permesso si chiede solo dopo la spiegazione.
@MainActor
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    /// Clic sul banner: la sessione segna il VOX come letto e apre Chronocol.
    var onOpen: (URL, String?) -> Void = { url, _ in NSWorkspace.shared.open(url) }

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAfterExplanation() async -> UNAuthorizationStatus {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge])
        return await authorizationStatus()
    }

    func removeAll() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func post(title: String, body: String, permalink: URL, documentId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        content.userInfo = [
            "documentId": documentId,
            "permalink": permalink.absoluteString
        ]
        let request = UNNotificationRequest(identifier: "globy.\(documentId).\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let raw = info["permalink"] as? String, let url = URL(string: raw) else { return }
        let documentId = (info["documentId"] as? String).flatMap { $0 == "summary" ? nil : $0 }
        await MainActor.run {
            onOpen(url, documentId)
        }
    }
}
