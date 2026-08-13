import Foundation

@MainActor
protocol LocalNotificationSceneReceiving: AnyObject {
    func receiveLocalNotificationURL(_ url: URL)
}
