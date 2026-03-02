import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Service for geocoding German addresses via OpenStreetMap Nominatim
/// and calculating driving distances via OSRM.
///
/// Both APIs are free and require no API key.
/// Nominatim: max 1 request/second, requires User-Agent header.
/// OSRM demo server: for moderate use; consider self-hosting for production.
class GeocodingService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  static const String _userAgent = 'GBO-Rollstuhlhandball/1.0';

  // In-memory cache for geocoding results
  static final Map<String, Map<String, double>?> _geocodeCache = {};
  // In-memory cache for distance results
  static final Map<String, DistanceResult?> _distanceCache = {};

  // Rate-limit tracking (max 1 req/sec for Nominatim)
  static DateTime? _lastNominatimRequest;

  /// Geocode a German address to lat/lng coordinates.
  /// Returns {lat, lng} or null if not found.
  Future<Map<String, double>?> geocodeAddress({
    String? street,
    String? houseNumber,
    String? plz,
    String? city,
  }) async {
    // Build cache key
    final cacheKey = '${street ?? ''}_${houseNumber ?? ''}_${plz ?? ''}_${city ?? ''}';
    if (_geocodeCache.containsKey(cacheKey)) {
      return _geocodeCache[cacheKey];
    }

    // Rate-limit
    await _enforceNominatimRateLimit();

    try {
      final queryParams = <String, String>{
        'format': 'json',
        'countrycodes': 'de',
        'limit': '1',
      };

      // Build structured query for best results
      if (street != null && street.isNotEmpty) {
        final fullStreet = houseNumber != null && houseNumber.isNotEmpty
            ? '$street $houseNumber'
            : street;
        queryParams['street'] = fullStreet;
      }
      if (plz != null && plz.isNotEmpty) {
        queryParams['postalcode'] = plz;
      }
      if (city != null && city.isNotEmpty) {
        queryParams['city'] = city;
      }

      final uri = Uri.parse('$_nominatimBaseUrl/search').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept-Language': 'de',
      });

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final result = {
            'lat': double.parse(results[0]['lat']),
            'lng': double.parse(results[0]['lon']),
          };
          _geocodeCache[cacheKey] = result;
          return result;
        }
      }

      // Fallback: try with just PLZ + city if full address failed
      if (street != null && street.isNotEmpty && (plz != null || city != null)) {
        await _enforceNominatimRateLimit();
        final fallbackParams = <String, String>{
          'format': 'json',
          'countrycodes': 'de',
          'limit': '1',
        };
        if (plz != null && plz.isNotEmpty) fallbackParams['postalcode'] = plz;
        if (city != null && city.isNotEmpty) fallbackParams['city'] = city;

        final fallbackUri = Uri.parse('$_nominatimBaseUrl/search')
            .replace(queryParameters: fallbackParams);
        final fallbackResponse = await http.get(fallbackUri, headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'de',
        });

        if (fallbackResponse.statusCode == 200) {
          final List<dynamic> results = json.decode(fallbackResponse.body);
          if (results.isNotEmpty) {
            final result = {
              'lat': double.parse(results[0]['lat']),
              'lng': double.parse(results[0]['lon']),
            };
            _geocodeCache[cacheKey] = result;
            return result;
          }
        }
      }

      _geocodeCache[cacheKey] = null;
      return null;
    } catch (e) {
      print('Geocoding error: $e');
      return null;
    }
  }

  /// Calculate driving distance and duration between two coordinates using OSRM.
  /// Returns DistanceResult with km and minutes, or null on failure.
  Future<DistanceResult?> calculateDrivingDistance(
    double lat1, double lng1,
    double lat2, double lng2,
  ) async {
    final cacheKey = '${lat1.toStringAsFixed(4)}_${lng1.toStringAsFixed(4)}_'
        '${lat2.toStringAsFixed(4)}_${lng2.toStringAsFixed(4)}';

    if (_distanceCache.containsKey(cacheKey)) {
      return _distanceCache[cacheKey];
    }

    try {
      // OSRM uses lng,lat order (not lat,lng!)
      final uri = Uri.parse(
        '$_osrmBaseUrl/route/v1/driving/$lng1,$lat1;$lng2,$lat2?overview=false',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final result = DistanceResult(
            distanceKm: (route['distance'] as num).toDouble() / 1000.0,
            durationMinutes: (route['duration'] as num).toDouble() / 60.0,
          );
          _distanceCache[cacheKey] = result;
          return result;
        }
      }

      _distanceCache[cacheKey] = null;
      return null;
    } catch (e) {
      print('OSRM distance calculation error: $e');
      return null;
    }
  }

  /// Calculate straight-line (Haversine) distance in km.
  /// Use this as a fast fallback when OSRM is unavailable.
  static double haversineDistance(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  /// Enforce max 1 request/second for Nominatim
  Future<void> _enforceNominatimRateLimit() async {
    if (_lastNominatimRequest != null) {
      final elapsed = DateTime.now().difference(_lastNominatimRequest!);
      if (elapsed.inMilliseconds < 1100) {
        await Future.delayed(Duration(milliseconds: 1100 - elapsed.inMilliseconds));
      }
    }
    _lastNominatimRequest = DateTime.now();
  }

  /// Clear all caches (useful when testing or when users want fresh data)
  static void clearCache() {
    _geocodeCache.clear();
    _distanceCache.clear();
  }
}

/// Result of a driving distance calculation.
class DistanceResult {
  final double distanceKm;
  final double durationMinutes;

  DistanceResult({
    required this.distanceKm,
    required this.durationMinutes,
  });

  /// Formatted distance string, e.g. "127 km"
  String get formattedDistance => '${distanceKm.round()} km';

  /// Formatted duration string, e.g. "1h 32min"
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final mins = (durationMinutes % 60).round();
    if (hours > 0) {
      return '${hours}h ${mins}min';
    }
    return '${mins} min';
  }

  @override
  String toString() => '$formattedDistance ($formattedDuration)';
}
