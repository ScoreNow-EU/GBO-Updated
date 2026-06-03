// Stub implementation for non-web platforms.
// Browser Notification API is only available on web.

Future<String> requestNotificationPermission() async => 'denied';

String getNotificationPermission() => 'unsupported';

void createBrowserNotification(
  String title, {
  String? body,
  String? tag,
}) {
  // No-op on non-web platforms.
}
