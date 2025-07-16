# iOS Setup Instructions for Referee Invitation Monitoring

## ✅ Files Added
The following files have been added to your `ios/Runner` directory:
- `RefereeInvitationMonitor.swift` - Native iOS monitoring implementation
- `AppDelegate.swift` - Updated with background task support
- `Info.plist` - Updated with required permissions and background modes

## 📱 Xcode Configuration Required

### 1. Enable Capabilities in Xcode
Open `ios/Runner.xcodeproj` in Xcode:

1. Select your app target (`Runner`)
2. Go to **"Signing & Capabilities"** tab
3. Click the **"+"** button to add capabilities
4. Add these capabilities:
   - **Push Notifications**
   - **Background Modes**

### 2. Configure Background Modes
In the **Background Modes** capability, enable:
- ✅ **Background fetch**
- ✅ **Remote notifications**
- ✅ **Background processing**

### 3. Add RefereeInvitationMonitor.swift to Project
1. In Xcode, right-click on the `Runner` group
2. Select **"Add Files to Runner"**
3. Navigate to `ios/Runner/RefereeInvitationMonitor.swift`
4. Click **"Add"**
5. Make sure the file is added to the `Runner` target

## 🧪 Testing

### Enable Background App Refresh
1. On your iOS device: **Settings** → **General** → **Background App Refresh**
2. Enable **Background App Refresh** globally
3. Enable it specifically for your app

### Test Background Tasks in Xcode
1. Run the app in Xcode
2. Put the app in background (Home button)
3. In Xcode debugger console, run:
   ```
   e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.gbo.referee-check"]
   ```

### Test Push Notifications
1. Log in as a referee
2. Create a referee invitation in the admin panel
3. Wait for background refresh (or trigger manually)
4. Should receive push notification with action buttons:
   - **Zusagen** (Accept)
   - **Absagen** (Decline)
   - **Später** (Later)

## 🔧 How It Works

1. **Flutter Side**: Checks every 30 seconds when app is active
2. **iOS Background**: Native iOS checks every 15 minutes via Background Tasks
3. **New Invitations**: Push notification sent with interactive buttons
4. **User Action**: Response saved directly to Firebase via method channel
5. **Confirmation**: Secondary notification confirms the action

## 🚨 Important Notes

- **Physical Device Required**: Push notifications only work on physical iOS devices
- **Background Limits**: iOS manages background execution time and frequency
- **Battery Optimization**: iOS automatically optimizes based on user behavior
- **User Control**: Users can disable background refresh in iOS Settings

## 📊 Debug Information

The app includes a debug widget on the referee dashboard that shows:
- Current monitoring status
- Last check timestamp
- Pending invitations count
- Manual test button

## 🎯 Production Considerations

For production deployment:
- Test thoroughly on various iOS devices
- Monitor background execution in production
- Consider user onboarding for notification permissions
- Implement proper error handling and fallbacks

---

**Next Steps**: Enable the capabilities in Xcode and test on a physical iOS device! 