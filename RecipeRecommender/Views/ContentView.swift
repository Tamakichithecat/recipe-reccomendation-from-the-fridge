import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(LocationManager.self) private var locationManager
    @State private var viewModel = PantryViewModel()
    @State private var ingredientName = ""
    @State private var ingredientQuantity = ""
    @State private var ingredientUnit = "g"
    @State private var navigateToSuggestion = false

    // スーパー検索範囲の設定
    @State private var searchRadiusText = "500"
    @State private var customCoordinate: CLLocationCoordinate2D?
    @State private var isShowingLocationPicker = false

    private var searchCenter: CLLocationCoordinate2D? {
        customCoordinate ?? locationManager.currentLocation?.coordinate
    }

    private var searchLocationLabel: String {
        customCoordinate != nil ? "指定した場所" : "現在位置"
    }

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    storeSearchSection
                    ingredientListSection
                    addIngredientSection
                }

                Button {
                    Task {
                        await viewModel.generateSuggestion()
                        navigateToSuggestion = true
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("最安レシピを提案")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading || viewModel.availableIngredients.isEmpty)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("今日の最安メニュー")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        NearbyStoreSearchView()
                    } label: {
                        Label("最寄りスーパー", systemImage: "map")
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToSuggestion) {
                if let suggestion = viewModel.suggestion {
                    RecipeSuggestionView(
                        suggestion: suggestion,
                        ingredients: viewModel.availableIngredients,
                        errorMessage: viewModel.errorMessage
                    ) {
                        viewModel.reset()
                        navigateToSuggestion = false
                    }
                }
            }
            .sheet(isPresented: $isShowingLocationPicker) {
                if let center = searchCenter {
                    LocationPickerView(
                        selectedCoordinate: $customCoordinate,
                        initialCenter: center
                    )
                }
            }
        }
    }

    // MARK: - スーパー検索範囲

    private var storeSearchSection: some View {
        Section(header: Text("スーパー検索範囲")) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.blue)
                Text("\(searchLocationLabel)から半径")
                TextField("m", text: $searchRadiusText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                Text("m以内")
            }
            .font(.subheadline)

            HStack(spacing: 12) {
                Button {
                    isShowingLocationPicker = true
                } label: {
                    Label("場所を地図で指定", systemImage: "map")
                        .font(.subheadline)
                }
                .disabled(searchCenter == nil)

                if customCoordinate != nil {
                    Button {
                        customCoordinate = nil
                    } label: {
                        Label("現在位置に戻す", systemImage: "location.fill")
                            .font(.subheadline)
                    }
                    .tint(.secondary)
                }
            }

            if locationManager.authorizationStatus == .denied
                || locationManager.authorizationStatus == .restricted {
                Label(
                    "位置情報が許可されていません。設定アプリから許可してください。",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
    }

    // MARK: - 冷蔵庫の食材

    private var ingredientListSection: some View {
        Section(header: Text("冷蔵庫の食材")) {
            ForEach(viewModel.availableIngredients) { ingredient in
                VStack(alignment: .leading) {
                    Text(ingredient.name)
                        .font(.headline)
                    Text("\(ingredient.quantity.clean) \(ingredient.unit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete(perform: viewModel.removeIngredients)
        }
    }

    // MARK: - 食材の追加

    private var addIngredientSection: some View {
        Section(header: Text("食材の追加")) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("食材名（例：にんじん）", text: $ingredientName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("数量", text: $ingredientQuantity)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    Picker("単位", selection: $ingredientUnit) {
                        ForEach(["g", "本", "玉", "丁", "ml"], id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Button(action: addIngredient) {
                    Label("食材を追加", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Actions

    private func addIngredient() {
        guard let quantity = Double(ingredientQuantity), quantity > 0 else { return }
        viewModel.addIngredient(name: ingredientName, quantity: quantity, unit: ingredientUnit)
        ingredientName = ""
        ingredientQuantity = ""
    }
}
