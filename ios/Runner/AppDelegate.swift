import Flutter
import UIKit
import BackgroundTasks
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var refereeMonitor: RefereeInvitationMonitor?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Initialize referee invitation monitor
    let controller = window?.rootViewController as! FlutterViewController
    refereeMonitor = RefereeInvitationMonitor()
    refereeMonitor?.configure(binaryMessenger: controller.binaryMessenger)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    
    // Schedule background refresh when app enters background
    scheduleBackgroundAppRefresh()
  }
  
  private func scheduleBackgroundAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.gbo.referee-check")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
    
    do {
      try BGTaskScheduler.shared.submit(request)
      print("📱 iOS: Background app refresh scheduled")
    } catch {
      print("📱 iOS: Could not schedule app refresh: \(error)")
    }
  }
}

// MARK: - RefereeInvitationMonitor

class RefereeInvitationMonitor: NSObject {
    private var channel: FlutterMethodChannel?
    private var currentRefereeId: String?
    
    func configure(binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "referee_invitation_monitoring", binaryMessenger: binaryMessenger)
        channel?.setMethodCallHandler(handleMethodCall)
        
        // Register background task
        registerBackgroundTask()
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startBackgroundMonitoring":
            if let refereeId = call.arguments as? String {
                startBackgroundMonitoring(refereeId: refereeId)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Referee ID required", details: nil))
            }
            
        case "stopBackgroundMonitoring":
            stopBackgroundMonitoring()
            result(nil)
            
        case "sendPushNotification":
            if let args = call.arguments as? [String: Any],
               let tournaments = args["tournaments"] as? [[String: Any]] {
                showPushNotification(tournaments: tournaments)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Tournament data required", details: nil))
            }
            
