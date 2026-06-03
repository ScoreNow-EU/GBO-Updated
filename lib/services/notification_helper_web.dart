// Web implementation using the browser Notification API.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String> requestNotificationPermission() async {
  return html.Notification.requestPermission();
}

String getNotificationPermission() {
  return html.Notification.permission ?? 'default';
}

void createBrowserNotification(
  String title, {
  String? body,
  String? tag,
}) {
  html.Notification(
    title,
    body: body,
    icon: '/icons/Icon-192.png',
    tag: tag,
  );
}
