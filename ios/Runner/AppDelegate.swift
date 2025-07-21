import Flutter
import UIKit
import BackgroundTasks
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var refereeMonitor: RefereeInvitationMonitor?
  private var notificationMonitor: NotificationMonitor?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize monitors after plugin registration
    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      refereeMonitor = RefereeInvitationMonitor()
      refereeMonitor?.configure(binaryMessenger: flutterViewController.binaryMessenger)
      
      notificationMonitor = NotificationMonitor()
      notificationMonitor?.configure(binaryMessenger: flutterViewController.binaryMessenger)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    
    // Schedule background refresh when app enters background
    scheduleBackgroundAppRefresh()
  }
  
  private func scheduleBackgroundAppRefresh() {
    // Schedule referee check
    let refereeRequest = BGAppRefreshTaskRequest(identifier: "com.gbo.referee-check")
    refereeRequest.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
    
    // Schedule notification check
    let notificationRequest = BGAppRefreshTaskRequest(identifier: "com.gbo.notification-check")
    notificationRequest.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
    
    do {
      try BGTaskScheduler.shared.submit(refereeRequest)
      try BGTaskScheduler.shared.submit(notificationRequest)
      print("📱 iOS: Background app refresh scheduled")
    } catch {
      print("📱 iOS: Could not schedule app refresh: \(error)")
    }
  }
}

// MARK: - NotificationMonitor

class NotificationMonitor: NSObject {
    private var channel: FlutterMethodChannel?
    private var currentUserEmail: String?
    
    func configure(binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "notification_monitoring", binaryMessenger: binaryMessenger)
        channel?.setMethodCallHandler(handleMethodCall)
        
