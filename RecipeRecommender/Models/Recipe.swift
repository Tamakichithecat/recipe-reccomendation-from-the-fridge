import Foundation

struct Recipe: Identifiable {
    let id = UUID()
    var name: String
    var ingredients: [IngredientRequirement]
    var steps: [String]
    var baseCost: Double
}

struct RecipeSuggestion {
    var recipe: Recipe
    var missingIngredients: [MissingIngredient]
    var store: Store?
    var totalCost: Double?
    var unavailableReason: String?
}
