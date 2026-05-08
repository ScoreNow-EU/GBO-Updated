/// Returned by the `createYoutubeBroadcast` cloud function.
///
/// `rtmpUrl` + `streamKey` are configured in OBS / vMix to push video to
/// YouTube. `embedUrl` is the player URL that gets stored on the tournament
/// (`livestreamUrl`); `watchUrl` is the public youtube.com link.
class LivestreamCredentials {
  final String broadcastId;
  final String streamId;
  final String watchUrl;
  final String embedUrl;
  final String rtmpUrl;
  final String streamKey;

  const LivestreamCredentials({
    required this.broadcastId,
    required this.streamId,
    required this.watchUrl,
    required this.embedUrl,
    required this.rtmpUrl,
    required this.streamKey,
  });

  factory LivestreamCredentials.fromMap(Map<String, dynamic> data) {
    return LivestreamCredentials(
      broadcastId: (data['broadcastId'] ?? '') as String,
      streamId: (data['streamId'] ?? '') as String,
      watchUrl: (data['watchUrl'] ?? '') as String,
      embedUrl: (data['embedUrl'] ?? '') as String,
      rtmpUrl: (data['rtmpUrl'] ?? '') as String,
      streamKey: (data['streamKey'] ?? '') as String,
    );
  }
}