        case "sendCustomNotification":
            if let args = call.arguments as? [String: Any],
               let title = args["title"] as? String,
               let message = args["message"] as? String,
               let userEmail = args["userEmail"] as? String {
                showCustomNotification(title: title, message: message, userEmail: userEmail)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Title, message and userEmail required", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Background Monitoring
    
    private func startBackgroundMonitoring(refereeId: String) {
        currentRefereeId = refereeId
        
        // Schedule background app refresh
        scheduleBackgroundRefresh()
        
        // Request notification permissions
        requestNotificationPermissions()
        
        print("📱 iOS: Started background monitoring for referee: \(refereeId)")
    }
    
    private func stopBackgroundMonitoring() {
        currentRefereeId = nil
        cancelBackgroundRefresh()
        print("📱 iOS: Stopped background monitoring")
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.gbo.referee-check", using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.gbo.referee-check")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📱 iOS: Background refresh scheduled")
        } catch {
            print("📱 iOS: Failed to schedule background refresh: \(error)")
        }
    }
    
    private func cancelBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.gbo.referee-check")
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        guard let refereeId = currentRefereeId else {
            task.setTaskCompleted(success: false)
            return
        }
        
        // Schedule next refresh
        scheduleBackgroundRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Check for pending invitations
        checkForPendingInvitations(refereeId: refereeId) { [weak self] result in
            if let pendingTournaments = result["pendingTournaments"] as? [[String: Any]],
               let newInvitations = result["newInvitations"] as? Int,
               newInvitations > 0 {
                
                self?.showPushNotification(tournaments: pendingTournaments)
            }
            
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Check for Invitations
    
    private func checkForPendingInvitations(refereeId: String, completion: @escaping ([String: Any]) -> Void) {
        channel?.invokeMethod("checkForPendingInvitations", arguments: refereeId) { result in
            if let resultDict = result as? [String: Any] {
                completion(resultDict)
            } else {
                completion([:])
            }
        }
    }
    
    // MARK: - Push Notifications
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("📱 iOS: Notification permissions granted")
                self.setupNotificationCategories()
            } else {
                print("📱 iOS: Notification permissions denied")
            }
        }
    }
    
    private func setupNotificationCategories() {
        let acceptAction = UNNotificationAction(
            identifier: "accept",
            title: "Zusagen",
            options: [.foreground]
        )
        
        let declineAction = UNNotificationAction(
            identifier: "decline",
            title: "Absagen",
            options: [.destructive]
        )
        
        let laterAction = UNNotificationAction(
            identifier: "later",
            title: "Später",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "referee_invitation",
            actions: [acceptAction, declineAction, laterAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Schiedsrichter-Einladung",
            categorySummaryFormat: "%u neue Einladungen",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func showPushNotification(tournaments: [[String: Any]]) {
        print("📱 iOS: showPushNotification called with \(tournaments.count) tournaments")
        
        guard let firstTournament = tournaments.first,
              let tournamentName = firstTournament["name"] as? String else {
            print("📱 iOS: No tournament data found or invalid format")
            return
        }
        
        print("📱 iOS: Creating notification for tournament: \(tournamentName)")
        
        let content = UNMutableNotificationContent()
        
        if tournaments.count == 1 {
            content.title = "Neue Schiedsrichter-Einladung"
            content.body = "Du wurdest zum/r \(tournamentName) als Schiedsrichter eingeladen"
        } else {
            content.title = "Neue Schiedsrichter-Einladungen"
            content.body = "Du hast \(tournaments.count) neue Turniereinladungen"
        }
        
        content.sound = .default
        content.badge = tournaments.count as NSNumber
        content.categoryIdentifier = "referee_invitation"
        
        // Add tournament data to userInfo
        content.userInfo = [
            "type": "referee_invitation",
            "tournaments": tournaments
        ]
        
        let request = UNNotificationRequest(
            identifier: "referee_invitation_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 iOS: Failed to show notification: \(error)")
            } else {
                        print("📱 iOS: Notification successfully scheduled for \(tournaments.count) tournaments")
      }
    }
  }
  
  private func showCustomNotification(title: String, message: String, userEmail: String) {
    print("📱 iOS: showCustomNotification called for user: \(userEmail)")
    print("📱 iOS: Title: \(title), Message: \(message)")
    
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    content.sound = .default
    content.badge = 1
    content.categoryIdentifier = "custom_notification"
    
    // Add custom data to userInfo
    content.userInfo = [
      "type": "custom_notification",
      "userEmail": userEmail,
      "title": title,
      "message": message
    ]
    
    let request = UNNotificationRequest(
      identifier: "custom_notification_\(Date().timeIntervalSince1970)",
      content: content,
      trigger: nil
    )
    
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("📱 iOS: Failed to show custom notification: \(error)")
      } else {
        print("📱 iOS: Custom notification successfully scheduled")
      }
    }
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension RefereeInvitationMonitor: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        
        guard let tournaments = userInfo["tournaments"] as? [[String: Any]],
              let firstTournament = tournaments.first,
              let tournamentId = firstTournament["id"] as? String,
              let refereeId = currentRefereeId else {
            completionHandler()
            return
        }
        
        var responseStatus: String
        switch actionIdentifier {
        case "accept":
            responseStatus = "accepted"
        case "decline":
            responseStatus = "declined"
        case "later":
            responseStatus = "pending"
        default:
            completionHandler()
            return
        }
        
        // Send response to Flutter
        let args = [
            "tournamentId": tournamentId,
            "refereeId": refereeId,
            "response": responseStatus
        ]
        
        channel?.invokeMethod("respondToInvitation", arguments: args) { result in
            if let success = result as? Bool, success {
                self.showConfirmationNotification(for: responseStatus)
            }
            completionHandler()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    private func showConfirmationNotification(for response: String) {
        let content = UNMutableNotificationContent()
        
        switch response {
        case "accepted":
            content.title = "Zusage gesendet"
            content.body = "Sie haben die Einladung angenommen"
        case "declined":
            content.title = "Absage gesendet"
            content.body = "Sie haben die Einladung abgelehnt"
        case "pending":
            content.title = "Später entscheiden"
            content.body = "Sie können später antworten"
        default:
            return
        }
        
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "confirmation_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
