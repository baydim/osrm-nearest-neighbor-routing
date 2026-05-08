import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const startLat = -8.803094;
  const startLng = 115.217775;

  // Uncomment untuk test dengan destinasi random:
  // final destinations = RouteSimulator.generateRandomDestinations(
  //   centerLat: startLat,
  //   centerLng: startLng,
  //   count: 10,
  //   radiusKm: 5,
  // );

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

  print(
    '🗺️  Membangun rute optimal untuk ${destinations.length} destinasi...\n',
  );

  try {
    final result = await RoutePlanner.buildOptimalRoute(
      startLat: startLat,
      startLng: startLng,
      destinations: destinations,
    );

    var totalDistance = 0;
    var totalDuration = 0;

    print('\n=== FINAL ROUTE (${result.length} TITIK) ===\n');

    for (var i = 0; i < result.length; i++) {
      final step = result[i];
      final d = step.destination;
      totalDistance += step.distanceMeters;
      totalDuration += step.durationSeconds;

      print(
        '${i + 1}. ${d.namaTempat}\n'
        '   LatLng : ${d.latitude}, ${d.longitude}\n'
        '   Jarak  : ${step.distanceMeters} m\n'
        '   Durasi : ${(step.durationSeconds / 60).toStringAsFixed(1)} menit\n',
      );
    }

    print('=== RINGKASAN ===');
    print(
      '📏 Total Jarak  : $totalDistance m (${(totalDistance / 1000).toStringAsFixed(2)} km)',
    );
    print(
      '⏱️  Total Durasi : ${(totalDuration / 60).toStringAsFixed(1)} menit',
    );
    print('\n🚀 TOTAL OSRM TABLE CALL : ${OsrmService.tableCallCount}');
    print('   (${destinations.length} destinasi → cukup 1 API call)\n');
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

  // FIX #7: gunakan const constructor
  const Destination(this.namaTempat, this.latitude, this.longitude);
}

class RouteStep {
  final Destination destination;
  final int distanceMeters;
  final int durationSeconds;

