import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    let initialCenter: CLLocationCoordinate2D

    @State private var pinCoordinate: CLLocationCoordinate2D
    @State private var cameraPosition: MapCameraPosition

    init(selectedCoordinate: Binding<CLLocationCoordinate2D?>, initialCenter: CLLocationCoordinate2D) {
        self._selectedCoordinate = selectedCoordinate
        self.initialCenter = initialCenter
        self._pinCoordinate = State(initialValue: initialCenter)
        self._cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: initialCenter,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        Marker("検索地点", coordinate: pinCoordinate)
                            .tint(.blue)
                    }
                    .onTapGesture { screenPoint in
                        if let coordinate = proxy.convert(screenPoint, from: .local) {
                            pinCoordinate = coordinate
                        }
                    }
                }

                VStack {
                    Spacer()
                    Text("地図をタップして検索地点を指定")
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("場所を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") {
                        selectedCoordinate = pinCoordinate
                        dismiss()
                    }
                }
            }
        }
    }
}
