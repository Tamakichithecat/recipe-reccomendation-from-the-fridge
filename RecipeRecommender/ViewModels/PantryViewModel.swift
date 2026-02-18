import Foundation
import Observation

@Observable
final class PantryViewModel {
    private let dataStore: any RecipeDataStore
    private let suggestionService: any RecipeSuggestionService

    var availableIngredients: [Ingredient] = []

    var suggestion: RecipeSuggestion?
    var isLoading = false
    var errorMessage: String?

    init(
        dataStore: any RecipeDataStore = MockRecipeDataStore(),
        suggestionService: any RecipeSuggestionService = OpenAIRecipeSuggestionService()
    ) {
        self.dataStore = dataStore
        self.suggestionService = suggestionService
    }

    @MainActor
    func generateSuggestion() async {
        isLoading = true
        errorMessage = nil

        do {
            suggestion = try await suggestionService.suggestRecipe(
                availableIngredients: availableIngredients,
                stores: dataStore.stores
            )
        } catch {
            suggestion = RecipeEngine.suggestRecipe(
                recipes: dataStore.recipes,
                availableIngredients: availableIngredients,
                stores: dataStore.stores
            )
            errorMessage = "OpenAI API失敗（\(error.localizedDescription)）。ローカル計算で提案しました。"
        }

        isLoading = false
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
        for index in offsets.sorted().reversed() {
            availableIngredients.remove(at: index)
        }
    }

    func reset() {
        availableIngredients = []
        suggestion = nil
        errorMessage = nil
    }
}
