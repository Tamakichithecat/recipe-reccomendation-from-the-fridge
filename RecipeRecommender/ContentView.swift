//
//  ContentView.swift
//  RecipeRecommender
//
//  Created by 岡崎隼斗 on 2026/02/17.
//

import SwiftUI
import Combine

// MARK: - Models

struct Ingredient: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unit: String
}

struct IngredientRequirement: Identifiable {
    let id = UUID()
    var name: String
    var quantityNeeded: Double
    var unit: String
}

struct MissingIngredient: Identifiable {
    let id = UUID()
    var name: String
    var requiredQuantity: Double
    var currentQuantity: Double
    var shortageQuantity: Double
    var unit: String
}

struct Recipe: Identifiable {
    let id = UUID()
    var name: String
    var ingredients: [IngredientRequirement]
    var steps: [String]
    var baseCost: Double // 既に家にある材料で完結する場合の最低コスト
}

struct Store: Identifiable {
    let id = UUID()
    var name: String
    var distanceMinutes: Int
    var pricePerIngredient: [String: Double] // 必要単位あたりの価格として扱う
}

struct RecipeSuggestion {
    var recipe: Recipe
    var missingIngredients: [MissingIngredient]
    var store: Store?
    var totalCost: Double?
    var unavailableReason: String?
}

private struct RecipeEvaluation {
    var recipe: Recipe
    var missingIngredients: [MissingIngredient]
    var store: Store?
    var totalCost: Double?
    var unavailableReason: String?

    var isPurchasable: Bool {
        missingIngredients.isEmpty || store != nil
    }
}

// MARK: - Recipe Engine

enum RecipeEngine {
    static func suggestRecipe(availableIngredients: [Ingredient], stores: [Store]) -> RecipeSuggestion? {
        let recipes = MockData.recipes

        let evaluations = recipes.map { evaluate(recipe: $0, availableIngredients: availableIngredients, stores: stores) }

        let purchasable = evaluations
            .filter { $0.isPurchasable }
            .sorted { lhs, rhs in
                let lhsCost = lhs.totalCost ?? .infinity
                let rhsCost = rhs.totalCost ?? .infinity

                if lhsCost == rhsCost {
                    let lhsDistance = lhs.store?.distanceMinutes ?? 0
                    let rhsDistance = rhs.store?.distanceMinutes ?? 0
                    return lhsDistance < rhsDistance
                }

                return lhsCost < rhsCost
            }

        if let best = purchasable.first {
            return RecipeSuggestion(
                recipe: best.recipe,
                missingIngredients: best.missingIngredients,
                store: best.store,
                totalCost: best.totalCost,
                unavailableReason: nil
            )
        }

        guard let fallback = evaluations.first else { return nil }
        return RecipeSuggestion(
            recipe: fallback.recipe,
            missingIngredients: fallback.missingIngredients,
            store: nil,
            totalCost: nil,
            unavailableReason: "不足食材をすべて購入できる店舗が見つかりません。"
        )
    }

    private static func evaluate(recipe: Recipe, availableIngredients: [Ingredient], stores: [Store]) -> RecipeEvaluation {
        let missing = missingIngredients(for: recipe, availableIngredients: availableIngredients)

        if missing.isEmpty {
            return RecipeEvaluation(
                recipe: recipe,
                missingIngredients: [],
                store: nil,
                totalCost: recipe.baseCost,
                unavailableReason: nil
            )
        }

        let (store, missingCost) = findCheapestStore(missingIngredients: missing, stores: stores)

        guard let selectedStore = store, let purchaseCost = missingCost else {
            return RecipeEvaluation(
                recipe: recipe,
                missingIngredients: missing,
                store: nil,
                totalCost: nil,
                unavailableReason: "不足食材をすべて購入できる店舗が見つかりません。"
            )
        }

        return RecipeEvaluation(
            recipe: recipe,
            missingIngredients: missing,
            store: selectedStore,
            totalCost: recipe.baseCost + purchaseCost,
            unavailableReason: nil
        )
    }

    private static func missingIngredients(for recipe: Recipe, availableIngredients: [Ingredient]) -> [MissingIngredient] {
        recipe.ingredients.compactMap { needed in
            let stocked = pantryQuantity(for: needed, in: availableIngredients)
            let shortage = max(0, needed.quantityNeeded - stocked)
            guard shortage > 0 else { return nil }

            return MissingIngredient(
                name: needed.name,
                requiredQuantity: needed.quantityNeeded,
                currentQuantity: stocked,
                shortageQuantity: shortage,
                unit: needed.unit
            )
        }
    }

    private static func pantryQuantity(for requirement: IngredientRequirement, in ingredients: [Ingredient]) -> Double {
        ingredients
            .filter {
                $0.name.caseInsensitiveCompare(requirement.name) == .orderedSame
                && $0.unit.caseInsensitiveCompare(requirement.unit) == .orderedSame
            }
            .reduce(0) { $0 + $1.quantity }
    }

    private static func findCheapestStore(missingIngredients: [MissingIngredient], stores: [Store]) -> (Store?, Double?) {
        guard !missingIngredients.isEmpty else { return (nil, 0) }

        let candidates = stores.compactMap { store -> (Store, Double)? in
            var total = 0.0
            for ingredient in missingIngredients {
                guard let unitPrice = store.pricePerIngredient[ingredient.name] else {
                    return nil
                }
                total += unitPrice * ingredient.shortageQuantity
            }
            return (store, total)
        }

        let best = candidates.sorted {
            if $0.1 == $1.1 {
                return $0.0.distanceMinutes < $1.0.distanceMinutes
            }
            return $0.1 < $1.1
        }.first

        return (best?.0, best?.1)
    }
}

