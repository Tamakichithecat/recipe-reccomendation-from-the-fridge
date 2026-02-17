import Foundation
import Combine

final class PantryViewModel: ObservableObject {
    private let dataStore: RecipeDataStore

    @Published var availableIngredients: [Ingredient] = [
        Ingredient(name: "キャベツ", quantity: 0.25, unit: "玉"),
        Ingredient(name: "味噌", quantity: 10, unit: "g")
    ]

    @Published var suggestion: RecipeSuggestion?

    init(dataStore: RecipeDataStore = MockRecipeDataStore()) {
        self.dataStore = dataStore
    }

    func generateSuggestion() {
        suggestion = RecipeEngine.suggestRecipe(
            recipes: dataStore.recipes,
            availableIngredients: availableIngredients,
            stores: dataStore.stores
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

        availableIngredients.append(Ingredient(name: trimmedName, quantity: quantity, unit: unit))
    }

    func removeIngredients(at offsets: IndexSet) {
        availableIngredients.remove(atOffsets: offsets)
    }
}
