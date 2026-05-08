import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Asumsi waktu berhenti di setiap titik (menit)
const int stopDurationMinutes = 10;

Future<void> main() async {
  const startLat = -8.803094;
  const startLng = 115.217775;
  const startName = 'Depot (Titik Berangkat)';

  final destinations = <Destination>[
    const Destination('Pondok Deta Guest House', -8.801072, 115.219258),
    const Destination(
      'Pura Dalem Khayangan Tanjung Benoa',
      -8.761089,
      115.221852,
    ),
    const Destination('Infinity Pool', -8.766845, 115.223429),
    const Destination('Warung Sarita Blok J/7', -8.803183, 115.218979),
    const Destination(
      'The Laguna Resort & Spa Nusa Dua, Bali',
      -8.796965,
      115.231620,
    ),
  ];

  print('🗺️  Membangun rute optimal untuk ${destinations.length} destinasi...');
  print('⏸️  Asumsi waktu berhenti per titik : $stopDurationMinutes menit\n');

  // ── Demo 1: raw result (seperti sebelumnya) ──────────────────────────────
  try {
    final result = await RoutePlanner.buildOptimalRoute(
      startLat: startLat,
      startLng: startLng,
      startName: startName,
      destinations: destinations,
    );

    print('\n╔══════════════════════════════════════════════════════════════╗');
    print('║              FINAL ROUTE  (${result.length} TITIK)                        ║');
    print('╚══════════════════════════════════════════════════════════════╝\n');

    print('📍 [0] $startName');
    print('       LatLng  : $startLat, $startLng');
    print('       Status  : TITIK BERANGKAT');

    var totalDrivingDistanceM = 0;
    var totalDrivingDurationSec = 0;

    for (var i = 0; i < result.length; i++) {
      final step = result[i];
      final d = step.destination;
      final fromName =
          i == 0 ? startName : result[i - 1].destination.namaTempat;

      totalDrivingDistanceM += step.distanceFromPrevMeters;
      totalDrivingDurationSec += step.durationFromPrevSeconds;

      final depotDistM = step.distanceFromDepotMeters;
      final depotDurMin = (step.durationFromDepotSeconds / 60).toStringAsFixed(1);
      final prevDistM = step.distanceFromPrevMeters;
      final prevDurMin = (step.durationFromPrevSeconds / 60).toStringAsFixed(1);

      print('\n       │');
      print('       │  🚗 $prevDistM m  •  $prevDurMin menit berkendara');
      print('       │  dari : "$fromName"');
      print('       ▼');
      print('📍 [${i + 1}] ${d.namaTempat}');
      print('       LatLng              : ${d.latitude}, ${d.longitude}');
      print('       ── Dari Depot ──────────────────────────────');
      print('       📏 Jarak dari depot  : $depotDistM m  (${(depotDistM / 1000).toStringAsFixed(2)} km)');
      print('       ⏱️  Durasi dari depot : $depotDurMin menit berkendara');
      print('       ── Dari Titik Sebelumnya ───────────────────');
      print('       📏 Jarak dari sebelum: $prevDistM m  (${(prevDistM / 1000).toStringAsFixed(2)} km)');
      print('       ⏱️  Durasi dari sebelum: $prevDurMin menit berkendara');
      print('       ── Aktivitas di Titik ──────────────────────');
      print('       ⏸️  Waktu berhenti    : $stopDurationMinutes menit');
    }

    final totalDrivingMin = totalDrivingDurationSec / 60;
    final totalStopMin = result.length * stopDurationMinutes;
    final totalMin = totalDrivingMin + totalStopMin;
    final totalHour = (totalMin / 60).floor();
    final totalRemainMin = (totalMin % 60).round();

    print('\n══════════════════════════════════════════════════════════════');
    print('📊 RINGKASAN PERJALANAN');
    print('══════════════════════════════════════════════════════════════');
    print('📏 Total Jarak Tempuh   : $totalDrivingDistanceM m  (${(totalDrivingDistanceM / 1000).toStringAsFixed(2)} km)');
    print('🚗 Total Waktu Berkendara: ${totalDrivingMin.toStringAsFixed(1)} menit');
    print('⏸️  Total Waktu Berhenti : $totalStopMin menit  (${result.length} titik × $stopDurationMinutes menit)');
    print('──────────────────────────────────────────────────────────────');
    print('⏱️  TOTAL WAKTU KESELURUHAN');
    print('   Tanpa berhenti : ${totalDrivingMin.toStringAsFixed(1)} menit');
    print('   Dengan berhenti: ${totalMin.toStringAsFixed(1)} menit  ($totalHour jam $totalRemainMin menit)');
    print('──────────────────────────────────────────────────────────────');
    print('🚀 OSRM API CALL     : ${OsrmService.tableCallCount}x');
    print('✅ Efisiensi         : 1 call untuk ${destinations.length} titik');
    print('══════════════════════════════════════════════════════════════\n');
  } on OsrmException catch (e) {
    print('❌ OSRM Error: ${e.message}');
  } catch (e, st) {
    print('❌ Error tidak terduga: $e\n$st');
  }

  // ── Demo 2: pakai RouteOptimizerService (Flutter-ready) ─────────────────
  print('\n── Demo RouteOptimizerService (JSON output) ──\n');
  try {
    final service = RouteOptimizerService(stopDurationMinutesPerStop: 10);

    final json = await service.buildOptimalRouteJson(
      startLat: startLat,
      startLng: startLng,
      startName: startName,
      destinations: destinations,
    );

    print(const JsonEncoder.withIndent('  ').convert(json));
  } on OsrmException catch (e) {
    print('❌ OSRM Error: ${e.message}');
  } catch (e, st) {
    print('❌ Error tidak terduga: $e\n$st');
  }
}

