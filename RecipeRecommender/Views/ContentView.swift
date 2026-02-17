import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PantryViewModel()
    @State private var ingredientName = ""
    @State private var ingredientQuantity = ""
    @State private var ingredientUnit = "g"

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
                    viewModel.generateSuggestion()
                } label: {
                    Text("最安レシピを提案")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .buttonStyle(.borderedProminent)

                if let suggestion = viewModel.suggestion {
                    RecipeSuggestionView(suggestion: suggestion)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: suggestion.recipe.id)
                } else {
                    Text("最安レシピを表示するにはボタンを押してください")
                        .foregroundColor(.secondary)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("今日の最安メニュー")
        }
    }

    private func addIngredient() {
        guard let quantity = Double(ingredientQuantity), quantity > 0 else { return }
        viewModel.addIngredient(name: ingredientName, quantity: quantity, unit: ingredientUnit)
        ingredientName = ""
        ingredientQuantity = ""
    }
}
