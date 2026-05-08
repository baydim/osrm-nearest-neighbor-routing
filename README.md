# OSRM Nearest Neighbor Routing

> 🇬🇧 [English](#english-version) | 🇮🇩 [Bahasa Indonesia](#versi-bahasa-indonesia)

---

<a name="english-version"></a>
# 🇬🇧 English Version

A Dart-based route optimization tool that calculates the most efficient path through multiple destinations using the **Nearest Neighbor** algorithm and the **OSRM (Open Source Routing Machine) Table API**.

This project solves the routing problem by fetching a full N×N distance matrix in a **single API call**, then running a greedy nearest-neighbor selection entirely in memory — making it fast, efficient, and safe for free-tier public OSRM usage.

---

## 🚀 Features

- **Real-World Distances** — Uses OSRM Table API for actual road-based driving distance and duration (traffic-agnostic).
- **Single API Call** — Fetches a full N×N matrix once, then resolves the entire route in memory. No repeated HTTP calls per step.
- **Greedy Nearest Neighbor Algorithm** — Fast heuristic that produces a "good enough" route, suitable for real-time courier apps.
- **Depot-Aware Logging** — Logs distance from the starting depot to each stop, and from the previous stop to the current one.
- **Fetch Lifecycle Logs** — Prints start/finish logs with elapsed time and response size for every OSRM request.
- **Dynamic Origin** — Starting point is configurable via `startLat`, `startLng`, and `startName`.
- **Simulator Included** — `RouteSimulator` generates random destination points for stress testing up to ~100 stops.
- **Clean Architecture** — Clear separation between Service, Logic, and Models.

---

## 🛠️ Prerequisites

- **Dart SDK**: Version 2.18.0 or higher
- **Internet Connection**: Required to call the OSRM public API

---

## 📦 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/username/osrm-nearest-neighbor-routing.git
   cd osrm-nearest-neighbor-routing
   ```

2. **Install dependencies**
   ```bash
   dart pub get
   ```

---

## 💻 Usage

1. Open `bin/main.dart`
2. Set your starting point and destinations inside `main()`:

```dart
const startLat  = -8.803094;
const startLng  = 115.217775;
const startName = 'Depot';

final destinations = <Destination>[
  Destination('Pondok Deta Guest House', -8.801072, 115.219258),
  Destination('Pura Dalem Khayangan',    -8.761089, 115.221852),
  // add more...
];

final result = await RoutePlanner.buildOptimalRoute(
  startLat:     startLat,
  startLng:     startLng,
  startName:    startName,
  destinations: destinations,
);
```

3. **Run the app**
   ```bash
   dart run
   ```

---

## 🧠 How It Works

1. **Build Full Point List** — Combine the depot (index `0`) with all destination points.
2. **Single OSRM Call** — Fetch a full N×N distance & duration matrix via the Table API (`?annotations=distance,duration`).
3. **Greedy Selection (In Memory)** — Starting from the depot, repeatedly pick the nearest unvisited point using the cached matrix.
4. **Record Each Step** — Each `RouteStep` stores:
   - Distance and duration from the **previous stop**
   - Distance and duration from the **depot** (direct, not cumulative)
5. **Repeat** — Until all destinations are visited.

> **Why 1 call instead of N calls?**
> The original approach called OSRM once per iteration (N calls for N stops). With a full matrix fetched upfront, the same result is achieved with **1 call**, drastically reducing latency and rate-limit risk on the free public server.

---

## 📂 Code Structure

| Class | Responsibility |
|---|---|
| `Destination` | Model: location name, latitude, longitude |
| `RouteStep` | Model: one leg of the journey — distance from previous, distance from depot, duration |
| `FullMatrixResult` | Model: 2D `distances[i][j]` and `durations[i][j]` matrices |
| `RoutePlanner` | Core logic: builds full point list, calls OSRM once, runs greedy in memory |
| `OsrmService` | HTTP layer: fetches full matrix, handles timeout, logs fetch lifecycle |
| `RouteSimulator` | Utility: generates random coordinates within a radius for testing |

---

## 📝 Example Output

```
┌─────────────────────────────────────────────
│ 🌐 OSRM FETCH #1 STARTED
│    Titik   : 6 koordinat
│    URL     : https://router.project-osrm.org/table/v1/driving/...
│    Timeout : 15s
└─────────────────────────────────────────────
┌─────────────────────────────────────────────
│ ✅ OSRM FETCH #1 COMPLETED
│    Status  : 200
│    Elapsed : 843ms
│    Body    : 1247 bytes
└─────────────────────────────────────────────

╔═════════════════════════════════════════════════════╗
║          FINAL ROUTE (5 TITIK)                      ║
╚═════════════════════════════════════════════════════╝

📍 [0] Depot
       LatLng : -8.803094, 115.217775
       Status : TITIK BERANGKAT

       │
       │  🚗 189 m  •  1 menit
       │  dari: "Depot"
       ▼
📍 [1] Warung Sarita Blok J/7
       LatLng : -8.803183, 115.218979
       Jarak dari depot     : 189 m
       Jarak dari sebelumnya: 189 m

       ...

══════════════════════════════════════════════════════
📊 TOTAL JARAK  : 12840 m
⏱  TOTAL DURASI : 28 menit
🚀 OSRM CALL    : 1x
✅ Efisiensi    : 1 call untuk 5 titik
══════════════════════════════════════════════════════
```

---

## ⚠️ API Limitations & Disclaimer

This project uses the **public OSRM demo server** (`router.project-osrm.org`).

- **Rate Limits** — The demo server is shared and has no guaranteed SLA. Do not use it in production.
- **Point Limit** — The public server handles up to ~100 coordinate points per request reliably.
- **Production Use** — For high-volume or commercial usage, self-host OSRM or use a commercial provider (e.g. Mapbox, HERE, Google Maps Routes API).

---

## pubspec.yaml

```yaml
name: osrm_nearest_neighbor
description: Command-line route optimizer using OSRM Table API and Nearest Neighbor heuristic.
version: 1.0.0

environment:
  sdk: '>=2.18.0 <4.0.0'

dependencies:
  http: ^1.1.0
```

---
---

<a name="versi-bahasa-indonesia"></a>
# 🇮🇩 Versi Bahasa Indonesia

Tool optimasi rute berbasis Dart yang menghitung jalur paling efisien melalui beberapa destinasi menggunakan algoritma **Nearest Neighbor** dan **OSRM (Open Source Routing Machine) Table API**.

Project ini menyelesaikan masalah routing dengan mengambil full N×N distance matrix dalam **satu API call**, lalu menjalankan seleksi greedy nearest-neighbor sepenuhnya di memory — menjadikannya cepat, efisien, dan aman untuk penggunaan OSRM public tier gratis.

---

## 🚀 Fitur

- **Jarak Nyata di Jalan** — Menggunakan OSRM Table API untuk jarak dan durasi berkendara berbasis jalan aktual (tidak memperhitungkan kondisi lalu lintas).
- **Hanya 1 API Call** — Mengambil full matrix N×N sekali, lalu seluruh rute diselesaikan di memory. Tidak ada HTTP call berulang per langkah.
- **Algoritma Greedy Nearest Neighbor** — Heuristik cepat yang menghasilkan rute "cukup optimal", cocok untuk aplikasi kurir real-time.
- **Log Per Titik** — Menampilkan jarak dari depot ke setiap titik, dan jarak dari titik sebelumnya ke titik berikutnya.
- **Log Siklus Fetch** — Mencetak log mulai/selesai dengan elapsed time dan ukuran response untuk setiap request OSRM.
- **Origin Dinamis** — Titik awal dapat dikonfigurasi via `startLat`, `startLng`, dan `startName`.
- **Simulator Tersedia** — `RouteSimulator` menghasilkan titik destinasi acak untuk stress testing hingga ~100 titik.
- **Arsitektur Bersih** — Pemisahan jelas antara Service, Logic, dan Model.

---

## 🛠️ Prasyarat

- **Dart SDK**: Versi 2.18.0 ke atas
- **Koneksi Internet**: Diperlukan untuk memanggil OSRM public API

---

## 📦 Instalasi

1. **Clone repository**
   ```bash
   git clone https://github.com/username/osrm-nearest-neighbor-routing.git
   cd osrm-nearest-neighbor-routing
   ```

2. **Install dependencies**
   ```bash
   dart pub get
   ```

---

## 💻 Cara Penggunaan

1. Buka `bin/main.dart`
2. Set titik awal dan daftar destinasi di dalam `main()`:

```dart
const startLat  = -8.803094;
const startLng  = 115.217775;
const startName = 'Depot';

final destinations = <Destination>[
  Destination('Pondok Deta Guest House', -8.801072, 115.219258),
  Destination('Pura Dalem Khayangan',    -8.761089, 115.221852),
  // tambah lebih banyak...
];

final result = await RoutePlanner.buildOptimalRoute(
  startLat:     startLat,
  startLng:     startLng,
  startName:    startName,
  destinations: destinations,
);
```

3. **Jalankan aplikasi**
   ```bash
   dart run
   ```

---

## 🧠 Cara Kerja

1. **Buat Daftar Titik Lengkap** — Gabungkan depot (index `0`) dengan semua titik destinasi.
2. **Satu Call OSRM** — Ambil full N×N matrix jarak & durasi via Table API (`?annotations=distance,duration`).
3. **Seleksi Greedy (Di Memory)** — Mulai dari depot, pilih titik terdekat yang belum dikunjungi menggunakan matrix yang sudah di-cache.
4. **Catat Setiap Langkah** — Setiap `RouteStep` menyimpan:
   - Jarak dan durasi dari **titik sebelumnya**
   - Jarak dan durasi dari **depot** (langsung, bukan akumulasi)
5. **Ulangi** — Sampai semua destinasi dikunjungi.

> **Kenapa 1 call, bukan N call?**
> Pendekatan lama memanggil OSRM sekali per iterasi (N call untuk N titik). Dengan matrix penuh yang diambil di awal, hasil yang sama dicapai dengan **1 call saja**, yang secara drastis mengurangi latency dan risiko rate-limit di public server gratis.

---

## 📂 Struktur Kode

| Class | Tanggung Jawab |
|---|---|
| `Destination` | Model: nama lokasi, latitude, longitude |
| `RouteStep` | Model: satu leg perjalanan — jarak dari sebelumnya, jarak dari depot, durasi |
| `FullMatrixResult` | Model: matriks 2D `distances[i][j]` dan `durations[i][j]` |
| `RoutePlanner` | Logika inti: bangun daftar titik, panggil OSRM sekali, jalankan greedy di memory |
| `OsrmService` | Layer HTTP: ambil full matrix, handle timeout, log siklus fetch |
| `RouteSimulator` | Utility: generate koordinat acak dalam radius tertentu untuk testing |

---

## 📝 Contoh Output

```
┌─────────────────────────────────────────────
│ 🌐 OSRM FETCH #1 STARTED
│    Titik   : 6 koordinat
│    URL     : https://router.project-osrm.org/table/v1/driving/...
│    Timeout : 15s
└─────────────────────────────────────────────
┌─────────────────────────────────────────────
│ ✅ OSRM FETCH #1 COMPLETED
│    Status  : 200
│    Elapsed : 843ms
│    Body    : 1247 bytes
└─────────────────────────────────────────────

╔═════════════════════════════════════════════════════╗
║          FINAL ROUTE (5 TITIK)                      ║
╚═════════════════════════════════════════════════════╝

📍 [0] Depot
       LatLng : -8.803094, 115.217775
       Status : TITIK BERANGKAT

       │
       │  🚗 189 m  •  1 menit
       │  dari: "Depot"
       ▼
📍 [1] Warung Sarita Blok J/7
       LatLng : -8.803183, 115.218979
       Jarak dari depot     : 189 m
       Jarak dari sebelumnya: 189 m

       ...

══════════════════════════════════════════════════════
📊 TOTAL JARAK  : 12840 m
⏱  TOTAL DURASI : 28 menit
🚀 OSRM CALL    : 1x
✅ Efisiensi    : 1 call untuk 5 titik
══════════════════════════════════════════════════════
```

---

## ⚠️ Keterbatasan API & Disclaimer

Project ini menggunakan **public OSRM demo server** (`router.project-osrm.org`).

- **Rate Limit** — Demo server bersifat shared dan tidak memiliki SLA. Jangan gunakan untuk production.
- **Batas Titik** — Public server dapat menangani hingga ~100 koordinat per request secara andal.
- **Penggunaan Production** — Untuk volume tinggi atau penggunaan komersial, self-host OSRM sendiri atau gunakan provider komersial (contoh: Mapbox, HERE, Google Maps Routes API).

---

## pubspec.yaml

```yaml
name: osrm_nearest_neighbor
description: Optimizer rute berbasis command-line menggunakan OSRM Table API dan heuristik Nearest Neighbor.
version: 1.0.0

environment:
  sdk: '>=2.18.0 <4.0.0'

dependencies:
  http: ^1.1.0
```