        // Register background task
        registerBackgroundTask()
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startBackgroundMonitoring":
            if let userEmail = call.arguments as? String {
                startBackgroundMonitoring(userEmail: userEmail)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "User email required", details: nil))
            }
            
        case "stopBackgroundMonitoring":
            stopBackgroundMonitoring()
            result(nil)
            
        case "showNotification":
            if let args = call.arguments as? [String: Any],
               let title = args["title"] as? String,
               let message = args["message"] as? String {
                let isTimeSensitive = args["isTimeSensitive"] as? Bool ?? false
                let userEmail = args["userEmail"] as? String
                showNotification(title: title, message: message, userEmail: userEmail, isTimeSensitive: isTimeSensitive)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Title and message required", details: nil))
            }
            
        case "checkTimeSensitivePermissions":
            checkTimeSensitivePermissions { hasPermission in
                result(hasPermission)
            }
            
        case "requestTimeSensitivePermission":
            requestTimeSensitivePermission { hasPermission in
                result(hasPermission)
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Background Monitoring
    
    private func startBackgroundMonitoring(userEmail: String) {
        currentUserEmail = userEmail
        
        // Schedule background app refresh
        scheduleBackgroundRefresh()
        
        // Request notification permissions
        requestNotificationPermissions()
        
        print("📱 iOS: Started notification monitoring for user: \(userEmail)")
    }
    
    private func stopBackgroundMonitoring() {
        currentUserEmail = nil
        cancelBackgroundRefresh()
        print("📱 iOS: Stopped notification monitoring")
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.gbo.notification-check", using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.gbo.notification-check")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📱 iOS: Background refresh scheduled")
        } catch {
            print("📱 iOS: Failed to schedule background refresh: \(error)")
        }
    }
    
    private func cancelBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.gbo.notification-check")
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule next refresh
        scheduleBackgroundRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Check for new notifications
        checkForNewNotifications { [weak self] result in
            if let notifications = result["notifications"] as? [[String: Any]],
               !notifications.isEmpty {
                for notification in notifications {
                    if let title = notification["title"] as? String,
                       let message = notification["message"] as? String,
                       let isTimeSensitive = notification["isTimeSensitive"] as? Bool,
                       let userEmail = notification["userEmail"] as? String {
                        self?.showNotification(title: title, message: message, userEmail: userEmail, isTimeSensitive: isTimeSensitive)
                    }
                }
            }
            
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Check for Notifications
    
    private func checkForNewNotifications(completion: @escaping ([String: Any]) -> Void) {
        channel?.invokeMethod("checkForNewNotifications", arguments: currentUserEmail) { result in
            if let resultDict = result as? [String: Any] {
                completion(resultDict)
            } else {
                completion([:])
            }
        }
    }
    
    // MARK: - Push Notifications
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .timeSensitive]) { granted, error in
            if granted {
                print("📱 iOS: Notification permissions granted (including time-sensitive)")
                self.setupNotificationCategories()
            } else {
                print("📱 iOS: Notification permissions denied")
                if let error = error {
                    print("📱 iOS: Permission error: \(error)")
                }
            }
        }
    }
    
    private func checkTimeSensitivePermissions(completion: @escaping (Bool) -> Void) {
        print("📱 iOS: Checking time-sensitive notification permissions...")
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 iOS: Current notification settings:")
            print("📱 iOS: Authorization status: \(settings.authorizationStatus.rawValue)")
            
            // First check if basic notifications are authorized
            guard settings.authorizationStatus == .authorized else {
                print("📱 iOS: Basic notifications not authorized, requesting all permissions...")
                self.requestTimeSensitivePermission(completion: completion)
                return
            }
            
            if #available(iOS 15.0, *) {
                print("📱 iOS: Time-sensitive setting: \(settings.timeSensitiveSetting.rawValue)")
                
                switch settings.timeSensitiveSetting {
                case .enabled:
                    print("📱 iOS: Time-sensitive notifications already enabled")
                    completion(true)
                case .disabled:
                    print("📱 iOS: Time-sensitive notifications disabled by user")
                    completion(false)
                case .notSupported:
                    print("📱 iOS: Time-sensitive notifications not supported on this device")
                    completion(false)
                @unknown default:
                    print("📱 iOS: Time-sensitive setting not determined, requesting permission...")
                    self.requestTimeSensitivePermission(completion: completion)
                }
            } else {
                print("📱 iOS: iOS 15+ required for time-sensitive notifications")
                completion(false)
            }
        }
    }
    
    private func requestTimeSensitivePermission(completion: @escaping (Bool) -> Void) {
        print("📱 iOS: Requesting time-sensitive notification permissions...")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .timeSensitive]) { granted, error in
            if let error = error {
                print("📱 iOS: Error requesting time-sensitive permission: \(error)")
                completion(false)
                return
            }
            
            print("📱 iOS: Permission request completed. Granted: \(granted)")
            
            if granted {
                UNUserNotificationCenter.current().getNotificationSettings { newSettings in
                    if #available(iOS 15.0, *) {
                        let isTimeSensitiveEnabled = newSettings.timeSensitiveSetting == .enabled
                        print("📱 iOS: Time-sensitive notifications enabled: \(isTimeSensitiveEnabled)")
                        
                        if isTimeSensitiveEnabled {
                            self.setupNotificationCategories()
                        }
                        
                        completion(isTimeSensitiveEnabled)
                    } else {
                        completion(false)
                    }
                }
            } else {
                completion(false)
            }
        }
    }
    
    private func setupNotificationCategories() {
        let standardCategory = UNNotificationCategory(
            identifier: "standard_notification",
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Benachrichtigung",
            categorySummaryFormat: "%u neue Benachrichtigungen",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )
        
        let timeSensitiveCategory = UNNotificationCategory(
            identifier: "time_sensitive_notification",
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Zeitkritische Benachrichtigung",
            categorySummaryFormat: "%u zeitkritische Benachrichtigungen",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([standardCategory, timeSensitiveCategory])
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func showNotification(title: String, message: String, userEmail: String?, isTimeSensitive: Bool) {
        print("📱 iOS: showNotification called")
        print("📱 iOS: Title: \(title), Message: \(message), User Email: \(userEmail ?? "all"), Time Sensitive: \(isTimeSensitive)")
        
        let content = UNMutableNotificationContent()
        content.title = isTimeSensitive ? "⚠️ \(title)" : title
        content.body = message
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = isTimeSensitive ? "time_sensitive_notification" : "standard_notification"
        
        // Set interruption level for time-sensitive notifications
        if #available(iOS 15.0, *) {
            content.interruptionLevel = isTimeSensitive ? .timeSensitive : .active
        }
        
        // Add custom data to userInfo
        content.userInfo = [
            "type": "standard_notification",
            "userEmail": userEmail ?? "all",
            "title": title,
            "message": message,
            "isTimeSensitive": isTimeSensitive
        ]
        
        let request = UNNotificationRequest(
            identifier: "notification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 iOS: Failed to show notification: \(error)")
            } else {
                print("📱 iOS: Notification successfully scheduled (Time Sensitive: \(isTimeSensitive))")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationMonitor: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification response if needed
        channel?.invokeMethod("handleNotificationResponse", arguments: userInfo)
        
        completionHandler()
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
                let isTimeSensitive = args["isTimeSensitive"] as? Bool ?? false
                showCustomNotification(title: title, message: message, userEmail: userEmail, isTimeSensitive: isTimeSensitive)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Title, message and userEmail required", details: nil))
            }
            
        case "checkTimeSensitivePermissions":
            checkTimeSensitivePermissions { hasPermission in
                result(hasPermission)
            }
            
        case "requestTimeSensitivePermission":
            requestTimeSensitivePermission { hasPermission in
                result(hasPermission)
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .timeSensitive]) { granted, error in
            if granted {
                print("📱 iOS: Notification permissions granted (including time-sensitive)")
                self.setupNotificationCategories()
            } else {
                print("📱 iOS: Notification permissions denied")
                if let error = error {
                    print("📱 iOS: Permission error: \(error)")
                }
            }
        }
    }
    
    private func checkTimeSensitivePermissions(completion: @escaping (Bool) -> Void) {
        print("📱 iOS: Checking time-sensitive notification permissions...")
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 iOS: Current notification settings:")
            print("📱 iOS: Authorization status: \(settings.authorizationStatus.rawValue)")
            
            // First check if basic notifications are authorized
            guard settings.authorizationStatus == .authorized else {
                print("📱 iOS: Basic notifications not authorized, requesting all permissions...")
                self.requestTimeSensitivePermission(completion: completion)
                return
            }
            
            if #available(iOS 15.0, *) {
                print("📱 iOS: Time-sensitive setting: \(settings.timeSensitiveSetting.rawValue)")
                
                switch settings.timeSensitiveSetting {
                case .enabled:
                    print("📱 iOS: Time-sensitive notifications already enabled")
                    completion(true)
                case .disabled:
                    print("📱 iOS: Time-sensitive notifications disabled by user")
                    completion(false)
                case .notSupported:
                    print("📱 iOS: Time-sensitive notifications not supported on this device")
                    completion(false)
                @unknown default:
                    // This handles the case where the user hasn't been asked for time-sensitive permissions yet
                    print("📱 iOS: Time-sensitive setting not determined, requesting permission...")
                    self.requestTimeSensitivePermission(completion: completion)
                }
            } else {
                print("📱 iOS: iOS 15+ required for time-sensitive notifications")
                completion(false)
            }
        }
    }
    
    private func requestTimeSensitivePermission(completion: @escaping (Bool) -> Void) {
        print("📱 iOS: Requesting time-sensitive notification permissions...")
        
        // First, let's check current settings before requesting
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 iOS: Current settings before request:")
            print("📱 iOS: Authorization status: \(settings.authorizationStatus.rawValue)")
            if #available(iOS 15.0, *) {
                print("📱 iOS: Time-sensitive setting: \(settings.timeSensitiveSetting.rawValue)")
            }
            
            // Request authorization with time-sensitive option
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .timeSensitive]) { granted, error in
                if let error = error {
                    print("📱 iOS: Error requesting time-sensitive permission: \(error)")
                    completion(false)
                    return
                }
                
                print("📱 iOS: Permission request completed. Granted: \(granted)")
                
                if granted {
                    // Check the actual setting after permission request
                    UNUserNotificationCenter.current().getNotificationSettings { newSettings in
                        print("📱 iOS: Settings after permission request:")
                        print("📱 iOS: Authorization status: \(newSettings.authorizationStatus.rawValue)")
                        
                        if #available(iOS 15.0, *) {
                            print("📱 iOS: Time-sensitive setting: \(newSettings.timeSensitiveSetting.rawValue)")
                            let isTimeSensitiveEnabled = newSettings.timeSensitiveSetting == .enabled
                            print("📱 iOS: Time-sensitive notifications enabled: \(isTimeSensitiveEnabled)")
                            
                            // Setup notification categories after permission is granted
                            if isTimeSensitiveEnabled {
                                self.setupNotificationCategories()
                            }
                            
                            completion(isTimeSensitiveEnabled)
                        } else {
                            print("📱 iOS: iOS 15+ required for time-sensitive notifications")
                            completion(false)
                        }
                    }
                } else {
                    print("📱 iOS: Time-sensitive notification permission denied by user")
                    completion(false)
                }
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
        
        let refereeCategory = UNNotificationCategory(
            identifier: "referee_invitation",
            actions: [acceptAction, declineAction, laterAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Schiedsrichter-Einladung",
            categorySummaryFormat: "%u neue Einladungen",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )
        
        let customCategory = UNNotificationCategory(
            identifier: "custom_notification",
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Benachrichtigung",
            categorySummaryFormat: "%u neue Benachrichtigungen",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )
        
        let timeSensitiveCategory = UNNotificationCategory(
            identifier: "time_sensitive_notification",
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Zeitkritische Benachrichtigung",
            categorySummaryFormat: "%u zeitkritische Benachrichtigungen",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([refereeCategory, customCategory, timeSensitiveCategory])
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
  
  private func showCustomNotification(title: String, message: String, userEmail: String, isTimeSensitive: Bool) {
    print("📱 iOS: showCustomNotification called for user: \(userEmail)")
    print("📱 iOS: Title: \(title), Message: \(message), Time Sensitive: \(isTimeSensitive)")
    
    let content = UNMutableNotificationContent()
    content.title = isTimeSensitive ? "⚠️ \(title)" : title
    content.body = message
    content.sound = .default
    content.badge = 1
    content.categoryIdentifier = isTimeSensitive ? "time_sensitive_notification" : "custom_notification"
    
    // Set interruption level for time-sensitive notifications
    if #available(iOS 15.0, *) {
      content.interruptionLevel = isTimeSensitive ? .timeSensitive : .active
    }
    
    // Add custom data to userInfo
    content.userInfo = [
      "type": "custom_notification",
      "userEmail": userEmail,
      "title": title,
      "message": message,
      "isTimeSensitive": isTimeSensitive
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
        print("📱 iOS: Custom notification successfully scheduled (Time Sensitive: \(isTimeSensitive))")
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