//////////////////////////////////////////////////////
/// MODELS
//////////////////////////////////////////////////////

class Destination {
  final String namaTempat;
  final double latitude;
  final double longitude;

  const Destination(this.namaTempat, this.latitude, this.longitude);

  /// Untuk keperluan serialisasi ke JSON
  Map<String, dynamic> toJson() => {
        'nama_tempat': namaTempat,
        'latitude': latitude,
        'longitude': longitude,
      };

  /// Buat Destination dari Map (berguna saat terima data dari Flutter UI)
  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
        json['nama_tempat'] as String,
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      );
}

class RouteStep {
  final Destination destination;
  final int distanceFromPrevMeters;
  final int durationFromPrevSeconds;
  final int distanceFromDepotMeters;
  final int durationFromDepotSeconds;

  const RouteStep({
    required this.destination,
    required this.distanceFromPrevMeters,
    required this.durationFromPrevSeconds,
    required this.distanceFromDepotMeters,
    required this.durationFromDepotSeconds,
  });

  Map<String, dynamic> toJson() => {
        'destination': destination.toJson(),
        'from_prev': {
          'distance_m': distanceFromPrevMeters,
          'distance_km': double.parse(
            (distanceFromPrevMeters / 1000).toStringAsFixed(2),
          ),
          'duration_seconds': durationFromPrevSeconds,
          'duration_minutes': double.parse(
            (durationFromPrevSeconds / 60).toStringAsFixed(1),
          ),
        },
        'from_depot': {
          'distance_m': distanceFromDepotMeters,
          'distance_km': double.parse(
            (distanceFromDepotMeters / 1000).toStringAsFixed(2),
          ),
          'duration_seconds': durationFromDepotSeconds,
          'duration_minutes': double.parse(
            (durationFromDepotSeconds / 60).toStringAsFixed(1),
          ),
        },
      };
}

class OsrmMatrix {
  final List<List<int>> distances;
  final List<List<int>> durations;

  const OsrmMatrix({required this.distances, required this.durations});
}

//////////////////////////////////////////////////////
/// CUSTOM EXCEPTION
//////////////////////////////////////////////////////

class OsrmException implements Exception {
  final String message;
  const OsrmException(this.message);

  @override
  String toString() => 'OsrmException: $message';
}

