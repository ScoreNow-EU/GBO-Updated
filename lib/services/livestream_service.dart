import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/livestream_credentials.dart';

/// Client-side service for the YouTube livestream automation.
///
/// All sensitive operations (token storage, broadcast creation) happen in
/// the `europe-west1` Cloud Functions; this class only orchestrates calls
/// and exposes a simple connection-status check.
class LivestreamService {
  static const String _region = 'europe-west1';
  static const String _oauthDocPath = 'config/youtube_oauth';

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  LivestreamService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: _region),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// True when an admin has connected a YouTube channel and the refresh
  /// token is stored. Reads `config/youtube_oauth` (admin-only — non-admins
  /// will see `false` due to rules).
  Future<bool> isYoutubeConnected() async {
    try {
      final snap = await _firestore.doc(_oauthDocPath).get();
      if (!snap.exists) return false;
      final data = snap.data();
      return data != null &&
          (data['refreshToken'] as String?)?.isNotEmpty == true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the connected channel title, or `null` if not connected /
  /// not readable.
  Future<String?> connectedChannelTitle() async {
    try {
      final snap = await _firestore.doc(_oauthDocPath).get();
      final title = snap.data()?['channelTitle'] as String?;
      return (title != null && title.isNotEmpty) ? title : null;
    } catch (_) {
      return null;
    }
  }

  /// Creates a new YouTube live broadcast for the given tournament. The
  /// cloud function also writes `livestreamUrl` + `livestreamEnabled` +
  /// `livestreamYoutubeBroadcastId` onto the tournament document.
  Future<LivestreamCredentials> createBroadcast({
    required String tournamentId,
    String? title,
    String? description,
    DateTime? scheduledStartTime,
    String privacyStatus = 'unlisted',
  }) async {
    final callable = _functions.httpsCallable('createYoutubeBroadcast');
    final result = await callable.call<Map<String, dynamic>>({
      'tournamentId': tournamentId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (scheduledStartTime != null)
        'scheduledStartTime': scheduledStartTime.toUtc().toIso8601String(),
      'privacyStatus': privacyStatus,
    });
    final data = Map<String, dynamic>.from(result.data);
    return LivestreamCredentials.fromMap(data);
  }

  /// Returns the Google OAuth consent URL for connecting a YouTube channel.
  /// The URL is generated server-side (secrets stay in Cloud Functions).
  Future<String> getYoutubeAuthUrl() async {
    final callable = _functions.httpsCallable('getYoutubeAuthUrl');
    final result = await callable.call<Map<String, dynamic>>();
    final data = Map<String, dynamic>.from(result.data);
    return data['url'] as String;
  }

  /// Removes the stored OAuth token (admin only). The next broadcast
  /// creation will require re-connecting the channel.
  Future<void> disconnectYoutube() async {
    await _firestore.doc(_oauthDocPath).delete();
  }
}
