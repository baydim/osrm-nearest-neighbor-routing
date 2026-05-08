import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const startLat = -8.803094;
  const startLng = 115.217775;
  const startName = 'Titik Berangkat (Depot)';

  // final destinations = RouteSimulator.generateRandomDestinations(
  //   centerLat: startLat,
  //   centerLng: startLng,
  //   count: 50,
  //   radiusKm: 5,
  // );

  final destinations = <Destination>[
    Destination('Pondok Deta Guest House', -8.801072, 115.219258),
    Destination('Pura Dalem Khayangan Tanjung Benoa', -8.761089, 115.221852),
    Destination('Infinity Pool', -8.766845, 115.223429),
    Destination('Warung Sarita Blok J/7', -8.803183, 115.218979),
    Destination(
      'The Laguna Resort & Spa Nusa Dua, Bali',
      -8.796965,
      115.231620,
    ),
  ];

  final result = await RoutePlanner.buildOptimalRoute(
    startLat: startLat,
    startLng: startLng,
    startName: startName,
    destinations: destinations,
  );

  // ── PRINT FINAL ROUTE ────────────────────────────────────────
  print('\n╔═════════════════════════════════════════════════════╗');
  print('║          FINAL ROUTE (${result.length} TITIK)                     ║');
  print('╚═════════════════════════════════════════════════════╝\n');

  // Titik 0 — Depot
  print('📍 [0] $startName');
  print('       LatLng : $startLat, $startLng');
  print('       Status : TITIK BERANGKAT');

  var totalDistance = 0;
  var totalDuration = 0;

  for (var i = 0; i < result.length; i++) {
    final step = result[i];
    final d = step.destination;
    final fromName = i == 0 ? startName : result[i - 1].destination.namaTempat;

    totalDistance += step.distanceMeters;
    totalDuration += step.durationSeconds;

    print('\n       │');
    print('       │  🚗 ${step.distanceMeters} m  •  ${(step.durationSeconds / 60).round()} menit');
    print('       │  dari: "$fromName"');
    print('       ▼');
    print('📍 [${i + 1}] ${d.namaTempat}');
    print('       LatLng : ${d.latitude}, ${d.longitude}');
    print('       Jarak dari depot    : ${step.distanceFromDepotMeters} m');
    print('       Jarak dari sebelumnya: ${step.distanceMeters} m');
  }

  print('\n══════════════════════════════════════════════════════');
  print('📊 TOTAL JARAK  : $totalDistance m');
  print('⏱  TOTAL DURASI : ${(totalDuration / 60).round()} menit');
  print('🚀 OSRM CALL    : ${OsrmService.tableCallCount}x');
  print('✅ Efisiensi    : 1 call untuk ${destinations.length} titik');
  print('══════════════════════════════════════════════════════\n');
}

//////////////////////////////////////////////////////
/// MODELS
//////////////////////////////////////////////////////

class Destination {
  final String namaTempat;
  final double latitude;
  final double longitude;

  const Destination(this.namaTempat, this.latitude, this.longitude);
}

class RouteStep {
  final Destination destination;

  /// Jarak dari titik sebelumnya (bisa dari depot atau titik sebelumnya)
  final int distanceMeters;

  /// Durasi dari titik sebelumnya
  final int durationSeconds;

  /// Jarak langsung dari depot ke titik ini (bukan akumulasi)
  final int distanceFromDepotMeters;

  /// Durasi langsung dari depot ke titik ini
  final int durationFromDepotSeconds;

  const RouteStep({
    required this.destination,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceFromDepotMeters,
    required this.durationFromDepotSeconds,
  });
}

//////////////////////////////////////////////////////
/// FULL MATRIX RESULT
//////////////////////////////////////////////////////

class FullMatrixResult {
  /// distances[i][j] = jarak dari titik i ke titik j (meter)
  final List<List<int>> distances;

  /// durations[i][j] = durasi dari titik i ke titik j (detik)
  final List<List<int>> durations;

  const FullMatrixResult(this.distances, this.durations);
}

//////////////////////////////////////////////////////
/// ROUTE PLANNER — 1 OSRM CALL + GREEDY IN MEMORY
//////////////////////////////////////////////////////

class RoutePlanner {
  static final OsrmService _osrm = OsrmService();