  // FIX #7: gunakan const constructor
  const RouteStep({
    required this.destination,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// Full (N+1)×(N+1) distance & duration matrix dari OSRM TABLE API.
/// [distances][i][j] = jarak dari node i ke node j, dalam meter.
/// [durations][i][j] = durasi dari node i ke node j, dalam detik.
/// Indeks 0 = origin (titik awal), indeks 1..N = destinations[0..N-1].
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
/// ROUTE PLANNER
///
/// FIX #1 – Satu OSRM TABLE call untuk full (N+1)×(N+1) matrix.
/// FIX #2 – Nearest Neighbor berbasis matrix cache (0 API call tambahan).
/// FIX #4 – 2-opt improvement setelah NN     (0 API call tambahan).
//////////////////////////////////////////////////////

class RoutePlanner {
  static final OsrmService _osrm = OsrmService();

  static Future<List<RouteStep>> buildOptimalRoute({
    required double startLat,
    required double startLng,
    required List<Destination> destinations,
  }) async {
    final n = destinations.length;
    if (n == 0) return [];

    // ── LANGKAH 1: Ambil full (N+1)×(N+1) matrix dalam SATU API call ───────
    // Indeks 0 = origin, indeks 1..N = destinations[0..N-1].
    // Tanpa parameter sources= → OSRM mengembalikan matriks penuh NxN.
    // SEBELUMNYA: loop N kali → N API calls. SEKARANG: selalu 1 API call.
    print('📡 Memanggil OSRM TABLE API (1 call untuk ${n + 1} node)...');
    final matrix = await _osrm.getFullMatrix(
      originLat: startLat,
      originLng: startLng,
      destinations: destinations,
    );

    // ── LANGKAH 2: Nearest Neighbor Heuristic berbasis matrix cache ─────────
    // Kompleksitas O(N²) – tanpa tambahan API call.
    final nnOrder = _nearestNeighbor(matrix, n);
    final nnCost = _pathCost(matrix, nnOrder);
    print('✅ Nearest Neighbor selesai. Jarak awal   : $nnCost m');

    // ── LANGKAH 3: 2-opt Improvement untuk open path ────────────────────────
    // Kompleksitas O(N² × iterasi) – tanpa tambahan API call.
    final optimizedOrder = _twoOptImprovement(matrix, nnOrder, n);
    final optCost = _pathCost(matrix, optimizedOrder);
    final pct = nnCost > 0
        ? ((nnCost - optCost) / nnCost * 100).toStringAsFixed(1)
        : '0.0';
    print('✅ 2-opt selesai.          Jarak akhir   : $optCost m (hemat $pct%)');

    // ── LANGKAH 4: Susun RouteStep dari order yang sudah dioptimasi ─────────
    final result = <RouteStep>[];
    var prevNode = 0; // indeks 0 = origin

    for (final destIdx in optimizedOrder) {
      final matrixIdx = destIdx + 1; // offset 1 karena indeks 0 = origin
      result.add(
        RouteStep(
          destination: destinations[destIdx],
          distanceMeters: matrix.distances[prevNode][matrixIdx],
          durationSeconds: matrix.durations[prevNode][matrixIdx],
        ),
      );
      prevNode = matrixIdx;
    }

    return result;
  }

  // ── Nearest Neighbor Heuristic ──────────────────────────────────────────
  // Dari origin (node 0), setiap langkah pilih destinasi terdekat yang
  // belum dikunjungi. Return: urutan indeks destinasi (0-based).
  static List<int> _nearestNeighbor(OsrmMatrix matrix, int n) {
    final visited = List<bool>.filled(n, false);
    final order = <int>[];
    var currentNode = 0; // matriks indeks 0 = origin

    for (var step = 0; step < n; step++) {
      var bestDestIdx = -1;
      var bestDist = 0x7FFFFFFFFFFFFFFF; // max int64

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

  // ── 2-opt Improvement (Open Path, bukan circular TSP) ──────────────────
  // Iteratif: coba semua pasangan (i, k), balik segmen [i..k] jika lebih
  // hemat. Ulangi hingga tidak ada perbaikan (local optimum tercapai).
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
            break outerLoop; // restart pencarian dengan rute terbaik
          }
        }
      }
    }

    return best;
  }

  // Hitung total jarak rute: origin → dest[order[0]] → ... → dest[order[n-1]].
  static int _pathCost(OsrmMatrix matrix, List<int> order) {
    var total = 0;
    var prev = 0; // matriks indeks 0 = origin

    for (final destIdx in order) {
      total += matrix.distances[prev][destIdx + 1];
      prev = destIdx + 1;
    }

    return total;
  }

  // Buat salinan order dengan segmen [i..k] dibalik (2-opt swap).
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
/// OSRM TABLE SERVICE
///
/// FIX #1 – 1 call untuk full (N+1)×(N+1) matrix (tanpa sources=).
/// FIX #2 – HTTP timeout 20 detik.
/// FIX #6 – Retry 3x dengan exponential backoff untuk error jaringan/5xx.
/// FIX #8 – Error message informatif dengan code & message dari OSRM.
//////////////////////////////////////////////////////

class OsrmService {
  static int tableCallCount = 0;

  static const _timeout = Duration(seconds: 20);
  static const _maxRetries = 3;

  /// Sentinel untuk jarak/durasi null (node tidak terjangkau).
  static const _unreachable = 999999999;