//////////////////////////////////////////////////////
/// ROUTE OPTIMIZER SERVICE  ← wrapper Flutter-ready
///
/// Gunakan class ini di Flutter app.
/// Semua algo tetap sama, hanya output dibungkus Map<String, dynamic>
/// sehingga bisa langsung dipakai State Management (BLoC, GetX, Riverpod).
///
/// Contoh pemakaian di Flutter:
///
///   final service = RouteOptimizerService(stopDurationMinutesPerStop: 10);
///
///   final json = await service.buildOptimalRouteJson(
///     startLat: currentLat,
///     startLng: currentLng,
///     startName: 'Gudang Utama',
///     destinations: listDestination,
///   );
///
///   // Akses data:
///   final steps = json['steps'] as List;
///   final totalKm = json['summary']['total_distance_km'];
///   final totalMenitDenganBerhenti = json['summary']['total_duration_with_stop_minutes'];
//////////////////////////////////////////////////////

class RouteOptimizerService {
  /// Berapa menit kurir berhenti di setiap titik untuk mengerjakan tugasnya
  final int stopDurationMinutesPerStop;

  const RouteOptimizerService({this.stopDurationMinutesPerStop = 10});

  /// Hitung rute optimal dan kembalikan sebagai [Map<String, dynamic>].
  ///
  /// Return structure:
  /// ```json
  /// {
  ///   "depot": { "name", "latitude", "longitude" },
  ///   "steps": [
  ///     {
  ///       "order": 1,
  ///       "destination": { "nama_tempat", "latitude", "longitude" },
  ///       "from_prev":  { "distance_m", "distance_km", "duration_seconds", "duration_minutes" },
  ///       "from_depot": { "distance_m", "distance_km", "duration_seconds", "duration_minutes" },
  ///       "stop_duration_minutes": 10
  ///     }
  ///   ],
  ///   "summary": {
  ///     "total_stops": 5,
  ///     "total_distance_m": 13450,
  ///     "total_distance_km": 13.45,
  ///     "total_driving_duration_seconds": 1704,
  ///     "total_driving_duration_minutes": 28.4,
  ///     "total_stop_duration_minutes": 50,
  ///     "total_duration_with_stop_minutes": 78.4,
  ///     "total_duration_with_stop_hours": 1,
  ///     "total_duration_with_stop_remaining_minutes": 18,
  ///     "osrm_api_call_count": 1
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> buildOptimalRouteJson({
    required double startLat,
    required double startLng,
    required String startName,
    required List<Destination> destinations,
  }) async {
    // Panggil algo yang sudah ada — tidak ada perubahan apapun di sini
    final steps = await RoutePlanner.buildOptimalRoute(
      startLat: startLat,
      startLng: startLng,
      startName: startName,
      destinations: destinations,
    );

    // ── Hitung summary ─────────────────────────────────────────────────────
    var totalDistanceM = 0;
    var totalDrivingSeconds = 0;

    for (final step in steps) {
      totalDistanceM += step.distanceFromPrevMeters;
      totalDrivingSeconds += step.durationFromPrevSeconds;
    }

    final totalDrivingMin = totalDrivingSeconds / 60;
    final totalStopMin = steps.length * stopDurationMinutesPerStop;
    final totalMin = totalDrivingMin + totalStopMin;

    // ── Susun JSON output ──────────────────────────────────────────────────
    return {
      'depot': {
        'name': startName,
        'latitude': startLat,
        'longitude': startLng,
      },
      'steps': steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        return {
          'order': i + 1,
          ...step.toJson(),
          'stop_duration_minutes': stopDurationMinutesPerStop,
        };
      }).toList(),
      'summary': {
        'total_stops': steps.length,
        'total_distance_m': totalDistanceM,
        'total_distance_km': double.parse(
          (totalDistanceM / 1000).toStringAsFixed(2),
        ),
        'total_driving_duration_seconds': totalDrivingSeconds,
        'total_driving_duration_minutes': double.parse(
          totalDrivingMin.toStringAsFixed(1),
        ),
        'total_stop_duration_minutes': totalStopMin,
        'total_duration_with_stop_minutes': double.parse(
          totalMin.toStringAsFixed(1),
        ),
        'total_duration_with_stop_hours': (totalMin / 60).floor(),
        'total_duration_with_stop_remaining_minutes': (totalMin % 60).round(),
        'osrm_api_call_count': OsrmService.tableCallCount,
      },
    };
  }

  /// Versi ringkas: hanya kembalikan list steps tanpa summary.
  /// Berguna kalau Yang Mulia hanya butuh urutan titik saja untuk di-render di peta.
  Future<List<Map<String, dynamic>>> buildOptimalStepsOnly({
    required double startLat,
    required double startLng,
    required String startName,
    required List<Destination> destinations,
  }) async {
    final steps = await RoutePlanner.buildOptimalRoute(
      startLat: startLat,
      startLng: startLng,
      startName: startName,
      destinations: destinations,
    );

    return steps.asMap().entries.map((entry) {
      final i = entry.key;
      final step = entry.value;
      return {
        'order': i + 1,
        ...step.toJson(),
        'stop_duration_minutes': stopDurationMinutesPerStop,
      };
    }).toList();
  }
}

