import SwiftUI

struct ContentView: View {
    @State private var viewModel = PantryViewModel()
    @State private var ingredientName = ""
    @State private var ingredientQuantity = ""
    @State private var ingredientUnit = "g"
    @State private var navigateToSuggestion = false

    var body: some View {
        NavigationStack {
            VStack {
                List {
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
        }
    }

    private func addIngredient() {
        guard let quantity = Double(ingredientQuantity), quantity > 0 else { return }
        viewModel.addIngredient(name: ingredientName, quantity: quantity, unit: ingredientUnit)
        ingredientName = ""
        ingredientQuantity = ""
    }
}
