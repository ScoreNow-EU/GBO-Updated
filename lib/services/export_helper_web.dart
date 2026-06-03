// Web implementation of CSV/JSON download
// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

void downloadCsv(String content, String filename) {
  final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void downloadJson(String content, String filename) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