//////////////////////////////////////////////////////
/// ROUTE PLANNER  (tidak ada perubahan algo)
//////////////////////////////////////////////////////

class RoutePlanner {
  static final OsrmService _osrm = OsrmService();

  static Future<List<RouteStep>> buildOptimalRoute({
    required double startLat,
    required double startLng,
    required String startName,
    required List<Destination> destinations,
  }) async {
    final n = destinations.length;
    if (n == 0) return [];

    print('📡 Memanggil OSRM TABLE API (1 call untuk ${n + 1} node)...');
    final matrix = await _osrm.getFullMatrix(
      originLat: startLat,
      originLng: startLng,
      destinations: destinations,
    );

    final nnOrder = _nearestNeighbor(matrix, n);
    final nnCost = _pathCost(matrix, nnOrder);
    print('✅ Nearest Neighbor selesai. Jarak awal    : $nnCost m');

    final optimizedOrder = _twoOptImprovement(matrix, nnOrder, n);
    final optCost = _pathCost(matrix, optimizedOrder);
    final pct = nnCost > 0
        ? ((nnCost - optCost) / nnCost * 100).toStringAsFixed(1)
        : '0.0';
    print('✅ 2-opt selesai.          Jarak akhir    : $optCost m (hemat $pct%)');

    final result = <RouteStep>[];
    var prevNode = 0;

    for (final destIdx in optimizedOrder) {
      final matrixIdx = destIdx + 1;

      result.add(
        RouteStep(
          destination: destinations[destIdx],
          distanceFromPrevMeters: matrix.distances[prevNode][matrixIdx],
          durationFromPrevSeconds: matrix.durations[prevNode][matrixIdx],
          distanceFromDepotMeters: matrix.distances[0][matrixIdx],
          durationFromDepotSeconds: matrix.durations[0][matrixIdx],
        ),
      );

      prevNode = matrixIdx;
    }

    return result;
  }

  static List<int> _nearestNeighbor(OsrmMatrix matrix, int n) {
    final visited = List<bool>.filled(n, false);
    final order = <int>[];
    var currentNode = 0;

    for (var step = 0; step < n; step++) {
      var bestDestIdx = -1;
      var bestDist = 999999999;

      for (var i = 0; i < n; i++) {
        if (visited[i]) continue;
        final dist = matrix.distances[currentNode][i + 1];
        if (dist < bestDist) {
          bestDist = dist;
          bestDestIdx = i;
        }
      }

      visited[bestDestIdx] = true;
      order.add(bestDestIdx);
      currentNode = bestDestIdx + 1;
    }

    return order;
  }

  static List<int> _twoOptImprovement(
    OsrmMatrix matrix,
    List<int> order,
    int n,
  ) {
    var best = List<int>.from(order);
    var improved = true;

    while (improved) {
      improved = false;
      final currentCost = _pathCost(matrix, best);

      outerLoop:
      for (var i = 0; i < n - 1; i++) {
        for (var k = i + 1; k < n; k++) {
          final candidate = _reverseSegment(best, i, k);
          if (_pathCost(matrix, candidate) < currentCost) {
            best = candidate;
            improved = true;
            break outerLoop;
          }
        }
      }
    }

    return best;
  }

