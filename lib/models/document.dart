import 'package:cloud_firestore/cloud_firestore.dart';

class Document {
  final String id;
  final String name;
  final String category; // 'spielordnung', 'regularien', 'satzung', 'sonstiges'
  final int version;
  final String uploadedBy; // userId
  final DateTime uploadedAt;
  final String storageUrl;
  final int fileSize; // bytes
  final String mimeType;

  Document({
    required this.id,
    required this.name,
    required this.category,
    this.version = 1,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.storageUrl,
    required this.fileSize,
    required this.mimeType,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'version': version,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'storageUrl': storageUrl,
      'fileSize': fileSize,
      'mimeType': mimeType,
    };
  }

  static Document fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Document(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'sonstiges',
      version: data['version'] ?? 1,
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedAt: data['uploadedAt'] != null
          ? (data['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
      storageUrl: data['storageUrl'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      mimeType: data['mimeType'] ?? '',
    );
  }

  static String categoryDisplayName(String category) {
    switch (category) {
      case 'spielordnung':
        return 'Spielordnung';
      case 'regularien':
        return 'Regularien';
      case 'satzung':
        return 'Satzung';
      case 'sonstiges':
        return 'Sonstiges';
      default:
        return category;
    }
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