  static Future<List<RouteStep>> buildOptimalRoute({
    required double startLat,
    required double startLng,
    required String startName,
    required List<Destination> destinations,
  }) async {
    if (destinations.isEmpty) return [];

    // Index 0 = depot/start, index 1..N = destinations
    final allPoints = <Destination>[
      Destination(startName, startLat, startLng),
      ...destinations,
    ];

    // ✅ 1 OSRM call saja
    final matrix = await _osrm.getFullMatrix(allPoints);

    final remaining = List<int>.generate(destinations.length, (i) => i + 1);
    final result = <RouteStep>[];
    var currentIndex = 0; // mulai dari depot (index 0)

    while (remaining.isNotEmpty) {
      var bestIndex = -1;
      var bestDistance = 999999999;
      var bestDuration = 0;

      for (final destIdx in remaining) {
        final d = matrix.distances[currentIndex][destIdx];
        if (d < bestDistance) {
          bestDistance = d;
          bestDuration = matrix.durations[currentIndex][destIdx];
          bestIndex = destIdx;
        }
      }

      remaining.remove(bestIndex);

      // Jarak & durasi langsung dari depot (index 0) ke titik ini
      final distFromDepot = matrix.distances[0][bestIndex];
      final durFromDepot = matrix.durations[0][bestIndex];

      result.add(
        RouteStep(
          destination: allPoints[bestIndex],
          distanceMeters: bestDistance,
          durationSeconds: bestDuration,
          distanceFromDepotMeters: distFromDepot,
          durationFromDepotSeconds: durFromDepot,
        ),
      );

      currentIndex = bestIndex;
    }

    return result;
  }
}

//////////////////////////////////////////////////////
/// OSRM SERVICE — FULL MATRIX (N×N)
//////////////////////////////////////////////////////

class OsrmService {
  static int tableCallCount = 0;

  static const _baseUrl = 'https://router.project-osrm.org';
  static const _timeout = Duration(seconds: 15);

  Future<FullMatrixResult> getFullMatrix(List<Destination> points) async {
    tableCallCount++;

    final coords = points.map((d) => '${d.longitude},${d.latitude}').join(';');

    final url = Uri.parse(
      '$_baseUrl/table/v1/driving/$coords'
      '?annotations=distance,duration',
    );

    // ── LOG: START FETCH ──────────────────────────────
    final stopwatch = Stopwatch()..start();
    print('┌─────────────────────────────────────────────');
    print('│ 🌐 OSRM FETCH #$tableCallCount STARTED');
    print('│    Titik   : ${points.length} koordinat');
    print('│    URL     : $url');
    print('│    Timeout : ${_timeout.inSeconds}s');
    print('└─────────────────────────────────────────────');
    // ─────────────────────────────────────────────────

    final http.Response response;

    try {
      response = await http.get(url).timeout(
        _timeout,
        onTimeout: () => throw Exception(
          'OSRM timeout setelah ${_timeout.inSeconds}s — '
          'coba kurangi jumlah titik atau cek koneksi',
        ),
      );
    } catch (e) {
      stopwatch.stop();
      print('┌─────────────────────────────────────────────');
      print('│ ❌ OSRM FETCH #$tableCallCount FAILED');
      print('│    Error   : $e');
      print('│    Elapsed : ${stopwatch.elapsedMilliseconds}ms');
      print('└─────────────────────────────────────────────');
      throw Exception('OSRM network error: $e');
    }

    stopwatch.stop();

    // ── LOG: FINISH FETCH ─────────────────────────────
    print('┌─────────────────────────────────────────────');
    print('│ ✅ OSRM FETCH #$tableCallCount COMPLETED');
    print('│    Status  : ${response.statusCode}');
    print('│    Elapsed : ${stopwatch.elapsedMilliseconds}ms');
    print('│    Body    : ${response.contentLength ?? response.body.length} bytes');
    print('└─────────────────────────────────────────────');
    // ─────────────────────────────────────────────────

    if (response.statusCode != 200) {
      throw Exception('OSRM HTTP error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json['code'] != 'Ok') {
      throw Exception('OSRM response error: ${json['code']} — ${json['message']}');
    }

    return FullMatrixResult(
      _parseMatrix(json['distances'] as List),
      _parseMatrix(json['durations'] as List),
    );
  }

  List<List<int>> _parseMatrix(List<dynamic> raw) {
    return raw.map<List<int>>((row) {
      return (row as List).map<int>((v) {
        if (v == null) return 999999999;
        return (v as num).round();
      }).toList();
    }).toList();
  }
}

//////////////////////////////////////////////////////
/// SIMULATOR — GENERATE RANDOM DESTINATIONS
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

    for (var i = 0; i < count; i++) {
      final dx = (rand.nextDouble() * 2 - 1) * radiusKm / 111;
      final dy = (rand.nextDouble() * 2 - 1) * radiusKm / 111;

      list.add(
        Destination(
          'Titik Sampah #${i + 1}',
          centerLat + dx,
          centerLng + dy,
        ),
      );
    }

    return list;
  }
}