  static int _pathCost(OsrmMatrix matrix, List<int> order) {
    var total = 0;
    var prev = 0;
    for (final destIdx in order) {
      total += matrix.distances[prev][destIdx + 1];
      prev = destIdx + 1;
    }
    return total;
  }

  static List<int> _reverseSegment(List<int> order, int i, int k) {
    final result = List<int>.from(order);
    var lo = i;
    var hi = k;
    while (lo < hi) {
      final tmp = result[lo];
      result[lo] = result[hi];
      result[hi] = tmp;
      lo++;
      hi--;
    }
    return result;
  }
}

//////////////////////////////////////////////////////
/// OSRM TABLE SERVICE  (tidak ada perubahan)
//////////////////////////////////////////////////////

class OsrmService {
  static int tableCallCount = 0;

  static const _timeout = Duration(seconds: 20);
  static const _maxRetries = 3;
  static const _unreachable = 999999999;

  Future<OsrmMatrix> getFullMatrix({
    required double originLat,
    required double originLng,
    required List<Destination> destinations,
  }) async {
    tableCallCount++;

    final coords = [
      '$originLng,$originLat',
      ...destinations.map((d) => '${d.longitude},${d.latitude}'),
    ].join(';');

    final url = Uri.parse(
      'https://router.project-osrm.org/table/v1/driving/$coords'
      '?annotations=distance,duration',
    );

    final body = await _getWithRetry(url);
    final json = jsonDecode(body) as Map<String, dynamic>;

    if (json['code'] != 'Ok') {
      throw OsrmException(
        'OSRM TABLE gagal — '
        'code: "${json['code']}", '
        'message: "${json['message'] ?? 'tidak ada keterangan'}"',
      );
    }

    List<List<int>> parseMatrix(List raw) => raw
        .map<List<int>>(
          (row) => (row as List)
              .map<int>(
                  (v) => v == null ? _unreachable : (v as num).round())
              .toList(),
        )
        .toList();

    return OsrmMatrix(
      distances: parseMatrix(json['distances'] as List),
      durations: parseMatrix(json['durations'] as List),
    );
  }

  Future<String> _getWithRetry(Uri url) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(url).timeout(
          _timeout,
          onTimeout: () => throw OsrmException(
            'Request timeout setelah ${_timeout.inSeconds} detik '
            '(percobaan $attempt/$_maxRetries)',
          ),
        );

        if (response.statusCode == 200) return response.body;

        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw OsrmException(
            'HTTP ${response.statusCode} (Client Error): ${response.reasonPhrase}. '
            'Periksa URL dan format koordinat.',
          );
        }

        lastError = OsrmException(
          'HTTP ${response.statusCode} (Server Error): ${response.reasonPhrase} '
          '(percobaan $attempt/$_maxRetries)',
        );
      } on OsrmException {
        rethrow;
      } catch (e) {
        lastError = e;
      }

      if (attempt < _maxRetries) {
        final waitMs = 500 * (1 << (attempt - 1));
        print(
          '⚠️  Percobaan $attempt gagal ($lastError), retry dalam ${waitMs}ms...',
        );
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }

    throw OsrmException(
      'Gagal menghubungi OSRM setelah $_maxRetries percobaan. '
      'Error terakhir: $lastError',
    );
  }
}

//////////////////////////////////////////////////////
/// SIMULATOR  (tidak ada perubahan)
//////////////////////////////////////////////////////

class RouteSimulator {
  static List<Destination> generateRandomDestinations({
    required double centerLat,
    required double centerLng,
    required int count,
    required double radiusKm,
  }) {
    final rand = Random();
    final list = <Destination>[];

    const latDegPerKm = 1.0 / 111.0;
    final lngDegPerKm = 1.0 / (111.0 * cos(centerLat * pi / 180.0));

    for (var i = 0; i < count; i++) {
      final dLat = (rand.nextDouble() * 2 - 1) * radiusKm * latDegPerKm;
      final dLng = (rand.nextDouble() * 2 - 1) * radiusKm * lngDegPerKm;

      list.add(
        Destination(
          'Titik Sampah #${i + 1}',
          centerLat + dLat,
          centerLng + dLng,
        ),
      );
    }

    return list;
  }
}
