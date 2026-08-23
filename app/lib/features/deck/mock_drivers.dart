import "../../core/models/driver.dart";

/// Compile-time dev switch for feel-testing the swipe deck without live
/// driver heartbeats (which sweep drivers offline after 15 s). Build/run
/// with `--dart-define=USE_MOCK_DRIVERS=true`; the default build keeps the
/// untouched real flow.
const bool useMockDrivers = bool.fromEnvironment("USE_MOCK_DRIVERS");

/// Five scripted deck cards around [phnomPenhCenter], sorted by distance like
/// `GET /api/drivers/nearby` would return them. Coords are within ~2 km;
/// eta_minutes assumes ~15 km/h city moto pace. Mock ids are never booked —
/// mock mode skips the booking sheet (a mock driverId would 404).
const List<Driver> mockDrivers = [
  Driver(
    id: 9001,
    userId: 9001,
    carModel: "Honda Dream 125",
    plate: "1AB-2345",
    licenseNo: "L-90001",
    verified: true,
    online: true,
    pricePerKm: 1.20,
    lat: 11.5601,
    lng: 104.9290,
    name: "Sok Dara",
    rating: 4.9,
    distanceKm: 0.4,
    etaMinutes: 2,
  ),
  Driver(
    id: 9002,
    userId: 9002,
    carModel: "Honda Vision",
    plate: "2KH-8811",
    licenseNo: "L-90002",
    verified: true,
    online: true,
    pricePerKm: 0.95,
    lat: 11.5620,
    lng: 104.9340,
    name: "Chan Sopheak",
    rating: 4.7,
    distanceKm: 0.9,
    etaMinutes: 4,
  ),
  Driver(
    id: 9003,
    userId: 9003,
    carModel: "Yamaha Nouvo",
    plate: "1EF-9021",
    licenseNo: "L-90003",
    verified: true,
    online: true,
    pricePerKm: 1.50,
    lat: 11.5530,
    lng: 104.9160,
    name: "Kim Sreyleap",
    rating: 5.0,
    distanceKm: 1.4,
    etaMinutes: 6,
  ),
  Driver(
    id: 9004,
    userId: 9004,
    carModel: "Suzuki Smash 115",
    plate: "2LM-4567",
    licenseNo: "L-90004",
    verified: true,
    online: true,
    pricePerKm: 1.10,
    lat: 11.5400,
    lng: 104.9260,
    name: "Touch Vibol",
    rating: 4.5,
    distanceKm: 1.8,
    etaMinutes: 8,
  ),
  Driver(
    id: 9005,
    userId: 9005,
    carModel: "Honda Wave 110i",
    plate: "1NP-3388",
    licenseNo: "L-90005",
    verified: true,
    online: true,
    pricePerKm: 1.35,
    lat: 11.5585,
    lng: 104.9455,
    name: "Ngo Piseth",
    rating: 4.8,
    distanceKm: 1.9,
    etaMinutes: 8,
  ),
];