  /// Ambil full (N+1)×(N+1) distance & duration matrix dalam SATU HTTP call.
  /// Indeks 0 = origin, indeks 1..N = destinations[0..N-1].
  Future<OsrmMatrix> getFullMatrix({
    required double originLat,
    required double originLng,
    required List<Destination> destinations,
  }) async {
    tableCallCount++;

    // Format koordinat OSRM: longitude,latitude (lng dulu, bukan lat)
    final coords = [
      '$originLng,$originLat',
      ...destinations.map((d) => '${d.longitude},${d.latitude}'),
    ].join(';');

    // Tanpa `sources=` → OSRM mengembalikan matriks penuh (N+1)×(N+1)
    // SEBELUMNYA: sources=0 → hanya baris origin, sehingga perlu N kali call
    final url = Uri.parse(
      'https://router.project-osrm.org/table/v1/driving/$coords'
      '?annotations=distance,duration',
    );

    final body = await _getWithRetry(url);
    final json = jsonDecode(body) as Map<String, dynamic>;

    if (json['code'] != 'Ok') {
      // FIX #8: sertakan code dan message dari respons OSRM
      throw OsrmException(
        'OSRM TABLE gagal — '
        'code: "${json['code']}", '
        'message: "${json['message'] ?? 'tidak ada keterangan'}"',
      );
    }

    final rawDist = json['distances'] as List;
    final rawDur = json['durations'] as List;

    // Parse baris×kolom → int (null = tidak terjangkau → sentinel _unreachable)
    List<List<int>> parseMatrix(List raw) => raw
        .map<List<int>>(
          (row) => (row as List)
              .map<int>((v) => v == null ? _unreachable : (v as num).round())
              .toList(),
        )
        .toList();

    return OsrmMatrix(
      distances: parseMatrix(rawDist),
      durations: parseMatrix(rawDur),
    );
  }

  /// HTTP GET dengan:
  ///  - Timeout 20 detik per attempt.
  ///  - Retry maks 3x (hanya untuk error jaringan & HTTP 5xx).
  ///  - HTTP 4xx langsung throw tanpa retry (client error).
  ///  - Exponential backoff: 500 ms → 1000 ms → 2000 ms.
  Future<String> _getWithRetry(Uri url) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .get(url)
            .timeout(
              _timeout,
              onTimeout: () {
                // FIX #2: lempar OsrmException saat timeout agar langsung dikenali
                throw OsrmException(
                  'Request timeout setelah ${_timeout.inSeconds} detik '
                  '(percobaan $attempt/$_maxRetries)',
                );
              },
            );

        if (response.statusCode == 200) return response.body;

        // 4xx = kesalahan di sisi client → tidak ada gunanya retry
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw OsrmException(
            'HTTP ${response.statusCode} (Client Error): ${response.reasonPhrase}. '
            'Periksa URL dan format koordinat.',
          );
        }

        // 5xx = server error → catat dan coba lagi
        lastError = OsrmException(
          'HTTP ${response.statusCode} (Server Error): ${response.reasonPhrase} '
          '(percobaan $attempt/$_maxRetries)',
        );
      } on OsrmException {
        // OsrmException (timeout atau 4xx) → langsung bubble up, jangan retry
        rethrow;
      } catch (e) {
        // Error jaringan lainnya (SocketException, dll.) → catat dan retry
        lastError = e;
      }

      if (attempt < _maxRetries) {
        final waitMs = 500 * (1 << (attempt - 1)); // 500 ms, 1000 ms, 2000 ms
        print(
          '⚠️  Percobaan $attempt gagal ($lastError), '
          'retry dalam ${waitMs}ms...',
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
/// SIMULATOR
///
/// FIX #3: longitude correction menggunakan cos(latitude).
/// SEBELUMNYA: dy = radiusKm / 111        → SALAH karena 1° lon ≠ 1° lat
/// SEKARANG  : dy = radiusKm / (111 × cos(lat)) → BENAR, sesuai geografi
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

    // 1° latitude ≈ 111 km (hampir konstan di seluruh bumi)
    const latDegPerKm = 1.0 / 111.0;

    // 1° longitude ≈ 111 km × cos(latitude) → mengecil mendekati kutub
    // FIX: tambahkan faktor cos(lat) agar titik acak tersebar merata secara fisik
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
