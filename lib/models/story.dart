import 'package:cloud_firestore/cloud_firestore.dart';

/// A short vertical video clip hosted on YouTube (unlisted).
///
/// Stories are created by admin/teamRHD, shown globally in the public
/// tournament overview as Instagram-style story bubbles.
class Story {
  final String id;
  final String title;
  final String videoUrl;    // Firebase Storage download URL
  final String uploadedBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int order;
  final String status; // 'uploading' | 'active'
  final String? groupTitle; // optional group name (stories with same groupTitle are shown together)

  const Story({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.uploadedBy,
    required this.createdAt,
    this.expiresAt,
    required this.order,
    required this.status,
    this.groupTitle,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isActive => status == 'active' && !isExpired;

  factory Story.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      videoUrl: (d['videoUrl'] as String?) ?? '',
      uploadedBy: (d['uploadedBy'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      order: (d['order'] as int?) ?? 0,
      status: (d['status'] as String?) ?? 'uploading',
      groupTitle: d['groupTitle'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'videoUrl': videoUrl,
        'uploadedBy': uploadedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'order': order,
        'status': status,
        if (groupTitle != null && groupTitle!.isNotEmpty)
          'groupTitle': groupTitle,
      };
}