// MARK: - Mock Data

enum MockData {
    static let recipes: [Recipe] = [
        Recipe(
            name: "野菜たっぷり味噌汁",
            ingredients: [
                IngredientRequirement(name: "大根", quantityNeeded: 0.5, unit: "本"),
                IngredientRequirement(name: "にんじん", quantityNeeded: 1, unit: "本"),
                IngredientRequirement(name: "豆腐", quantityNeeded: 0.5, unit: "丁"),
                IngredientRequirement(name: "味噌", quantityNeeded: 30, unit: "g")
            ],
            steps: [
                "野菜を食べやすい大きさに切る",
                "鍋で煮てから味噌を溶く"
            ],
            baseCost: 120
        ),
        Recipe(
            name: "鶏肉とキャベツの炒め物",
            ingredients: [
                IngredientRequirement(name: "鶏もも肉", quantityNeeded: 200, unit: "g"),
                IngredientRequirement(name: "キャベツ", quantityNeeded: 0.5, unit: "玉"),
                IngredientRequirement(name: "醤油", quantityNeeded: 15, unit: "ml")
            ],
            steps: [
                "材料を切り、鶏肉から炒める",
                "キャベツを加えて味付け"
            ],
            baseCost: 250
        )
    ]

    static let stores: [Store] = [
        Store(
            name: "スーパーA",
            distanceMinutes: 6,
            pricePerIngredient: [
                "にんじん": 80,
                "豆腐": 90,
                "味噌": 150,
                "鶏もも肉": 320,
                "大根": 120,
                "醤油": 10
            ]
        ),
        Store(
            name: "スーパーB",
            distanceMinutes: 3,
            pricePerIngredient: [
                "にんじん": 70,
                "キャベツ": 150,
                "豆腐": 100,
                "鶏もも肉": 330,
                "味噌": 170,
                "大根": 110,
                "醤油": 12
            ]
        )
    ]
}

// MARK: - ViewModel

final class PantryViewModel: ObservableObject {
    @Published var availableIngredients: [Ingredient] = [
        Ingredient(name: "キャベツ", quantity: 0.25, unit: "玉"),
        Ingredient(name: "味噌", quantity: 10, unit: "g")
    ]
    @Published var suggestion: RecipeSuggestion?

    func generateSuggestion() {
        suggestion = RecipeEngine.suggestRecipe(
            availableIngredients: availableIngredients,
            stores: MockData.stores
        )
    }

    func addIngredient(name: String, quantity: Double, unit: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, quantity.isFinite, quantity > 0 else { return }

        if let existingIndex = availableIngredients.firstIndex(where: {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
            && $0.unit.caseInsensitiveCompare(unit) == .orderedSame
        }) {
            availableIngredients[existingIndex].quantity += quantity
            return
        }

        let ingredient = Ingredient(name: trimmedName, quantity: quantity, unit: unit)
        availableIngredients.append(ingredient)
    }

    func removeIngredients(at offsets: IndexSet) {
        availableIngredients.remove(atOffsets: offsets)
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var viewModel = PantryViewModel()
    @State private var ingredientName = ""
    @State private var ingredientQuantity = ""
    @State private var ingredientUnit = "g"

    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("冷蔵庫の食材")) {
                        ForEach(viewModel.availableIngredients) { ingredient in
                            VStack(alignment: .leading) {
                                Text("\(ingredient.name)")
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
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            HStack {
                                TextField("数量", text: $ingredientQuantity)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())

                                Picker("単位", selection: $ingredientUnit) {
                                    ForEach(["g", "本", "玉", "丁", "ml"], id: \.self) { unit in
                                        Text(unit).tag(unit)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
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

struct RecipeSuggestionView: View {
    let suggestion: RecipeSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text("提案レシピ")
                .font(.title2)
                .bold()
            Text(suggestion.recipe.name)
                .font(.title3)

            Text("作り方")
                .font(.headline)
            ForEach(Array(suggestion.recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .bold()
                    Text(step)
                }
            }

            if suggestion.missingIngredients.isEmpty {
                Label("追加購入なしで作れます！", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("不足食材")
                        .font(.headline)
                    ForEach(suggestion.missingIngredients) { ingredient in
                        Text("\(ingredient.name)：必要 \(ingredient.requiredQuantity.clean) \(ingredient.unit) / 保有 \(ingredient.currentQuantity.clean) \(ingredient.unit) / 不足 \(ingredient.shortageQuantity.clean) \(ingredient.unit)")
                    }

                    if let store = suggestion.store {
                        HStack {
                            Image(systemName: "cart.fill")
                            Text("購入先：\(store.name)（徒歩約\(store.distanceMinutes)分）")
                        }
                        .padding(.top, 8)
                    }
                }
            }

            if let reason = suggestion.unavailableReason {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }

            if let totalCost = suggestion.totalCost {
                Text("合計想定額：¥\(Int(totalCost))")
                    .font(.title3)
                    .bold()
                    .padding(.top, 8)
            } else {
                Text("合計想定額：算出不可")
                    .font(.title3)
                    .bold()
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding([.horizontal, .bottom])
    }
}

// MARK: - Helpers

extension Double {
    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", self)
        : String(self)
    }
}
