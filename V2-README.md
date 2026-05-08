# OSRM Route Optimizer — v2

> 🇬🇧 [English](#english-version) | 🇮🇩 [Bahasa Indonesia](#versi-bahasa-indonesia)

---

<a name="english-version"></a>
# 🇬🇧 English Version

A Dart-based route optimization tool that calculates the most efficient delivery path using **Nearest Neighbor + 2-opt** algorithms and the **OSRM Table API** — all in a **single API call**.

Designed to be embedded directly into Flutter apps via `RouteOptimizerService`, returning clean `Map<String, dynamic>` JSON output ready for any state management solution (BLoC, GetX, Riverpod).

---

## 🚀 What's New in v2

| Feature | v1 | v2 |
|---|---|---|
| Algorithm | Nearest Neighbor only | **Nearest Neighbor + 2-opt improvement** |
| Output | `List<RouteStep>` only | `List<RouteStep>` + **JSON via `RouteOptimizerService`** |
| Flutter integration | Manual parsing | **Ready-to-use service class** |
| Error handling | Generic `Exception` | **Typed `OsrmException`** |
| HTTP retry | None | **3x exponential backoff** |
| Geo accuracy (Simulator) | Fixed degree offset | **cos(lat) longitude correction** |
| `Destination` model | No serialization | **`toJson()` + `fromJson()`** |

---

## 🚀 Try It Live in DartPad

[![Open in DartPad](https://img.shields.io/badge/Open%20in-DartPad-blue?style=for-the-badge&logo=dart)](https://dartpad.dev/?gist=fe5cf28b829231bb27c49e7f79301af6)

*(Klik badge di atas untuk mencoba demo langsung di DartPad)*

---

## 🧠 How the Algorithm Works

### Step 1 — Single OSRM API Call
All points (depot + destinations) are sent in one request to the OSRM Table API, returning a full **(N+1)×(N+1)** distance and duration matrix.

```
Index 0         = depot / starting point
Index 1 .. N    = destinations[0 .. N-1]
```

### Step 2 — Nearest Neighbor Heuristic
Starting from the depot, greedily pick the closest unvisited destination at each step using the cached matrix. **O(N²), zero additional API calls.**

### Step 3 — 2-opt Improvement
Iteratively try reversing segments of the route. If a reversal produces a shorter total distance, keep it. Repeat until no improvement is found (local optimum). **O(N² × iterations), zero additional API calls.**

### Step 4 — Build RouteStep List
For each stop in the optimized order, record:
- Distance & duration from the **previous stop**
- Distance & duration from the **depot** (direct road distance, not cumulative)

> **Result**: A complete, optimized route resolved from **1 API call** regardless of destination count.

---

## 🛠️ Prerequisites

- **Dart SDK**: 2.18.0 or higher
- **Internet connection**: Required for the OSRM public API call

---

## 📦 Installation

```bash
git clone https://github.com/username/osrm-route-optimizer.git
cd osrm-route-optimizer
dart pub get
```

**`pubspec.yaml`**
```yaml
name: osrm_route_optimizer
description: Route optimizer using OSRM Table API, Nearest Neighbor + 2-opt.
version: 2.0.0

environment:
  sdk: '>=2.18.0 <4.0.0'

dependencies:
  http: ^1.1.0
```

---

## 💻 Basic Usage (CLI / Raw)

```dart
final destinations = <Destination>[
  Destination('Pondok Deta Guest House', -8.801072, 115.219258),
  Destination('Warung Sarita Blok J/7', -8.803183, 115.218979),
  // add more...
];

final steps = await RoutePlanner.buildOptimalRoute(
  startLat:     -8.803094,
  startLng:     115.217775,
  startName:    'Depot',
  destinations: destinations,
);

for (final step in steps) {
  print('${step.destination.namaTempat} — ${step.distanceFromPrevMeters} m');
}
```

---

## 📱 Flutter Integration via `RouteOptimizerService`

### Setup

```dart
final service = RouteOptimizerService(stopDurationMinutesPerStop: 10);
```

`stopDurationMinutesPerStop` is how many minutes the courier stops at each location to perform their task (e.g. waste pickup). Defaults to `10`.

---

### Method 1 — Full JSON with Summary

```dart
final Map<String, dynamic> result = await service.buildOptimalRouteJson(
  startLat:     currentLat,
  startLng:     currentLng,
  startName:    'Gudang Utama',
  destinations: listDestination,
);
```

**Accessing the result:**

```dart
// Depot info
final depot = result['depot'] as Map<String, dynamic>;
final depotName = depot['name'];           // String
final depotLat  = depot['latitude'];       // double
final depotLng  = depot['longitude'];      // double

// Steps (ordered route)
final steps = result['steps'] as List<dynamic>;

for (final step in steps) {
  final order       = step['order'];                              // int: 1, 2, 3...
  final namaTemp    = step['destination']['nama_tempat'];         // String
  final lat         = step['destination']['latitude'];            // double
  final lng         = step['destination']['longitude'];           // double

  // Distance & duration from previous stop
  final distPrevM   = step['from_prev']['distance_m'];           // int (meters)
  final distPrevKm  = step['from_prev']['distance_km'];          // double
  final durPrevSec  = step['from_prev']['duration_seconds'];     // int
  final durPrevMin  = step['from_prev']['duration_minutes'];     // double

  // Distance & duration from depot (direct road, not cumulative)
  final distDepotM  = step['from_depot']['distance_m'];          // int (meters)
  final distDepotKm = step['from_depot']['distance_km'];         // double
  final durDepotSec = step['from_depot']['duration_seconds'];    // int
  final durDepotMin = step['from_depot']['duration_minutes'];    // double

  // Stop duration at this location
  final stopMin     = step['stop_duration_minutes'];             // int
}

// Summary
final summary = result['summary'] as Map<String, dynamic>;
final totalStops        = summary['total_stops'];                          // int
final totalDistM        = summary['total_distance_m'];                     // int
final totalDistKm       = summary['total_distance_km'];                    // double
final drivingMin        = summary['total_driving_duration_minutes'];       // double
final stopMin           = summary['total_stop_duration_minutes'];          // int
final totalMin          = summary['total_duration_with_stop_minutes'];     // double
final totalHours        = summary['total_duration_with_stop_hours'];       // int
final remainMin         = summary['total_duration_with_stop_remaining_minutes']; // int
final apiCallCount      = summary['osrm_api_call_count'];                  // int
```

---

### Method 2 — Steps Only (Lightweight, for Map Rendering)

```dart
final List<Map<String, dynamic>> steps = await service.buildOptimalStepsOnly(
  startLat:     currentLat,
  startLng:     currentLng,
  startName:    'Gudang Utama',
  destinations: listDestination,
);

// Use directly on a map widget
for (final step in steps) {
  final lat = step['destination']['latitude'] as double;
  final lng = step['destination']['longitude'] as double;
  // add marker to map...
}
```

---

### BLoC Example

```dart
// In your Cubit/Bloc event handler:
Future<void> _onLoadRoute(LoadRouteEvent event, Emitter emit) async {
  emit(RouteLoading());
  try {
    final service = RouteOptimizerService(stopDurationMinutesPerStop: 10);
    final result = await service.buildOptimalRouteJson(
      startLat:     event.startLat,
      startLng:     event.startLng,
      startName:    event.depotName,
      destinations: event.destinations,
    );
    emit(RouteLoaded(result));
  } on OsrmException catch (e) {
    emit(RouteError(e.message));
  }
}
```

### GetX Example

```dart
class RouteController extends GetxController {
  final _service = RouteOptimizerService(stopDurationMinutesPerStop: 10);

  final routeResult = Rxn<Map<String, dynamic>>();
  final isLoading   = false.obs;
  final errorMsg    = ''.obs;

  Future<void> loadRoute({
    required double startLat,
    required double startLng,
    required String startName,
    required List<Destination> destinations,
  }) async {
    isLoading.value = true;
    errorMsg.value  = '';
    try {
      routeResult.value = await _service.buildOptimalRouteJson(
        startLat:     startLat,
        startLng:     startLng,
        startName:    startName,
        destinations: destinations,
      );
    } on OsrmException catch (e) {
      errorMsg.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }
}
```

### Riverpod Example

```dart
final routeServiceProvider = Provider(
  (ref) => RouteOptimizerService(stopDurationMinutesPerStop: 10),
);

final routeProvider = FutureProvider.family<Map<String, dynamic>, RouteParams>(
  (ref, params) async {
    final service = ref.read(routeServiceProvider);
    return service.buildOptimalRouteJson(
      startLat:     params.startLat,
      startLng:     params.startLng,
      startName:    params.startName,
      destinations: params.destinations,
    );
  },
);
```

---

### Creating `Destination` from API / Database

```dart
// From Supabase / REST API response
final destination = Destination.fromJson({
  'nama_tempat': 'Warung Sarita',
  'latitude':    -8.803183,
  'longitude':   115.218979,
});

// From a list of maps (e.g. Supabase .select() result)
final destinations = (responseList as List)
    .map((e) => Destination.fromJson(e as Map<String, dynamic>))
    .toList();
```

---

## 📂 Code Structure

| Class | Responsibility |
|---|---|
| `Destination` | Model: name, lat, lng. Includes `toJson()` / `fromJson()` |
| `RouteStep` | Model: one journey leg — distance/duration from previous stop and from depot |
| `OsrmMatrix` | Model: full N×N `distances[i][j]` and `durations[i][j]` matrices |
| `OsrmException` | Typed exception for all OSRM-related errors |
| `RouteOptimizerService` | **Flutter-ready wrapper.** Two methods: full JSON + steps-only |
| `RoutePlanner` | Core algorithm: NN + 2-opt, builds `List<RouteStep>` |
| `OsrmService` | HTTP layer: fetch full matrix, timeout, 3x exponential backoff retry |
| `RouteSimulator` | Utility: generate random destinations within radius for testing |

---

## 📝 Example JSON Output

```json
{
  "depot": {
    "name": "Depot (Titik Berangkat)",
    "latitude": -8.803094,
    "longitude": 115.217775
  },
  "steps": [
    {
      "order": 1,
      "destination": {
        "nama_tempat": "Warung Sarita Blok J/7",
        "latitude": -8.803183,
        "longitude": 115.218979
      },
      "from_prev": {
        "distance_m": 219,
        "distance_km": 0.22,
        "duration_seconds": 35,
        "duration_minutes": 0.6
      },
      "from_depot": {
        "distance_m": 219,
        "distance_km": 0.22,
        "duration_seconds": 35,
        "duration_minutes": 0.6
      },
      "stop_duration_minutes": 10
    }
  ],
  "summary": {
    "total_stops": 5,
    "total_distance_m": 8271,
    "total_distance_km": 8.27,
    "total_driving_duration_seconds": 936,
    "total_driving_duration_minutes": 15.6,
    "total_stop_duration_minutes": 50,
    "total_duration_with_stop_minutes": 65.6,
    "total_duration_with_stop_hours": 1,
    "total_duration_with_stop_remaining_minutes": 6,
    "osrm_api_call_count": 1
  }
}
```

---

## ⚠️ API Limitations & Disclaimer

This project uses the **public OSRM demo server** (`router.project-osrm.org`).

- **Rate Limits** — Shared server, no guaranteed SLA. Do not use in production.
- **Point Limit** — Handles up to ~100 coordinate points per request reliably.
- **Production** — Self-host OSRM or use a commercial provider (Mapbox, HERE, Google Maps Routes API).

---
---

<a name="versi-bahasa-indonesia"></a>
# 🇮🇩 Versi Bahasa Indonesia

Tool optimasi rute berbasis Dart yang menghitung jalur pengiriman paling efisien menggunakan algoritma **Nearest Neighbor + 2-opt** dan **OSRM Table API** — cukup dengan **satu API call**.

Dirancang untuk langsung digunakan di Flutter app via `RouteOptimizerService`, mengembalikan output JSON `Map<String, dynamic>` yang siap dipakai di state management apapun (BLoC, GetX, Riverpod).

---

## 🚀 Yang Baru di v2

| Fitur | v1 | v2 |
|---|---|---|
| Algoritma | Nearest Neighbor saja | **Nearest Neighbor + 2-opt improvement** |
| Output | `List<RouteStep>` saja | `List<RouteStep>` + **JSON via `RouteOptimizerService`** |
| Integrasi Flutter | Parsing manual | **Service class siap pakai** |
| Error handling | `Exception` generic | **`OsrmException` typed** |
| HTTP retry | Tidak ada | **3x exponential backoff** |
| Akurasi geo (Simulator) | Offset derajat tetap | **Koreksi longitude cos(lat)** |
| Model `Destination` | Tanpa serialisasi | **`toJson()` + `fromJson()`** |

---

## 🧠 Cara Kerja Algoritma

### Langkah 1 — Satu OSRM API Call
Semua titik (depot + destinasi) dikirim dalam satu request ke OSRM Table API, menghasilkan matriks **(N+1)×(N+1)** jarak dan durasi.

```
Index 0         = depot / titik awal
Index 1 .. N    = destinations[0 .. N-1]
```

### Langkah 2 — Nearest Neighbor Heuristic
Mulai dari depot, pilih destinasi terdekat yang belum dikunjungi di setiap langkah menggunakan matrix yang sudah di-cache. **O(N²), tanpa API call tambahan.**

### Langkah 3 — 2-opt Improvement
Iteratif coba balik segmen rute. Jika pembalikan menghasilkan total jarak lebih pendek, simpan. Ulangi sampai tidak ada perbaikan (local optimum). **O(N² × iterasi), tanpa API call tambahan.**

### Langkah 4 — Susun RouteStep
Untuk setiap titik di urutan yang sudah dioptimasi, catat:
- Jarak & durasi dari **titik sebelumnya**
- Jarak & durasi dari **depot** (jarak jalan langsung, bukan akumulasi)

> **Hasil**: Rute lengkap dan optimal dari **1 API call** berapapun jumlah destinasinya.

---

## 🛠️ Prasyarat

- **Dart SDK**: 2.18.0 ke atas
- **Koneksi internet**: Diperlukan untuk OSRM public API call

---

## 📦 Instalasi

```bash
git clone https://github.com/username/osrm-route-optimizer.git
cd osrm-route-optimizer
dart pub get
```

**`pubspec.yaml`**
```yaml
name: osrm_route_optimizer
description: Optimizer rute menggunakan OSRM Table API, Nearest Neighbor + 2-opt.
version: 2.0.0

environment:
  sdk: '>=2.18.0 <4.0.0'

dependencies:
  http: ^1.1.0
```

---

## 💻 Penggunaan Dasar (CLI / Raw)

```dart
final destinations = <Destination>[
  Destination('Pondok Deta Guest House', -8.801072, 115.219258),
  Destination('Warung Sarita Blok J/7', -8.803183, 115.218979),
  // tambah lebih banyak...
];

final steps = await RoutePlanner.buildOptimalRoute(
  startLat:     -8.803094,
  startLng:     115.217775,
  startName:    'Depot',
  destinations: destinations,
);

for (final step in steps) {
  print('${step.destination.namaTempat} — ${step.distanceFromPrevMeters} m');
}
```

---

## 📱 Integrasi Flutter via `RouteOptimizerService`

### Setup

```dart
final service = RouteOptimizerService(stopDurationMinutesPerStop: 10);
```

`stopDurationMinutesPerStop` adalah berapa menit kurir berhenti di setiap titik untuk mengerjakan tugasnya (contoh: pickup sampah). Default `10`.

---

### Method 1 — Full JSON dengan Summary

```dart
final Map<String, dynamic> result = await service.buildOptimalRouteJson(
  startLat:     currentLat,
  startLng:     currentLng,
  startName:    'Gudang Utama',
  destinations: listDestination,
);
```

**Cara akses hasilnya:**

```dart
// Info depot
final depot     = result['depot'] as Map<String, dynamic>;
final depotName = depot['name'];       // String
final depotLat  = depot['latitude'];   // double
final depotLng  = depot['longitude'];  // double

// Steps (urutan rute yang sudah dioptimasi)
final steps = result['steps'] as List<dynamic>;

for (final step in steps) {
  final order       = step['order'];                              // int: 1, 2, 3...
  final namaTemp    = step['destination']['nama_tempat'];         // String
  final lat         = step['destination']['latitude'];            // double
  final lng         = step['destination']['longitude'];           // double

  // Jarak & durasi dari titik sebelumnya
  final distPrevM   = step['from_prev']['distance_m'];           // int (meter)
  final distPrevKm  = step['from_prev']['distance_km'];          // double
  final durPrevSec  = step['from_prev']['duration_seconds'];     // int
  final durPrevMin  = step['from_prev']['duration_minutes'];     // double

  // Jarak & durasi dari depot (jalan langsung, bukan akumulasi)
  final distDepotM  = step['from_depot']['distance_m'];          // int (meter)
  final distDepotKm = step['from_depot']['distance_km'];         // double
  final durDepotSec = step['from_depot']['duration_seconds'];    // int
  final durDepotMin = step['from_depot']['duration_minutes'];    // double

  // Waktu berhenti di titik ini
  final stopMin     = step['stop_duration_minutes'];             // int
}

// Summary
final summary = result['summary'] as Map<String, dynamic>;
final totalStops   = summary['total_stops'];                                    // int
final totalDistM   = summary['total_distance_m'];                               // int
final totalDistKm  = summary['total_distance_km'];                              // double
final drivingMin   = summary['total_driving_duration_minutes'];                 // double
final stopMin      = summary['total_stop_duration_minutes'];                    // int
final totalMin     = summary['total_duration_with_stop_minutes'];               // double
final totalHours   = summary['total_duration_with_stop_hours'];                 // int
final remainMin    = summary['total_duration_with_stop_remaining_minutes'];     // int
final apiCallCount = summary['osrm_api_call_count'];                            // int
```

---

### Method 2 — Steps Only (Ringan, untuk Render di Peta)

```dart
final List<Map<String, dynamic>> steps = await service.buildOptimalStepsOnly(
  startLat:     currentLat,
  startLng:     currentLng,
  startName:    'Gudang Utama',
  destinations: listDestination,
);

// Langsung pakai di map widget
for (final step in steps) {
  final lat = step['destination']['latitude'] as double;
  final lng = step['destination']['longitude'] as double;
  // tambahkan marker ke peta...
}
```

---

### Contoh Integrasi BLoC

```dart
// Di dalam event handler Cubit/Bloc:
Future<void> _onLoadRoute(LoadRouteEvent event, Emitter emit) async {
  emit(RouteLoading());
  try {
    final service = RouteOptimizerService(stopDurationMinutesPerStop: 10);
    final result = await service.buildOptimalRouteJson(
      startLat:     event.startLat,
      startLng:     event.startLng,
      startName:    event.depotName,
      destinations: event.destinations,
    );
    emit(RouteLoaded(result));
  } on OsrmException catch (e) {
    emit(RouteError(e.message));
  }
}
```

### Contoh Integrasi GetX

```dart
class RouteController extends GetxController {
  final _service = RouteOptimizerService(stopDurationMinutesPerStop: 10);

  final routeResult = Rxn<Map<String, dynamic>>();
  final isLoading   = false.obs;
  final errorMsg    = ''.obs;

  Future<void> loadRoute({
    required double startLat,
    required double startLng,
    required String startName,
    required List<Destination> destinations,
  }) async {
    isLoading.value = true;
    errorMsg.value  = '';
    try {
      routeResult.value = await _service.buildOptimalRouteJson(
        startLat:     startLat,
        startLng:     startLng,
        startName:    startName,
        destinations: destinations,
      );
    } on OsrmException catch (e) {
      errorMsg.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }
}
```

### Contoh Integrasi Riverpod

```dart
final routeServiceProvider = Provider(
  (ref) => RouteOptimizerService(stopDurationMinutesPerStop: 10),
);

final routeProvider = FutureProvider.family<Map<String, dynamic>, RouteParams>(
  (ref, params) async {
    final service = ref.read(routeServiceProvider);
    return service.buildOptimalRouteJson(
      startLat:     params.startLat,
      startLng:     params.startLng,
      startName:    params.startName,
      destinations: params.destinations,
    );
  },
);
```

---

### Membuat `Destination` dari API / Database

```dart
// Dari response Supabase / REST API
final destination = Destination.fromJson({
  'nama_tempat': 'Warung Sarita',
  'latitude':    -8.803183,
  'longitude':   115.218979,
});

// Dari list of maps (contoh: hasil .select() Supabase)
final destinations = (responseList as List)
    .map((e) => Destination.fromJson(e as Map<String, dynamic>))
    .toList();
```

---

## 📂 Struktur Kode

| Class | Tanggung Jawab |
|---|---|
| `Destination` | Model: nama, lat, lng. Dilengkapi `toJson()` / `fromJson()` |
| `RouteStep` | Model: satu leg perjalanan — jarak/durasi dari titik sebelumnya dan dari depot |
| `OsrmMatrix` | Model: matriks N×N `distances[i][j]` dan `durations[i][j]` |
| `OsrmException` | Exception typed untuk semua error terkait OSRM |
| `RouteOptimizerService` | **Wrapper siap Flutter.** Dua method: full JSON + steps-only |
| `RoutePlanner` | Algoritma inti: NN + 2-opt, menghasilkan `List<RouteStep>` |
| `OsrmService` | Layer HTTP: ambil full matrix, timeout, retry 3x exponential backoff |
| `RouteSimulator` | Utility: generate destinasi acak dalam radius untuk testing |

---

## 📝 Contoh JSON Output

```json
{
  "depot": {
    "name": "Depot (Titik Berangkat)",
    "latitude": -8.803094,
    "longitude": 115.217775
  },
  "steps": [
    {
      "order": 1,
      "destination": {
        "nama_tempat": "Warung Sarita Blok J/7",
        "latitude": -8.803183,
        "longitude": 115.218979
      },
      "from_prev": {
        "distance_m": 219,
        "distance_km": 0.22,
        "duration_seconds": 35,
        "duration_minutes": 0.6
      },
      "from_depot": {
        "distance_m": 219,
        "distance_km": 0.22,
        "duration_seconds": 35,
        "duration_minutes": 0.6
      },
      "stop_duration_minutes": 10
    }
  ],
  "summary": {
    "total_stops": 5,
    "total_distance_m": 8271,
    "total_distance_km": 8.27,
    "total_driving_duration_seconds": 936,
    "total_driving_duration_minutes": 15.6,
    "total_stop_duration_minutes": 50,
    "total_duration_with_stop_minutes": 65.6,
    "total_duration_with_stop_hours": 1,
    "total_duration_with_stop_remaining_minutes": 6,
    "osrm_api_call_count": 1
  }
}
```

---

## ⚠️ Keterbatasan API & Disclaimer

Project ini menggunakan **public OSRM demo server** (`router.project-osrm.org`).

- **Rate Limit** — Server shared, tidak ada SLA. Jangan gunakan untuk production.
- **Batas Titik** — Andal hingga ~100 koordinat per request.
- **Production** — Self-host OSRM atau gunakan provider komersial (Mapbox, HERE, Google Maps Routes API).
