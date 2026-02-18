import Foundation
import CoreLocation
import MapKit

struct NearbyStore: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let walkingMinutes: Int
    let address: String?
}

enum StoreSearchService {
    /// MapKit の MKLocalSearch を使って指定範囲内のスーパーマーケットを検索する。
    /// Google Maps Places API など外部APIへの差し替えも、この関数のシグネチャを維持すれば可能。
    static func searchNearbyStores(
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async throws -> [NearbyStore] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "スーパーマーケット"
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        let userLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return response.mapItems
            .map { item -> NearbyStore in
                let storeLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = userLocation.distance(from: storeLocation)
                let walkingMinutes = max(1, Int(ceil(distance / 80.0))) // 徒歩速度 約80m/分

                return NearbyStore(
                    name: item.name ?? "不明な店舗",
                    coordinate: item.placemark.coordinate,
                    distance: distance,
                    walkingMinutes: walkingMinutes,
                    address: item.placemark.title
                )
            }
            .filter { $0.distance <= radiusMeters }
            .sorted { $0.distance < $1.distance }
    }
}
