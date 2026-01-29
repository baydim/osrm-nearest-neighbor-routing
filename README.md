
# OSRM Nearest Neighbor Routing

A Dart-based route optimization tool that calculates the most efficient path through multiple destinations using the **Nearest Neighbor** algorithm and the **OSRM (Open Source Routing Machine) Table API**.

This project solves the routing problem by iteratively finding the closest unvisited location based on real-world driving distances (not just straight-line logic), making it suitable for logistics, delivery routing, or travel planning.

## 🚀 Features

- **Real-World Distances**: Uses OSRM Table API to get actual driving distance and duration (traffic-agnostic).
- **Greedy Heuristic Algorithm**: Implements the Nearest Neighbor approach for fast calculation of "Good Enough" routes.
- **Dynamic Origin**: Calculates routing dynamically from a starting Latitude/Longitude.
- **Simulator Included**: Contains a `RouteSimulator` to generate random destination points for stress testing.
- **Clean Architecture**: Separation of concerns between Service, Logic, and Models.

## 🛠️ Prerequisites

- **Dart SDK**: Version 2.12 or higher.
- **Internet Connection**: Required to fetch data from the OSRM API.

## 📦 Installation

1. **Clone the repository**
   ```bash
   git clone [https://github.com/username/osrm-nearest-neighbor-routing.git](https://github.com/username/osrm-nearest-neighbor-routing.git)
   cd osrm-nearest-neighbor-routing

```

2. **Install Dependencies**
This project requires the `http` package.
```bash
dart pub get

```



## 💻 Usage

1. Open `main.dart` (or the file containing the code).
2. Modify the `startLat`, `startLng`, or the `destinations` list in the `main()` function to suit your needs.
3. Run the application:

```bash
dart run main.dart

```

### Example Code Snippet (main)

```dart
final destinations = <Destination>[
  Destination('Pondok Deta Guest House', -8.801072, 115.219258),
  Destination('Pura Dalem Khayangan', -8.761089, 115.221852),
  // ... add more points
];

final result = await RoutePlanner.buildOptimalRoute(
  startLat: startLat,
  startLng: startLng,
  destinations: destinations,
);

```

## 🧠 How It Works

The routing logic is encapsulated in `RoutePlanner`:

1. **Start**: The agent starts at a defined coordinate (Origin).
2. **Matrix Calculation**: The system calls OSRM to get a distance matrix from the current point to all remaining unvisited destinations.
3. **Selection**: It selects the destination with the lowest driving distance (`distanceMeters`).
4. **Update**: The selected destination becomes the new "Current Point" and is removed from the "Unvisited" list.
5. **Repeat**: Steps 2-4 are repeated until all destinations are visited.

## 📂 Code Structure

* **`Destination`**: Model class representing a location (Name, Lat, Lng).
* **`RouteStep`**: Model representing a leg of the journey (Target Destination, Distance, Duration).
* **`RoutePlanner`**: The core logic class that implements the greedy algorithm loop.
* **`OsrmService`**: Handles HTTP requests to `router.project-osrm.org`. It parses the JSON response and handles errors.
* **`RouteSimulator`**: A utility to generate random coordinates within a specific radius (useful for testing scalability).

## ⚠️ API Limitation & Disclaimer

This project uses the public OSRM demo server (`router.project-osrm.org`).

* **Rate Limits**: The demo server has usage limits. Do not use this URL for heavy production loads.
* **Production**: For commercial or high-volume usage, it is recommended to host your own OSRM instance or use a commercial routing provider.

## 📝 Example Output

```text
=== FINAL ROUTE (5 TITIK) ===

1. Warung Sarita Blok J/7
   LatLng : -8.803183, 115.218979
   Jarak  : 250 m
   Durasi : 1 menit

2. Pondok Deta Guest House
   LatLng : -8.801072, 115.219258
   Jarak  : 400 m
   Durasi : 2 menit

...

🚀 TOTAL OSRM TABLE CALL: 5

```




---

### 2. Tambahan Penting: `pubspec.yaml`

Karena kode Anda mengimport `package:http`, Anda **wajib** memiliki file `pubspec.yaml` agar orang lain bisa menjalankan kodenya. Jika belum ada, buat file bernama `pubspec.yaml` di folder yang sama dengan isi berikut:

```yaml
name: osrm_nearest_neighbor
description: A command-line application for optimized routing using OSRM.
version: 1.0.0
environment:
  sdk: '>=2.18.0 <4.0.0'

dependencies:
  http: ^1.1.0

```
