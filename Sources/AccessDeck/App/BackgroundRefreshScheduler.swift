#if os(iOS)
import BackgroundTasks
import Foundation

@MainActor
enum BackgroundRefreshScheduler {
    static let taskIdentifier = "com.lanrenwen.accessdeck.ios.refresh"
    private static var registered = false

    static func register() {
        guard !registered else { return }
        registered = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            Task { @MainActor in
                let success = await AppModel.performBackgroundRefresh()
                schedule()
                task.setTaskCompleted(success: success)
            }
        }
    }

    static func schedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
#endif
