import SwiftUI
import MapKit

struct NearbyStoreSearchView: View {
    @State private var locationManager = LocationManager()
    @State private var searchRadiusText = "500"
    @State private var nearbyStores: [NearbyStore] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            mapSection
            listSection
        }
        .navigationTitle("最寄りのスーパー検索")
        .onAppear {
            locationManager.requestPermission()
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(nearbyStores) { store in
                Marker(store.name, coordinate: store.coordinate)
                    .tint(.red)
            }
        }
        .frame(height: 300)
    }

    // MARK: - List

    private var listSection: some View {
        List {
            searchSettingsSection
            locationStatusSection
            if hasSearched {
                searchResultsSection
            }
        }
    }

    // MARK: - Search Settings

    private var searchSettingsSection: some View {
        Section(header: Text("検索設定")) {
            HStack {
                Text("検索範囲")
                Spacer()
                TextField("半径", text: $searchRadiusText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("m")
            }

            Button {
                searchStores()
            } label: {
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("スーパーを検索", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSearching || locationManager.currentLocation == nil)
        }
    }

    // MARK: - Location Status

    @ViewBuilder
    private var locationStatusSection: some View {
        if locationManager.currentLocation == nil {
            Section {
                switch locationManager.authorizationStatus {
                case .notDetermined:
                    Button("位置情報の使用を許可") {
                        locationManager.requestPermission()
                    }
                case .denied, .restricted:
                    Label(
                        "位置情報の使用が許可されていません。設定アプリから許可してください。",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundColor(.orange)
                default:
                    ProgressView("位置情報を取得中...")
                }
            }
        }

        if let error = locationManager.locationError {
            Section {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        Section(header: Text("検索結果（\(nearbyStores.count)件）")) {
            if nearbyStores.isEmpty {
                Text("指定範囲内にスーパーが見つかりませんでした")
                    .foregroundColor(.secondary)
            } else {
                ForEach(nearbyStores) { store in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.name)
                            .font(.headline)
                        if let address = store.address {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 16) {
                            Label("\(Int(store.distance))m", systemImage: "location.fill")
                            Label("徒歩約\(store.walkingMinutes)分", systemImage: "figure.walk")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Actions

    private func searchStores() {
        guard let location = locationManager.currentLocation,
              let radius = Double(searchRadiusText), radius > 0 else { return }

        isSearching = true
        Task {
            let stores = await StoreSearchService.searchNearbyStores(
                center: location.coordinate,
                radiusMeters: radius
            )
            nearbyStores = stores
            isSearching = false
            hasSearched = true
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: radius * 2.5,
                    longitudinalMeters: radius * 2.5
                )
            )
        }
    }
}
