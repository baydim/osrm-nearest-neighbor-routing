import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const startLat = -8.803094;
  const startLng = 115.217775;

//   final destinations = RouteSimulator.generateRandomDestinations(
//     centerLat: startLat,
//     centerLng: startLng,
//     count: 5,
//     radiusKm: 2,
//   );
  
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
    destinations: destinations,
  );

  print('\n=== FINAL ROUTE (${result.length} TITIK) ===\n');

  for (var i = 0; i < result.length; i++) {
    final step = result[i];
    final d = step.destination;

    print(
      '${i + 1}. ${d.namaTempat}\n'
      '   LatLng : ${d.latitude}, ${d.longitude}\n'
      '   Jarak  : ${step.distanceMeters} m\n'
      '   Durasi : ${(step.durationSeconds / 60).round()} menit\n',
    );
  }

  print('\n🚀 TOTAL OSRM TABLE CALL: ${OsrmService.tableCallCount}\n');
}

//////////////////////////////////////////////////////
/// MODELS
//////////////////////////////////////////////////////

class Destination {
  final String namaTempat;
  final double latitude;
  final double longitude;

  Destination(this.namaTempat, this.latitude, this.longitude);
}

class RouteStep {
  final Destination destination;
  final int distanceMeters;
  final int durationSeconds;

  RouteStep({
    required this.destination,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

//////////////////////////////////////////////////////
/// ROUTE PLANNER (TABLE + NEAREST NEIGHBOR)
//////////////////////////////////////////////////////

class RoutePlanner {
  static final OsrmService _osrm = OsrmService();

  static Future<List<RouteStep>> buildOptimalRoute({
    required double startLat,
    required double startLng,
    required List<Destination> destinations,
  }) async {
    final remaining = List<Destination>.from(destinations);
    final result = <RouteStep>[];

    var currentLat = startLat;
    var currentLng = startLng;

    while (remaining.isNotEmpty) {
      final table = await _osrm.getDistanceTable(
        originLat: currentLat,
        originLng: currentLng,
        destinations: remaining,
      );

      int bestIndex = -1;
      int bestDistance = 1 << 60;
      int bestDuration = 0;

      for (var i = 0; i < table.distances.length; i++) {
        final d = table.distances[i];
        if (d < bestDistance) {
          bestDistance = d;
          bestDuration = table.durations[i];
          bestIndex = i;
        }
      }

      final chosen = remaining.removeAt(bestIndex);

      result.add(
        RouteStep(
          destination: chosen,
          distanceMeters: bestDistance,
          durationSeconds: bestDuration,
        ),
      );

      currentLat = chosen.latitude;
      currentLng = chosen.longitude;
    }

    return result;
  }
}

//////////////////////////////////////////////////////
/// OSRM TABLE SERVICE (FIXED & SAFE)
//////////////////////////////////////////////////////

class OsrmTableResult {
  final List<int> distances;
  final List<int> durations;

  OsrmTableResult(this.distances, this.durations);
}

class OsrmService {
  static int tableCallCount = 0;

  Future<OsrmTableResult> getDistanceTable({
    required double originLat,
    required double originLng,
    required List<Destination> destinations,
  }) async {
    tableCallCount++;

    final coords = [
      '$originLng,$originLat',
      ...destinations.map((d) => '${d.longitude},${d.latitude}')
    ].join(';');

    final url = Uri.parse(
      'https://router.project-osrm.org/table/v1/driving/$coords'
      '?annotations=distance,duration&sources=0',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('OSRM HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    if (json['code'] != 'Ok') {
      throw Exception('OSRM TABLE FAILED');
    }

    final rawDistances = json['distances'][0] as List;
    final rawDurations = json['durations'][0] as List;

    final distances = rawDistances
        .skip(1)
        .map<int>((v) => v == null ? 999999999 : (v as num).round())
        .toList();

    final durations = rawDurations
        .skip(1)
        .map<int>((v) => v == null ? 999999999 : (v as num).round())
        .toList();

    return OsrmTableResult(distances, durations);
  }
}

//////////////////////////////////////////////////////
/// SIMULATOR (100 TITIK)
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
