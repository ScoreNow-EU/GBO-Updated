// Stub implementation for non-web platforms.
// CSV export via browser download is only supported on web.
void downloadCsv(String content, String filename) {
  throw UnsupportedError(
    'CSV download is only available on the web platform. '
    'Use share functionality to export on mobile/desktop.',
  );
}
