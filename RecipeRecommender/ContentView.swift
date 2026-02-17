//
//  ContentView.swift
//  RecipeRecommender
//
//  Created by 岡崎隼斗 on 2026/02/17.
//

import SwiftUI
internal import Combine

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
    var pricePerIngredient: [String: Double]
}

struct RecipeSuggestion {
    var recipe: Recipe
    var missingIngredients: [IngredientRequirement]
    var store: Store?
    var totalCost: Double // baseCost + missingCost
}

// MARK: - Recipe Engine

enum RecipeEngine {
    static func suggestRecipe(availableIngredients: [Ingredient], stores: [Store]) -> RecipeSuggestion? {
        let recipes = MockData.recipes
        
        // スコア算出：現有食材でどれだけ賄えるか
        guard let bestRecipe = recipes
            .map({ recipe -> (Recipe, Int) in
                let matchCount = recipe.ingredients.filter { needed in
                    availableIngredients.contains(where: { $0.name.lowercased() == needed.name.lowercased() && $0.quantity >= needed.quantityNeeded })
                }.count
                return (recipe, matchCount)
            })
            .sorted(by: { $0.1 > $1.1 })
            .first?.0 else { return nil }
        
        // 不足食材を算出
        let missing = bestRecipe.ingredients.filter { needed in
            guard let stocked = availableIngredients.first(where: { $0.name.lowercased() == needed.name.lowercased() }) else {
                return true
            }
            return stocked.quantity < needed.quantityNeeded
        }
        
        // 最安の店舗を算出
        let store = findCheapestStore(missingIngredients: missing, stores: stores)
        let missingCost = missing.reduce(0) { partialResult, needed in
            partialResult + (store?.pricePerIngredient[needed.name] ?? 0)
        }
        
        return RecipeSuggestion(
            recipe: bestRecipe,
            missingIngredients: missing,
            store: store,
            totalCost: bestRecipe.baseCost + missingCost
        )
    }
    
    private static func findCheapestStore(missingIngredients: [IngredientRequirement], stores: [Store]) -> Store? {
        guard !missingIngredients.isEmpty else { return nil }
        
        return stores
            .map { store -> (Store, Double) in
                let cost = missingIngredients.reduce(0) { partialResult, ingredient in
                    partialResult + (store.pricePerIngredient[ingredient.name] ?? .infinity)
                }
                return (store, cost)
            }
            .filter { $0.1 != .infinity }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.distanceMinutes < $1.0.distanceMinutes
                } else {
                    return $0.1 < $1.1
                }
            }
            .first?.0
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
                "鶏もも肉": 320
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
                "味噌": 170
            ]
        )
    ]
}

// MARK: - ViewModel

final class PantryViewModel: ObservableObject {
    var objectWillChange: ObservableObjectPublisher
    
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
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let ingredient = Ingredient(name: name, quantity: quantity, unit: unit)
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
        guard let quantity = Double(ingredientQuantity) else { return }
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
                        Text("\(ingredient.name)：あと \(ingredient.quantityNeeded.clean) \(ingredient.unit)")
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
            
            Text("合計想定額：¥\(Int(suggestion.totalCost))")
                .font(.title3)
                .bold()
                .padding(.top, 8)
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

